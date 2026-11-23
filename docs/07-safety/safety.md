# Safety

The model gets freedom. Safety moves out of the model's way into a thin layer that never blocks an answer, only adds to it.

## Stays deterministic

| What | Why | Today |
|---|---|---|
| **Risk detection** on the user's text, pinning "Zadzwoń 112" | Must work when the model is slow, wrong or off | `ratunek/detect/risk_detector.dart`, `risk.json`; 112 follows the latest turn (`chat_screen.dart`) |
| **Crisis detection** (suicidal thoughts, self-harm, panic) → caring instruction + 116 123 line + pinned 112 | The phone test showed first aid for "nie chce mi się żyć" | `czat/answer/conversation.dart` (`isCrisis`, `kCrisisHelpLine`) from PR #1. In the rebuild it becomes a safety-layer rule, not a pipeline branch |
| **Rescue cards** (CPR, bleeding, choking, unconscious) | Verified content, life-critical order of steps | `ratunek/` assets, `answer_router.dart` |
| **Actions need a tap** (call, SMS) | Irreversible, outward-facing | `CallPanelView`, alarm panel |
| **No-AI fallback** | The model may be missing or crash | `buildQuoteFallback`, "Tryb bez AI" |

## Becomes a marker instead of a filter

- Unsourced sentences → "bez źródła".
- Numbers not in the cited snippet → "sprawdź w źródle".
- Snippets below the relevance floor are not shown as sources.

## Prompt-level rules (the model's job, with the markers as a backstop)

- No doses, medicine names or numbers that are not in a snippet.
- No diagnosis.
- Gender-neutral Polish.
- Crisis wording: caring, without judging, ask whether the person is safe, give 116 123 and 112. The 116 123 line is appended by code if the model leaves it out (as today).

## Tests that must survive the rebuild

- Every phrase in `risk.json` and `kCrisisPhrases` still pins 112 (existing tests: `pipeline_risk_first_test.dart`, `thinking_risk_call_test.dart`, `conversation_test.dart`).
- A risk turn never shows a form or a todo list (`answer_router_test.dart`, `panel_model_test.dart` `forRisk`).
- Rescue card text is byte-identical to the asset.
- Eval: crisis sentences from the phone test (`Nie chce mi się żyć`, `Mam atak paniki`) always end with 112 + 116 123.

## Open safety question

Panic is grouped with suicidal thoughts today, so it also shows 116 123 and 112. That is acceptable for now. A clinician or rescuer should review the crisis wording before release. The spec already marks rescue content "Do weryfikacji".
