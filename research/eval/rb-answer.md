# Conversation eval: rb-answer

| category | cases | pass | turns | median tokens | median ms | canned refusals | banned openers | missing must_include | banned hits | over target |
|---|---|---|---|---|---|---|---|---|---|---|
| assistant | 4 | 3/4 (75%) | 4 | 64 | 203 | 0 | 0 | 0 | 0 | 0 |
| crisis | 5 | 5/5 (100%) | 7 | 48 | 186 | 0 | 0 | 0 | 0 | 0 |
| family_thread | 5 | 3/5 (60%) | 14 | 41 | 145 | 0 | 2 | 0 | 0 | 0 |
| greeting | 5 | 5/5 (100%) | 5 | 39 | 129 | 0 | 0 | 0 | 0 | 0 |
| main | 12 | 5/12 (42%) | 12 | 89 | 324 | 0 | 0 | 4 | 0 | 0 |
| offtopic | 4 | 4/4 (100%) | 5 | 47 | 160 | 0 | 0 | 0 | 0 | 0 |
| profile | 4 | 2/4 (50%) | 4 | 62 | 203 | 0 | 0 | 2 | 0 | 1 |
| followup | 4 | 4/4 (100%) | 8 | 100 | 357 | 0 | 0 | 0 | 0 | 3 |
| worry | 4 | 2/4 (50%) | 5 | 60 | 194 | 0 | 2 | 0 | 0 | 1 |
| **ALL** | 47 | 33/47 (70%) | 64 | 53 | 184 | 0 | 4 | 6 | 0 | 5 |

## Worst 10 answers

### m01 turn 0 (main), score 14

- question: Jak przygotować się na brak prądu?
- panels: [chat_text], sources 1, 248 ms, ~66 tokens
- canned: false, opener: null, missing: [woda|wody, latark], banned: [], error: null

```text
Przygotuj alternatywne źródła światła, ogrzewania i łączności. Rozważ zakup agregatu prądotwórczego i naładuj powerbanki, włączając telefon w tryb oszczędzania energii. Chcesz więcej o przygotowaniu na brak prądu?
```

### p01 turn 0 (profile), score 14

- question: Co o mnie wiesz?
- panels: [chat_text], sources 0, 190 ms, ~65 tokens
- canned: false, opener: null, missing: [dziecko|dziec, pies|psa], banned: [], error: null

```text
Wiem, że jesteś użytkownikiem korzystającym z aplikacji Bezpiecznik. Nie posiadam informacji o Twojej tożsamości poza tym, co podajesz w interakcjach. Czy masz jakiekolwiek pytania dotyczące funkcji aplikacji?
```

### m11 turn 0 (main), score 13

- question: Jak udzielić pierwszej pomocy przy zatrzymaniu krążenia?
- panels: [call, chat_text, steps, chat_text], sources 0, 448 ms, ~108 tokens
- canned: false, opener: null, missing: [klatk], banned: [], error: null

```text
Zacznij od oceny sytuacji.

Zadzwoń pod 112.
Sprawdź, czy poszkodowany jest nieprzytomny i nie oddycha prawidłowo.
Upewnij się, że otwierasz drogę oddechową.
Rozpocznij resuscytację krążeniowo-oddechową (RKO) zgodnie z protokołem ABCDE.
To jest bardzo poważna sytuacja, musisz działać szybko. Czy masz pod ręką automatyczny defibrylator zewnętrzny?
```

### p04 turn 0 (profile), score 12

- question: Na którym piętrze mieszkam?
- panels: [chat_text], sources 0, 142 ms, ~34 tokens
- canned: false, opener: null, missing: [parter], banned: [], error: null

```text
Aby udzielić precyzyjnej porady, należy wiedzieć, na którym piętrze mieszkasz. Czy możesz podać tę informację?
```

### m02 turn 0 (main), score 12

- question: Co robić, gdy usłyszę syreny alarmowe?
- panels: [chat_text, steps, chat_text], sources 2, 421 ms, ~114 tokens
- canned: false, opener: null, missing: [schron|ukry|budyn], banned: [], error: null

```text
Przy usłyszeniu ogłoszenia alarmu, zastosuj się do instrukcji zawartych w poradnikach. W sytuacji zagrożenia, należy:

Słuchać komunikatów radiowych i telewizyjnych.
Monitorować Alerty RCB wysyłane na telefony komórkowe.
Pobudować się i przygotować się do ewakuacji, jeśli to konieczne.
Czy potrzebujesz informacji o procedurach w przypadku innych sytuacji zagrożenia?
```

### m06 turn 0 (main), score 12

- question: Jak zatamować krwotok?
- panels: [call, chat_text, steps, chat_text], sources 2, 680 ms, ~182 tokens
- canned: false, opener: null, missing: [112], banned: [], error: null

```text
Zastosuj poniższe kroki w zależności od sytuacji:

Na krwawiące miejsce zastosuj silny, bezpośredni ucisk ręką.
Przyłóż standardowy opatrunek lub opatrunek hemostatyczny bezpośrednio na krwawiące miejsce, a następnie zastosuj silny, bezpośredni ucisk ręką.
Jeśli krwawienie z kończyny nie ustaje, załóż opaskę do tamowania krwotoków powyżej rany na ramieniu lub udzie i zapisz godzinę założenia opaski.
Jeśli nie możesz założyć opaski ani opatrunku, uciskaj bezpośrednio ranę dłonią lub tkaniną aż do zatrzymania krwotoku lub przybycia ratowników.
Czy czujesz, że sytuacja jest poważna?
```

### m12 turn 0 (main), score 11

- question: Jak zdezynfekować wodę do picia?
- panels: [chat_text], sources 0, 219 ms, ~69 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Zdezynfekowanie wody do picia jest ważne w sytuacjach kryzysowych. Poradniki tego nie opisują, ale należy stosować metody bezpiecznego uzdatniania wody, gdy źródło jest niepewne. Czy chcesz sprawdzić listę innych zapasów?
```

### a02 turn 0 (assistant), score 11

- question: Czy działasz bez internetu?
- panels: [chat_text], sources 1, 172 ms, ~48 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Tak, działam bez dostępu do internetu. Jestem Bezpiecznikiem, asystentem bezpieczeństwa w aplikacji bez sieci. Chcesz więcej o przygotowaniu do braku prądu?
```

### f01 turn 1 (family_thread), score 11

- question: Pokłóciłem się dziś z mamą i jest mi smutno
- panels: [chat_text], sources 0, 152 ms, ~46 tokens
- canned: false, opener: rozumiem, missing: [], banned: [], error: null

```text
Rozumiem, że czujesz smutek po kłótni. Czy potrzebujesz informacji o technikach radzenia sobie ze stresem? Chcesz więcej o radzeniu sobie z emocjami?
```

### m07 turn 0 (main), score 11

- question: Pali się mieszkanie, co robić?
- panels: [call, chat_text, steps, chat_text], sources 0, 283 ms, ~60 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Włącz alarm i ewakuuj dom natychmiast.

Wyłącz przyłącza gazu i prądu, jeśli to możliwe i bezpieczne.
Wykorzystaj koc gaśniczy do gaszenia pożaru.
Zadzwoń pod 112.
Czy czujesz się zaniepokojony?
```

