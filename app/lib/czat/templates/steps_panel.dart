import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../ratunek/ui/card_link_button.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'panel_card.dart';
import 'panel_model.dart';
import 'template_registry.dart';

/// Header shown when every step is checked (spec `steps` "Stany").
const String stepsAllDoneText = 'Wszystko zrobione';


/// `steps`: numbered, checkable steps; a source chip appears under a step only
/// when its source differs from the previous step's (BG18: no repeated chips).
/// The first unchecked step is the current one (bar + bold).
class StepsPanelView extends StatelessWidget {
  const StepsPanelView({super.key, required this.scope});

  final PanelScope scope;

  @override
  Widget build(BuildContext context) {
    final panel = scope.panel as StepsPanel;
    final items = panel.itemsFor(scope.variant);
    final done = scope.done;
    final indexes = List.generate(items.length, (i) => i);
    final allDone = items.isNotEmpty && indexes.every(done.contains);
    final current = indexes.indexWhere((i) => !done.contains(i));

    return PanelCard(
      title: allDone ? '${panel.title}: $stepsAllDoneText' : panel.title,
      done: allDone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            _StepRow(
              number: i + 1,
              item: items[i],
              source: _chipSource(scope, items, i),
              variant: scope.variant ?? scope.answer.selectedVariant,
              done: done.contains(i),
              current: i == current,
              onChanged: (v) => scope.onDoneChanged(i, v),
              onOpenSource: scope.onOpenSource,
            ),
        ],
      ),
    );
  }
}

/// Source for step [i]'s chip, or null when it equals the previous step's.
SourceRecord? _chipSource(PanelScope scope, List<PanelItem> items, int i) {
  final s = scope.answer.source(items[i].sourceId);
  if (s == null || i == 0) return s;
  final p = scope.answer.source(items[i - 1].sourceId);
  final same =
      p != null &&
      p.docId == s.docId &&
      p.pageLabel == s.pageLabel &&
      p.chipLabel == s.chipLabel;
  return same ? null : s;
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.item,
    required this.source,
    required this.variant,
    required this.done,
    required this.current,
    required this.onChanged,
    required this.onOpenSource,
  });

  final int number;
  final PanelItem item;
  final SourceRecord? source;
  final String? variant;
  final bool done;
  final bool current;
  final ValueChanged<bool> onChanged;
  final void Function(SourceRecord) onOpenSource;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final numBg = done ? t.verifiedTint : (current ? t.signal : t.bg300);
    final numFg = done ? t.verified : (current ? t.signalInk : t.ink200);
    return Padding(
      padding: EdgeInsets.only(bottom: t.space1),
      // Reference czat-odpowiedz.png: the number sits on the title's left
      // edge and the current-step tint and bar bleed `space-2` into the
      // card padding (painted outside the row, layout unchanged).
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -t.space2,
            right: -t.space2,
            top: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: t.durationBase,
              curve: t.easeInOut,
              decoration: BoxDecoration(
                color: current
                    ? t.overlayHover
                    : t.overlayHover.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(t.radiusMd),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: t.space3, bottom: t.space1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: numBg,
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? Icon(LucideIcons.check, size: 16, color: numFg)
                      : Text(
                          '$number',
                          style: t.label.copyWith(
                            color: numFg,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                ),
                SizedBox(width: t.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.text,
                        style: t.chat.copyWith(
                          height: 28 / 17,
                          fontWeight: current
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: done ? t.ink300 : t.ink100,
                        ),
                      ),
                      if (source != null)
                        SourceChip(
                          source: source!,
                          onTap: () => onOpenSource(source!),
                        ),
                      if (item.cardLinkLabel != null && item.cardLinkId != null)
                        CardLinkButton(
                          label: item.cardLinkLabel!,
                          cardId: item.cardLinkId!,
                          variant: variant,
                        ),
                    ],
                  ),
                ),
                // The 48 dp hit area is taller than the 28 dp first line;
                // lift it so the 24 dp visual box centres on that line
                // (hit testing follows the transform).
                Transform.translate(
                  offset: Offset(0, -(t.minTouchTarget - 28) / 2),
                  child: BzCheck(
                    value: done,
                    onChanged: onChanged,
                    label: 'Krok $number: ${item.text}',
                  ),
                ),
              ],
            ),
          ),
          if (current)
            Positioned(
              left: -t.space2,
              top: t.space3,
              bottom: t.space3,
              width: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.signal,
                  borderRadius: BorderRadius.circular(t.radiusFull),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
