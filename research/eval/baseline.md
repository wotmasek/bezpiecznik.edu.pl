# Conversation eval: baseline

| category | cases | pass | turns | median tokens | median ms | canned refusals | banned openers | missing must_include | banned hits | over target |
|---|---|---|---|---|---|---|---|---|---|---|
| assistant | 4 | 3/4 (75%) | 4 | 91 | 339 | 0 | 0 | 1 | 0 | 2 |
| crisis | 5 | 1/5 (20%) | 7 | 58 | 1 | 2 | 1 | 2 | 0 | 0 |
| family_thread | 5 | 0/5 (0%) | 14 | 0 | 2 | 14 | 0 | 0 | 0 | 0 |
| greeting | 5 | 5/5 (100%) | 5 | 48 | 185 | 0 | 0 | 0 | 0 | 1 |
| main | 12 | 6/12 (50%) | 12 | 120 | 2187 | 1 | 0 | 5 | 0 | 2 |
| offtopic | 4 | 4/4 (100%) | 5 | 0 | 38 | 4 | 0 | 0 | 0 | 0 |
| profile | 4 | 0/4 (0%) | 4 | 0 | 138 | 4 | 0 | 4 | 0 | 0 |
| followup | 4 | 3/4 (75%) | 8 | 107 | 1577 | 1 | 0 | 0 | 0 | 0 |
| worry | 4 | 0/4 (0%) | 5 | 41 | 195 | 1 | 3 | 0 | 0 | 1 |
| **ALL** | 47 | 22/47 (47%) | 64 | 41 | 141 | 27 | 4 | 12 | 0 | 6 |

## Worst 10 answers

### p01 turn 0 (profile), score 17

- question: Co o mnie wiesz?
- panels: [no_source], sources 0, 1 ms, ~0 tokens
- canned: true, opener: null, missing: [dziecko|dziec, pies|psa], banned: [], error: null

```text

```

### p04 turn 0 (profile), score 15

- question: Na którym piętrze mieszkam?
- panels: [no_source], sources 0, 126 ms, ~0 tokens
- canned: true, opener: null, missing: [parter], banned: [], error: null

```text

```

### p02 turn 0 (profile), score 15

- question: Ile osób mieszka ze mną?
- panels: [no_source], sources 0, 138 ms, ~0 tokens
- canned: true, opener: null, missing: [2|dwie|dwoje|dwóch|dwa], banned: [], error: null

```text

```

### p03 turn 0 (profile), score 15

- question: Czy mam zwierzęta?
- panels: [no_source], sources 0, 141 ms, ~0 tokens
- canned: true, opener: null, missing: [pies|psa|psem], banned: [], error: null

```text

```

### m12 turn 0 (main), score 14

- question: Jak zdezynfekować wodę do picia?
- panels: [no_source], sources 0, 99 ms, ~0 tokens
- canned: true, opener: null, missing: [], banned: [], error: null

```text

```

### m11 turn 0 (main), score 14

- question: Jak udzielić pierwszej pomocy przy zatrzymaniu krążenia?
- panels: [call, quote, quote, quote], sources 3, 2967 ms, ~524 tokens
- canned: false, opener: null, missing: [112, klatk], banned: [], error: null

```text
Jak rozpoznać zatrzymanie krążenia. Oznaki są proste: poszkodowany jest nieprzytomny i nie oddycha prawidłowo. Na początku mogą wystąpić ruchy przypominające drgawki. Sytuacja wymaga szybkiego działania.

Co oznacza „prawidłowy oddech”? Jedną z największych barier w udzieleniu pomocy jest sytuacja, gdy ofiara wydaje się oddychać. Wygląda, jakby łapała powietrze, jęczała, wzdychała, bulgotała, stękała, charczała lub miała trudności z oddychaniem.

To nie jest oddychanie. To mimowolne sapanie, uciekanie powietrza. Dzieje się tak we wczesnych stadiach wielu zatrzymań krążenia. Nazywa się to „oddechem agonalnym” i bywa mylone z oznaką życia. Ratownik musi rozpoznać, że to nie jest oddychanie, i natychmiast wezwać pomoc oraz rozpocząć RKO.
Ocena ABCDE. W każdej sytuacji udzielania pierwszej pomocy ERC zaleca schemat ABCDE, aby rozpoznać i leczyć stany zagrożenia życia. Ocena musi być dokładna, ale szybka.

Protokół ABCDE to łatwa do zapamiętania lista, która umożliwia szybką ocenę i przygotowuje do udzielenia podstawowej pierwszej pomocy. Oznacza on:
- A – drogi oddechowe (Airway),
- B – oddychanie (Breathing),
- C – krążenie (Circulation),
- D – stan neurologiczny (Disability),
- E – ekspozycja (Exposure).
Osoby, u których do zatrzymania krążenia doszło w trakcie intensywnego wysiłku fizycznego lub zabawy, mogą sprawiać wrażenie, że ciężko oddychają, i często mają otwarte oczy. Mimo to są w stanie zatrzymania krążenia i wymagają natychmiastowej RKO.

Nie myl zatrzymania krążenia z drgawkami. Krótkie, przypominające drgawki ruchy są często obserwowane u młodszych ofiar zatrzymania krążenia i mogą utrudniać jego rozpoznanie. Gdy ruchy ustaną, natychmiast oceń oddech.
```

### f03 turn 1 (family_thread), score 13

- question: Nie odzywa sie do mnie od tygodnia
- panels: [no_source], sources 0, 1 ms, ~0 tokens
- canned: true, opener: null, missing: [], banned: [], error: null

```text

```

### c04 turn 0 (crisis), score 13

- question: Boję się wojny
- panels: [no_source], sources 0, 1 ms, ~0 tokens
- canned: true, opener: null, missing: [], banned: [], error: null

```text

```

### c05 turn 0 (crisis), score 13

- question: Pokłóciłem się z mamą
- panels: [no_source], sources 0, 1 ms, ~0 tokens
- canned: true, opener: null, missing: [], banned: [], error: null

```text

```

### a02 turn 0 (assistant), score 13

- question: Czy działasz bez internetu?
- panels: [steps], sources 2, 1363 ms, ~101 tokens
- canned: false, opener: null, missing: [internet], banned: [], error: null

```text
Przygotowanie przed powodzią
Zapoznaj się z lokalnym systemem ostrzegania przed powodzią.
Edukuj najbliższych członków rodziny o działaniach w razie powodzi.
Przygotuj alternatywne źródła światła, ogrzewania i łączności.
Przygotuj zapasy żywności gotowej do spożycia i wody.
Miej przy sobie zapas gotówki w różnych nominałach.
```

