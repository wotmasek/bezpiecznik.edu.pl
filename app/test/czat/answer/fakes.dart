import 'dart:async';

import 'package:bezpiecznik/czat/llm/llm_engine.dart';
import 'package:bezpiecznik/czat/retrieval/retriever.dart';

KbChunk chunk(String id, String text, {String? original, String page = '14'}) => KbChunk(
  id: id,
  docId: 'doc',
  docShort: 'Poradnik',
  title: 'Poradnik bezpieczeństwa',
  publisher: 'RCB',
  pageLabel: page,
  pdfPage: 16,
  chapter: null,
  text: text,
  original: original,
  topics: const [],
  verify: false,
  score: -5,
);

RetrievalResult found(List<KbChunk> c) =>
    RetrievalResult(decision: RetrievalDecision.found, chunks: c);

/// Scripted engine: each generate() consumes the next script entry. An entry
/// is a list of chunks to stream, or an [LlmException] to throw, or null to
/// hang until cancelled.
class FakeEngine implements LlmEngine {
  FakeEngine(this.script);

  final List<Object?> script;
  final List<LlmRequest> requests = [];
  int cancelCalls = 0;
  bool streamCancelled = false;

  @override
  Stream<String> generate(LlmRequest req) {
    requests.add(req);
    final entry = script.isEmpty ? <String>[''] : script.removeAt(0);
    late StreamController<String> c;
    c = StreamController<String>(
      onListen: () async {
        if (entry == null) return; // hangs
        if (entry is LlmException) {
          c.addError(entry);
          await c.close();
          return;
        }
        for (final t in entry as List<String>) {
          c.add(t);
          await Future<void>.delayed(Duration.zero);
        }
        await c.close();
      },
      onCancel: () => streamCancelled = true,
    );
    return c.stream;
  }

  @override
  Future<void> cancel() async => cancelCalls++;

  @override
  Future<void> warmUp() async {}

  final List<LlmRequest> prepared = [];
  Object? prepareError;

  @override
  Future<void> prepare(LlmRequest req) async {
    prepared.add(req);
    if (prepareError != null) throw prepareError!;
  }

  @override
  Future<void> dispose() async {}

  @override
  LlmInfo get info => const LlmInfo(name: 'fake', model: 'fake');

  @override
  LlmTiming? get lastTiming => null;
}
