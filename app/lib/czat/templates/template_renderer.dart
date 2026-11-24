import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'form_panel.dart' show formSenderProvider;
import '../../ratunek/cards/verify_badge.dart';
import '../../wspolne/theme/bz_buttons.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'md_blocks.dart';
import 'panel_model.dart';
import 'read_aloud.dart';
import 'template_registry.dart';

/// Footer under every `rescue_card` message (spec "Teksty").
const String rescueCardFooterText = 'Ta instrukcja nie zastępuje połączenia z 112.';

/// Label of the source pill under an answer: `Źródła · {n}`.
String sourcesPillLabel(int n) => 'Źródła · $n';

/// Label above a message by origin (spec "Etykieta nad wiadomoscia"); null = none.
/// Intent answers (`intent` set) carry no label.
String? answerLabelFor(AnswerOrigin origin, [String? intent]) => switch (origin) {
  AnswerOrigin.rescueCard => 'Karta ratunkowa',
  AnswerOrigin.rules => intent == null ? 'Z twojego profilu' : null,
  AnswerOrigin.noAi => 'Tryb bez AI: fragmenty źródeł',
  AnswerOrigin.ai || AnswerOrigin.refusal => null,
};

/// Draws an [AssistantAnswer] as text, ChatGPT style (redesign 2026-11):
///
/// 1. header row: origin label, `VerifyBadge`, and one [VariantChip] for the
///    whole message when any panel has variants;
/// 2. the templates through the [TemplateRegistry] (unknown ones skipped).
///    `call` is not drawn here: the chat screen pins "Zadzwoń 112" above the
///    composer for the whole conversation;
/// 3. an action row: "Czytaj na głos" (steps with `read_aloud`) and the
///    "Źródła · n" pill, which (like a tapped footnote) unfolds the numbered
///    source list;
/// 4. the note and the rescue-card footer.
///
/// Per-message state (variant, checked items, sent form) changes through
/// [onChanged], which receives the updated answer (the owner stores it).
class TemplateRenderer extends ConsumerStatefulWidget {
  const TemplateRenderer({super.key, required this.answer, this.onChanged});

  final AssistantAnswer answer;
  final ValueChanged<AssistantAnswer>? onChanged;

  @override
  ConsumerState<TemplateRenderer> createState() => _TemplateRendererState();
}

class _TemplateRendererState extends ConsumerState<TemplateRenderer> {
  bool _sourcesOpen = false;

