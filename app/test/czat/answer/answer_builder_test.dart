import 'package:bezpiecznik/czat/answer/answer_builder.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Map<String, Object?> _steps(String title, List<String> texts, {String type = 'steps'}) => {
  'type': type,
  'title': title,
  'items': [
    for (final t in texts) {'text': t, 'source_id': 'c1'},
  ],
};

void main() {
  final chunks = [chunk('c1', 'tekst')];

  List<String> itemTexts(ChatPanel p) => [for (final i in (p as StepsPanel).items) i.text];

  // The on-device model often writes one panel per step, each numbered "1".
  test('one-step panels with the same title become one numbered list', () {
    final a = buildModelAnswer(
      [
        _steps('Co zrobić', ['Pierwszy krok.']),
        _steps('Co zrobić', ['Drugi krok.']),
        _steps('Co zrobić', ['Trzeci krok.']),
      ],
      chunks,
      risk: false,
    );
    expect(a.panels, hasLength(1));
    expect(itemTexts(a.panels.single), ['Pierwszy krok.', 'Drugi krok.', 'Trzeci krok.']);
  });

  test('panels with different titles or types stay apart', () {
    final a = buildModelAnswer(
      [
        _steps('Teraz', ['A.']),
        _steps('Potem', ['B.']),
        _steps('Potem', ['C.'], type: 'bullets'),
      ],
      chunks,
      risk: false,
    );
    expect(a.panels, hasLength(3));
  });

  test('only neighbours merge: a quote in between keeps the order of the answer', () {
    final a = buildModelAnswer(
      [
        _steps('Teraz', ['A.']),
        {'type': 'quote', 'source_id': 'c1'},
        _steps('Teraz', ['B.']),
      ],
      chunks,
      risk: false,
    );
    expect([for (final p in a.panels) p.type], ['steps', 'quote', 'steps']);
  });

  Map<String, Object?> form() => {
    'type': 'form',
    'questions': [
      {'text': 'Gdzie jesteś?', 'multiple': false, 'options': ['W domu', 'Na zewnątrz']},
    ],
  };

  test('todo stays a todo without risk, becomes bullets on a risk question', () {
    final todo = _steps('Do plecaka', ['Woda.'], type: 'todo');
    expect(buildModelAnswer([todo], chunks, risk: false).panels.single, isA<TodoPanel>());
    final risky = buildModelAnswer([todo], chunks, risk: true);
    expect([for (final p in risky.panels) p.type], ['call', 'bullets']);
  });

  test('a form is kept only alone and never on a risk question', () {
    expect(buildModelAnswer([form()], chunks, risk: false).panels.single, isA<FormPanel>());
    expect(
      [for (final p in buildModelAnswer([form(), _steps('Teraz', ['A.'])], chunks, risk: false).panels) p.type],
      ['steps'],
    );
    expect([for (final p in buildModelAnswer([form()], chunks, risk: true).panels) p.type], ['call']);
  });

  test('the call panel still goes first for a risk phrase', () {
    final a = buildModelAnswer(
      [_steps('Teraz', ['A.']), _steps('Teraz', ['B.'])],
      chunks,
      risk: true,
    );
    expect([for (final p in a.panels) p.type], ['call', 'steps']);
  });

  group('markdown answer', () {
    final c1 = chunk('c1', 'Uciskaj klatkę piersiową 30 razy, potem 2 oddechy.');
    final c2 = chunk('c2', 'Zapas wody: 1,5 litra na osobę.');

    test('a number missing from the cited chunk is marked, not deleted', () {
      final a = buildMarkdownAnswer(
        '1. Uciskaj 30 razy [1].\n2. Uciskaj 100 razy na minutę [1].\n3. Wypij 1.5 litra [2].',
        [c1, c2],
        risk: false,
      );
      final items = (a.panels.single as StepsPanel).items;
      expect([for (final i in items) i.check], [false, true, false]);
      expect(items[1].text, 'Uciskaj 100 razy na minutę.');
    });

    test('a paragraph sentence is marked too; uncited numbers are not checked', () {
      final a = buildMarkdownAnswer('Uciskaj 50 razy [1]. Dzwoń pod 112.', [c1], risk: false);
      final p = a.panels.single as ChatTextPanel;
      expect([for (final i in p.items) (i.sourceId, i.check)], [('c1', true), (null, false)]);
    });

    test('risk never gets a form or todo; crisis adds 116 123 and the call panel', () {
      final r = buildMarkdownAnswer('- Spakuj wodę [1]', [c2], risk: true);
      expect([for (final p in r.panels) p.type], ['call', 'bullets']);
      final c = buildMarkdownAnswer('Jestem tu. Czy jesteś w bezpiecznym miejscu?', const [], risk: false, crisis: true);
      expect(c.panels.first, isA<CallPanel>());
      expect((c.panels.last as ChatTextPanel).text, contains('116 123'));
    });

    test('placeholders copied from the prompt are removed', () {
      final a = buildMarkdownAnswer('Masz psa [Profil domu]. Tak [n].', const [], risk: false);
      expect((a.panels.single as ChatTextPanel).text, 'Masz psa. Tak.');
    });
  });

  group('cleanAnswerText', () {
    test('drops a leading "Rozumiem, że" and keeps the rest', () {
      expect(cleanAnswerText('Rozumiem, że czujesz lęk. Co się stało?'), 'Czujesz lęk. Co się stało?');
      expect(cleanAnswerText('Oczywiście. Weź wodę [1].'), 'Weź wodę [1].');
    });
    test('removes invented word citations, keeps numeric ones', () {
      expect(cleanAnswerText('Zostań w domu [Poradnik]. Woda [2].'), 'Zostań w domu. Woda [2].');
    });
    test('leaves "Rozumiem" inside a sentence alone', () {
      expect(cleanAnswerText('Nie rozumiem pytania.'), 'Nie rozumiem pytania.');
    });
  });
}
