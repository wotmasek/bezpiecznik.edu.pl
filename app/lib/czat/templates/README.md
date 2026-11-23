# Chat templates (C03)

Spec: `bezpiecznik/03-ekrany/szablony-czatu.md`, `ekran-1-czat.md`.

## Data contract (`panel_model.dart`)

- `ChatPanel.fromJson(Object?)` never throws. Sealed subtypes: `StepsPanel`, `BulletsPanel`,
  `QuotePanel`, `NoSourcePanel(kind: noSource | offTopic)`, `CallPanel`, `CprPanel`, `MapPanel`,
  `SignalPanel`, `AnimationPanel`, `UnknownPanel` (unknown type / malformed / content panel with no
  elements; the renderer skips it). Every panel keeps its original JSON in `raw`.
- `NoSourcePanel` JSON: `{"type":"no_source","kind":"no_source"|"off_topic"}` (the spec has no JSON for refusals).
- `SourceRecord` ("Rekord zrodla"); `chipLabel` = `▸ {doc_short}, s. {page_label}`; `text` falls back to `original`.
- `AssistantAnswer { panels, sources: Map<id, SourceRecord>, verify, cardId, origin, selectedVariant, done }`.
  `sources` may be a map or a list in JSON. `verify:true` makes the renderer draw `VerifyBadge`.
  `done` = checked items, key `"{panelIndex}:{variantId|''}"`; `withDone()` / `copyWith(selectedVariant:)`.

## Rendering

`TemplateRenderer(answer:, onChanged:)` draws label (by origin), VerifyBadge, panels through the
registry and the 112 footer for `rescue_card`. State changes (variant, checked step) come back through
`onChanged(updatedAnswer)`; the chat controller stores them (`updateAnswer`).

`TemplateRegistry` (`templateRegistryProvider`) maps `panels[].type` -> `Widget Function(BuildContext, PanelScope)`.
Defaults: `steps`, `bullets`, `todo`, `form`, `quote`, `no_source`, `chat_text` (light markdown,
`md_text.dart`); placeholders (bordered box with the type name, key
`placeholder-{type}`) for `call`, `cpr`, `map`, `signal`, `animation`. Plug in without editing this folder:

```dart
final r = TemplateRegistry.withDefaults()..register('call', (context, scope) => ...);
ProviderScope(overrides: [templateRegistryProvider.overrideWithValue(r)], ...)
```

`PanelScope` gives: `panel`, `index`, `answer`, `variant` (selected, shared by the message),
`showVariantSwitch` (true only for the first panel with variants), `onVariantChanged`, `done`,
`onDoneChanged(item, value)`, `onOpenSource`. `sourceOpenerProvider` (default: source sheet; takes the tapped BuildContext) is called by source
chips and "Powiększ"; the PDF-preview task overrides it.
`formSenderProvider` (default: chat controller `send`) sends a form's answers; the gallery overrides it.

## Gallery

`TemplateGalleryScreen` (route path const `templateGalleryRoutePath = '/gallery/templates'`) renders
`template_fixtures.dart`, a generated copy of `test/fixtures/templates/*.json` (a test checks they match;
regenerate with `night-shift/work/c03/gen_fixtures.py <worktree root>`). Fixtures are synthetic, not safety content.
