import 'dart:ui' show CheckedState;

import 'package:bezpiecznik/czat/templates/md_blocks.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/todo_panel.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _src = SourceRecord(sourceId: 'a', docId: 'd', docTitle: 'Dok', docShort: 'Dok', pageLabel: '3');

/// Pumps a todo with [n] items (all citing one page) and keeps `done` in state.
Future<({Set<int> done, List<int> shown})> _pump(WidgetTester tester, int n) async {
  final done = <int>{};
  final shown = <int>[];
  final answer = AssistantAnswer(
    sources: {'a': _src},
    panels: [
      TodoPanel(title: 'Do plecaka', items: [for (var i = 0; i < n; i++) PanelItem(text: 'rzecz $i', sourceId: 'a')]),
    ],
  );
  await tester.pumpWidget(MaterialApp(
    theme: buildBzTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (context, setState) => TodoPanelView(
            scope: PanelScope(
              panel: answer.panels.single,
              index: 0,
              answer: answer,
              variant: null,
              showVariantSwitch: false,
              onVariantChanged: (_) {},
              done: {...done},
              onDoneChanged: (i, v) => setState(() => v ? done.add(i) : done.remove(i)),
              onOpenSource: (_) {},
              footnotes: Footnotes.of(answer, null),
              onShowSources: () => shown.add(1),
            ),
          ),
        ),
      ),
    ),
  ));
  return (done: done, shown: shown);
}

void main() {
  testWidgets('todo: row tap toggles, counter follows, checked text is struck through', (tester) async {
    final h = await _pump(tester, 3);
    expect(find.text('Do plecaka'), findsOneWidget);
    expect(find.text('0 z 3'), findsOneWidget);

    await tester.tap(find.text('rzecz 1'));
    await tester.pump();
    expect(h.done, {1});
    expect(find.text('1 z 3'), findsOneWidget);
    final style = tester.widget<Text>(find.text('rzecz 1')).style!;
    expect(style.decoration, TextDecoration.lineThrough);
    expect(tester.getSemantics(find.byKey(const ValueKey('todo-1'))).flagsCollection.isChecked, CheckedState.isTrue);
    expect(tester.getSize(find.byKey(const ValueKey('todo-0'))).height, greaterThanOrEqualTo(48));

    await tester.tap(find.text('rzecz 1'));
    await tester.pump();
    expect(h.done, isEmpty);
    expect(find.text('0 z 3'), findsOneWidget);
  });

  testWidgets('todo: footnote tap shows sources and does not toggle the item', (tester) async {
    final h = await _pump(tester, 3);
    expect(find.byType(FootnoteMark), findsOneWidget, reason: 'one page -> one footnote after the last');
    await tester.tap(find.byType(FootnoteMark));
    await tester.pump();
    expect(h.shown, [1]);
    expect(h.done, isEmpty);
    expect(find.text('0 z 3'), findsOneWidget);
  });

  testWidgets('todo: more than 8 items collapse behind "Pokaż wszystkie"', (tester) async {
    await _pump(tester, 10);
    expect(find.textContaining('rzecz 7'), findsOneWidget);
    expect(find.text('rzecz 8'), findsNothing);
    expect(find.text('0 z 10'), findsOneWidget);
    // Footnote moves to the last shown item.
    expect(find.byType(FootnoteMark), findsOneWidget);

    await tester.tap(find.text('Pokaż wszystkie · 10'));
    await tester.pump();
    expect(find.textContaining('rzecz 9'), findsOneWidget);
    await tester.tap(find.text('Zwiń'));
    await tester.pump();
    expect(find.textContaining('rzecz 9'), findsNothing);
  });

  testWidgets('todo: 8 items show no collapse button', (tester) async {
    await _pump(tester, 8);
    expect(find.textContaining('Pokaż wszystkie'), findsNothing);
  });
}
