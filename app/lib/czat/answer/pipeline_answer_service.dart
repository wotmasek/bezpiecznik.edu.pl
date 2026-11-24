/// The answer pipeline, one pass (docs/03-architecture/overview.md):
/// safety -> retrieval (never a gate) -> one Polish prompt on the live
/// conversation of the chat -> free markdown -> panels. The model always
/// answers; source quotes only when it is off, failing or timing out.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../paczki/pack_controller.dart';
import '../../profil/profile_store.dart';
import '../../ratunek/detect/risk_detector.dart';
import '../../ustawienia/settings_store.dart';
import '../intent/shelter_intent.dart' show isAlarmQuickAction;
import '../llm/llm_engine.dart';
import '../llm/llm_engine_off.dart';
import '../llm/llm_provider.dart';
import '../retrieval/retrieval_provider.dart';
import '../retrieval/retriever.dart';
import '../templates/panel_model.dart';
import '../ui/answer_service.dart';
import 'answer_builder.dart';
import 'answer_prompt.dart';
import 'conversation.dart';

typedef SearchFn = Future<RetrievalResult> Function(String question);

const bool _chatLog = bool.fromEnvironment('CHAT_LOG');

/// Retrieval / prompt query for the "Alarm / schron" quick action.
const String kAlarmQuery = 'sygnały alarmowe syreny alarm schron';

AssistantAnswer _withShelterMap(AssistantAnswer a) => a.copyWith(
  panels: [
    ...a.panels,
    const MapPanel(
      target: 'nearest_shelter',
      raw: {'type': 'map', 'target': 'nearest_shelter'},
    ),
  ],
);

class PipelineAnswerService implements AnswerService {
  PipelineAnswerService({
    required this.search,
    required this.engine,
    required this.isRisk,
    this.profileContext,
    this.noAi,
    this.modelNote,
    this.onLog,
  });

  final SearchFn search;
  final LlmEngine engine;

  /// Risk phrase check on the user's question only (never on model output).
  final FutureOr<bool> Function(String question) isRisk;

  /// Compact profile context for the prompt; empty / null when unavailable.
  final Future<String> Function()? profileContext;

  /// "Tryb bez AI", asked once per request (the setting may still be loading
  /// at a cold start). When true the model is never called: source quotes only.
  final Future<bool> Function()? noAi;

  /// Why the model is not available right now (e.g. still downloading), shown
  /// under the source quotes; null when there is nothing to explain.
  final String? Function()? modelNote;

  /// Diagnostics; no user data beyond the question and the model output.
  final void Function(String message)? onLog;

  /// The exact messages fed to the model per chat (live conversation): user
  /// turns are snippet block + question, assistant turns the raw model text.
  /// ponytail: in memory only, rebuilt from the chat history after a restart.
  final Map<String, List<LlmMessage>> _transcripts = {};

  /// The system prompt each live chat started with: kept for the whole chat
  /// (a profile edit applies from the next chat), so the prefix stays exact.
  final Map<String, String> _systems = {};

  /// Transcript of [chatId] as the next request will see it (tests).
  List<LlmMessage> transcriptOf(String chatId) => List.unmodifiable(_transcripts[chatId] ?? const []);

  @override
  Stream<AnswerEvent> answer(String question, ChatContext ctx) {
    final run = _Run(engine);
    late final StreamController<AnswerEvent> out;
    out = StreamController<AnswerEvent>(
      onListen: () => unawaited(_execute(question, ctx, run, out)),
      onCancel: run.cancel,
    );
    return out.stream;
  }

