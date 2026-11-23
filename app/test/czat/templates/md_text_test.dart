import 'package:bezpiecznik/czat/templates/md_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('parseMd: paragraphs, bullets, numbered lines, headings', () {
    expect(parseMd('## Co teraz\nPierwsza linia\ndruga linia\n\n- jeden\n* dwa\n• trzy\n\n1. krok\n2) drugi\n\n**Ważne** na końcu'), [
      const MdBlock(MdKind.heading, 'Co teraz'),
      const MdBlock(MdKind.paragraph, 'Pierwsza linia\ndruga linia'),
      const MdBlock(MdKind.bullet, 'jeden', marker: '•'),
      const MdBlock(MdKind.bullet, 'dwa', marker: '•'),
      const MdBlock(MdKind.bullet, 'trzy', marker: '•'),
      const MdBlock(MdKind.numbered, 'krok', marker: '1.'),
      const MdBlock(MdKind.numbered, 'drugi', marker: '2.'),
      const MdBlock(MdKind.paragraph, '**Ważne** na końcu'),
    ]);
  });

  test('parseMd: plain text stays one paragraph; no-space markers are text', () {
    expect(parseMd('Spokojnie, jestem tu.'), [const MdBlock(MdKind.paragraph, 'Spokojnie, jestem tu.')]);
    expect(parseMd('#hashtag\n-5 stopni\n2024.'), [const MdBlock(MdKind.paragraph, '#hashtag\n-5 stopni\n2024.')]);
    expect(parseMd('\n\n'), isEmpty);
  });

  test('mdInline: **bold**, unmatched ** stays literal', () {
    const b = TextStyle(fontWeight: FontWeight.w700);
    final spans = mdInline('a **b** c', b);
    expect([for (final s in spans) s.text], ['a ', 'b', ' c']);
    expect(spans[1].style, b);
    expect(spans[0].style, isNull);
    expect([for (final s in mdInline('2 ** 3', b)) s.text].join(), '2 ** 3');
    expect([for (final s in mdInline('**a** i **b', b)) s.text].join(), 'a i **b');
  });
}
