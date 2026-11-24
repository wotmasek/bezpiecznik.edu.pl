# Why Edge Gallery feels smarter

Same model family, same `.litertlm` E2B weights. The difference is configuration and flow.

| | Google Edge Gallery (Gemma-4-E2B-it) | Bezpiecznik today |
|---|---|---|
| Context | 32000 tokens | 2048 |
| Answer length | up to 4000 tokens | 160 (talk), 600 (guides) |
| Accelerator | GPU first, then CPU | CPU |
| Minimum RAM | 8 GB | 6 GB (our target) |
| Conversation | the whole chat, multi-turn | one sentence (talk) or one previous question (guides) |
| Output | free text | JSON panels, every item checked against a source |
| Temperature | default sampling | 0.1 for guides, 0.6 for talk |
| Who decides the topic | the model | a keyword gate before the model |

Source for the Edge Gallery column: `model_allowlists/1_0_23.json` in `google-ai-edge/gallery` (read 2026-11-23): `maxContextLength: 32000`, `maxTokens: 4000`, `accelerators: "gpu,cpu"`, `minDeviceMemoryInGb: 8`.

## What we can and cannot copy

- **Copy:** the model sees the conversation, writes free text, and decides what to do.
- **Do not copy:** the 32k context. On our CPU path the cost scales with the reserved context, even when it is empty: the same 1.6k prompt took 6.4 s to the first token at 2048 and 24 s at 16384 ([performance](../08-performance/performance.md)). A 6 GB phone cannot afford it.
- **Do not copy:** GPU first. On the Galaxy A55 demo phone the GPU returned garbage, and GPU fp16 output breaks past about 2048 tokens (LiteRT-LM issue #4001, open).
- **Our addition:** sources. Edge Gallery has none; we keep [n] citations so the user can see what is backed by a guide.