  Future<void> _execute(
    String question,
    ChatContext ctx,
    _Run run,
    StreamController<AnswerEvent> out,
  ) async {
    void emit(AnswerEvent e) {
      if (!run.cancelled && !out.isClosed) out.add(e);
    }

    var risk = false;
    var crisis = false;
    try {
      if (await _noAiMode()) run.engine = OffEngine();
      if (run.cancelled) return;
      emit(const AnswerThinking(ThinkingPhase.searching));
      // "Alarm / schron" quick action: ask for the alarm signals and add the
      // nearest-shelter map card to whatever the answer gives.
      final alarm = isAlarmQuickAction(question);
      if (alarm) question = kAlarmQuery;
      // A personal crisis (suicidal thoughts, self-harm, panic) is a risk turn
      // that never goes to the guides: the keyword search turned "atak
      // paniki" into an air-raid evacuation.
      crisis = !alarm && isCrisis(question);
      // Risk first: a pipeline error below must still be able to show 112.
      risk = crisis || await isRisk(question);
      if (run.cancelled) return;
      // Show 112 now, not after the model (owner rule).
      if (risk) emit(const AnswerThinking(ThinkingPhase.searching, true));

      final result = crisis ? null : await _retrieve(question, ctx);
      if (run.cancelled) return;
      final chunks = result != null && result.decision == RetrievalDecision.found
          ? result.chunks.take(kMaxPromptChunks).toList()
          : const <KbChunk>[];

      emit(AnswerThinking(ThinkingPhase.composing, risk));
      final profile = await _profile();
      if (run.cancelled) return;

      final answer = await _compose(
        question: question,
        ctx: ctx,
        profile: profile,
        chunks: chunks,
        offTopic: result?.decision == RetrievalDecision.offTopic,
        risk: risk,
        crisis: crisis,
        run: run,
      );
      if (answer != null) emit(AnswerReady(alarm ? _withShelterMap(answer) : answer));
    } catch (e) {
      // Retrieval or an unexpected bug: never crash the chat.
      onLog?.call('pipeline error: $e');
      // Never lose the 112 block for a risk phrase because of an error.
      if (crisis) {
        emit(AnswerReady(buildChatReply(kCrisisFallback, crisis: true)));
      } else if (risk) {
        emit(AnswerReady(buildRefusal(NoSourceKind.noSource, risk: true)));
      } else {
        emit(const AnswerFailed('Nie udało się przygotować odpowiedzi. Spróbuj ponownie.'));
      }
    } finally {
      if (!out.isClosed) await out.close();
    }
  }

  /// Search on every turn. A follow-up ("a ile wody?") is searched together
  /// with the previous question; so is a short question that finds nothing
  /// on its own.
  Future<RetrievalResult> _retrieve(String question, ChatContext ctx) async {
    final previous = ctx.previousQuestion?.trim() ?? '';
    final withPrevious = previous.isEmpty ? null : '$previous $question';
    var result = await search(
      withPrevious != null && isFollowUp(question) ? withPrevious : question,
    );
    if (withPrevious != null &&
        result.decision != RetrievalDecision.found &&
        question.trim().split(RegExp(r'\s+')).length <= 5) {
      final retry = await search(withPrevious);
      if (retry.decision == RetrievalDecision.found) result = retry;
    }
    return result;
  }

