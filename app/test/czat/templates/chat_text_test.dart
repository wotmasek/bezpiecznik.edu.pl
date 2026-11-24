import 'package:bezpiecznik/czat/templates/chat_text.dart';
import 'package:bezpiecznik/czat/templates/md_blocks.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('chat_text: plain text with the "Rozmowa" label', (tester) async {
    final a = AssistantAnswer.fromJson({
      'origin': 'ai',
      'panels': [
        {'type': 'chat_text', 'text': 'Spokojnie, jestem tu.'},
      ],
    });
    expect(a.panels.single, isA<ChatTextPanel>());
    expect(AssistantAnswer.fromJson(a.toJson()).panels.single, isA<ChatTextPanel>());
    await tester.pumpWidget(ProviderScope(
      overrides: [templateRegistryProvider.overrideWithValue(TemplateRegistry.withDefaults())],
      child: MaterialApp(
        theme: buildBzTheme(),
        home: Scaffold(body: TemplateRenderer(answer: a)),
      ),
    ));
    expect(find.text(chatTextLabel), findsOneWidget);
    expect(find.text('Spokojnie, jestem tu.'), findsOneWidget);
  });

  testWidgets('chat_text: markdown lists, bold and headings', (tester) async {
    final a = AssistantAnswer.fromJson({
      'origin': 'ai',
      'panels': [
        {'type': 'chat_text', 'text': '## Plan\nZrób **to** teraz.\n\n- woda\n- latarka\n\n1. Wyjdź'},
      ],
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [templateRegistryProvider.overrideWithValue(TemplateRegistry.withDefaults())],
      child: MaterialApp(theme: buildBzTheme(), home: Scaffold(body: TemplateRenderer(answer: a))),
    ));
    expect(find.byType(MdHeading), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Zrób to teraz.'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('Wyjdź'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
  });

  testWidgets('chat_text: cited sentences get footnote pills and the sources pill, no label', (tester) async {
    Map<String, Object?> src(String id, String page) => {
      'source_id': id,
      'doc_id': 'doc',
      'doc_short': 'Poradnik',
      'page_label': page,
      'pdf_page': 1,
      'text': 'Tekst $id.',
    };
    final a = AssistantAnswer.fromJson({
      'origin': 'ai',
      'panels': [
        {
          'type': 'chat_text',
          'text': 'Trzy litry wody. Nie wchodź do windy.',
          'items': [
            {'text': 'Trzy litry wody.', 'source_id': 'a'},
            {'text': ' Nie wchodź do windy.', 'source_id': 'b'},
          ],
        },
      ],
      'sources': {'a': src('a', '6'), 'b': src('b', '14')},
    });
    expect((a.panels.single as ChatTextPanel).items, hasLength(2));
    await tester.pumpWidget(ProviderScope(
      overrides: [templateRegistryProvider.overrideWithValue(TemplateRegistry.withDefaults())],
      child: MaterialApp(theme: buildBzTheme(), home: Scaffold(body: TemplateRenderer(answer: a))),
    ));
    expect(find.byType(FootnoteMark), findsNWidgets(2));
    expect(find.text(sourcesPillLabel(2)), findsOneWidget);
    expect(find.text(chatTextLabel), findsNothing);
  });
}
