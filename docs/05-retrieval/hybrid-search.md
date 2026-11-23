# Hybrid retrieval

## Today

- `retriever.dart` runs BM25 over `kb.sqlite` (FTS5) with synonyms and typo repair, after a domain-word gate.
- It returns up to 4 chunks, capped at 2,000 characters in the prompt.
- The KB is about 60,000 characters of chunk text from 10 guides, roughly 18k tokens.
- Failures seen on the phone came from word overlap without meaning:
  - "atak paniki" → air raid,
  - "nie chce mi się żyć" → casualty first aid,
  - "tata chory" → "osoba wspierana".

## Target

1. **Two searches, merged:** BM25 (today's code, minus the refusing gate) and vector search. Results are merged with reciprocal rank fusion and deduplicated per page.
2. **Embeddings computed at build time.** The KB is fixed, so chunk vectors ship in `kb.sqlite`. On the phone only the query vector is computed.
3. **Query from the conversation.** The query is the user turn plus the previous user turn. The model may call `search_guides` again with its own reformulated query.
4. **Relevance floor.** Below a score threshold, return nothing rather than something. The model then answers unsourced, and the UI shows it.
5. **Compact output.** 2–3 snippets, each ≤ ~250 tokens, cut at sentence ends. Each carries an id, document, page and highlight rects for "Powiększ".
6. **Rescue-card intents first.** A matched emergency phrase still opens the verified card directly (D10). Retrieval adds context; it does not replace the card.

## Embedding model: candidates (to measure)

All three are available through the same plugin family (`flutter_edge_ai_litertlm` embedding backend). Sizes are from https://flutteredge.ai/docs/models, read 2026-11-23.

| Model | Size | Notes |
|---|---|---|
| EmbeddingGemma 2 (270M) | ~165 MB + ~71 MB weight cache | Gemma 4 family, bundled tokenizer, 1024-token input cap in the plugin |
| EmbeddingGemma (300M) | ~179–196 MB | "100+ languages" per model card; Polish not named |
| Gecko (110M) | ~112–120 MB | Probably English-centred (unverified) |

**Polish quality is unverified for all of them.** M3 decides with a small benchmark: the eval questions (M0) checked for recall@3 against hand-marked correct pages. Compare BM25, vector and hybrid.

Storage: the model (~0.2 GB) plus vectors fit inside the 5–10 GB budget.

RAM is to be measured: the embedder runs next to the LLM. Unload the embedder after the query, or keep it if it is small enough.

## Interfaces

```dart
abstract class KnowledgeSearch {
  Future<List<Snippet>> search(String query, {int k = 3, int maxTokensEach = 250});
}
// BM25Search (today), VectorSearch (new), HybridSearch(bm25, vector) implements KnowledgeSearch
```

`search_guides` wraps `HybridSearch`. Tests run BM25 alone when no embedder is present, for CI and no-model mode.
