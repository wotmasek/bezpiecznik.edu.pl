import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_buttons.dart';
import '../../wspolne/theme/bz_chip.dart';
import '../../wspolne/theme/bz_theme.dart';
import '../ui/chat_controller.dart';
import 'panel_model.dart';
import 'template_registry.dart';

/// Hint under a multiple-choice question.
const String formMultipleHint = 'Możesz wybrać kilka';

/// Sends the form answers as the user's next message. Default: the chat
/// controller; tests and the gallery override it.
final formSenderProvider = Provider<void Function(String text)>(
  (ref) => (text) => ref.read(chatControllerProvider.notifier).send(text),
);

/// The message built from the answers: `"Kto mieszka w domu: Dorośli,
/// Dzieci. Czym ogrzewasz dom: Gaz."`. Unanswered questions are left out;
/// options keep the order of the form.
String formAnswerText(List<FormQuestion> questions, List<Set<int>> picked) {
  final parts = [
    for (var q = 0; q < questions.length; q++)
      if (picked[q].isNotEmpty)
        '${questions[q].text.replaceFirst(RegExp(r'[\s?]+$'), '')}: '
            '${[for (var o = 0; o < questions[q].options.length; o++) if (picked[q].contains(o)) questions[q].options[o]].join(', ')}',
  ];
  return parts.isEmpty ? '' : '${parts.join('. ')}.';
}

/// `form`: 1-3 choice questions in one bordered block; "Wyślij" sends the
/// answers as the user's message, "Pomiń" just closes it. A closed form
/// (sent or skipped, stored in the answer) renders nothing.
class FormPanelView extends ConsumerStatefulWidget {
  const FormPanelView({super.key, required this.scope});

  final PanelScope scope;

  @override
  ConsumerState<FormPanelView> createState() => _FormPanelViewState();
}

class _FormPanelViewState extends ConsumerState<FormPanelView> {
  late final List<Set<int>> _picked = [
    for (final _ in (widget.scope.panel as FormPanel).questions) <int>{},
  ];

  void _toggle(FormQuestion q, int qi, int o) => setState(() {
    final set = _picked[qi];
    if (set.remove(o)) return;
    if (!q.multiple) set.clear();
    set.add(o);
  });

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    if (scope.answer.formClosed(scope.index)) return const SizedBox.shrink();
    final t = context.bz;
    final questions = (scope.panel as FormPanel).questions;
    final hasAnswer = _picked.any((s) => s.isNotEmpty);
    return Container(
      padding: EdgeInsets.all(t.space4),
      decoration: BoxDecoration(
        color: t.bg100,
        border: Border.all(color: t.line100),
        borderRadius: BorderRadius.circular(t.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var qi = 0; qi < questions.length; qi++) ...[
            Text(questions[qi].text, style: t.chat.copyWith(color: t.ink100, fontWeight: FontWeight.w600)),
            if (questions[qi].multiple) Text(formMultipleHint, style: t.caption.copyWith(color: t.ink300)),
            SizedBox(height: t.space1),
            Wrap(
              spacing: t.space2,
              children: [
                for (var o = 0; o < questions[qi].options.length; o++)
                  // 40 dp chip, 48 dp hit area: the 4 dp above and below
                  // also toggle it.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: () => _toggle(questions[qi], qi, o),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: (t.minTouchTarget - BzChip.height) / 2),
                      child: BzChip(
                        label: questions[qi].options[o],
                        selected: _picked[qi].contains(o),
                        onChanged: (_) => _toggle(questions[qi], qi, o),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: t.space5),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              BzButton(
                label: 'Pomiń',
                variant: BzButtonVariant.ghost,
                onPressed: () => scope.onDoneChanged(0, true),
              ),
              SizedBox(width: t.space2),
              BzButton(
                label: 'Wyślij',
                variant: BzButtonVariant.primary,
                size: BzButtonSize.lg,
                onPressed: hasAnswer
                    ? () {
                        final text = formAnswerText(questions, _picked);
                        scope.onDoneChanged(0, true);
                        ref.read(formSenderProvider)(text);
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
