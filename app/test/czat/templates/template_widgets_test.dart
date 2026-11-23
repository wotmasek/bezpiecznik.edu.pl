import 'dart:convert';

import 'package:bezpiecznik/czat/templates/md_blocks.dart';
import 'package:bezpiecznik/czat/templates/no_source.dart';
import 'package:bezpiecznik/czat/templates/panel_card.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_fixtures.dart';
import 'package:bezpiecznik/czat/templates/template_gallery.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
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
  testWidgets('steps: heading, numbered list, a footnote ends each same-page run', (tester) async {
    await tester.pumpWidget(host(Stateful(fixture('steps'))));
    expect(find.text('Teraz'), findsOneWidget);
    expect(find.textContaining('Przykładowy krok 1', findRichText: true), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('3.'), findsOneWidget);
    // Pages 14, 22, 14 -> footnotes 1, 2, 1; no checkboxes.
    expect([for (final m in tester.widgetList<FootnoteMark>(find.byType(FootnoteMark))) m.number], [1, 2, 1]);
    expect(find.byType(BzCheck), findsNothing);
  });

  testWidgets('steps: variant switch changes the listed steps', (tester) async {
    await tester.pumpWidget(host(Stateful(fixture('steps_variants'))));
    Future<void> pick(String label) async {
      await tester.tap(find.byKey(const Key('variant-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    final step3 = find.textContaining('Przykładowy krok 3', findRichText: true);
    expect(step3, findsNothing, reason: 'adult has 2 steps');
    expect(find.text('Dorosły'), findsOneWidget);
    await pick('Dziecko');
    expect(step3, findsOneWidget);
    expect(find.text('Dziecko'), findsOneWidget);
    await pick('Niemowlę');
    expect(find.textContaining('Przykładowy krok 2', findRichText: true), findsNothing);
  });

  testWidgets('bullets: plain has no checkboxes, checkable has a counter', (tester) async {
    await tester.pumpWidget(host(Stateful(fixture('bullets'))));
    expect(find.text('Przykładowy element A'), findsOneWidget);
    expect(find.text('0 z 2'), findsNothing);

    await tester.pumpWidget(host(Stateful(fixture('bullets_checkable')), overrides: const []));
    await tester.pumpAndSettle();
    expect(find.text('0 z 2'), findsOneWidget);
    await tester.tap(find.byType(BzCheck).first);
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
    expect(find.text('Źródło'), findsOneWidget);
    expect(find.text('Dokument przykładowy (fixture)'), findsOneWidget);
    expect(find.textContaining('s. 14 · Fixture 2025'), findsOneWidget);
    expect(find.textContaining('Przykładowy fragment źródła'), findsOneWidget);
    expect(find.text('Tryb bez AI: fragmenty źródeł'), findsOneWidget);
    await tester.tap(find.text('Powiększ'));
    expect(opened, ['fixture-s1-f1']);
  });

  testWidgets('footnote tap unfolds the source list, a row opens the source', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      host(
        TemplateRenderer(answer: fixture('steps')),
        overrides: [sourceOpenerProvider.overrideWithValue((_, s) => opened.add(s.pageLabel))],
      ),
    );
    expect(find.byKey(const Key('sources-list')), findsNothing);
    await tester.tap(find.byType(FootnoteMark).at(1));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('source-row-2')));
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
    // No inline call panel: the chat pins "Zadzwoń 112" above the composer.
    expect(find.byKey(const ValueKey('placeholder-call')), findsNothing);

    await tester.pumpWidget(host(TemplateRenderer(answer: fixture('unknown_ignored'))));
    await tester.pumpAndSettle();
    expect(find.text('Po nieznanym'), findsOneWidget);
    expect(find.textContaining('hologram'), findsNothing);
  });

  testWidgets('registry: placeholders for call/cpr/map/signal/animation and a plug-in builder', (tester) async {
    for (final t in ['call', 'cpr', 'map', 'signal', 'animation']) {
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
    expect(find.text('Dokument przykładowy (fixture)'), findsOneWidget);
    for (final t in ['call', 'cpr', 'map', 'signal', 'animation']) {
      expect(find.byKey(ValueKey('placeholder-$t')), findsWidgets, reason: t);
    }
    expect(tester.takeException(), isNull);
  });
}
