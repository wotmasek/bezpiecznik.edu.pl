import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'panel_model.dart';

/// Text-first building blocks of an answer (chat redesign 2026-11, ChatGPT
/// style): no cards, a heading, numbered or bulleted lines, footnotes [n]
/// that point at the numbered source list under the answer.

/// Width of the list marker column ("1.", "•", checkbox).
const double mdMarkerWidth = 28;

/// Panel title as a heading (`step` 20/28 bold).
class MdHeading extends StatelessWidget {
  const MdHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Semantics(header: true, child: Text(text, style: t.step.copyWith(color: t.ink100)));
  }
}

/// One list line: a marker column ("1.", "•") and the content.
class MdListItem extends StatelessWidget {
  const MdListItem({super.key, required this.marker, required this.child});

  /// Text of the marker, e.g. `"3."` or `"•"`.
  final String marker;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: mdMarkerWidth,
          child: ExcludeSemantics(
            child: Text(
              marker,
              style: t.chat.copyWith(
                color: t.ink200,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Caption after an item whose number is not in its cited fragment.
const String checkSourceCaption = 'sprawdź w źródle';

/// Caption after a list item with no citation (decision D2).
const String unsourcedCaption = 'bez źródła';

/// The quiet caption span ([checkSourceCaption] by default).
TextSpan checkSourceSpan(BuildContext context, [String caption = checkSourceCaption]) {
  final t = context.bz;
  return TextSpan(text: ' · $caption', style: t.caption.copyWith(color: t.ink300));
}

/// Item text with an optional footnote pill at its end.
class MdItemText extends StatelessWidget {
  const MdItemText({
    super.key,
    required this.text,
    this.footnote,
    this.onFootnote,
    this.style,
    this.check = false,
    this.unsourced = false,
  });

  final String text;
  final int? footnote;
  final VoidCallback? onFootnote;
  final TextStyle? style;

  /// Adds the [checkSourceCaption] after the text.
  final bool check;

  /// Adds the [unsourcedCaption] after the text, unless [check] is set.
  final bool unsourced;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final n = footnote;
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (n != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(left: t.space2 - 2),
                child: FootnoteMark(number: n, onTap: onFootnote),
              ),
            ),
          if (check) checkSourceSpan(context) else if (unsourced) checkSourceSpan(context, unsourcedCaption),
        ],
      ),
      style: style ?? t.chat.copyWith(color: t.ink100),
    );
  }
}

/// Footnote pill `[n]`: 20 dp visual, the tap area grows to 48 dp without
/// moving the text around it.
class FootnoteMark extends StatelessWidget {
  const FootnoteMark({super.key, required this.number, this.onTap});

  final int number;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    // No `alignment` here: inside a WidgetSpan it would make the pill as
    // wide as the whole line.
    final pill = Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: t.bg300, borderRadius: BorderRadius.circular(t.radiusFull)),
      child: Text(
        '$number',
        textAlign: TextAlign.center,
        style: t.caption.copyWith(
          color: t.ink200,
          height: 20 / 13,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      label: 'Źródło $number',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Invisible padding enlarges the hit area (48 dp) vertically.
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: pill),
      ),
    );
  }
}

/// One numbered source of an answer: every item citing the same document
/// page shares it.
class FootnoteGroup {
  const FootnoteGroup({required this.number, required this.label, required this.source});

  final int number;

  /// `{doc_short} · s. {page_label}`.
  final String label;

  /// First cited fragment of that page (opened by the source sheet).
  final SourceRecord source;
}

/// Footnote numbering of a whole answer, in reading order. Quotes carry
/// their own caption and are not numbered.
class Footnotes {
  Footnotes._(this.groups, this._byKey);

  factory Footnotes.of(AssistantAnswer answer, String? variant) {
    final groups = <FootnoteGroup>[];
    final byKey = <String, FootnoteGroup>{};
    for (final p in answer.panels) {
      final items = switch (p) {
        StepsPanel() => p.itemsFor(variant),
        BulletsPanel() => p.items,
        TodoPanel() => p.items,
        ChatTextPanel() => p.items,
        _ => const <PanelItem>[],
      };
      for (final it in items) {
        final s = answer.source(it.sourceId);
        if (s == null) continue;
        final key = _key(s);
        if (byKey.containsKey(key)) continue;
        final g = FootnoteGroup(
          number: groups.length + 1,
          label: s.pageLabel.isEmpty ? s.docShort : '${s.docShort} · s. ${s.pageLabel}',
          source: s,
        );
        groups.add(g);
        byKey[key] = g;
      }
    }
    return Footnotes._(groups, byKey);
  }

  static const Footnotes none = Footnotes._empty();

  const Footnotes._empty() : groups = const [], _byKey = const {};

  final List<FootnoteGroup> groups;
  final Map<String, FootnoteGroup> _byKey;

  static String _key(SourceRecord s) => '${s.docId.isEmpty ? s.docShort : s.docId}|${s.pageLabel}';

  /// Group number of [source], or null when it is not cited.
  int? numberOf(SourceRecord? source) => source == null ? null : _byKey[_key(source)]?.number;
}

/// Footnote to draw after item [i]: the group number when item [i] ends a run
/// of items citing the same page (the next shown item cites another page, or
/// [i] is the last shown one). [shown] = how many items are visible.
int? footnoteAfter(
  Footnotes notes,
  AssistantAnswer answer,
  List<PanelItem> items,
  int i, {
  int? shown,
}) {
  final last = (shown ?? items.length) - 1;
  final n = notes.numberOf(answer.source(items[i].sourceId));
  if (n == null) return null;
  if (i >= last) return n;
  final next = notes.numberOf(answer.source(items[i + 1].sourceId));
  return next == n ? null : n;
}

/// Quiet variant switch "Dorosły ⌄": opens a small menu with the options and
/// a check at the selected one (replaces the segmented control).
class VariantChip extends StatelessWidget {
  const VariantChip({super.key, required this.options, required this.value, required this.onChanged});

  final List<VariantOption> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final current = options.firstWhere((o) => o.id == value, orElse: () => options.first);
    return Semantics(
      button: true,
      label: 'Wariant: ${current.label}. Zmień',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('variant-chip'),
        borderRadius: BorderRadius.circular(t.radiusFull),
        onTap: () => _open(context),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.minTouchTarget),
          child: Padding(
            padding: EdgeInsets.only(left: t.space3, right: t.space2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(current.label, style: t.label.copyWith(color: t.ink200)),
                SizedBox(width: t.space1),
                Icon(LucideIcons.chevronDown, size: 16, color: t.ink200),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final t = context.bz;
    final box = context.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final rect = Rect.fromPoints(
      box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      color: t.bg200,
      elevation: 1,
      constraints: const BoxConstraints(minWidth: 216),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMd),
        side: BorderSide(color: t.line150),
      ),
      items: [
        for (final o in options)
          PopupMenuItem<String>(
            value: o.id,
            height: t.minTouchTarget,
            child: Row(
              children: [
                Expanded(child: Text(o.label, style: t.chat.copyWith(color: t.ink100))),
                if (o.id == value) Icon(LucideIcons.check, size: 20, color: t.ink100),
              ],
            ),
          ),
      ],
    );
    if (picked != null && picked != value) onChanged(picked);
  }
}
