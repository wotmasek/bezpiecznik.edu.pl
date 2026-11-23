import 'dart:convert';

import 'package:bezpiecznik/czat/templates/no_source.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/steps_panel.dart';
import 'package:bezpiecznik/czat/templates/template_fixtures.dart';
import 'package:bezpiecznik/czat/templates/template_gallery.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
import 'package:bezpiecznik/czat/templates/todo_panel.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget host(Widget child, {List overrides = const []}) => ProviderScope(
  key: UniqueKey(),
  // Core renderer tests: placeholders for module templates.
  overrides: overrides.isEmpty
      ? [templateRegistryProvider.overrideWithValue(TemplateRegistry.withDefaults())]
      : [...overrides],
  child: MaterialApp(
    theme: buildBzTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

AssistantAnswer fixture(String name) => AssistantAnswer.fromJson(jsonDecode(templateFixtures[name]!));

/// Keeps the answer in state like the controller does.
class Stateful extends StatefulWidget {
  const Stateful(this.initial, {super.key});

  final AssistantAnswer initial;

  @override
  State<Stateful> createState() => _StatefulState();
}

class _StatefulState extends State<Stateful> {
  late AssistantAnswer a = widget.initial;

  @override
  Widget build(BuildContext context) =>
      TemplateRenderer(answer: a, onChanged: (n) => setState(() => a = n));
}

void main() {
  testWidgets('steps: numbered, source chip under each step, current step bold', (tester) async {
    await tester.pumpWidget(host(Stateful(fixture('steps'))));
    expect(find.text('Teraz'), findsOneWidget);
    expect(find.text('Przykładowy krok 1'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Przykład, s.\u00A014'), findsNWidgets(2));
    expect(find.text('Przykład, s.\u00A022'), findsOneWidget);
    final first = tester.widget<Text>(find.text('Przykładowy krok 1'));
    final second = tester.widget<Text>(find.text('Przykładowy krok 2'));
    expect(first.style!.fontWeight, FontWeight.w700);
    expect(second.style!.fontWeight, FontWeight.w500);
  });

  testWidgets('steps: checking moves the current step and finishing shows "Wszystko zrobione"', (tester) async {
    await tester.pumpWidget(host(Stateful(fixture('steps'))));
    Future<void> check(String stepText) async {
      await tester.tap(find.bySemanticsLabel(RegExp('Krok \\d: $stepText')).first);
      await tester.pump();
    }

    await check('Przykładowy krok 1');
    expect(tester.widget<Text>(find.text('Przykładowy krok 1')).style!.fontWeight, FontWeight.w500);
    expect(tester.widget<Text>(find.text('Przykładowy krok 2')).style!.fontWeight, FontWeight.w700);
    expect(find.textContaining(stepsAllDoneText), findsNothing);

    await check('Przykładowy krok 2');
    await check('Przykładowy krok 3');
    expect(find.text('Teraz: $stepsAllDoneText'), findsOneWidget);
  });

  testWidgets('steps: variant switch changes the listed steps', (tester) async {
    await tester.pumpWidget(host(Stateful(fixture('steps_variants'))));
    expect(find.text('Przykładowy krok 3'), findsNothing, reason: 'adult has 2 steps');
    expect(find.text('Dorosły'), findsOneWidget);
    await tester.tap(find.text('Dziecko'));
    await tester.pump();
    expect(find.text('Przykładowy krok 3'), findsOneWidget);
    await tester.tap(find.text('Niemowlę'));
    await tester.pump();
    expect(find.text('Przykładowy krok 2'), findsNothing);
  });

  testWidgets('bullets: plain has no checkboxes, checkable has a counter', (tester) async {
    await tester.pumpWidget(host(Stateful(fixture('bullets'))));
    expect(find.text('Przykładowy element A'), findsOneWidget);
    expect(find.text('0 z 2'), findsNothing);
    expect(find.byType(TodoPanelView), findsNothing);

    // Legacy checkable bullets are a to-do list.
    await tester.pumpWidget(host(Stateful(fixture('bullets_checkable'))));
    await tester.pumpAndSettle();
    expect(find.byType(TodoPanelView), findsOneWidget);
    expect(find.text('0 z 2'), findsOneWidget);
    await tester.tap(find.text('Woda pitna'));
    await tester.pump();
    expect(find.text('1 z 2'), findsOneWidget);
  });

  testWidgets('quote: text, document, page and "Powiększ"', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      host(
        TemplateRenderer(answer: fixture('quote')),
        overrides: [sourceOpenerProvider.overrideWithValue((_, s) => opened.add(s.sourceId))],
      ),
    );
    expect(find.text('Przykład · s. 14'), findsOneWidget);
    expect(find.textContaining('Przykładowy fragment źródła'), findsOneWidget);
    expect(find.text('Tryb bez AI: fragmenty źródeł'), findsOneWidget);
    await tester.tap(find.text('Powiększ'));
    expect(opened, ['fixture-s1-f1']);
  });

  testWidgets('chip tap goes to the source opener', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      host(
        TemplateRenderer(answer: fixture('steps')),
        overrides: [sourceOpenerProvider.overrideWithValue((_, s) => opened.add(s.pageLabel))],
      ),
    );
    await tester.tap(find.text('Przykład, s.\u00A022'));
    expect(opened, ['22']);
  });

  testWidgets('NoSource: exact texts, no 112', (tester) async {
    await tester.pumpWidget(host(TemplateRenderer(answer: fixture('no_source'))));
    expect(
      find.text('Nie wiem. Moje źródła tego nie opisują. Zapytaj lekarza, farmaceutę albo właściwą instytucję.'),
      findsOneWidget,
    );
    await tester.pumpWidget(host(TemplateRenderer(answer: fixture('off_topic'))));
    await tester.pumpAndSettle();
    expect(
      find.text('Pomagam tylko w sytuacjach kryzysowych i bezpieczeństwie. Tego nie opisują moje źródła.'),
      findsOneWidget,
    );
    expect(noSourceText.contains('112'), isFalse);
    expect(offTopicText.contains('112'), isFalse);
  });

  testWidgets('rescue card: label, VerifyBadge, 112 footer; unknown panels ignored', (tester) async {
    await tester.pumpWidget(host(TemplateRenderer(answer: fixture('call'))));
    expect(find.text('Karta ratunkowa'), findsOneWidget);
    expect(find.text('Do weryfikacji'), findsOneWidget);
    expect(find.text('Ta instrukcja nie zastępuje połączenia z 112.'), findsOneWidget);
    expect(find.byKey(const ValueKey('placeholder-call')), findsOneWidget);

    await tester.pumpWidget(host(TemplateRenderer(answer: fixture('unknown_ignored'))));
    await tester.pumpAndSettle();
    expect(find.text('Po nieznanym'), findsOneWidget);
    expect(find.textContaining('hologram'), findsNothing);
  });

  testWidgets('registry: placeholders for cpr/map/signal/animation and a plug-in builder', (tester) async {
    // `call` is drawn by the renderer's header, never as a panel.
    for (final t in ['cpr', 'map', 'signal', 'animation']) {
      await tester.pumpWidget(host(TemplateRenderer(answer: fixture(t))));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('placeholder-$t')), findsOneWidget, reason: t);
      expect(find.text(t), findsOneWidget);
    }

    final registry = TemplateRegistry.withDefaults()
      ..register('map', (c, s) => Text('real map ${(s.panel as MapPanel).target}'));
    await tester.pumpWidget(
      host(
        TemplateRenderer(answer: fixture('map')),
        overrides: [templateRegistryProvider.overrideWithValue(registry)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('real map nearest_shelter'), findsOneWidget);
    expect(find.byKey(const ValueKey('placeholder-map')), findsNothing);
  });

  testWidgets('gallery renders every fixture', (tester) async {
    tester.view.physicalSize = const Size(800, 40000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(const SizedBox.shrink()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [templateRegistryProvider.overrideWithValue(TemplateRegistry.withDefaults())],
        child: MaterialApp(theme: buildBzTheme(), home: const TemplateGalleryScreen()),
      ),
    );
    for (final name in templateFixtures.keys) {
      expect(find.byKey(ValueKey('fixture-$name')), findsOneWidget, reason: name);
    }
    expect(find.text('Teraz'), findsOneWidget);
    expect(find.text('Do plecaka'), findsOneWidget);
    expect(find.text('Lista do odhaczenia'), findsOneWidget);
    expect(find.text('Kto mieszka w domu?'), findsOneWidget);
    expect(find.text('Przykład · s. 14'), findsOneWidget);
    for (final t in ['cpr', 'map', 'signal', 'animation']) {
      expect(find.byKey(ValueKey('placeholder-$t')), findsWidgets, reason: t);
    }
    expect(tester.takeException(), isNull);

    // The gallery's form shows the message instead of sending it to the chat.
    await tester.tap(find.text('Gaz'));
    await tester.pump();
    await tester.tap(find.text('Wyślij'));
    await tester.pump();
    expect(find.text('Czym ogrzewasz dom: Gaz.'), findsOneWidget);
    expect(find.text('Kto mieszka w domu?'), findsNothing);
  });
}
