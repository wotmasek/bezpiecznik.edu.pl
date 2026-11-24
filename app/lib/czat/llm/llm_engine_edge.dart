import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../paczki/pack.dart' show modelPackFileName;
import '../answer/answer_prompt.dart' show kModelContextTokens;
import '../../paczki/pack_dir.dart';
import 'live_conversation.dart';
import 'llm_engine.dart';

// Backend of the on-device model. CPU by default: on the demo phone (Galaxy
// A55, Samsung Xclipse 530, OpenCL at float16) the GPU returned random tokens
// for every prompt, while the CPU (XNNPACK) answered correctly and sooner.
// `--dart-define=LLM_BACKEND=gpu` (optionally with `LLM_FP32=true`) is for
// measuring another phone, see lib/czat/llm/README.md.
const String _backendDefine = String.fromEnvironment('LLM_BACKEND', defaultValue: 'cpu');
const bool _fp32Define = bool.fromEnvironment('LLM_FP32');

/// User-facing message when the model file is not on the device.
const String edgeModelMissingMessage = 'Model AI nie jest jeszcze pobrany.';

/// File name of the Gemma 4 E2B LiteRT-LM model.
const String edgeModelFileName = modelPackFileName;

/// Directories searched for [edgeModelFileName], in order.
typedef ModelDirsProvider = Future<List<String>> Function();

/// The packs dir (in-app download) first, then the app documents dir, then the
/// app-specific external dir (reachable by `adb push` without root).
Future<List<String>> defaultModelDirs() async {
  final dirs = <String>[];
  try {
    dirs.add((await defaultPacksDir()).path);
  } catch (_) {}
  try {
    dirs.add((await getApplicationDocumentsDirectory()).path);
  } catch (_) {}
  try {
    final ext = await getExternalStorageDirectory();
    if (ext != null) dirs.add(ext.path);
  } catch (_) {}
  return dirs;
}

/// Thin seam over `flutter_edge_ai`, so the engine logic is testable on host.
abstract class EdgeRuntime {
  Future<void> load(String modelPath);
  Stream<String> run(LlmRequest req);

  /// Opens the live chat for [req] without a turn (see LiveConversation.prepare).
  Future<void> prepare(LlmRequest req);

  /// Whether the last [run] continued the live conversation (true), opened
  /// it (false), or was one-shot (null).
  bool? get lastReused;

  Future<void> stop();
  Future<void> close();
}

/// Real runtime. Touches the native plugin only from [load].
class FlutterEdgeAiRuntime implements EdgeRuntime {
  FlutterEdgeAiRuntime({this.inferenceEngines = const []});

  /// Engine providers for `FlutterEdgeAi.initialize` (core registers none):
  /// pass `[LiteRtLmEngine()]` from `flutter_edge_ai_litertlm`.
  final List<InferenceEngineProvider> inferenceEngines;

  InferenceModel? _model;

  /// The chat generating right now (live or one-shot), for [stop].
  InferenceChat? _chat;

  bool _stopped = false;

  /// The one live conversation (D7).
  late final LiveConversation<InferenceChat> _live = LiveConversation(
    open: (req) => _open(_model!, req, null),
    send: _send,
    close: (chat) => chat.close(),
    isStopped: () => _stopped,
  );

  bool _lastWasLive = false;

  @override
  bool? get lastReused => _lastWasLive ? _live.lastReused : null;

  @override
  Future<void> load(String modelPath) async {
    await FlutterEdgeAi.initialize(inferenceEngines: inferenceEngines);
    await FlutterEdgeAi.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(modelPath).install();
    // Context size, not output size. The prompt builder keeps prompt +
    // answer inside it (a smaller context also loads and prefills faster).
    // The XNNPACK weight cache needs no setting here: flutter_edge_ai_litertlm
    // passes the app support directory as LiteRT-LM's cacheDir by default
    // (LiteRtLmEngineHost.cacheDir).
    _model = await FlutterEdgeAi.getActiveModel(
      maxTokens: kModelContextTokens,
      preferredBackend: _backendDefine == 'gpu' ? PreferredBackend.gpu : PreferredBackend.cpu,
      activationDataType: _fp32Define ? ActivationDataType.float32 : null,
    );
  }

  // A fresh chat cannot be given prior assistant turns: the .litertlm session
  // buffers every addQuery as raw text of ONE user message (its
  // ConversationConfig has no initialMessages), so history is flattened.
  static String _flatten(List<LlmMessage> messages) {
    if (messages.length == 1) return messages.single.content;
    return messages
        .map((m) => '${m.role == LlmRole.user ? 'User' : 'Assistant'}: ${m.content}')
        .join('\n');
  }

  Future<InferenceChat> _open(InferenceModel model, LlmRequest req, ResponseFormat? format) {
    return model.openChat(
      temperature: req.temperature,
      enableThinking: false,
      systemInstruction: req.systemPrompt.isEmpty ? null : req.systemPrompt,
      maxOutputTokens: req.maxTokens,
      modelType: ModelType.gemma4,
      responseFormat: format,
    );
  }

  @override
  Stream<String> run(LlmRequest req) {
    final model = _model;
    if (model == null) return Stream.error(const LlmError('Edge model not loaded'));
    _stopped = false;
    _lastWasLive = isLiveRequest(req);
    return _lastWasLive ? _live.run(req) : _runOneShot(model, req);
  }

