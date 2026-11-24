# Conversation eval: rb-answer

| category | cases | pass | turns | median tokens | median ms | canned refusals | banned openers | missing must_include | banned hits | over target |
|---|---|---|---|---|---|---|---|---|---|---|
| assistant | 4 | 4/4 (100%) | 4 | 63 | 201 | 0 | 0 | 0 | 0 | 0 |
| crisis | 5 | 4/5 (80%) | 7 | 51 | 200 | 0 | 1 | 0 | 0 | 0 |
| family_thread | 5 | 3/5 (60%) | 14 | 34 | 131 | 0 | 2 | 0 | 0 | 0 |
| greeting | 5 | 5/5 (100%) | 5 | 23 | 115 | 0 | 0 | 0 | 0 | 0 |
| main | 12 | 7/12 (58%) | 12 | 86 | 363 | 0 | 0 | 4 | 0 | 0 |
| offtopic | 4 | 4/4 (100%) | 5 | 34 | 124 | 0 | 0 | 0 | 0 | 0 |
| profile | 4 | 2/4 (50%) | 4 | 41 | 133 | 0 | 0 | 0 | 0 | 0 |
| followup | 4 | 4/4 (100%) | 8 | 128 | 492 | 0 | 0 | 0 | 0 | 3 |
| worry | 4 | 2/4 (50%) | 5 | 57 | 206 | 0 | 2 | 0 | 0 | 1 |
| **ALL** | 47 | 35/47 (74%) | 64 | 44 | 157 | 0 | 5 | 4 | 0 | 4 |

## Worst 10 answers

### m11 turn 0 (main), score 12

- question: Jak udzielić pierwszej pomocy przy zatrzymaniu krążenia?
- panels: [call, chat_text, steps], sources 2, 439 ms, ~95 tokens
- canned: false, opener: null, missing: [klatk], banned: [], error: null

```text
Zadzwoń pod 112.

Sprawdź, czy osoba jest nieprzytomna i nie oddycha prawidłowo.
Zacznij ocenę ABCDE: A – drogi oddechowe, B – oddychanie, C – krążenie, D – stan neurologiczny, E – ekspozycja.
Przy ocenie oddychania, pamiętaj, że mimowolne sapanie lub uciekanie powietrza to nie jest prawidłowe oddychanie.
```

### m02 turn 0 (main), score 12

- question: Co robić, gdy usłyszę syreny alarmowe?
- panels: [chat_text, steps, chat_text], sources 1, 292 ms, ~74 tokens
- canned: false, opener: null, missing: [schron|ukry|budyn], banned: [], error: null

```text
Przy usłyszeniu ogłoszenia alarmu, należy:

Posłuchać komunikatów radiowych.
Sprawdzić informacje w mediach (radio, telewizja, internet).
Upewnić się, że wszyscy członkowie rodziny wiedzą, co robić.
Czy chcesz więcej informacji o powodzi?
```

### m01 turn 0 (main), score 12

- question: Jak przygotować się na brak prądu?
- panels: [chat_text, chat_text], sources 1, 304 ms, ~78 tokens
- canned: false, opener: null, missing: [latark], banned: [], error: null

```text
Przygotuj alternatywne źródła światła, ogrzewania i łączności. Włącz w telefonie tryb oszczędzania energii i naładuj powerbanki. Możesz rozważyć zakup agregatu prądotwórczego.
Czy chcesz więcej o przygotowaniu na przerwy w dostawach wody, prądu i gazu?
```

### m06 turn 0 (main), score 12

- question: Jak zatamować krwotok?
- panels: [call, chat_text, steps, chat_text], sources 3, 750 ms, ~200 tokens
- canned: false, opener: null, missing: [112], banned: [], error: null

```text
Zastosuj następujące kroki przy krwotoku:

Na krwawiące miejsce zastosuj silny, bezpośredni ucisk ręką.
Przyłóż standardowy lub opatrunek hemostatyczny bezpośrednio na krwawiące miejsce, a następnie zastosuj silny, bezpośredni ucisk ręką.
Jeśli krwawienie z kończyny nie ustaje, załóż opaskę do tamowania krwotoków powyżej rany na ramieniu lub udzie, zapisując godzinę założenia opaski.
Jeśli nie możesz założyć opaski ani opatrunku, uciskaj bezpośrednio ranę dłonią lub tkaniną aż do zatrzymania krwotoku lub przybycia ratowników.
Po opanowaniu krwotczenia załóż opatrunek uciskowy.
Czy potrzebujesz informacji o innych procedurach ratunkowych?
```

### m12 turn 0 (main), score 11

- question: Jak zdezynfekować wodę do picia?
- panels: [chat_text], sources 0, 139 ms, ~40 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Nie ma poradnika dotyczącego dezynfekowania wody do picia. Zaleca się używanie wody butelkowanej lub gotowania wody [Poradniki].
```

### c04 turn 0 (crisis), score 11

- question: Boję się wojny
- panels: [chat_text], sources 0, 180 ms, ~61 tokens
- canned: false, opener: rozumiem, missing: [], banned: [], error: null

```text
Rozumiem, że czujesz lęk przed wojną. W tej sytuacji najważniejsze jest zachowanie spokoju i przygotowanie się na ewentualne zagrożenie. Chcesz wiedzieć, jak przygotować się do sytuacji awaryjnej?
```

### w03 turn 0 (worry), score 11

- question: Boje sie ze zabraknie pradu i jedzenia
- panels: [chat_text, chat_text], sources 2, 497 ms, ~137 tokens
- canned: false, opener: rozumiem, missing: [], banned: [], error: null

```text
Rozumiem, że obawiasz się braku prądu i jedzenia. To może być stresujące, ale należy zachować spokój.
W sytuacji braku prądu, należy skupić się na utrzymaniu ciepła i bezpieczeństwa. Zapasy domowe powinny obejmować żywność gotową do spożycia oraz minimum 3 litry wody na osobę na dobę. Jeśli brakuje prądu, należy rozważyć zastosowanie prowizorycznych rozwiązań w kwestii higieny, np. użycie wiader na toalety. Chcesz listę zapasów żywności?
```

### w04 turn 0 (worry), score 11

- question: Jestem przerażony tym, co się dzieje na świecie
- panels: [chat_text], sources 0, 101 ms, ~31 tokens
- canned: false, opener: rozumiem, missing: [], banned: [], error: null

```text
Rozumiem, że sytuacja może budzić lęk. Czy potrzebujesz informacji o bezpieczeństwie w Twoim miejscu?
```

### p04 turn 0 (profile), score 11

- question: Na którym piętrze mieszkam?
- panels: [chat_text], sources 1, 122 ms, ~33 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Dom znajduje się na parterze. Czy potrzebujesz informacji o planie ewakuacji lub przygotowaniu na awarie?
```

### p03 turn 0 (profile), score 11

- question: Czy mam zwierzęta?
- panels: [chat_text], sources 1, 154 ms, ~44 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Dom ma psa. W sytuacjach kryzysowych należy pamiętać o zwierzętach, które się opiekują. Czy potrzebujesz pomocy w przygotowaniu czegoś dla psa?
```

