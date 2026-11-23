import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart' show LiteRtLmEngine;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Context-size benchmark of the on-device model (CPU), 2026-11-23.
/// Needs `gemma-4-E2B-it.litertlm` and `bench_corpus.txt` (guide chunks) in
/// the app's external files dir. Run on a phone:
///   flutter test integration_test/ctx_bench_test.dart -d SERIAL
/// Prints `CTX:` lines; sample RAM from the host with `dumpsys meminfo`.
const _needle = 'Hasło do skrytki w piwnicy to ZIELONY-47.';
const _question =
    '\n\nPytanie: Jakie jest hasło do skrytki w piwnicy? Najpierw podaj je dokładnie. '
    'Potem w trzech krótkich punktach napisz, o czym jest powyższy tekst.';

// `--dart-define=CTX_CONTROL=true`: the same 1.5k prompt at 2048, 16384, 2048
// (separates the context allocation from heat).
const _control = bool.fromEnvironment('CTX_CONTROL');
const _plan = <(int, List<int>)>[
  if (_control) ...[(2048, [1500]), (16384, [1500]), (8192, [1500]), (2048, [1500])]
  else ...[(2048, [1500]), (4096, [1500, 3500]), (8192, [1500, 3500, 7500]), (16384, [1500, 12000])],
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('context benchmark', (tester) async {
    final dir = (await getExternalStorageDirectory())!.path;
    final corpus = await File(p.join(dir, 'bench_corpus.txt')).readAsString();
    await FlutterEdgeAi.initialize(inferenceEngines: const [LiteRtLmEngine()]);
    await FlutterEdgeAi.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(p.join(dir, 'gemma-4-E2B-it.litertlm')).install();

    void log(String m) => debugPrint('CTX: t=${DateTime.now().millisecondsSinceEpoch} $m');

    for (final entry in _plan) {
      final ctx = entry.$1;
      InferenceModel? model;
      try {
        final sw = Stopwatch()..start();
        model = await FlutterEdgeAi.getActiveModel(
          maxTokens: ctx,
          preferredBackend: PreferredBackend.cpu,
        );
        // The first session forces the engine to load.
        final warm = await model.openSession(temperature: 0, maxOutputTokens: 8);
        final perChar = (await warm.sizeInTokens(corpus.substring(0, 8000))) / 8000;
        await warm.close();
        log('ctx=$ctx load_ms=${sw.elapsedMilliseconds} tokens_per_char=${perChar.toStringAsFixed(3)}');

        for (final target in entry.$2) {
          final body = corpus.substring(0, (target / perChar).round().clamp(0, corpus.length));
          final at = (body.length * 0.15).round();
          final cut = body.indexOf('\n', at) < 0 ? at : body.indexOf('\n', at);
          final prompt = '${body.substring(0, cut)}\n$_needle\n${body.substring(cut)}$_question';
          final session = await model.openSession(temperature: 0, maxOutputTokens: 160);
          final promptTokens = await session.sizeInTokens(prompt);
          log('ctx=$ctx target=$target prompt_tokens=$promptTokens start');
          final run = Stopwatch()..start();
          int? ttft;
          final out = StringBuffer();
          await session.addQueryChunk(Message.text(text: prompt, isUser: true));
          await for (final tok in session.getResponseAsync()) {
            ttft ??= run.elapsedMilliseconds;
            out.write(tok);
          }
          final total = run.elapsedMilliseconds;
          final text = out.toString();
          final outTokens = await session.sizeInTokens(text);
          final decodeMs = total - (ttft ?? total);
          final tps = decodeMs > 0 ? (outTokens - 1) * 1000 / decodeMs : 0;
          final prefillTps = ttft != null && ttft > 0 ? promptTokens * 1000 / ttft : 0;
          log(
            'ctx=$ctx target=$target prompt_tokens=$promptTokens ttft_ms=$ttft total_ms=$total '
            'out_tokens=$outTokens prefill_tps=${prefillTps.toStringAsFixed(0)} '
            'decode_tps=${tps.toStringAsFixed(1)} needle=${text.contains('ZIELONY-47')} '
            'answer=${text.replaceAll('\n', ' / ').substring(0, text.length.clamp(0, 220))}',
          );
          await session.close();
        }
      } catch (e) {
        log('ctx=$ctx ERROR $e');
      } finally {
        await model?.close();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 45)));
}
