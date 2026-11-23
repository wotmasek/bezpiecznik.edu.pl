import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'panel_model.dart';
import 'template_registry.dart';

/// Label of the "enlarge" action (opens the PDF preview, post-MVP).
const String quoteExpandLabel = 'Powiększ';

/// `quote`: original source fragment on a paper window (max 200 dp) with the
/// highlight token, "Powiększ" in its corner and `{doc_short} · s. {page}`
/// under it. Text mode: the page image is not available yet, so the
/// fragment text is shown highlighted.
class QuotePanelView extends StatelessWidget {
  const QuotePanelView({super.key, required this.scope});

  final PanelScope scope;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final panel = scope.panel as QuotePanel;
    final source = scope.answer.source(panel.sourceId);
    if (source == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuotePaper(text: source.text, onTap: () => scope.onOpenSource(source)),
        SizedBox(height: t.space2),
        Text(
          source.pageLabel.isEmpty ? source.docShort : '${source.docShort} · s. ${source.pageLabel}',
          style: t.caption.copyWith(color: t.ink300),
        ),
      ],
    );
  }
}

const double _lineHeight = 22;
const double _padV = 18;
const double _padH = 20;
const int _maxLines = 8;
const double _padPill = 52;

/// Collapsed window height: top padding plus a whole number of lines.
const double quoteWindowMaxHeight = _padV + _maxLines * _lineHeight;

/// Paper window with the highlighted fragment. Collapsed (default): clipped
/// to whole lines, the fade into the paper only shows when the text is
/// actually clipped. [expanded] (source sheet): the whole fragment as a plain
/// page, since a mark over everything marks nothing.
class QuotePaper extends StatelessWidget {
  const QuotePaper({super.key, required this.text, this.onTap, this.expanded = false});

  final String text;
  final VoidCallback? onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    const baseStyle = TextStyle(fontFamily: 'serif', fontSize: 14, height: _lineHeight / 14);
    final pill = !expanded && onTap != null;
    // Room under the text for the "Powiększ" pill, so it never covers a line.
    final padBottom = pill ? _padPill : _padV;
    return Semantics(
      label: text,
      excludeSemantics: true,
      button: onTap != null,
      onTap: onTap,
      onTapHint: pill ? quoteExpandLabel : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(t.radiusMd),
          child: LayoutBuilder(
            builder: (context, box) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: baseStyle),
                textDirection: TextDirection.ltr,
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: (box.maxWidth - 2 * _padH).clamp(0, double.infinity));
              final clipped = !expanded && painter.height + _padV + padBottom > quoteWindowMaxHeight;
              painter.dispose();
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: expanded ? double.infinity : quoteWindowMaxHeight),
                child: Stack(
                  children: [
                    ColoredBox(
                      color: t.paper,
                      child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(_padH, _padV, _padH, padBottom),
                          child: Text.rich(
                            TextSpan(
                              text: text,
                              style: expanded ? null : TextStyle(
                                backgroundColor: t.highlight,
                                decoration: TextDecoration.underline,
                                decorationColor: t.signalPress,
                                decorationThickness: 2,
                              ),
                            ),
                            style: baseStyle.copyWith(color: t.paperInk),
                          ),
                        ),
                      ),
                    ),
                    if (clipped)
                      Positioned(
                        key: const ValueKey('quote-fade'),
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 2 * _lineHeight,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [t.paper.withValues(alpha: 0), t.paper],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (pill)
                      Positioned(right: 0, bottom: 0, child: _ExpandPill(onTap: onTap!)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "Powiększ" in the paper's bottom-right corner: 32 dp pill on a paper-ink
/// tint, 8 dp of transparent padding make the hit area 48 dp.
class _ExpandPill extends StatelessWidget {
  const _ExpandPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return GestureDetector(
      key: const ValueKey('quote-expand'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all((t.minTouchTarget - 32) / 2),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.only(left: 10, right: 12),
          decoration: BoxDecoration(
            color: t.paperInk.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(t.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.maximize2, size: 16, color: t.paperInk),
              const SizedBox(width: 6),
              Text(quoteExpandLabel, style: t.label.copyWith(color: t.paperInk, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
