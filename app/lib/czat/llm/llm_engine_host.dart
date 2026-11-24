import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'llm_engine.dart';

/// Polish user-facing message when the host bridge cannot be reached.
const String hostUnavailableMessage = 'Model AI jest niedostępny.';

/// Spec "Limit czasu odpowiedzi AI: 20 s".
const Duration defaultNoTokenTimeout = Duration(seconds: 20);
const Duration defaultConnectTimeout = Duration(seconds: 5);

/// Default client factory: one fresh client per generation, so [cancel] can
/// close it without breaking later generations.
http.Client _defaultClient(Duration connectTimeout) =>
    IOClient(HttpClient()..connectionTimeout = connectTimeout);

/// OpenAI-compatible llama-server bridge (`adb reverse tcp:8080 tcp:8080`).
class HostLlmEngine implements LlmEngine {
  HostLlmEngine({
    required this.baseUrl,
    this.noTokenTimeout = defaultNoTokenTimeout,
    this.connectTimeout = defaultConnectTimeout,
    this.useJsonSchemaFormat = false,
    this.modelName = 'local',
    http.Client Function()? clientFactory,
    this.onTiming,
  }) : _clientFactory = clientFactory ?? (() => _defaultClient(connectTimeout));

  final String baseUrl;
  final Duration noTokenTimeout;
  final Duration connectTimeout;

  /// Use `response_format: json_schema` (strict) when a schema is given.
  /// Off by default: it returned truncated JSON once; `json_object` is stable.
  final bool useJsonSchemaFormat;
  final String modelName;
  final http.Client Function() _clientFactory;
  final void Function(LlmTiming timing)? onTiming;

  LlmTiming? _lastTiming;
  http.Client? _client;
  _Run? _run;

  @override
  LlmInfo get info => LlmInfo(name: 'host', model: modelName, endpoint: baseUrl);

  @override
  LlmTiming? get lastTiming => _lastTiming;

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> prepare(LlmRequest req) async {}

  /// Builds the JSON body; exposed for tests.
  Map<String, Object?> buildBody(LlmRequest req) {
    final messages = <Map<String, String>>[
      if (req.systemPrompt.isNotEmpty)
        {'role': 'system', 'content': req.systemPrompt},
      for (final m in req.messages)
        {'role': m.role == LlmRole.user ? 'user' : 'assistant', 'content': m.content},
    ];
    final body = <String, Object?>{
      'model': modelName,
      'messages': messages,
      'stream': true,
      'max_tokens': req.maxTokens,
      'temperature': req.temperature,
      'chat_template_kwargs': {'enable_thinking': false},
    };
    if (req.jsonMode || req.jsonSchema != null) {
      body['response_format'] = (useJsonSchemaFormat && req.jsonSchema != null)
          ? {
              'type': 'json_schema',
              'json_schema': {
                'name': 'answer',
                'strict': true,
                'schema': req.jsonSchema,
              },
            }
          : {'type': 'json_object'};
    }
    return body;
  }

  @override
  Stream<String> generate(LlmRequest req) {
    final run = _Run();
    late final StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () {
        unawaited(_execute(req, run, controller));
      },
      onCancel: () => _abort(run),
    );
    return controller.stream;
  }

  Future<void> _execute(
    LlmRequest req,
    _Run run,
    StreamController<String> out,
  ) async {
    _run = run;
    final timer = LlmTimer('host');
    final client = _clientFactory();
    _client = client;
    run.client = client;
    Object? failure;
    Timer? idle;

    void armIdle() {
      idle?.cancel();
      idle = Timer(noTokenTimeout, () {
        failure = const LlmTimeout();
        _abort(run);
      });
    }

    try {
      armIdle();
      final request = http.Request('POST', Uri.parse('$baseUrl/v1/chat/completions'))
        ..headers['content-type'] = 'application/json'
        ..headers['accept'] = 'text/event-stream'
        ..body = jsonEncode(buildBody(req));
      final response = await client.send(request);
      if (run.cancelled) return;
      if (response.statusCode != 200) {
        final text = await response.stream.bytesToString();
        throw LlmError('HTTP ${response.statusCode}: $text');
      }
      var buffer = '';
      var done = false;
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        if (run.cancelled) break;
        armIdle();
        buffer += chunk;
        while (true) {
          final nl = buffer.indexOf('\n');
          if (nl < 0) break;
          final line = buffer.substring(0, nl).trim();
          buffer = buffer.substring(nl + 1);
          final token = _parseLine(line);
          if (token == _doneMarker) {
            done = true;
            break;
          }
          if (token != null && token.isNotEmpty) {
            timer.token();
            if (!run.cancelled && !out.isClosed) out.add(token);
          }
        }
        if (done) break;
      }
      if (!done && !run.cancelled && buffer.trim().isNotEmpty) {
        final token = _parseLine(buffer.trim());
        if (token != null && token != _doneMarker && token.isNotEmpty) {
          timer.token();
          if (!out.isClosed) out.add(token);
        }
      }
    } catch (e) {
      if (run.cancelled && failure == null) {
        // Closing the client on cancel surfaces as an exception: not an error.
      } else {
        failure ??= _mapError(e);
      }
    } finally {
      idle?.cancel();
      client.close();
      if (identical(_client, client)) _client = null;
      if (identical(_run, run)) _run = null;
      final timing = timer.finish(cancelled: run.cancelled && failure == null);
      _lastTiming = timing;
      onTiming?.call(timing);
      if (!out.isClosed) {
        if (failure != null) out.addError(failure!);
        await out.close();
      }
    }
  }

  static const String _doneMarker = '\u0000DONE';

  /// Returns the content delta, [_doneMarker] for `[DONE]`, or null.
  String? _parseLine(String line) {
    if (!line.startsWith('data:')) return null;
    final data = line.substring(5).trim();
    if (data.isEmpty) return null;
    if (data == '[DONE]') return _doneMarker;
    try {
      final json = jsonDecode(data);
      if (json is! Map) return null;
      final choices = json['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final delta = (choices.first as Map)['delta'];
      if (delta is! Map) return null;
      final content = delta['content'];
      return content is String ? content : null;
    } on FormatException {
      return null;
    }
  }

  LlmException _mapError(Object e) {
    if (e is LlmException) return e;
    if (e is SocketException || e is http.ClientException || e is HandshakeException) {
      return const LlmUnavailable(hostUnavailableMessage);
    }
    if (e is TimeoutException) return const LlmTimeout();
    return LlmError(e.toString());
  }

  void _abort(_Run run) {
    run.cancelled = true;
    run.client?.close();
  }

  @override
  Future<void> cancel() async {
    final run = _run;
    if (run != null) _abort(run);
  }

  @override
  Future<void> dispose() async {
    await cancel();
    _client?.close();
    _client = null;
  }
}

class _Run {
  bool cancelled = false;
  http.Client? client;
}