  void _showSources() {
    if (!_sourcesOpen) setState(() => _sourcesOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final answer = widget.answer;
    final registry = ref.watch(templateRegistryProvider);
    final openSource = ref.watch(sourceOpenerProvider);

    // One variant for the whole message, picked in the header.
    var options = const <VariantOption>[];
    for (final p in answer.panels) {
      if (p.variantOptions.isNotEmpty) {
        options = p.variantOptions;
        break;
      }
    }
    final variant = options.isEmpty
        ? null
        : (options.any((o) => o.id == answer.selectedVariant) ? answer.selectedVariant : options.first.id);
    final notes = Footnotes.of(answer, variant);

    final label = answerLabelFor(answer.origin, answer.intent);
    final children = <Widget>[];
    if (label != null || answer.verify || variant != null) {
      children.add(
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: t.space2,
                runSpacing: t.space1,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (label != null) Text(label, style: t.caption.copyWith(color: t.ink300)),
                  if (answer.verify) const VerifyBadge(),
                ],
              ),
            ),
            if (variant != null)
              VariantChip(
                options: options,
                value: variant,
                onChanged: (id) => widget.onChanged?.call(answer.copyWith(selectedVariant: id)),
              ),
          ],
        ),
      );
    }

    StepsPanel? readAloud;
    for (var i = 0; i < answer.panels.length; i++) {
      final panel = answer.panels[i];
      if (panel is UnknownPanel || panel is CallPanel) continue;
      if (panel is StepsPanel && panel.readAloud) readAloud ??= panel;
      final builder = registry.builderFor(panel.type);
      if (builder == null) continue;
      final panelVariant = panel.variantOptions.isEmpty ? null : variant;
      final scope = PanelScope(
        panel: panel,
        index: i,
        answer: answer,
        variant: variant,
        showVariantSwitch: false,
        onVariantChanged: (id) => widget.onChanged?.call(answer.copyWith(selectedVariant: id)),
        done: answer.doneFor(i, panelVariant),
        onDoneChanged: (item, value) => widget.onChanged?.call(answer.withDone(i, panelVariant, item, value)),
        onOpenSource: (s) => openSource(context, s),
        footnotes: notes,
        onShowSources: _showSources,
      );
      children.add(KeyedSubtree(key: ValueKey('panel-$i-${panel.type}'), child: builder(context, scope)));
    }

    final readTexts = [for (final it in readAloud?.itemsFor(variant) ?? const <PanelItem>[]) it.text];
    if (readTexts.isNotEmpty || notes.groups.isNotEmpty) {
      children.add(
        Wrap(
          spacing: t.space2,
          runSpacing: t.space2,
          children: [
            if (readTexts.isNotEmpty) ReadAloudButton(texts: readTexts, done: const {}),
            if (notes.groups.isNotEmpty)
              BzButton(
                key: const Key('sources-pill'),
                label: sourcesPillLabel(notes.groups.length),
                icon: LucideIcons.bookOpen,
                variant: BzButtonVariant.secondary,
                size: BzButtonSize.md,
                onPressed: () => setState(() => _sourcesOpen = !_sourcesOpen),
              ),
          ],
        ),
      );
      if (_sourcesOpen && notes.groups.isNotEmpty) {
        children.add(
          _SourceList(
            key: const Key('sources-list'),
            groups: notes.groups,
            onOpen: (s) => openSource(context, s),
          ),
        );
      }
    }

    if (answer.truncated) {
      children.add(
        Align(
          alignment: Alignment.centerLeft,
          child: BzButton(
            key: const Key('show-more'),
            label: 'Pokaż więcej',
            icon: LucideIcons.chevronDown,
            variant: BzButtonVariant.secondary,
            size: BzButtonSize.md,
            onPressed: () {
              widget.onChanged?.call(answer.copyWith(truncated: false));
              ref.read(formSenderProvider)('Kontynuuj.');
            },
          ),
        ),
      );
    }

    final note = answer.note;
    if (note != null && note.isNotEmpty) {
      children.add(Text(note, key: const Key('answer-note'), style: t.caption.copyWith(color: t.ink300)));
    }
    if (answer.origin == AnswerOrigin.rescueCard) {
      children.add(Text(rescueCardFooterText, style: t.caption.copyWith(color: t.ink300)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: t.space4),
          children[i],
        ],
      ],
    );
  }
}

/// Numbered sources under the answer: `1  ERC 2025, Pierwsza pomoc · s. 12  ›`.
class _SourceList extends StatelessWidget {
  const _SourceList({super.key, required this.groups, required this.onOpen});

  final List<FootnoteGroup> groups;
  final ValueChanged<SourceRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups)
          Semantics(
            button: true,
            label: 'Źródło ${g.number}: ${g.source.docTitle.isEmpty ? g.label : g.source.docTitle}, '
                'strona ${g.source.pageLabel}. Otwórz.',
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('source-row-${g.number}'),
              borderRadius: BorderRadius.circular(t.radiusSm),
              onTap: () => onOpen(g.source),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    SizedBox(
                      width: mdMarkerWidth,
                      child: Text(
                        '${g.number}',
                        style: t.label.copyWith(
                          color: t.ink300,
                          fontWeight: FontWeight.w400,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(g.label, style: t.label.copyWith(color: t.ink200, fontWeight: FontWeight.w400)),
                    ),
                    Icon(LucideIcons.chevronRight, size: 16, color: t.ink300),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
