import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'md_blocks.dart';
import 'md_text.dart';
import 'panel_model.dart';
import 'template_registry.dart';

/// Small label over a conversational reply that cites no guide.
const String chatTextLabel = 'Rozmowa';

/// `chat_text`: chat text with light markdown, no card. A paragraph with
/// cited sentences ([ChatTextPanel.items]) gets a footnote pill after each
/// run of sentences citing the same page. The "Rozmowa" label shows once,
/// over the first chat text of an answer that cites nothing.
class ChatTextView extends StatelessWidget {
  const ChatTextView({super.key, required this.scope});

  final PanelScope scope;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final panel = scope.panel as ChatTextPanel;
    final firstChat = scope.answer.panels.indexWhere((p) => p is ChatTextPanel) == scope.index;
    final showLabel = firstChat && scope.footnotes.groups.isEmpty;
    final items = panel.items;
    final style = t.chat.copyWith(color: t.ink100);
    const bold = TextStyle(fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(chatTextLabel, style: t.caption.copyWith(color: t.ink200)),
          SizedBox(height: t.space2),
        ],
        if (items.isEmpty)
          MdText(panel.text)
        else
          Text.rich(
            TextSpan(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  ...mdInline(items[i].text, bold),
                  if (footnoteAfter(scope.footnotes, scope.answer, items, i) case final n?)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(left: t.space2 - 2),
                        child: FootnoteMark(number: n, onTap: scope.onShowSources),
                      ),
                    ),
                  if (items[i].check) checkSourceSpan(context),
                ],
              ],
            ),
            style: style,
          ),
      ],
    );
  }
}
