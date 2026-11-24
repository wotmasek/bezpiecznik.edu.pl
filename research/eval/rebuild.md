# Conversation eval: rebuild

| category | cases | pass | turns | median tokens | median ms | canned refusals | banned openers | missing must_include | banned hits | over target |
|---|---|---|---|---|---|---|---|---|---|---|
| assistant | 4 | 4/4 (100%) | 4 | 68 | 229 | 0 | 0 | 0 | 0 | 0 |
| crisis | 5 | 5/5 (100%) | 7 | 50 | 216 | 0 | 0 | 0 | 0 | 0 |
| family_thread | 5 | 5/5 (100%) | 14 | 36 | 166 | 0 | 0 | 0 | 0 | 0 |
| greeting | 5 | 5/5 (100%) | 5 | 26 | 155 | 0 | 0 | 0 | 0 | 1 |
| main | 12 | 7/12 (58%) | 12 | 117 | 435 | 0 | 0 | 3 | 0 | 0 |
| offtopic | 4 | 4/4 (100%) | 5 | 43 | 136 | 0 | 0 | 0 | 0 | 1 |
| profile | 4 | 2/4 (50%) | 4 | 44 | 177 | 0 | 0 | 1 | 0 | 0 |
| followup | 4 | 4/4 (100%) | 8 | 137 | 579 | 0 | 0 | 0 | 0 | 2 |
| worry | 4 | 4/4 (100%) | 5 | 71 | 319 | 0 | 0 | 0 | 0 | 1 |
| **ALL** | 47 | 40/47 (85%) | 64 | 50 | 206 | 0 | 0 | 4 | 0 | 5 |

## Worst 10 answers

### p04 turn 0 (profile), score 12

- question: Na którym piętrze mieszkam?
- panels: [chat_text], sources 0, 74 ms, ~16 tokens
- canned: false, opener: null, missing: [parter], banned: [], error: null

```text
Podaj informację o piętrze, na którym się znajdujesz.
```

### m02 turn 0 (main), score 12

- question: Co robić, gdy usłyszę syreny alarmowe?
- panels: [chat_text, steps, chat_text], sources 2, 435 ms, ~112 tokens
- canned: false, opener: null, missing: [schron|ukry|budyn], banned: [], error: null

```text
Przy usłyszeniu syren alarmowych należy:

Upewnij się, że wszyscy domownicy wiedzą, co robić w razie zagrożenia.
Monitoruj media, radio oraz aplikację RSO.
Bądź gotów na ogłoszenie alarmu: ciągły, modulowany dźwięk syreny przez 3 minuty.
Nie zwlekaj z przygotowaniem się do ewentualnych działań ratunkowych.
Czy chcesz wiedzieć więcej o przygotowaniu do powodzi?
```

### m06 turn 0 (main), score 12

- question: Jak zatamować krwotok?
- panels: [call, chat_text], sources 2, 364 ms, ~95 tokens
- canned: false, opener: null, missing: [112], banned: [], error: null

```text
Na krwawiące miejsce zastosuj silny, bezpośredni ucisk ręką. Przyłóż standardowy opatrunek lub opatrunek hemostatyczny bezpośrednio na krwawiące miejsce, a następnie zastosuj silny, bezpośredni ucisk ręką. Jeśli krwawienie zagraża życiu i nie zostało opanowane bezpośrednim uciskiem, załóż opaskę uciskową.
```

### m11 turn 0 (main), score 12

- question: Jak udzielić pierwszej pomocy przy zatrzymaniu krążenia?
- panels: [call, chat_text, steps, chat_text], sources 2, 462 ms, ~117 tokens
- canned: false, opener: null, missing: [klatk], banned: [], error: null

```text
W sytuacji zatrzymania krążenia należy wykonać następujące kroki:

Zadzwoń pod 112.
Sprawdź, czy poszkodowany jest nieprzytomny i nie oddycha prawidłowo.
Rozpocznij ocenę ABCDE, zaczynając od drożności dróg oddechowych (A).
Rozpocznij resuscytację krążenia (RKO) zgodnie z procedurami ERC.
Czy chcesz więcej o procedurach udzielania pierwszej pomocy przy zatrzymaniu krążenia?
```

### m12 turn 0 (main), score 11

- question: Jak zdezynfekować wodę do picia?
- panels: [chat_text], sources 0, 250 ms, ~74 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Zdezynfekowanie wody do picia wymaga użycia środków do dezynfekcji wody, takich jak gotowanie [Poradnik 1]. Można również zastosować inne metody, o których mowa w ogólnych poradnikach dotyczących higieny. Chcesz więcej o środkach czystości?
```

### p03 turn 0 (profile), score 11

- question: Czy mam zwierzęta?
- panels: [chat_text], sources 1, 178 ms, ~44 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
W domu przebywa pies. Pamiętaj o zwierzętach, które posiadasz w sytuacji kryzysowej. Chcesz wiedzieć, jak przygotować sprzęt do transportu psa?
```

### m07 turn 0 (main), score 11

- question: Pali się mieszkanie, co robić?
- panels: [call, steps], sources 0, 208 ms, ~38 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Wyłącz źródło zapłonu.
Użyj gaśnicy i koca gaśniczego.
Jeśli ogień nie gaśnie, opuść pomieszczenie i wezwij pomoc pod 112.
```

### c04 turn 0 (crisis), score 0

- question: Boję się wojny
- panels: [chat_text], sources 0, 137 ms, ~40 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Wojna to sytuacja bardzo niepokojąca. Skupmy się na tym, co możesz zrobić w obecnym miejscu. Czy masz dostęp do karty ratunkowej?
```

### c04 turn 1 (crisis), score 0

- question: Mam atak paniki, nie mogę oddychać
- panels: [call, chat_text], sources 0, 221 ms, ~53 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Zacznij powoli oddychać. Wdech nosem, wydech ustami. Czy jesteś w bezpiecznym miejscu? Możesz skontaktować się z telefonem zaufania pod 116 123 lub numerem alarmowym 112.
```

### c05 turn 0 (crisis), score 0

- question: Pokłóciłem się z mamą
- panels: [chat_text], sources 0, 94 ms, ~22 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Potrzebujesz wsparcia w tej trudnej sytuacji. O co poszło w tej kłótni?
```

