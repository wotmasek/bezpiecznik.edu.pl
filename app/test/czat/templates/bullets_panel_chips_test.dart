import 'package:bezpiecznik/czat/templates/bullets_panel.dart';
import 'package:bezpiecznik/czat/templates/md_blocks.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
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

Future<void> _pump(WidgetTester tester, List<String> ids, {VoidCallback? onShowSources}) async {
  final answer = AssistantAnswer(
    sources: {'a': _src('a', '67'), 'b': _src('b', '70')},
    panels: [
      BulletsPanel(title: 'T', items: [for (final id in ids) PanelItem(text: 'punkt $id', sourceId: id)]),
    ],
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildBzTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BulletsPanelView(
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
              onShowSources: onShowSources,
            ),
          ),
        ),
      ),
    ),
  );
}

List<int> _marks(WidgetTester tester) =>
    [for (final m in tester.widgetList<FootnoteMark>(find.byType(FootnoteMark))) m.number];

void main() {
  testWidgets('bullets: same source on 3 items -> one footnote after the last', (tester) async {
    await _pump(tester, ['a', 'a', 'a']);
    expect(_marks(tester), [1]);
    expect(find.text('•'), findsNWidgets(3));
  });

  testWidgets('bullets: A, A, B -> [1] [2]; A, B, A -> [1] [2] [1]', (tester) async {
    await _pump(tester, ['a', 'a', 'b']);
    expect(_marks(tester), [1, 2]);
    await _pump(tester, ['a', 'b', 'a']);
    expect(_marks(tester), [1, 2, 1]);
  });

  testWidgets('bullets: footnote tap shows the sources', (tester) async {
    var shown = 0;
    await _pump(tester, ['a'], onShowSources: () => shown++);
    await tester.tap(find.byType(FootnoteMark));
    expect(shown, 1);
  });
}
