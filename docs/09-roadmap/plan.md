# Roadmap

Each milestone ends with a check that can fail. Order matters: measure first, then change one layer at a time, and keep the app shippable after each step.

| # | Milestone | Done when |
|---|---|---|
| **M0** | **Eval set and harness.** 60–80 Polish questions: phone-test paths (talk, family, profile, follow-ups, crisis, off-topic), `content/tests/questions.jsonl`, rescue phrases. Each question carries: expected behaviour, acceptable sources (doc + page), must-include (112, 116 123), must-not (form on risk, invented numbers). Runs on the laptop (llama-server, same weights) and on the phone. | Baseline numbers for today's `main` saved in `research/eval/` |
| **M1** | **Engine: 4096 context + live conversation.** One conversation per chat kept in the engine; system prompt read once; history compaction; `cacheDir`. | Same eval score as M0; first token on a follow-up turn ≤ 50% of M0; peak RAM ≤ 3 GB on Pixel 9 |
| **M2** | **Module registry and contract** (`app/lib/agent/`). Existing features moved behind tools without behaviour change: `search_guides` (BM25), `get_profile`, `rescue_card_lookup`, `show_form`, `show_todo`, `show_quote`, `offer_call_112`. | All existing tests green; each module has its own tests; no UI change |
| **M3** | **Hybrid retrieval.** Embedder chosen by recall@3 on M0 questions (BM25 vs vector vs hybrid), vectors built into `kb.sqlite`, relevance floor. | recall@3 ≥ BM25 + 15 points on the eval set; "atak paniki" / "tata chory" no longer hit wrong chapters; RAM with embedder measured |
| **M4** | **Answer pass: free markdown + citations.** One assistant prompt, temperature ~0.6–0.7, [n] mapping, "bez źródła" and "sprawdź w źródle" markers, rendering into today's components. Keyword gate and canned refusals removed (refusal only as model-off fallback). | Eval: talk paths answered (no canned "Nie wiem"), citation precision measured, zero invented numbers unmarked, crisis rules pass |
| **M5** | **Agent loop with native tools.** 2–3 optional tools per turn, max 2 calls, allowlist, parse failures as text. Form answers return as tool results. | Tool-choice accuracy on the phone measured; a tool is enabled only above an agreed threshold (proposal: 80%) |
| **M6** | **Map module, generalised.** Home location in the profile, `map_where_am_i`, `map_find_place`, `map_route`, `show_navigation` with compass fallback. | Data size for whole-Poland routing and address search measured against the 5–10 GB budget; "zaprowadź mnie do domu" works offline in one region |
| **M7** | **Device validation.** Real 6 GB phone: load, answers, background kill, heat over 10 minutes; Pixel 9 regression. | Minimum requirements confirmed or raised in `wymagania-systemowe.md` |
| **M8** | **Merge and cleanup.** Spec updated, this folder removed ([cleanup](cleanup-at-merge.md)). | `docs/` gone from `main`; spec describes the new flow |

M2 and M3 can run in parallel (different folders). M4 needs M1–M3. M5 needs M2 and M4. M6 needs M2.
