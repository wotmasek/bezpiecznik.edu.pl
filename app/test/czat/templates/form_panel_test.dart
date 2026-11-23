import 'dart:convert';

import 'package:bezpiecznik/czat/templates/form_panel.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_fixtures.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
import 'package:bezpiecznik/wspolne/theme/bz_buttons.dart';
import 'package:bezpiecznik/wspolne/theme/bz_chip.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Renders the `form` fixture through the renderer, keeping the answer in
/// state like the chat controller does; returns the sent messages.
Future<List<String>> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sent = <String>[];
  var answer = AssistantAnswer.fromJson(jsonDecode(templateFixtures['form']!));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      templateRegistryProvider.overrideWithValue(TemplateRegistry.withDefaults()),
      formSenderProvider.overrideWithValue(sent.add),
    ],
    child: MaterialApp(
      theme: buildBzTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) =>
                TemplateRenderer(answer: answer, onChanged: (a) => setState(() => answer = a)),
          ),
        ),
      ),
    ),
  ));
  return sent;
}

BzButton _send(WidgetTester tester) =>
    tester.widget<BzButton>(find.ancestor(of: find.text('Wyślij'), matching: find.byType(BzButton)));

bool _on(WidgetTester tester, String label) =>
    tester.widget<BzChip>(find.ancestor(of: find.text(label), matching: find.byType(BzChip))).selected;

void main() {
  testWidgets('form: single = radio, multiple = toggles, Wyślij disabled until an answer', (tester) async {
    await _pump(tester);
    expect(find.text(formMultipleHint), findsOneWidget);
    expect(_send(tester).onPressed, isNull);

    await tester.tap(find.text('Prąd'));
    await tester.pump();
    expect(_send(tester).onPressed, isNotNull);
    await tester.tap(find.text('Gaz'));
    await tester.pump();
    expect(_on(tester, 'Prąd'), isFalse);
    expect(_on(tester, 'Gaz'), isTrue);
    await tester.tap(find.text('Gaz'));
    await tester.pump();
    expect(_on(tester, 'Gaz'), isFalse);
    expect(_send(tester).onPressed, isNull);

    await tester.tap(find.text('Dzieci'));
    await tester.tap(find.text('Dorośli'));
    await tester.pump();
    expect(_on(tester, 'Dzieci'), isTrue);
    expect(_on(tester, 'Dorośli'), isTrue);
    // The 48 dp hit area around the 40 dp chip also toggles it.
    await tester.tapAt(tester.getRect(find.widgetWithText(BzChip, 'Zwierzęta')).topCenter - const Offset(0, 3));
    await tester.pump();
    expect(_on(tester, 'Zwierzęta'), isTrue);
  });

  testWidgets('form: Wyślij sends one message and closes the form', (tester) async {
    final sent = await _pump(tester);
    await tester.tap(find.text('Dzieci'));
    await tester.tap(find.text('Dorośli'));
    await tester.tap(find.text('Gaz'));
    await tester.pump();
    await tester.tap(find.text('Wyślij'));
    await tester.pump();
    expect(sent, ['Kto mieszka w domu: Dorośli, Dzieci. Czym ogrzewasz dom: Gaz.']);
    expect(find.byType(FormPanelView), findsOneWidget);
    expect(find.text('Kto mieszka w domu?'), findsNothing, reason: 'closed form renders nothing');
  });

  testWidgets('form: Pomiń closes without sending', (tester) async {
    final sent = await _pump(tester);
    await tester.tap(find.text('Pomiń'));
    await tester.pump();
    expect(sent, isEmpty);
    expect(find.text('Kto mieszka w domu?'), findsNothing);
  });

  testWidgets('form: a stored closed form renders nothing', (tester) async {
    final json = jsonDecode(templateFixtures['form']!) as Map<String, dynamic>;
    final closed = AssistantAnswer.fromJson(json).withDone(0, null, 0, true);
    expect(AssistantAnswer.fromJson(closed.toJson()).formClosed(0), isTrue);
    await tester.pumpWidget(ProviderScope(
      overrides: [templateRegistryProvider.overrideWithValue(TemplateRegistry.withDefaults())],
      child: MaterialApp(theme: buildBzTheme(), home: Scaffold(body: TemplateRenderer(answer: closed))),
    ));
    expect(find.text('Kto mieszka w domu?'), findsNothing);
    expect(find.text('Wyślij'), findsNothing);
  });

  test('formAnswerText: form order, unanswered left out, trailing "?" dropped', () {
    const qs = [
      FormQuestion(text: 'Kto? ', options: ['A', 'B', 'C'], multiple: true),
      FormQuestion(text: 'Gdzie?', options: ['X', 'Y']),
      FormQuestion(text: 'Kiedy', options: ['T', 'U']),
    ];
    expect(formAnswerText(qs, [{2, 0}, {}, {1}]), 'Kto: A, C. Kiedy: U.');
    expect(formAnswerText(qs, [{}, {}, {}]), '');
  });
}
