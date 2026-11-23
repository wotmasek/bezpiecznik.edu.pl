# Answers and citations

## Output format

- The model writes **free Polish markdown**: paragraphs, numbered lists, bullets, at most one heading. There is no JSON.
- Claims from a guide end with `[n]`, where `n` is the snippet number given in the context.
- Temperature is ~0.6–0.7 for the single answer pass (D15).

## What the orchestrator does with it

1. **Maps [n] to sources.** It builds the footnote list ("Źródła · n") exactly as today: `md_blocks.dart` and `Footnotes`.
2. **Marks unsourced content.** A list item or sentence with factual content and no [n] gets a quiet "bez źródła" marker. Chit-chat sentences are not marked: a sentence with no digits and no imperative verb counts as talk. The heuristic is to be tuned on the eval set.
3. **Checks numbers.** A number in a cited sentence that does not occur in the cited snippet gets an "sprawdź w źródle" marker. It replaces today's deletion. Today's validator logic (numbers, negations) is reused as a checker, not a filter.
4. **Renders into today's components (D13):**
   - a numbered list → `StepsPanel` look (collapsed after 5, "Pokaż wszystkie kroki"),
   - bullets → `BulletsPanel`,
   - a checklist from `show_todo` → `TodoPanel`,
   - paragraphs → `chat_text` markdown.
5. **Label at the top.** "Z poradników" when at least one [n] is used; "Rozmowa" otherwise. This replaces "Rozmowa – nie z poradników".

## Prompt rules (target text lives in the prompt layer)

- Answer what was asked, first. Use the snippets when they fit; cite them with [n].
- If the snippets do not cover the question, say so in one sentence and answer only in general terms, with no numbers, doses or medical instructions.
- Never invent numbers, doses or medicine names.
- Keep negations from the source.
- Use gender-neutral Polish (D17).
- Mention 112 when life may be in danger. The safety layer pins the button anyway.
- Do not invent your own feelings or memories. On questions about the user, use only what they wrote and what `get_profile` returns.

## What changes for the user

| Today | After |
|---|---|
| "Nie wiem. Zapytaj lekarza…" for most talk | A real reply that keeps the conversation going |
| Steps built from the wrong chunk | Relevant snippets (hybrid search), or an honest "poradniki tego nie opisują" |
| Silent deletion of unsupported items | Visible "bez źródła" / "sprawdź w źródle" markers |
| Same look | Same look |
