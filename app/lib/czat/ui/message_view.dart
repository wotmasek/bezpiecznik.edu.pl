import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import '../data/chat_store.dart';
import '../templates/panel_model.dart';
import '../templates/template_renderer.dart';
import 'chat_controller.dart';
import 'thinking.dart';

const String copyLabel = 'Kopiuj';

/// One message of the list: user bubble on the right (bg-200, radius 18, max
/// 80% wide), assistant content on the full width on the left.
class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.message, required this.onAnswerChanged});

  final ChatMessage message;
  final ValueChanged<AssistantAnswer> onAnswerChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: 0.8,
          alignment: Alignment.centerRight,
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onLongPressStart: (d) => _copyMenu(context, d.globalPosition),
              child: Container(
                key: const Key('user-bubble'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: t.bg200,
                  borderRadius: BorderRadius.circular(t.radiusLg),
                ),
                child: Text(message.text, style: t.chat),
              ),
            ),
          ),
        ),
      );
    }
    switch (message.status) {
      // A risk conversation keeps "Zadzwoń 112" pinned above the composer
      // (chat screen), so no state here carries a call card.
      case MessageStatus.generating:
        return Thinking(phase: message.phase, partialText: message.partialText);
      case MessageStatus.stopped:
      case MessageStatus.error:
        return Text(
          message.text,
          style: t.chat.copyWith(color: message.status == MessageStatus.stopped ? t.ink300 : t.ink200),
        );
      case MessageStatus.done:
        final answer = message.answer;
        if (answer == null) return const SizedBox.shrink();
        return TemplateRenderer(answer: answer, onChanged: onAnswerChanged);
    }
  }

  Future<void> _copyMenu(BuildContext context, Offset at) async {
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
      items: const [PopupMenuItem(value: 'copy', child: Text(copyLabel))],
    );
    if (picked == 'copy') await Clipboard.setData(ClipboardData(text: message.text));
  }
}
