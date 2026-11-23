import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app_templates.dart';
import 'bullets_panel.dart';
import 'chat_text.dart';
import 'md_blocks.dart';
import 'no_source.dart';
import 'panel_model.dart';
import 'placeholder_panel.dart';
import 'quote_panel.dart';
import 'source_sheet.dart';
import 'steps_panel.dart';

/// Everything a panel builder needs to draw one template of a message.
class PanelScope {
  const PanelScope({
    required this.panel,
    required this.index,
    required this.answer,
    required this.variant,
    required this.showVariantSwitch,
    required this.onVariantChanged,
    required this.done,
    required this.onDoneChanged,
    required this.onOpenSource,
    this.footnotes = Footnotes.none,
    this.onShowSources,
  });

  final ChatPanel panel;

  /// Position in `answer.panels`.
  final int index;
  final AssistantAnswer answer;

  /// Selected variant id of the message (null when no panel has variants).
  final String? variant;

  /// Legacy: panels used to draw the segmented switch. The renderer now draws
  /// one [VariantChip] in the message header and always passes false.
  final bool showVariantSwitch;
  final ValueChanged<String> onVariantChanged;

  /// Checked item indexes of this panel (for the selected variant).
  final Set<int> done;
  final void Function(int itemIndex, bool value) onDoneChanged;

  /// Opens the PDF preview for a source (no-op until PV exists).
  final void Function(SourceRecord source) onOpenSource;

  /// Footnote numbers of the whole answer (see [footnoteAfter]).
  final Footnotes footnotes;

  /// Tapping a footnote: expands the numbered source list under the answer.
  final VoidCallback? onShowSources;
}

typedef PanelBuilder = Widget Function(BuildContext context, PanelScope scope);

/// Map from `panels[].type` to its widget builder. Other tasks plug in with
/// [register] (replaces a placeholder) without touching this package:
///
/// ```dart
/// final r = TemplateRegistry.withDefaults()..register('call', buildCallPanel);
/// ProviderScope(overrides: [templateRegistryProvider.overrideWithValue(r)]);
/// ```
class TemplateRegistry {
  TemplateRegistry([Map<String, PanelBuilder>? builders]) : _builders = {...?builders};

  /// `steps`, `bullets`, `quote`, `no_source` real; `call`, `cpr`, `map`,
  /// `signal`, `animation` placeholders.
  factory TemplateRegistry.withDefaults() {
    return TemplateRegistry({
      'steps': (c, s) => StepsPanelView(scope: s),
      'bullets': (c, s) => BulletsPanelView(scope: s),
      // Replaced by the real views (todo list, form) in their tasks.
      'todo': (c, s) => BulletsPanelView(scope: s),
      'form': (c, s) => const PlaceholderPanelView(type: 'form'),
      'quote': (c, s) => QuotePanelView(scope: s),
      'no_source': (c, s) => NoSourceView(kind: (s.panel as NoSourcePanel).kind),
      'chat_text': (c, s) => ChatTextView(text: (s.panel as ChatTextPanel).text),
      for (final t in const ['call', 'cpr', 'map', 'signal', 'animation'])
        t: (c, s) => PlaceholderPanelView(type: t),
    });
  }

  final Map<String, PanelBuilder> _builders;

  void register(String type, PanelBuilder builder) => _builders[type] = builder;

  PanelBuilder? builderFor(String type) => _builders[type];

  Iterable<String> get types => _builders.keys;
}

final templateRegistryProvider = Provider<TemplateRegistry>(
  (ref) => buildAppTemplateRegistry(),
);

/// Called when a source chip / "Powiększ" is tapped. Default: source sheet.
final sourceOpenerProvider = Provider<void Function(BuildContext, SourceRecord)>(
  (ref) => openSourceSheet,
);
