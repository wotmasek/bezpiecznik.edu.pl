import 'package:bezpiecznik/czat/answer/answer_builder.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
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

    test('D2: an uncited list item is unsourced; cited items and paragraphs are not', () {
      final a = buildMarkdownAnswer(
        'Zrób zapas [1].\n\n- Spakuj wodę [1]\n- Weź latarkę\n\n1. Wyjdź z budynku\n\nNie martw się.',
        [c2],
        risk: false,
      );
      final bullets = a.panels.whereType<BulletsPanel>().single.items;
      expect([for (final i in bullets) i.unsourced], [false, true]);
      expect(a.panels.whereType<StepsPanel>().single.items.single.unsourced, isTrue);
      final texts = a.panels.whereType<ChatTextPanel>().toList();
      expect(texts, hasLength(2));
      expect(texts.expand((p) => p.items).any((i) => i.unsourced), isFalse);
      expect(a.toJson().toString(), contains('unsourced: true'));
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
      expect(cleanAnswerText('Gotuj wodę [Poradnik 1].'), 'Gotuj wodę [1].');
    });
    test('leaves "Rozumiem" inside a sentence alone', () {
      expect(cleanAnswerText('Nie rozumiem pytania.'), 'Nie rozumiem pytania.');
    });
  });

  test('emergency numbers are never "sprawdź w źródle"', () {
    final c = chunk('x', 'Bądź czujny.');
    expect(numberNotInSource('Zadzwoń pod 112 albo 116 123.', c), isFalse);
    expect(numberNotInSource('Weź 5 litrów.', c), isTrue);
  });
}
