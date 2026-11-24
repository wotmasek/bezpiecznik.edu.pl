# Next steps after the 2026-11-24 sprint

State on `main` (b1ca7e4, release v2026.11.24):
- Model-first chat: one markdown answer with [n] citations; no keyword gate, no canned refusal.
- Engine: 4096 context, live conversation, system prompt read at chat open by a hidden one-token turn.
- Markers "bez źródła" and "sprawdź w źródle", "Pokaż więcej", form of address in the profile.
- Eval: 47 cases (`tools/eval_conv.sh <label>`), 38–41/47.
- Phone runs: `research/model-test/`.

Each item: why, how, done when. Order = recommended order.

## 1. Bugs found on the Mi 9T Pro (small, do first)

| Bug | Fix | Done when |
|---|---|---|
| "Dzieki" (no diacritics) read as "dzieci"; once answered only "Zadzwoń pod 112." | Normalise common words without diacritics before the model (dzieki→dzięki, prad→prąd …), or add a line on input without Polish letters to the prompt; add eval cases without diacritics | Eval cases f04-nodiacritics pass 3 runs in a row |
| Help-line number garbled ("116 lub 123") | Post-process: any 116/123 pattern that is not exactly "116 123" is replaced; the code already appends the correct line on crisis | Unit test |
| Floor from the profile ignored (p04) | Profile facts as a bullet list at the top of the prompt; eval p04 | p04 passes 3 runs |
| "Pokaż więcej" stays on older messages | Show only on the latest assistant message | Widget test |
| Prime turn has no unit test | Fake runtime test: prepare → prime runs once → first run is a continuation | Test |

## 2. Hybrid retrieval (M3): biggest remaining quality gap

The misses that stay stable across eval runs are retrieval-bound: sirens, bleeding, fire, CPR, water disinfection.
- **Ask the owner before downloading an embedding model**: give the name, source and size.
- Candidates from the research: EmbeddingGemma 2 (~165 MB + cache), EmbeddingGemma (~180–196 MB). Both run through `flutter_edge_ai_litertlm`. Polish quality is unverified.
- Vectors are computed at build time into `kb.sqlite`; only the query is embedded on the phone. Merge BM25 and vectors with RRF and add a relevance floor (`docs/05-retrieval/hybrid-search.md`).
- Done when: main 12/12 on two runs, recall@3 measured against hand-marked pages, RAM measured on the Mi 9T Pro.

## 3. Faster first answer (beyond the prime turn)

Research (2026-11-24) found no model swap that keeps Polish quality. In order:
1. **Shorter prompt.** The system prompt is ~520 tokens; use 2 snippets of ≤ 400 characters instead of 3 of ≤ 600. Measure on the eval and on the Mi 9T Pro.
2. **Prefill the system prompt once and clone it per chat**, if flutter_edge_ai can reach LiteRT-LM session clone (C++). Check the plugin source first.
3. **Gemma 3 1B as a "fast mode"** only after a Polish eval. High quality risk.
4. **Bielik 1.5B/4.5B** needs an engine switch (llama.cpp): high effort, no Android speed data.

## 4. Module registry and native tools (M2, M5)

Phone probe (`research/tool-probe/results.md`):
- 11–12/16 correct tool choices, no wrong tool, `show_form` never called.
- Tools are fixed per chat, and a tool call adds about 4.5 s.
- Guideline: one fixed set of ≤ 5 tools per chat; the orchestrator gates calls. Retrieval stays app-side. Start with `get_profile` and `map_find_place`, and skip `show_form` until a prompt makes E2B call it.
- Done when: tool-choice accuracy ≥ 80% on a 30-prompt phone eval (Q6), and the safety tests stay green.

## 5. Map module (M6)

- Home location in the profile (pin on the map).
- `map_where_am_i`, `map_find_place`, `map_route`, `show_navigation` with a compass fallback.
- First measure the data size for whole-Poland routing and address search against the 5–10 GB budget (Q4).

## 6. Fine-tuning: later, as one experiment

Research (2026-11-24):
- `.litertlm` in flutter_edge_ai_litertlm rejects `loraPath` (`ffi_inference_model.dart:410`), so LoRA can't be applied at runtime.
- The path is: LoRA training (Unsloth claims 8–10 GB VRAM for E2B), merge, then `litert-torch export_hf` to `.litertlm`. This export is documented for Gemma 4 with chat-template caveats.
- Value: style, citation format and input without diacritics move into the weights, so the prompt can be ~100 tokens and the first answer gets faster. Facts stay in RAG; never train guide facts.

Smallest experiment (2–3 days):
1. Export the untouched E2B with `export_hf` and check that it matches today's model on the eval and in speed.
2. Train a rank-8 LoRA on about 600 examples, with a short prompt and variants without diacritics.
3. Merge, export, run the eval on the phone.

Go only if:
- quality ≥ today's model with the long prompt;
- the first answer is faster;
- there are no crisis or citation regressions.

## 7. Cleanup at the final merge

Follow `docs/09-roadmap/cleanup-at-merge.md`: move the durable parts into `bezpiecznik/` and delete `docs/`.
