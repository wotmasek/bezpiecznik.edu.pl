# Module catalogue

First set for the rebuild. "Exists today" names the code that the module wraps, so most of the work is moving, not writing.

## Data modules (the model reads)

| Tool | Arguments | Returns to the model | Exists today | Notes |
|---|---|---|---|---|
| `search_guides` | `query` | 2–3 snippets, ≤ ~250 tokens each, with [n] | `czat/retrieval/retriever.dart` (BM25) | Becomes hybrid ([retrieval](../05-retrieval/hybrid-search.md)). The orchestrator calls it every content turn; the model may call it again with a better query |
| `get_profile` | `section?` (domownicy, leki, zwierzęta, dom) | Short facts, ≤ 100 tokens | `profil/profile_model.dart` `toPromptContext()` | Replaces pasting the profile into every prompt. Phone test: the pasted profile was ignored |
| `map_where_am_i` | — | Position, accuracy, region, whether a detailed pack exists | `mapa/` GPS code | |
| `map_find_place` | `what` (dom, adres, miejscowość, rodzaj punktu) | Up to 3 places with distance and direction | `mapa/`, `points.sqlite` | "dom" needs a **home location in the profile** (new field: pin on the map). Address and town search offline needs an index ([open questions](../09-roadmap/open-questions.md)) |
| `map_route` | `to` (place id), `mode` (pieszo, samochód) | Length, time, first 3 turns | Spec only: `02-funkcje/03-mapa/trasy.md` | Offline road graph; compass fallback without GPS fix. Data size to measure |
| `rescue_card_lookup` | `situation` (enum of card ids) | Card title and first steps, as data | `ratunek/` cards, `answer_router.dart` | The full card is rendered by the interaction tool below |

## Interaction modules (the model shows, the user may answer)

| Tool | What the user sees | Waits for the user | Renderer today |
|---|---|---|---|
| `show_form` | 1–3 choice questions | Yes: answers come back as the tool result | `templates/form_panel.dart` |
| `show_todo` | Checklist (preparation only) | No; ticks are saved in the message or profile | `templates/todo_panel.dart` |
| `show_rescue_card` | Verified card with steps, variant chip, CPR coach | No | `ratunek/`, `templates/steps_panel.dart` |
| `show_quote` | Source page with "Powiększ" | No | `templates/quote_panel.dart` |
| `show_navigation` | Map with route and compass | No | `mapa/` screens |

Plain answers need no tool: numbered lists, bullets and headings in the model's markdown render through `md_blocks.dart`.

## Action modules (the user's tap executes)

| Tool | Button | Notes |
|---|---|---|
| `offer_call_112` | "Zadzwoń 112" pinned above the composer | The safety layer pins it on its own for risk phrases; the model can also offer it |
| `offer_sms_family` | "Powiadom bliskich" with location | Existing alarm panel logic; never sends without the tap |

## Offered per turn (selection rules)

| Situation | Offered optional tools |
|---|---|
| Default | `get_profile`, `map_find_place`, `show_form` |
| Preparation words (spakować, przygotować, zapas) | `get_profile`, `show_todo` |
| Place words (gdzie, schron, dom, droga, jak dojść) | `map_where_am_i`, `map_find_place`, `show_navigation` |
| Risk phrase | `show_rescue_card`, `offer_call_112` (form never) |

`search_guides` is always available and is called by the orchestrator anyway.