  Future<bool> _noAiMode() async {
    try {
      return await noAi?.call() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String> _profile() async {
    try {
      return await profileContext?.call() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// The transcript of [ctx.chatId], or one rebuilt from the chat history
  /// (app restart): not byte-identical, so the engine reopens once.
  List<LlmMessage> _transcript(ChatContext ctx) =>
      _transcripts[ctx.chatId] ??
      [
        for (final t in ctx.history)
          t.user ? LlmMessage.user('Pytanie: ${t.text.trim()}') : LlmMessage.assistant(t.text.trim()),
      ];

  /// What the user sees without the model: quotes when there are sources,
  /// the caring crisis text, else the calm refusal.
  AssistantAnswer _fallback(
    List<KbChunk> chunks, {
    required bool risk,
    required bool crisis,
    required bool offTopic,
    required bool modelOff,
    String? note,
  }) {
    if (crisis) return buildChatReply(kCrisisFallback, crisis: true);
    if (chunks.isEmpty) {
      return buildRefusal(offTopic && !risk ? NoSourceKind.offTopic : NoSourceKind.noSource, risk: risk);
    }
    return buildQuoteFallback(chunks, risk: risk, modelOff: modelOff, note: note);
  }

  /// One model pass on the live conversation. Null when cancelled.
  Future<AssistantAnswer?> _compose({
    required String question,
    required ChatContext ctx,
    required String profile,
    required List<KbChunk> chunks,
    required bool offTopic,
    required bool risk,
    required bool crisis,
    required _Run run,
  }) async {
    final system = _systems[ctx.chatId] ?? answerSystemPrompt(profile: profile);
    // The crisis note goes with the turn, not the system prompt, so the
    // conversation prefix stays the same.
    final user = LlmMessage.user(
      '${snippetMessage(question, chunks)}${crisis ? '\n$kCrisisPromptNote' : ''}',
    );
    final past = trimTranscript(system, _transcript(ctx), user);
    final req = buildAnswerRequest(
      system: system,
      messages: [...past, user],
      chatId: ctx.chatId,
    );
    final String text;
    try {
      text = await run.collect(req);
    } catch (e) {
      if (run.cancelled) return null;
      onLog?.call('llm unavailable: $e');
      return _fallback(
        chunks,
        risk: risk,
        crisis: crisis,
        offTopic: offTopic,
        modelOff: true,
        note: e is LlmTimeout ? kLlmTimeoutNote : modelNote?.call(),
      );
    }
    if (run.cancelled) return null;
    final answer = text.trim().isEmpty ? null : buildMarkdownAnswer(text, chunks, risk: risk, crisis: crisis);
    if (answer == null || answer.panels.every((p) => p is CallPanel)) {
      onLog?.call('empty model output');
      return _fallback(chunks, risk: risk, crisis: crisis, offTopic: offTopic, modelOff: false);
    }
    // Byte-for-byte the streamed text: anything else reopens the conversation.
    _transcripts[ctx.chatId] = [...past, user, LlmMessage.assistant(text)];
    _systems[ctx.chatId] = system;
    return answer;
  }
}

/// State of one answer: cancellation and the running LLM subscription.
class _Run {
  _Run(this.engine);

  LlmEngine engine;
  bool cancelled = false;
  StreamSubscription<String>? _sub;
  Completer<String>? _pending;

  /// Collects the whole generation. Completes with '' when cancelled.
  Future<String> collect(LlmRequest req) {
    final done = Completer<String>();
    _pending = done;
    final buf = StringBuffer();
    _sub = engine.generate(req).listen(
      (t) => buf.write(t),
      onError: (Object e, StackTrace st) {
        if (!done.isCompleted) done.completeError(e, st);
      },
      onDone: () {
        if (!done.isCompleted) done.complete(buf.toString());
      },
      cancelOnError: true,
    );
    return done.future;
  }

  Future<void> cancel() async {
    if (cancelled) return;
    cancelled = true;
    final sub = _sub;
    _sub = null;
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete('');
    await sub?.cancel();
    await engine.cancel();
  }
}

/// Loads the risk detector from the bundled phrase assets.
final answerRiskDetectorProvider = FutureProvider<RiskDetector>(
  (ref) => RiskDetector.load(rootBundle),
);

/// The pipeline wired to the real providers. The coordinator points
/// `answerServiceProvider` at this.
final pipelineAnswerServiceProvider = Provider<AnswerService>((ref) {
  return PipelineAnswerService(
    search: (q) async => (await ref.read(retrieverProvider.future)).search(q),
    engine: ref.watch(llmEngineProvider),
    // "Tryb bez AI" (opt-in): awaits the settings so the first question after
    // a cold start already honours it.
    noAi: () async => (await ref.read(settingsProvider.future)).noAiMode,
    modelNote: () => modelPendingNote(ref.read(packsProvider)),
    // Diagnostics for test builds only (`--dart-define=CHAT_LOG=true`): the
    // log holds the question and raw model output, so it is off by default.
    onLog: _chatLog ? (m) => debugPrint('[czat] $m') : null,
    isRisk: (q) async {
      try {
        return (await ref.read(answerRiskDetectorProvider.future)).isRisk(q);
      } catch (_) {
        return false;
      }
    },
    profileContext: () async =>
        (await ref.read(profileProvider.future)).toPromptContext(),
  );
});
