# Performance

## Measured (Pixel 9, Tensor G4, 12 GB, CPU, 2026-11-23)

Test: `app/integration_test/ctx_bench_test.dart`, run with `--no-uninstall` (without it, `flutter test` uninstalls the app and its downloaded model).

Setup:
- The prompt is real guide chunks with a hidden "password" line at 15%.
- The answer is 160 tokens.

| Context | Prompt | First token | Writing | Peak RAM (PSS) | Password found |
|---|---|---|---|---|---|
| 2048 | 1.6k | 6.4–8.4 s | 17–20 tok/s | 2.5 GB | yes |
| 4096 | 1.6k / 3.6k | 7.7 s / 17.6 s | 16–17 tok/s | 2.9 GB | yes |
| 8192 | 1.6k / 3.6k / 7.7k | 11.5 s / 27 s / 75 s | 8–12 tok/s | 3.6 GB | yes |
| 16384 | 1.6k / 12.2k | 24–27 s / 198 s | 6.4 tok/s | 4.5 GB | yes |

Control run, the same 1.6k prompt in order 2048 → 16384 → 8192 → 2048:

| Context | First token | Writing |
|---|---|---|
| 2048 | 6.4 s | 17.1 tok/s |
| 16384 | 24.3 s | 6.3 tok/s |
| 8192 | 16.9 s | 9.1 tok/s |
| 2048 (heated) | 11.7 s | 9.4 tok/s |

Thermal status went from 0 to 1 during the control run.

Conclusions:

- **Quality:** a larger context does not hurt quality.
- **Reserved context costs time and RAM** even when empty.
- **Heat** slows the phone by about 1.8× within minutes.
- **Prompt length is the main latency lever.** The phone reads about 100–250 tokens per second.

## Model load

- Engine load measured 1.5–4.4 s with the model file already on disk.
- The first app answer also includes installing and loading the engine. To measure in M1 with `cacheDir` set.

## Tuning list (try in this order, measure each)

| # | Change | Expected | Source |
|---|---|---|---|
| 1 | Live conversation in the engine (KV kept between turns), system prompt read once | Removes re-reading history every turn: the biggest saving | LiteRT-LM `Conversation`/`Session.clone()`; our measurement of prefill speed |
| 2 | Context 4096 (from 2048), never more | Room for history and tools at ~+0.4 GB | Measured above |
| 3 | `cacheDir` set to a writable app folder | Shorter second load (Google: "can improve 2nd load time"); not measured | LiteRT-LM Android docs, flutter_edge_ai option |
| 4 | Thread count sweep 2/3/4/6 on Pixel 9 and a 6 GB phone | Keep 4 unless another is >10% faster; matters most on non-Pixel phones (no core pinning there) | LiteRT-LM `cpu_affinity_utils.cc`, Arm learning path |
| 5 | Shorter prompts: compact snippets, short system prompt | ~0.35–1 s per 100 tokens saved | Measured prefill rate |
| 6 | Engine in the main process (not a separate `:ai` service process) | Avoids a reported crash on the second conversation | LiteRT-LM issue #2028 |
| 7 | GPU only opt-in, with FLOAT32 above 2k | Faster first token on some phones; fp16 breaks past ~2k; garbage on the A55 demo phone | LiteRT-LM issue #4001; our A55 note |

Rejected:

- **llama.cpp.** Several times slower prefill and more RAM on phones in the edge-llm-bench data.
- **E4B.** Edge Gallery requires 12 GB for it.
- **NPU.** No E2B build for Tensor G4, Snapdragon or MediaTek phones.

## Minimum requirements

Source of truth: `bezpiecznik/05-technologia/wymagania-systemowe.md`.

- Minimum: 6 GB RAM, Android 11, 5–10 GB storage.
- 6 GB is below Google's 8 GB for E2B, so it must be confirmed on a real 6 GB phone in M7.
