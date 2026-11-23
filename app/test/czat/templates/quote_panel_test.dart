import 'dart:convert';

import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/quote_panel.dart';
import 'package:bezpiecznik/czat/templates/template_fixtures.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

AssistantAnswer quoteWith(String text) {
  final json = jsonDecode(templateFixtures['quote']!) as Map<String, dynamic>;
  (json['sources']['fixture-s1-f1'] as Map<String, dynamic>)['text'] = text;
  return AssistantAnswer.fromJson(json);
}

Future<List<String>> pump(WidgetTester t, String text) async {
  final opened = <String>[];
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        templateRegistryProvider.overrideWithValue(TemplateRegistry.withDefaults()),
        sourceOpenerProvider.overrideWithValue((_, s) => opened.add(s.sourceId)),
      ],
      child: MaterialApp(
        theme: buildBzTheme(),
        home: Scaffold(body: SingleChildScrollView(child: TemplateRenderer(answer: quoteWith(text)))),
      ),
    ),
  );
  return opened;
}

void main() {
  final longText = List.filled(60, 'Bardzo długi fragment źródła').join(' ');

  testWidgets('long quote: fade, whole-line clip, 48 dp Powiększ inside the paper opens source', (t) async {
    final opened = await pump(t, longText);
    expect(find.byKey(const ValueKey('quote-fade')), findsOneWidget);
    expect((quoteWindowMaxHeight - 18) % 22, 0);
    final paper = find.byType(ClipRRect).first;
    expect(t.getSize(paper).height, quoteWindowMaxHeight);
    final pill = find.byKey(const ValueKey('quote-expand'));
    expect(find.descendant(of: find.byType(QuotePaper), matching: pill), findsOneWidget);
    expect(t.getSize(pill).height, greaterThanOrEqualTo(48));
    expect(t.getSize(pill).width, greaterThanOrEqualTo(48));
    expect(t.getRect(pill).bottomRight, t.getRect(paper).bottomRight);
    expect(find.text('Przykład · s. 14'), findsOneWidget);
    expect(find.text('Dokument przykładowy (fixture)'), findsNothing);
    await t.tap(find.text(quoteExpandLabel));
    expect(opened, ['fixture-s1-f1']);
  });

  testWidgets('short quote: no fade', (t) async {
    await pump(t, 'Krótki fragment.');
    expect(find.byKey(const ValueKey('quote-fade')), findsNothing);
    expect(find.text('Powiększ'), findsOneWidget);
  });

  testWidgets('expanded paper (source sheet) has no Powiększ', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: buildBzTheme(),
      home: Scaffold(body: QuotePaper(text: longText, expanded: true, onTap: () {})),
    ));
    expect(find.byKey(const ValueKey('quote-expand')), findsNothing);
    expect(find.byKey(const ValueKey('quote-fade')), findsNothing);
  });
}
