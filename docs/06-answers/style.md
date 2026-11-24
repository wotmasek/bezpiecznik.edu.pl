# Answer style: short and to the point

Owner, 2026-11-23: answers should say what matters, without padding. Faster for the user, cheaper for the context.

## Why it matters (measured)

On Pixel 9 at 4096 context the model writes about 16–17 tokens per second.

| Answer length | Writing time |
|---|---|
| 800 tokens (today's budget) | ~48 s |
| 300 tokens | ~18 s |
| 120 tokens | ~7 s |

Every token written also stays in the live conversation and uses the 4096 window. Brevity is the second-largest latency lever, after not re-reading history.

Observed padding in the phone test: almost every talk reply opened with "Rozumiem, że…", restated the question and closed with an offer to talk more.

## Rules

1. **Answer first.** The first sentence is the answer or the first action.
   - No openers ("Rozumiem, że…", "Świetne pytanie", "Oczywiście").
   - No restating the question.
   - No closing summaries.
2. **Default length:** 1–3 sentences, or a list of up to 6 items. One sentence carries one piece of information.
3. **By situation:**

| Situation | Shape |
|---|---|
| Emergency | Only actions, in order, imperative, ≤ 6 steps; the verified card carries the rest |
| How-to or preparation | Up to 6 most important items, then "Chcesz pełną listę?" |
| Fact question | 1–2 sentences with [n] |
| Feelings, family, worry | 1–2 sentences that acknowledge, plus one question; no unrequested advice |
| Off-topic | One sentence, then what the app can help with |

4. **Depth on request.** When a topic is wider, give the essentials and offer one specific follow-up ("Chcesz więcej o zapasie wody?"). In a live conversation "tak" is cheap: the model continues without re-reading anything.
5. **Safety beats brevity.** 112, 116 123, "nie", "nigdy" and the source's warnings are never cut.

## Enforcement

- **Prompt:** the rules above, plus 2 short examples (few-shot). Small models follow examples better than rules. With the live conversation they are read once per chat, so their ~250 tokens are affordable.
- **Hard limit:** `maxOutputTokens` 300 by default, 450 for preparation lists. If the answer is cut, the UI shows "Pokaż więcej" and the model continues in the same conversation.
- **Budget:** the answer reservation in [budget-4096](../04-context/budget-4096.md) drops from 800 to 300–450 tokens. The freed tokens go to history (1,500 → 1,600) and to keeping the total under 4,096.

## Draft prompt (Polish, ~220 tokens)

```text
Jesteś Bezpiecznikiem, asystentem bezpieczeństwa, który działa bez internetu.

Styl:
- Zacznij od odpowiedzi. Bez wstępów („Rozumiem, że…”, „Oczywiście”), bez powtarzania pytania, bez podsumowań.
- Krótko: 1–3 zdania albo lista do 6 punktów. Jedno zdanie, jedna informacja.
- W nagłej sytuacji tylko czynności, po kolei, w trybie rozkazującym.
- Gdy ktoś mówi o emocjach: jedno, dwa zdania, które to uznają, i jedno pytanie. Bez rad, o które nie prosi.
- Gdy temat jest szerszy: najważniejsze, potem jedno pytanie „Chcesz więcej o …?”.
- Pisz neutralnie płciowo („czy jesteś w bezpiecznym miejscu?”).

Źródła:
- Fakty z fragmentów oznaczaj [n]. Nie dodawaj liczb, dawek ani nazw leków spoza fragmentów.
- Gdy fragmenty nie pasują, powiedz to jednym zdaniem.

Przykład 1
Użytkownik: Ile wody na osobę?
Ty: 3 litry dziennie na osobę, zapas na minimum 3 dni [1]. Chcesz listę reszty zapasów?

Przykład 2
Użytkownik: Pokłóciłem się z mamą i jest mi źle.
Ty: Kłótnia z bliską osobą potrafi długo ciążyć. O co poszło?
```

The final wording comes from the eval (M0/M4).

## How we measure it

The eval set (M0) records for every answer:

- tokens written,
- whether it starts with a banned opener,
- whether every must-include item is present (112, 116 123, the key step).

Target: median answer ≤ 120 tokens for talk and fact questions, zero lost must-include items. Too short is a failure too.