  // LiteRT-LM's createConversation may prefill the preface (system
  // instruction) natively; the package exposes no explicit prefill, so this
  // is the most that can be done without a throwaway turn.
  @override
  Future<void> prepare(LlmRequest req) async {
    if (_model == null) throw const LlmError('Edge model not loaded');
    if (isLiveRequest(req)) await _live.prepare(req);
  }

  Stream<String> _send(InferenceChat chat, List<LlmMessage> fresh) async* {
    _chat = chat;
    try {
      await chat.addQuery(Message.text(text: _flatten(fresh), isUser: true));
      await for (final r in chat.generateChatResponseAsync()) {
        if (_stopped) break;
        if (r is TextResponse && r.token.isNotEmpty) yield r.token;
      }
    } finally {
      _chat = null;
    }
  }

  /// JSON and id-less requests: a chat of their own, closed after the reply.
  /// The live chat stays open: the model allows several sessions (no
  /// maxConcurrentSessions cap), though on Android CPU they share one native
  /// conversation, so the live chat's next turn is replayed by the package.
  Stream<String> _runOneShot(InferenceModel model, LlmRequest req) async* {
    ResponseFormat? format;
    if (req.jsonSchema != null) {
      format = ResponseFormat.jsonSchema(req.jsonSchema!);
    } else if (req.jsonMode) {
      format = ResponseFormat.jsonObject();
    }
    InferenceChat chat;
    try {
      chat = await _open(model, req, format);
    } on ResponseFormatUnsupportedException {
      // Fallback path of lokalne-ai.md: schema is described in the prompt.
      chat = await _open(model, req, null);
    }
    try {
      yield* _send(chat, req.messages);
    } finally {
      await chat.close();
    }
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    await _chat?.stopGeneration();
  }

  @override
  Future<void> close() async {
    await stop();
    await _live.closeChat();
    await _model?.close();
    _model = null;
  }
}

/// On-device LiteRT-LM engine (arm64 only). Nothing native is touched until
/// the first [warmUp].
class EdgeAiEngine implements LlmEngine {
  EdgeAiEngine({
    EdgeRuntime? runtime,
    ModelDirsProvider? modelDirs,
    // Time to the first token = reading the whole prompt. On the CPU that is
    // ~65 tokens/s (Galaxy A55), so a 1.3 k token prompt needs ~20 s: the
    // spec's 20 s limit cut off answers that were about to start.
    this.noTokenTimeout = const Duration(seconds: 90),
    this.onTiming,
  }) : _runtime = runtime ?? FlutterEdgeAiRuntime(),
       _modelDirs = modelDirs ?? defaultModelDirs;

  final EdgeRuntime _runtime;
  final ModelDirsProvider _modelDirs;
  final Duration noTokenTimeout;
  final void Function(LlmTiming timing)? onTiming;

  Future<void>? _warm;
  LlmTiming? _lastTiming;
  bool _cancelled = false;

  @override
  LlmInfo get info => const LlmInfo(name: 'edge', model: edgeModelFileName);

  @override
  LlmTiming? get lastTiming => _lastTiming;

  Future<String?> _findModel() async {
    for (final dir in await _modelDirs()) {
      final path = p.join(dir, edgeModelFileName);
      if (await File(path).exists()) return path;
    }
    return null;
  }

  @override
  Future<void> warmUp() {
    return _warm ??= _load().catchError((Object e) {
      _warm = null; // allow a retry, e.g. after `adb push`
      throw e;
    });
  }

  Future<void> _load() async {
    final path = await _findModel();
    if (path == null) throw const LlmUnavailable(edgeModelMissingMessage);
    try {
      await _runtime.load(path);
    } on LlmException {
      rethrow;
    } catch (e) {
      throw LlmUnavailable('$edgeModelMissingMessage ($e)');
    }
  }

  /// The running [prepare]; [generate] waits for it (one request at a time).
  Future<void>? _preparing;

  @override
  Future<void> prepare(LlmRequest req) {
    final sw = Stopwatch()..start();
    final f = _preparing = () async {
      await warmUp();
      await _runtime.prepare(req);
    }();
    return f.whenComplete(() {
      if (identical(_preparing, f)) _preparing = null;
      developer.log('edge prepare_ms=${sw.elapsedMilliseconds}', name: 'llm');
    });
  }

  @override
  Stream<String> generate(LlmRequest req) async* {
    final preparing = _preparing;
    if (preparing != null) {
      try {
        await preparing;
      } catch (_) {}
    }
    _cancelled = false;
    final timer = LlmTimer('edge');
    var cancelled = false;
    var ran = false;
    try {
      await warmUp();
      ran = true;
      final it = StreamIterator<String>(_runtime.run(req));
      try {
        while (true) {
          final Future<bool> next = it.moveNext();
          final bool has = await (timer.tokenCount == 0 ? next.timeout(noTokenTimeout) : next);
          if (!has) break;
          timer.token();
          yield it.current;
        }
      } finally {
        // Not awaited: a native stream stuck mid-generation never completes
        // its cancellation.
        unawaited(it.cancel());
      }
      cancelled = _cancelled;
    } on TimeoutException {
      await _runtime.stop();
      throw const LlmTimeout();
    } on LlmException {
      rethrow;
    } catch (e) {
      if (_cancelled) {
        cancelled = true;
      } else {
        throw LlmError(e.toString());
      }
    } finally {
      final timing = timer.finish(
        cancelled: cancelled || _cancelled,
        reused: ran ? _runtime.lastReused : null,
      );
      _lastTiming = timing;
      onTiming?.call(timing);
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await _runtime.stop();
  }

  @override
  Future<void> dispose() async {
    if (_warm != null) await _runtime.close();
    _warm = null;
  }
}
