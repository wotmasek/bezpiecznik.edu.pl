import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'md_blocks.dart';

/// Kind of one block of chat markdown.
enum MdKind { paragraph, bullet, numbered, heading }

/// One block: a paragraph (lines joined with '\n'), a list line or a heading.
class MdBlock {
  const MdBlock(this.kind, this.text, {this.marker = ''});

  final MdKind kind;
  final String text;

  /// `"3."` for numbered lines, `"•"` for bullets.
  final String marker;

  @override
  bool operator ==(Object other) =>
      other is MdBlock && other.kind == kind && other.text == text && other.marker == marker;

  @override
  int get hashCode => Object.hash(kind, text, marker);

  @override
  String toString() => 'MdBlock($kind, $marker, $text)';
}

final _bullet = RegExp(r'^\s*[-*•]\s+(.*)$');
final _numbered = RegExp(r'^\s*(\d{1,3})[.)]\s+(.*)$');
final _heading = RegExp(r'^\s*#{1,3}\s+(.*)$');

/// Small markdown subset of the model's chat text: paragraphs (blank line),
/// `- `/`* `/`• ` bullets, `1. ` numbered lines, `#`-`###` headings.
/// Everything else is plain text.
List<MdBlock> parseMd(String src) {
  final out = <MdBlock>[];
  final para = <String>[];
  void flush() {
    if (para.isNotEmpty) out.add(MdBlock(MdKind.paragraph, para.join('\n')));
    para.clear();
  }

  for (final line in src.split('\n')) {
    if (line.trim().isEmpty) {
      flush();
    } else if (_heading.firstMatch(line) case final m?) {
      flush();
      out.add(MdBlock(MdKind.heading, m[1]!.trim()));
    } else if (_bullet.firstMatch(line) case final m?) {
      flush();
      out.add(MdBlock(MdKind.bullet, m[1]!.trim(), marker: '•'));
    } else if (_numbered.firstMatch(line) case final m?) {
      flush();
      out.add(MdBlock(MdKind.numbered, m[2]!.trim(), marker: '${m[1]}.'));
    } else {
      para.add(line.trim());
    }
  }
  flush();
  return out;
}

/// `**bold**` spans; an unmatched `**` stays literal.
List<TextSpan> mdInline(String text, TextStyle bold) {
  final parts = text.split('**');
  if (parts.length.isEven) {
    final tail = parts.removeLast();
    parts.last = '${parts.last}**$tail';
  }
  return [
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty) TextSpan(text: parts[i], style: i.isOdd ? bold : null),
  ];
}

/// Renders [text] as chat markdown (see [parseMd]).
class MdText extends StatelessWidget {
  const MdText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final style = t.chat.copyWith(color: t.ink100);
    const bold = TextStyle(fontWeight: FontWeight.w700);
    final blocks = parseMd(text);
    Widget rich(String s) => Text.rich(TextSpan(children: mdInline(s, bold)), style: style);
    bool isList(MdBlock b) => b.kind == MdKind.bullet || b.kind == MdKind.numbered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(
              top: i == 0 ? 0 : (isList(blocks[i]) && isList(blocks[i - 1]) ? t.space1 : t.space3),
            ),
            child: switch (blocks[i].kind) {
              MdKind.heading => MdHeading(blocks[i].text),
              MdKind.paragraph => rich(blocks[i].text),
              _ => MdListItem(marker: blocks[i].marker, child: rich(blocks[i].text)),
            },
          ),
      ],
    );
  }
}
