import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../ratunek/ui/card_link_button.dart';
import '../../wspolne/theme/bz_buttons.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'md_blocks.dart';
import 'panel_model.dart';
import 'template_registry.dart';

/// Steps shown before "Pokaż wszystkie kroki".
const int stepsCollapsedCount = 5;

/// Label of the expand button: `Pokaż wszystkie kroki · {n}`.
String stepsShowAllLabel(int n) => 'Pokaż wszystkie kroki · $n';

/// Label of the collapse button.
const String stepsCollapseLabel = 'Zwiń';

/// `steps`: an optional heading and a numbered list, as plain text (no card).
/// A footnote `[n]` ends each run of steps citing the same page. Lists longer
/// than [stepsCollapsedCount] start collapsed.
class StepsPanelView extends StatefulWidget {
  const StepsPanelView({super.key, required this.scope});

  final PanelScope scope;

  @override
  State<StepsPanelView> createState() => _StepsPanelViewState();
}

class _StepsPanelViewState extends State<StepsPanelView> {
  bool _expanded = false;

  @override
  void didUpdateWidget(StepsPanelView old) {
    super.didUpdateWidget(old);
    if (old.scope.variant != widget.scope.variant) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final scope = widget.scope;
    final panel = scope.panel as StepsPanel;
    final items = panel.itemsFor(scope.variant);
    final variant = scope.variant ?? scope.answer.selectedVariant;
    final collapsible = items.length > stepsCollapsedCount;
    final shown = collapsible && !_expanded ? stepsCollapsedCount : items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (panel.title.isNotEmpty) ...[MdHeading(panel.title), SizedBox(height: t.space2)],
        for (var i = 0; i < shown; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : t.space1),
            child: MdListItem(
              marker: '${i + 1}.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MdItemText(
                    text: items[i].text,
                    footnote: footnoteAfter(scope.footnotes, scope.answer, items, i, shown: shown),
                    onFootnote: scope.onShowSources,
                check: items[i].check,
                unsourced: items[i].unsourced,
                  ),
                  if (items[i].cardLinkLabel != null && items[i].cardLinkId != null)
                    CardLinkButton(label: items[i].cardLinkLabel!, cardId: items[i].cardLinkId!, variant: variant),
                ],
              ),
            ),
          ),
        if (collapsible) ...[
          SizedBox(height: t.space3),
          Align(
            alignment: Alignment.centerLeft,
            child: BzButton(
              key: const Key('steps-toggle'),
              label: _expanded ? stepsCollapseLabel : stepsShowAllLabel(items.length),
              icon: _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              variant: BzButtonVariant.secondary,
              size: BzButtonSize.md,
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
        ],
      ],
    );
  }
}
