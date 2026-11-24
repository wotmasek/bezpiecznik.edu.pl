import 'llm_engine.dart';

/// `LLM=off`: no AI answer; the chat falls back to source quotes.
class OffEngine implements LlmEngine {
  @override
  Future<void> warmUp() async {}

  @override
  Future<void> prepare(LlmRequest req) async {}

  @override
  Stream<String> generate(LlmRequest req) => Stream<String>.error(const LlmDisabled());

  @override
  Future<void> cancel() async {}

  @override
  LlmInfo get info => const LlmInfo(name: 'off', model: 'none');

  @override
  LlmTiming? get lastTiming => null;

  @override
  Future<void> dispose() async {}
}
