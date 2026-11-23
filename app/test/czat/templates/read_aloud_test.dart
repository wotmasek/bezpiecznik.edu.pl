import 'dart:async';

import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/read_aloud.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeVoice implements ReadAloudVoice {
  _FakeVoice({this.available = true, this.throwing = false});

  final bool available;
  final bool throwing;
  final spoken = <String>[];
  var stops = 0;
  Completer<void>? _pending;

  @override
  Future<bool> isAvailable() async {
    if (throwing) throw StateError('no tts');
    return available;
  }

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    _pending = Completer<void>();
    return _pending!.future;
  }

  void finish() => _pending?.complete();

  @override
  Future<void> stop() async {
    stops++;
    _pending?.complete();
  }
}

Future<void> _pump(
  WidgetTester tester,
  ReadAloudVoice voice, {
  bool readAloud = true,
}) async {
  final answer = AssistantAnswer(
    sources: const {},
    panels: [
      StepsPanel(
        title: 'T',
        readAloud: readAloud,
        items: const [
          PanelItem(text: 'raz'),
          PanelItem(text: 'dwa'),
          PanelItem(text: 'trzy'),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        readAloudVoiceProvider.overrideWithValue(voice),
        templateRegistryProvider.overrideWithValue(TemplateRegistry.withDefaults()),
      ],
      child: MaterialApp(
        theme: buildBzTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: TemplateRenderer(answer: answer)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('no button without read_aloud', (tester) async {
    await _pump(tester, _FakeVoice(), readAloud: false);
    expect(find.text(readAloudStartLabel), findsNothing);
  });

  testWidgets('hidden when no voice or TTS throws', (tester) async {
    await _pump(tester, _FakeVoice(available: false));
    expect(find.text(readAloudStartLabel), findsNothing);
    await _pump(tester, _FakeVoice(throwing: true));
    expect(find.text(readAloudStartLabel), findsNothing);
  });

  testWidgets('reads steps in order, tap again stops', (tester) async {
    final v = _FakeVoice();
    await _pump(tester, v);
    expect(
      tester.getSize(find.text(readAloudStartLabel).hitTestable()).height,
      greaterThan(0),
    );
    await tester.tap(find.text(readAloudStartLabel));
    await tester.pump();
    expect(v.spoken, ['raz']);
    expect(find.text(readAloudStopLabel), findsOneWidget);
    v.finish();
    await tester.pump();
    expect(v.spoken, ['raz', 'dwa']);
    await tester.tap(find.text(readAloudStopLabel));
    await tester.pump();
    expect(find.text(readAloudStartLabel), findsOneWidget);
    expect(v.spoken, ['raz', 'dwa']);
  });

  testWidgets('reads from step 1 to the end, then the button resets', (tester) async {
    final v = _FakeVoice();
    await _pump(tester, v);
    await tester.tap(find.text(readAloudStartLabel));
    await tester.pump();
    v.finish();
    await tester.pump();
    v.finish();
    await tester.pump();
    expect(v.spoken, ['raz', 'dwa', 'trzy']);
    v.finish();
    await tester.pump();
    await tester.pump();
    expect(find.text(readAloudStartLabel), findsOneWidget);
  });
}
