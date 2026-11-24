# Conversation eval: baseline

| category | cases | pass | turns | median tokens | median ms | canned refusals | banned openers | missing must_include | banned hits | over target |
|---|---|---|---|---|---|---|---|---|---|---|
| assistant | 4 | 3/4 (75%) | 4 | 101 | 311 | 0 | 0 | 1 | 0 | 3 |
| crisis | 5 | 0/5 (0%) | 7 | 55 | 219 | 0 | 5 | 2 | 0 | 0 |
| family_thread | 5 | 1/5 (20%) | 14 | 47 | 204 | 1 | 3 | 0 | 0 | 1 |
| greeting | 5 | 5/5 (100%) | 5 | 52 | 218 | 0 | 0 | 0 | 0 | 3 |
| main | 12 | 6/12 (50%) | 12 | 142 | 1707 | 1 | 0 | 5 | 0 | 2 |
| offtopic | 4 | 3/4 (75%) | 5 | 47 | 187 | 1 | 1 | 0 | 0 | 2 |
| profile | 4 | 0/4 (0%) | 4 | 58 | 188 | 2 | 0 | 4 | 0 | 0 |
| followup | 4 | 3/4 (75%) | 8 | 123 | 1609 | 1 | 0 | 0 | 0 | 2 |
| worry | 4 | 0/4 (0%) | 5 | 34 | 163 | 1 | 4 | 0 | 0 | 0 |
| **ALL** | 47 | 21/47 (45%) | 64 | 57 | 219 | 7 | 13 | 12 | 0 | 13 |

## Worst 10 answers

### p03 turn 0 (profile), score 15

- question: Czy mam zwierzęta?
- panels: [no_source], sources 0, 67 ms, ~0 tokens
- canned: true, opener: null, missing: [pies|psa|psem], banned: [], error: null

```text

```

### p04 turn 0 (profile), score 15

- question: Na którym piętrze mieszkam?
- panels: [no_source], sources 0, 70 ms, ~0 tokens
- canned: true, opener: null, missing: [parter], banned: [], error: null

```text

```

### m12 turn 0 (main), score 14

- question: Jak zdezynfekować wodę do picia?
- panels: [no_source], sources 0, 78 ms, ~0 tokens
- canned: true, opener: null, missing: [], banned: [], error: null

```text

```

### m11 turn 0 (main), score 14

- question: Jak udzielić pierwszej pomocy przy zatrzymaniu krążenia?
- panels: [call, quote, quote, quote], sources 3, 4209 ms, ~524 tokens
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

### p01 turn 0 (profile), score 14

- question: Co o mnie wiesz?
- panels: [chat_text], sources 0, 192 ms, ~60 tokens
- canned: false, opener: null, missing: [dziecko|dziec, pies|psa], banned: [], error: null

```text
Jestem Bezpiecznikiem, programem pomocnym w aplikacji o bezpieczeństwie. Mogę Ci pomóc w przypadku różnych sytuacji, oferując poradniki, mapę schronów czy przycisk SOS. Jak mogę Ci dzisiaj pomóc?
```

### w04 turn 0 (worry), score 13

- question: Jestem przerażony tym, co się dzieje na świecie
- panels: [no_source], sources 0, 1 ms, ~0 tokens
- canned: true, opener: null, missing: [], banned: [], error: null

```text

```

### a02 turn 0 (assistant), score 13

- question: Czy działasz bez internetu?
- panels: [steps], sources 2, 1170 ms, ~101 tokens
- canned: false, opener: null, missing: [internet], banned: [], error: null

```text
Przygotowanie przed powodzią
Zapoznaj się z lokalnym systemem ostrzegania przed powodzią.
Edukuj najbliższych członków rodziny o działaniach w razie powodzi.
Przygotuj alternatywne źródła światła, ogrzewania i łączności.
Przygotuj zapasy żywności gotowej do spożycia i wody.
Miej przy sobie zapas gotówki w różnych nominałach.
```

### c02 turn 0 (crisis), score 13

- question: Mam atak paniki
- panels: [call, chat_text], sources 0, 213 ms, ~53 tokens
- canned: false, opener: rozumiem, missing: [oddych|oddech], banned: [], error: null

```text
Rozumiem, że przeżywasz atak paniki. Czy czujesz się teraz bezpiecznie? Pamiętaj, że nie jesteś sam. Jeśli potrzebujesz wsparcia, możesz zadzwonić pod 116 123 lub pod 112.
```

### f05 turn 0 (family_thread), score 13

- question: Ona uważa, że za mało pomagam w domu
- panels: [no_source], sources 0, 2 ms, ~0 tokens
- canned: true, opener: null, missing: [], banned: [], error: null

```text

```

### u03 turn 1 (followup), score 13

- question: a co z dokumentami?
- panels: [no_source], sources 0, 76 ms, ~0 tokens
- canned: true, opener: null, missing: [], banned: [], error: null

```text

```

