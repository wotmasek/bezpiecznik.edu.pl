import 'package:bezpiecznik/czat/answer/answer_builder.dart';
import 'package:bezpiecznik/czat/templates/form_panel.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<List<String>> pump(WidgetTester t, AssistantAnswer a, [List<AssistantAnswer>? changed]) async {
  final sent = <String>[];
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        templateRegistryProvider.overrideWithValue(TemplateRegistry.withDefaults()),
        formSenderProvider.overrideWithValue(sent.add),
      ],
      child: MaterialApp(
        theme: buildBzTheme(),
        home: Scaffold(body: TemplateRenderer(answer: a, onChanged: changed?.add)),
      ),
    ),
  );
  return sent;
}

void main() {
  test('looksTruncated: long text and unfinished near-limit text, not a short or finished one', () {
    expect(looksTruncated('Krótka odpowiedź.'), isFalse);
    expect(looksTruncated('${'a' * 1500}.'), isTrue); // at the limit, even with a final dot
    expect(looksTruncated('${'a' * 1200} i dalej'), isTrue); // near the limit, mid-sentence
    expect(looksTruncated('${'a' * 1200}.'), isFalse); // near the limit, finished
    expect(looksTruncated('Krótka bez kropki'), isFalse);
  });

  test('truncated round-trips through json and defaults to false', () {
    expect(const AssistantAnswer().truncated, isFalse);
    expect(AssistantAnswer.fromJson(const AssistantAnswer(truncated: true).toJson()).truncated, isTrue);
  });

  final text = buildMarkdownAnswer('Tekst odpowiedzi.', const [], risk: false);

  testWidgets('no button without the flag', (t) async {
    await pump(t, text);
    expect(find.text('Pokaż więcej'), findsNothing);
  });

  testWidgets('flagged answer shows the button; tap sends "Kontynuuj." and clears the flag', (t) async {
    final changed = <AssistantAnswer>[];
    final sent = await pump(t, text.copyWith(truncated: true), changed);
    expect(find.text('Pokaż więcej'), findsOneWidget);
    await t.tap(find.byKey(const Key('show-more')));
    expect(sent, ['Kontynuuj.']);
    expect(changed.single.truncated, isFalse);
  });
}
