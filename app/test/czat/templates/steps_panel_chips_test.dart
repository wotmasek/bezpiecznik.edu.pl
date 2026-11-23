import 'package:bezpiecznik/czat/templates/md_blocks.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/steps_panel.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

SourceRecord _src(String id, String page) => SourceRecord(
  sourceId: id,
  docId: 'erc',
  docTitle: 'ERC 2025',
  docShort: 'ERC',
  pageLabel: page,
);

Future<void> _pump(WidgetTester tester, List<String> ids) async {
  final answer = AssistantAnswer(
    sources: {'a': _src('a', '67'), 'b': _src('b', '70')},
    panels: [
      StepsPanel(title: 'T', items: [for (var i = 0; i < ids.length; i++) PanelItem(text: 'krok $i', sourceId: ids[i])]),
    ],
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildBzTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: StepsPanelView(
            scope: PanelScope(
              panel: answer.panels.first,
              index: 0,
              answer: answer,
              variant: null,
              showVariantSwitch: false,
              onVariantChanged: (_) {},
              done: const {},
              onDoneChanged: (_, _) {},
              onOpenSource: (_) {},
              footnotes: Footnotes.of(answer, null),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Footnote number drawn after each of the first [count] steps (null = none).
List<int?> _marks(WidgetTester tester, int count) => [
  for (var i = 0; i < count; i++)
    () {
      final m = find.descendant(
        of: find.ancestor(of: find.text('${i + 1}.'), matching: find.byType(MdListItem)),
        matching: find.byType(FootnoteMark),
      );
      return m.evaluate().isEmpty ? null : tester.widget<FootnoteMark>(m).number;
    }(),
];

void main() {
  testWidgets('same page on 3 steps -> one footnote at the end of the run', (tester) async {
    await _pump(tester, ['a', 'a', 'a']);
    expect(_marks(tester, 3), [null, null, 1]);
  });

  testWidgets('A, A, B -> footnotes after step 2 and step 3', (tester) async {
    await _pump(tester, ['a', 'a', 'b']);
    expect(_marks(tester, 3), [null, 1, 2]);
  });

  testWidgets('collapsed list puts the footnote on the last visible step', (tester) async {
    await _pump(tester, List.filled(7, 'a'));
    expect(find.text('6.'), findsNothing);
    expect(_marks(tester, 5), [null, null, null, null, 1]);
  });

  testWidgets('43 steps: 5 shown, "Pokaż wszystkie kroki · 43" expands, "Zwiń" collapses', (tester) async {
    await _pump(tester, List.filled(43, 'a'));
    expect(find.byType(MdListItem), findsNWidgets(5));
    expect(find.text('5.'), findsOneWidget);
    expect(find.text('6.'), findsNothing);
    expect(tester.getSize(find.byKey(const Key('steps-toggle'))).height, greaterThanOrEqualTo(48));

    await tester.tap(find.text(stepsShowAllLabel(43)));
    await tester.pump();
    expect(find.byType(MdListItem), findsNWidgets(43));
    expect(find.text('43.'), findsOneWidget);
    expect(_marks(tester, 5), [null, null, null, null, null]);

    await tester.ensureVisible(find.text(stepsCollapseLabel));
    await tester.tap(find.text(stepsCollapseLabel));
    await tester.pump();
    expect(find.byType(MdListItem), findsNWidgets(5));
    expect(find.text(stepsShowAllLabel(43)), findsOneWidget);
  });

  testWidgets('5 steps or fewer: no toggle button', (tester) async {
    await _pump(tester, List.filled(5, 'a'));
    expect(find.byKey(const Key('steps-toggle')), findsNothing);
  });

  testWidgets('footnote pill stays small and inline (not a full-width bar)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildBzTheme(),
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: MdItemText(text: 'Krok do wykonania.', footnote: 1, onFootnote: () {}),
        ),
      ),
    ));
    final size = tester.getSize(find.byType(FootnoteMark));
    expect(size.width, lessThan(40));
    expect(size.height, lessThanOrEqualTo(26));
  });
}
