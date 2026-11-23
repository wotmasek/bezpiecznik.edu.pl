# Context budget: 4096 tokens

## How much that is

- **Text:** Polish guide text measures 0.307 tokens per character on the model's tokenizer (Pixel 9, 2026-11-23). 4096 tokens is about 13,300 characters, about 1,900–2,000 words, about 7 pages of typescript (1,800 characters each).
- **Answer included:** the answer must fit in the same window.

## Split of one turn (target)

| Part | Tokens | Rule |
|---|---|---|
| System prompt and tool declarations | ≤ 600 | Read once per conversation (live conversation), not every turn |
| Guide snippets from `search_guides` | ≤ 800 | 2–3 snippets, ≤ 250 tokens each, cut at sentence ends |
| Profile (via `get_profile`, only when needed) | ≤ 100 | Facts, not prose |
| Other tool results | ≤ 300 | Per module default; longer data is paged |
| Conversation history | ≤ 1,500 | About 10–12 short exchanges; older turns trimmed or summarised |
| Answer | ≤ 800 | `maxOutputTokens` |
| Reserve | ~300 | Template tokens, safety notes |

## How it is kept small

1. **Live conversation in the engine (D7).** History is kept in the engine's KV cache between turns. Each turn the model reads only the new user text and new tool results. Today the full prompt is rebuilt and re-read every turn.
2. **History compaction.** When history passes ~1,500 tokens, old turns get compacted:
   - A guide answer keeps only its titles and the sources it used.
   - Talk keeps a short summary written by the model in one extra pass, or simply the last N turns if the summary pass is too slow.
3. **Compact tool results.** Snippets come with ids, not full pages. "Pokaż całość" opens the source page in the UI and does not load it into the model.
4. **Tools instead of pasted context.** The profile and the map are pulled only when the model asks or the orchestrator's rule fires.
5. **Short system prompt.** One prompt for everything. Rules are stated once; there are no per-path prompts.

## Why not more (measured on Pixel 9, CPU)

| Context reserved | First token at 1.6k prompt | Writing speed | Peak RAM |
|---|---|---|---|
| 2048 | 6.4–8.4 s | 17–20 tok/s | 2.5 GB |
| **4096** | **7.7 s** | **16–17 tok/s** | **2.9 GB** |
| 8192 | 11.5 s | 8–12 tok/s | 3.6 GB |
| 16384 | 24–27 s | 6.4 tok/s | 4.5 GB |

The cost depends on the **reserved** context, not on how much of it is used. Reading the prompt runs at about 100–250 tokens per second, so a full 4096-token prompt costs about 17–20 s. That is why the live conversation (D7) matters more than the context size.

RAM is a floor, not a lever (D6). Below 6 GB the app falls back to 2048 or to no-AI mode. It never goes above 4096.
