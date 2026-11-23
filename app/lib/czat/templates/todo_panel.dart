import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_buttons.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'md_blocks.dart';
import 'panel_model.dart';
import 'template_registry.dart';

/// Items shown before "Pokaż wszystkie".
const int todoCollapsedCount = 8;

/// `todo`: heading with a "{checked} z {total}" counter and a list to tick
/// off (round checkboxes, the whole row toggles). Long lists collapse to
/// [todoCollapsedCount] items.
class TodoPanelView extends StatefulWidget {
  const TodoPanelView({super.key, required this.scope});

  final PanelScope scope;

  @override
  State<TodoPanelView> createState() => _TodoPanelViewState();
}

class _TodoPanelViewState extends State<TodoPanelView> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final scope = widget.scope;
    final panel = scope.panel as TodoPanel;
    final items = panel.items;
    final checked = scope.done.where((i) => i < items.length).length;
    final collapsible = items.length > todoCollapsedCount;
    final shown = collapsible && !_all ? todoCollapsedCount : items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: panel.title.isEmpty ? const SizedBox.shrink() : MdHeading(panel.title)),
            SizedBox(width: t.space2),
            Text(
              '$checked z ${items.length}',
              style: t.caption.copyWith(
                color: t.ink300,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SizedBox(height: t.space1),
        for (var i = 0; i < shown; i++)
          _TodoRow(
            key: ValueKey('todo-$i'),
            text: items[i].text,
            checked: scope.done.contains(i),
            onChanged: (v) => scope.onDoneChanged(i, v),
            footnote: footnoteAfter(scope.footnotes, scope.answer, items, i, shown: shown),
            onFootnote: scope.onShowSources,
          ),
        if (collapsible)
          Padding(
            padding: EdgeInsets.only(top: t.space2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: BzButton(
                label: _all ? 'Zwiń' : 'Pokaż wszystkie · ${items.length}',
                icon: _all ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                size: BzButtonSize.md,
                onPressed: () => setState(() => _all = !_all),
              ),
            ),
          ),
      ],
    );
  }
}

/// One to-do line: 20 dp round checkbox and the text; the whole row (min
/// 48 dp) is the tap target, the footnote pill keeps its own tap.
class _TodoRow extends StatelessWidget {
  const _TodoRow({
    super.key,
    required this.text,
    required this.checked,
    required this.onChanged,
    this.footnote,
    this.onFootnote,
  });

  final String text;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final int? footnote;
  final VoidCallback? onFootnote;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final style = checked
        ? t.chat.copyWith(
            color: t.ink300,
            decoration: TextDecoration.lineThrough,
            decorationColor: t.ink300,
          )
        : t.chat.copyWith(color: t.ink100);
    // Centres the 20 dp box on the first text line.
    final boxTop = ((style.fontSize ?? 17) * (style.height ?? 1.5) - 20) / 2;
    return Semantics(
      container: true,
      checked: checked,
      child: InkWell(
        onTap: () => onChanged(!checked),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.minTouchTarget),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: t.space2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: mdMarkerWidth,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: boxTop < 0 ? 0 : boxTop),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: checked ? t.ink100 : null,
                          border: Border.all(color: checked ? t.ink100 : t.line200, width: 1.5),
                        ),
                        child: checked ? Icon(LucideIcons.check, size: 14, color: t.bg000) : null,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: MdItemText(text: text, footnote: footnote, onFootnote: onFootnote, style: style),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
