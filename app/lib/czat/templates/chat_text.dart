import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'md_text.dart';

/// Small label over a conversational reply: it is not a sourced answer.
const String chatTextLabel = 'Rozmowa – nie z poradników';

/// `chat_text`: chat text (small talk, calming) with light markdown, no card,
/// no sources.
class ChatTextView extends StatelessWidget {
  const ChatTextView({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(chatTextLabel, style: t.caption.copyWith(color: t.ink200)),
        SizedBox(height: t.space2),
        MdText(text),
      ],
    );
  }
}
