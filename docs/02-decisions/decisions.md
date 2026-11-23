# Decisions

Status: **Decided** = agreed with the owner on 2026-11-23. **Proposed** = recommended, waiting for the owner. **To measure** = depends on a missing number.

| # | Decision | Status | Why |
|---|---|---|---|
| D1 | **The model always answers.** No canned "Nie wiem" before the model has seen the question. | Decided | Determinism in front of the model killed its usefulness ([diagnosis](../01-diagnosis/phone-test.md)). |
| D2 | **Citations instead of blocking guards.** Every claim from the guides carries [n]; a sentence without a source is shown as unsourced, not deleted. | Decided | The user sees what is backed by a source; the model is not muted. |
| D3 | **Agent with tools ("internal MCP").** System prompt layer, model engine and tools are separate. Tools register through one contract. | Decided | New features become new modules; each layer is testable alone. |
| D4 | **Three kinds of modules:** data (model reads), interaction (model shows something, may wait for an answer), action (needs the user's tap). | Decided | Owner: display tools (forms, checklists, cards) are a separate module family from internal tools (profile, search). |
| D5 | **Map is one general module**, not "nearest shelter": where am I, find a place (home, address, town, point type), nearest X, route, compass fallback. | Decided | Owner: the agent should guide home or anywhere in Poland, offline, from GPS. |
| D6 | **Context fixed at 4096 tokens** for every device. RAM only lowers it (below 6 GB: 2048 or no AI), never raises it. | Decided | Reserved context slows every turn even when empty; 4096 costs 2.9 GB and ~7.7 s to the first token on Pixel 9 ([measurements](../08-performance/performance.md)). |
| D7 | **Keep the conversation alive in the engine** (KV cache between turns) instead of re-sending history. | Decided | Re-reading 4k tokens costs ~17–20 s per turn on a phone; a live conversation reads only the new turn. |
| D8 | **Hybrid retrieval:** BM25 + vector search, run by the app on every content question, compact results (2–3 snippets). | Decided | Keyword search returned wrong chunks ("atak paniki" → air raid). Small models are unreliable at deciding when to search. |
| D9 | **Optional tools for the model: 2–3 at a time**, max 2 tool calls per answer. | Decided | E2B-class models are weak at tool selection; each call is another model pass (seconds). |
| D10 | **Rescue cards stay deterministic** (verified content from assets). The model may open and comment on them, never rewrite them. | Decided | Life-critical steps must not be generated. |
| D11 | **Safety layer outside the model:** risk and crisis detection pins 112 and adds 116 123, whatever the model does. | Decided | Shipped in PR #1; must survive the rebuild. |
| D12 | **Calls and SMS are actions the model can only propose**; the user's tap executes them. | Proposed | Irreversible, outward-facing. |
| D13 | **Look stays.** Today's components (steps, todo, form, quote, map card, footnotes, "Źródła · n") are reused as renderers of interaction modules. | Decided | The problem is mechanics, not looks. |
| D14 | **Engine:** Gemma 4 E2B `.litertlm`, LiteRT-LM via flutter_edge_ai, CPU by default. GPU only opt-in. No switch to llama.cpp. | Proposed | E4B needs ~12 GB per Edge Gallery; llama.cpp is several times slower at prefill on phones in published benchmarks; GPU fp16 is buggy past 2k. |
| D15 | **One temperature for the answer pass** (~0.6–0.7). | Proposed | One pass = one temperature; grounding comes from context and citations, not from temperature 0.1. |
| D16 | **Minimum device:** 6 GB RAM, Android 11, 5–10 GB storage. | Decided | `bezpiecznik/05-technologia/wymagania-systemowe.md` on `main`. 6 GB is below Google's 8 GB for E2B in Edge Gallery, so it must be confirmed on a real 6 GB phone. |
| D17 | **Gender-neutral Polish** in all model output ("czy jesteś teraz w bezpiecznym miejscu?" rather than "czy jesteś bezpieczna?"). | Proposed | Phone test: the model assumed a female user. |
