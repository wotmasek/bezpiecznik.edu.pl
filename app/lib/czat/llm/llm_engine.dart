import 'dart:developer' as developer;

/// Role of a chat message sent to the model.
enum LlmRole { user, assistant }

class LlmMessage {
  const LlmMessage(this.role, this.content);
  const LlmMessage.user(String content) : this(LlmRole.user, content);
  const LlmMessage.assistant(String content) : this(LlmRole.assistant, content);

  final LlmRole role;
  final String content;
}

/// One generation request. Engines never mutate it.
class LlmRequest {
  const LlmRequest({
    this.systemPrompt = '',
    required this.messages,
    this.jsonMode = false,
    this.jsonSchema,
    this.maxTokens = 512,
    this.temperature = 0.2,
    this.conversationId,
  });

  /// Live conversation key (docs/03-architecture, D7). When set, an engine
  /// that can keep a conversation open (edge) reuses it: if [messages] start
  /// with exactly the messages it already read in this conversation (same
  /// system prompt and temperature), it reads only the new ones. Anything
  /// else reopens the conversation. Null (and JSON requests): one-shot.
  final String? conversationId;

  final String systemPrompt;
  final List<LlmMessage> messages;

  /// Ask the model for a single JSON object.
  final bool jsonMode;

  /// Optional JSON schema (draft subset). Used for constrained decoding when
  /// the engine supports it; otherwise the schema must also be described in
  /// the prompt (the fallback path of lokalne-ai.md).
  final Map<String, Object?>? jsonSchema;
  final int maxTokens;
  final double temperature;
}

/// Static description of an engine, for logs and diagnostics.
class LlmInfo {
  const LlmInfo({required this.name, required this.model, this.endpoint});

  final String name;
  final String model;
  final String? endpoint;

  @override
  String toString() => 'LlmInfo($name, $model${endpoint == null ? '' : ', $endpoint'})';
}

/// Timing of one generation. [firstToken] is null when nothing was produced.
class LlmTiming {
  const LlmTiming({
    required this.requestStart,
    this.firstToken,
    required this.done,
    required this.tokenCount,
    this.cancelled = false,
  });

  final DateTime requestStart;
  final DateTime? firstToken;
  final DateTime done;
  final int tokenCount;
  final bool cancelled;

  Duration? get timeToFirstToken => firstToken?.difference(requestStart);
  Duration get total => done.difference(requestStart);

  @override
  String toString() =>
      'ttft=${timeToFirstToken?.inMilliseconds ?? '-'}ms '
      'total=${total.inMilliseconds}ms tokens=$tokenCount'
      '${cancelled ? ' cancelled' : ''}';
}

/// Measures one generation and logs it (`dart:developer`, name `llm`).
class LlmTimer {
  LlmTimer(this.engine, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _start = _clock();
  }

  final String engine;
  final DateTime Function() _clock;
  late final DateTime _start;
  DateTime? _first;
  int _tokens = 0;
  bool _finished = false;

  int get tokenCount => _tokens;

  /// Records one streamed chunk.
  void token() {
    _first ??= _clock();
    _tokens++;
  }

  LlmTiming finish({bool cancelled = false}) {
    final timing = LlmTiming(
      requestStart: _start,
      firstToken: _first,
      done: _clock(),
      tokenCount: _tokens,
      cancelled: cancelled,
    );
    if (!_finished) {
      _finished = true;
      developer.log('$engine $timing', name: 'llm');
    }
    return timing;
  }
}

sealed class LlmException implements Exception {
  const LlmException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Engine is switched off (`LLM=off`); the chat shows source quotes only.
class LlmDisabled extends LlmException {
  const LlmDisabled() : super('LLM is disabled');
}

/// Engine cannot be reached or has no model. [message] is user-facing Polish.
class LlmUnavailable extends LlmException {
  const LlmUnavailable(super.message);
}

/// No token within the allowed time (spec: 20 s).
class LlmTimeout extends LlmException {
  const LlmTimeout([super.message = 'LLM did not answer in time']);
}

class LlmError extends LlmException {
  const LlmError(super.message);
}

abstract class LlmEngine {
  /// Prepares the engine (loads the model). Safe to call repeatedly.
  Future<void> warmUp();

  /// Streams text chunks as they are generated. Cancelling via [cancel] or the
  /// subscription ends the stream without an error. Errors are [LlmException]s.
  Stream<String> generate(LlmRequest req);

  /// Stops the running generation, if any.
  Future<void> cancel();

  LlmInfo get info;

  /// Timing of the last finished (or cancelled) generation.
  LlmTiming? get lastTiming;

  Future<void> dispose();
}
