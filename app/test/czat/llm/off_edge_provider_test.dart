import 'dart:async';
import 'dart:io';

import 'package:bezpiecznik/czat/llm/llm_engine.dart';
import 'package:bezpiecznik/czat/llm/llm_engine_edge.dart';
import 'package:bezpiecznik/czat/llm/llm_engine_host.dart';
import 'package:bezpiecznik/czat/llm/llm_engine_off.dart';
import 'package:bezpiecznik/czat/llm/llm_provider.dart';
import 'package:bezpiecznik/wspolne/config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const req = LlmRequest(messages: [LlmMessage.user('hi')]);

class FakeRuntime implements EdgeRuntime {
  FakeRuntime(this.tokens, {this.hang = false});
  final List<String> tokens;
  final bool hang;
  String? loadedPath;
  int loads = 0;
  int stops = 0;
  bool closed = false;

  @override
  Future<void> load(String modelPath) async {
    loads++;
    loadedPath = modelPath;
  }

  @override
  Stream<String> run(LlmRequest req) async* {
    if (prepareGate != null && !prepareGate!.isCompleted) runStartedDuringPrepare = true;
    if (hang) await Completer<void>().future;
    for (final t in tokens) {
      yield t;
    }
  }

  @override
  bool? lastReused;

  final List<LlmRequest> prepared = [];
  Completer<void>? prepareGate;
  bool runStartedDuringPrepare = false;

  @override
  Future<void> prepare(LlmRequest req) async {
    prepared.add(req);
    await prepareGate?.future;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> close() async => closed = true;
}

void main() {
  test('OffEngine fails with LlmDisabled', () async {
    final e = OffEngine();
    await expectLater(e.generate(req), emitsError(isA<LlmDisabled>()));
    await e.warmUp();
    await e.cancel();
    await e.dispose();
    expect(e.info.name, 'off');
  });

  group('EdgeAiEngine', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('llm_edge_test_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('a question during prepare waits for it, then is answered', () async {
      final rt = FakeRuntime(['a', 'b'])..prepareGate = Completer<void>();
      File('${dir.path}/$edgeModelFileName').writeAsStringSync('x');
      final e = EdgeAiEngine(runtime: rt, modelDirs: () async => [dir.path]);
      final prep = e.prepare(req);
      final answer = e.generate(req).join();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      rt.prepareGate!.complete();
      await prep;
      expect(await answer, 'ab');
      expect(rt.prepared, hasLength(1));
      expect(rt.runStartedDuringPrepare, false);
      expect(rt.loads, 1);
    });

    test('prepare without a model throws; generate still reports it', () async {
      final rt = FakeRuntime(['a']);
      final e = EdgeAiEngine(runtime: rt, modelDirs: () async => [dir.path]);
      final prep = e.prepare(req);
      await expectLater(prep, throwsA(isA<LlmUnavailable>()));
      await expectLater(e.generate(req).toList(), throwsA(isA<LlmUnavailable>()));
    });

    test('missing model -> LlmUnavailable with Polish message, nothing native', () async {
      final rt = FakeRuntime(['a']);
      final e = EdgeAiEngine(runtime: rt, modelDirs: () async => [dir.path]);
      await expectLater(
        e.generate(req).toList(),
        throwsA(
          isA<LlmUnavailable>().having(
            (x) => x.message,
            'message',
            'Model AI nie jest jeszcze pobrany.',
          ),
        ),
      );
      expect(rt.loads, 0);
    });

    test('finds model in second dir, loads once, streams, records timing', () async {
      final second = Directory('${dir.path}/ext')..createSync();
      File('${second.path}/$edgeModelFileName').writeAsStringSync('x');
      final rt = FakeRuntime(['Cze', 'ść']);
      final e = EdgeAiEngine(
        runtime: rt,
        modelDirs: () async => ['${dir.path}/none', second.path],
      );
      expect(await e.generate(req).toList(), ['Cze', 'ść']);
      expect(await e.generate(req).toList(), ['Cze', 'ść']);
      expect(rt.loads, 1);
      expect(rt.loadedPath, '${second.path}/$edgeModelFileName');
      expect(e.lastTiming!.tokenCount, 2);
      expect(e.lastTiming!.reused, isNull);
      rt.lastReused = true;
      expect(await e.generate(req).toList(), ['Cze', 'ść']);
      expect(e.lastTiming!.reused, true);
      expect(e.lastTiming.toString(), contains('reused=true'));
      await e.dispose();
      expect(rt.closed, true);
    });

    test('no-token timeout -> LlmTimeout and runtime stopped', () async {
      File('${dir.path}/$edgeModelFileName').writeAsStringSync('x');
      final rt = FakeRuntime(const [], hang: true);
      final e = EdgeAiEngine(
        runtime: rt,
        modelDirs: () async => [dir.path],
        noTokenTimeout: const Duration(milliseconds: 100),
      );
      await expectLater(e.generate(req).toList(), throwsA(isA<LlmTimeout>()));
      expect(rt.stops, greaterThan(0));
    });

    test('retry after the model appears', () async {
      final rt = FakeRuntime(['a']);
      final e = EdgeAiEngine(runtime: rt, modelDirs: () async => [dir.path]);
      await expectLater(e.warmUp(), throwsA(isA<LlmUnavailable>()));
      File('${dir.path}/$edgeModelFileName').writeAsStringSync('x');
      await e.warmUp();
      expect(rt.loads, 1);
    });
  });

  group('llmEngineProvider', () {
    LlmEngine pick(LlmMode mode) {
      final c = ProviderContainer(
        overrides: [llmModeProvider.overrideWithValue(mode)],
      );
      addTearDown(c.dispose);
      return c.read(llmEngineProvider);
    }

    test('host -> HostLlmEngine', () {
      final e = pick(LlmMode.host);
      expect(e, isA<HostLlmEngine>());
      expect(e.info.endpoint, hostLlmBaseUrl);
    });
    test('edge -> EdgeAiEngine (no native call on creation)', () {
      expect(pick(LlmMode.edge), isA<EdgeAiEngine>());
    });
    test('off -> OffEngine', () {
      expect(pick(LlmMode.off), isA<OffEngine>());
    });
  });
}
