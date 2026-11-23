# Fix recipe: making Bezpiecznik usable

Working folder for the next big update. It turns the conclusions of the 2026-11-23 session (phone tests, context benchmark, research) into a recipe: what changes, why, and in what order.

**Temporary.** At the merge to `main`, durable parts move into the spec (`bezpiecznik/`) and this folder is deleted. See [cleanup at merge](09-roadmap/cleanup-at-merge.md).

## The problem in one paragraph

Gemma 4 E2B in the app has the same weights as in Google's Edge Gallery, but it feels far dumber. The reason is the plumbing around it, not the model.

- A keyword gate sends almost every sentence to a keyword search.
- A JSON-only, temperature-0.1 "copy the guide" prompt then turns that sentence into steps, or it ends in a canned "Nie wiem".
- Talk gets one sentence with no history.
- The context is 2048 tokens.

The model never decides anything.

## The fix in one paragraph

The fix is model-first, built on modules.

- **Model-first:** the model always answers, in free text with [n] citations. Sentences without a source are shown as such. They are not silently deleted.
- **Tools:** the app gives the model swappable modules (knowledge, profile, map, rescue cards, interaction widgets, human-confirmed actions) through one tool contract.
- **Knowledge search:** hybrid, BM25 plus vectors, and it returns compact results.
- **Context:** fixed at 4096 tokens, with the conversation kept alive in the engine so history is not re-read every turn.
- **Safety:** non-blocking, but always on. Crisis and risk detection pins 112. Rescue cards stay verified content. Calls and SMS need the user's tap.
- **UI:** the look stays the same. The mechanics change.

## Reading order

| # | File | What it settles |
|---|---|---|
| 1 | [Diagnosis: phone test](01-diagnosis/phone-test.md) | What breaks today, with evidence |
| 2 | [Diagnosis: why Edge Gallery feels smarter](01-diagnosis/edge-gallery-gap.md) | Same model, different setup |
| 3 | [Decisions](02-decisions/decisions.md) | Every decision with status and reason |
| 4 | [Architecture overview](03-architecture/overview.md) | Layers and the flow of one turn |
| 5 | [Module contract](03-architecture/module-contract.md) | How a module is defined; adding a new one |
| 6 | [Module catalogue](03-architecture/modules.md) | Data, interaction and action modules |
| 7 | [Agent loop](03-architecture/agent-loop.md) | Tool calling with the on-device model |
| 8 | [Context budget: 4096](04-context/budget-4096.md) | What fits, and how it is kept small |
| 9 | [Hybrid retrieval](05-retrieval/hybrid-search.md) | BM25 + vectors, compact results |
| 10 | [Answers and citations](06-answers/citations.md) | Free text, [n], unsourced marking, rendering into today's components |
| 11 | [Safety](07-safety/safety.md) | What stays deterministic and why |
| 12 | [Performance](08-performance/performance.md) | Measurements and the tuning list |
| 13 | [Roadmap](09-roadmap/plan.md) | Milestones with exit criteria |
| 14 | [Open questions](09-roadmap/open-questions.md) | What is not decided yet |

## Status words used here

- **Decided:** agreed with the owner in the session.
- **Proposed:** recommended, waiting for the owner.
- **To measure:** depends on a number we do not have yet.
