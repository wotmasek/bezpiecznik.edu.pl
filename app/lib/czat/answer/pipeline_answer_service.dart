/// The real answer pipeline: retrieval -> prompt -> LLM -> tolerant parse
/// (1 retry) -> validation -> panels. AI is always on; the model only
/// rephrases retrieved chunks, never answers from its own knowledge.
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
import 'answer_parser.dart';
import 'answer_prompt.dart';
import 'answer_validator.dart';
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
    AnswerValidator? validator,
    this.onLog,
  }) : validator = validator ?? AnswerValidator();

  final SearchFn search;
  final LlmEngine engine;

  /// Risk phrase check on the user's question only (never on model output).
  final FutureOr<bool> Function(String question) isRisk;

  /// Compact profile context for the prompt; empty / null when unavailable.
  final Future<String> Function()? profileContext;
  final AnswerValidator validator;

  /// "Tryb bez AI", asked once per request (the setting may still be loading
  /// at a cold start). When true the model is never called: source quotes only.
  final Future<bool> Function()? noAi;

  /// Why the model is not available right now (e.g. still downloading), shown
  /// under the source quotes; null when there is nothing to explain.
  final String? Function()? modelNote;

  /// Diagnostics (rejected items, retries); no user data beyond the question.
  final void Function(String message)? onLog;

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
    try {
      if (await _noAiMode()) run.engine = OffEngine();
      if (run.cancelled) return;
      emit(const AnswerThinking(ThinkingPhase.searching));
      // "Alarm / schron" quick action: ask for the alarm signals and add the
      // nearest-shelter map card to whatever the sources give.
      final alarm = isAlarmQuickAction(question);
      if (alarm) question = kAlarmQuery;
      // A personal crisis (suicidal thoughts, self-harm, panic) never goes to
      // the guides: a caring reply with 116 123 and the pinned 112.
      if (!alarm && isCrisis(question)) {
        risk = true;
        emit(const AnswerThinking(ThinkingPhase.composing, true));
        final talk = await _chat(question, ctx, run, crisis: true);
        if (run.cancelled) return;
        emit(AnswerReady(talk ?? buildChatReply(kCrisisFallback, crisis: true)));
        return;
      }
      // Risk first: a pipeline error below must still be able to show 112.
      risk = await isRisk(question);
      if (run.cancelled) return;
      // Show 112 now, not after the model (owner rule): the final answer
      // starts with the same `call` panel.
      if (risk) emit(const AnswerThinking(ThinkingPhase.searching, true));
      // Feelings, thanks, questions about the assistant or the profile: talk,
      // even when the sentence shares words with the guides ("mama", "dom").
      final talkFirst = !risk && !alarm && isTalk(question);
      if (talkFirst) {
        emit(const AnswerThinking(ThinkingPhase.composing));
        final talk = await _chat(question, ctx, run);
        if (run.cancelled) return;
        if (talk != null) {
          emit(AnswerReady(talk));
          return;
        }
      }
      // A follow-up ("a ile wody?") is searched together with the previous
      // question; so is a short question that finds nothing on its own.
      final previous = ctx.previousQuestion?.trim() ?? '';
      final withPrevious = previous.isEmpty ? null : '$previous $question';
      var result = await search(
        withPrevious != null && isFollowUp(question) ? withPrevious : question,
      );
      if (run.cancelled) return;
      if (withPrevious != null &&
          result.decision != RetrievalDecision.found &&
          question.trim().split(RegExp(r'\s+')).length <= 5) {
        final retry = await search(withPrevious);
        if (run.cancelled) return;
        if (retry.decision == RetrievalDecision.found) result = retry;
      }

      if (result.decision != RetrievalDecision.found || result.chunks.isEmpty) {
        // A risk phrase is never "off topic" (the risk detector tolerates
        // typos the domain gate does not, e.g. "pazar"): refuse as noSource,
        // which carries the 112 call panel.
        final kind = result.decision == RetrievalDecision.offTopic && !risk
            ? NoSourceKind.offTopic
            : NoSourceKind.noSource;
        // Owner 08:33: off-topic small talk gets a short warm reply (no facts),
        // labelled as not from the guides. So does a sentence with no source
        // in the middle of a conversation ("ona uważa, że za mało pomagam").
        // Any failure: the refusal.
        final talkInstead = !risk &&
            !alarm &&
            !talkFirst &&
            (kind == NoSourceKind.offTopic || ctx.inConversation);
        if (talkInstead) {
          emit(const AnswerThinking(ThinkingPhase.composing));
          final talk = await _chat(question, ctx, run);
          if (run.cancelled) return;
          if (talk != null) {
            emit(AnswerReady(talk));
            return;
          }
        }
        final refusal = buildRefusal(kind, risk: risk);
        emit(AnswerReady(alarm ? _withShelterMap(refusal) : refusal));
        return;
      }

      final chunks = result.chunks;
      emit(AnswerThinking(ThinkingPhase.composing, risk));
      final ctxText = await _profile();
      if (run.cancelled) return;

      final answer = await _compose(
        question: question,
        previous: ctx.previousQuestion,
        profile: ctxText,
        chunks: chunks,
        risk: risk,
        run: run,
      );
      if (answer != null) emit(AnswerReady(alarm ? _withShelterMap(answer) : answer));
    } catch (e) {
      // Retrieval or an unexpected bug: never crash the chat.
      onLog?.call('pipeline error: $e');
      // Never lose the 112 block for a risk phrase because of an error.
      if (risk) {
        emit(AnswerReady(buildRefusal(NoSourceKind.noSource, risk: true)));
      } else {
        emit(const AnswerFailed('Nie udało się przygotować odpowiedzi. Spróbuj ponownie.'));
      }
    } finally {
      if (!out.isClosed) await out.close();
    }
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

  /// Conversational reply (small talk, feelings, the profile, a crisis), or
  /// null (model error, timeout, empty output, cancelled). It sees the last
  /// turns of the chat and the profile. A crisis reply always carries the
  /// 116 123 / 112 line and the call panel.
  Future<AssistantAnswer?> _chat(
    String question,
    ChatContext ctx,
    _Run run, {
    bool crisis = false,
  }) async {
    try {
      final profile = await _profile();
      if (run.cancelled) return null;
      final text = (await run
              .collect(LlmRequest(
                systemPrompt: chatSystemPrompt(profile: profile, crisis: crisis),
                messages: [
                  for (final t in ctx.history)
                    t.user ? LlmMessage.user(clipTurn(t.text)) : LlmMessage.assistant(clipTurn(t.text)),
                  LlmMessage.user(question),
                ],
                maxTokens: 280,
                temperature: 0.7,
              ))
              .timeout(const Duration(seconds: 40)))
          .trim();
      if (text.isEmpty || run.cancelled) return null;
      return buildChatReply(text, crisis: crisis);
    } catch (e) {
      onLog?.call('chat reply unavailable: $e');
      if (e is TimeoutException) unawaited(run.engine.cancel());
      return null;
    }
  }

  /// Null when cancelled.
  Future<AssistantAnswer?> _compose({
    required String question,
    required String? previous,
    required String profile,
    required List<KbChunk> chunks,
    required bool risk,
    required _Run run,
  }) async {
    final prompted = chunks.take(kMaxPromptChunks).toList();
    for (var attempt = 0; attempt < 2; attempt++) {
      final req = buildAnswerRequest(
        question: question,
        previousQuestion: previous,
        profileContext: profile,
        chunks: prompted,
        retry: attempt > 0,
      );
      final String text;
      try {
        text = await run.collect(req);
      } catch (e) {
        if (run.cancelled) return null;
        onLog?.call('llm unavailable: $e');
        return buildQuoteFallback(
          prompted,
          risk: risk,
          modelOff: true,
          note: e is LlmTimeout ? kLlmTimeoutNote : modelNote?.call(),
        );
      }
      if (run.cancelled) return null;

      final json = parseModelJson(text);
      if (json == null) {
        onLog?.call('unparseable model output (attempt ${attempt + 1}): ${text.length > 400 ? text.substring(0, 400) : text}');
        continue;
      }
      final raw = json['panels'];
      if (raw is List && raw.isEmpty) {
        // The model itself says the fragments do not answer the question.
        return buildRefusal(NoSourceKind.noSource, risk: risk);
      }
      final v = validator.validate(json, prompted);
      for (final r in v.rejected) {
        onLog?.call('rejected $r');
      }
      if (!v.hasContent) {
        // Parsed but no item was even checked (garbled structure): one retry.
        // Items rejected by the validator are a real verdict: no retry.
        if (attempt == 0 && v.rejected.isEmpty) {
          onLog?.call('no usable panels (attempt 1), retrying');
          continue;
        }
        return buildQuoteFallback(prompted, risk: risk, modelOff: false);
      }
      final answer = buildModelAnswer(v.panels, prompted, risk: risk);
      // Risk + only a `form`: nothing left to show but the sources.
      if (answer.panels.every((p) => p is CallPanel)) {
        return buildQuoteFallback(prompted, risk: risk, modelOff: false);
      }
      return answer;
    }
    return buildQuoteFallback(prompted, risk: risk, modelOff: false);
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
