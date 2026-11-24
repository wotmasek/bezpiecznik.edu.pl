# Conversation eval: final

| category | cases | pass | turns | median tokens | median ms | canned refusals | banned openers | missing must_include | banned hits | over target |
|---|---|---|---|---|---|---|---|---|---|---|
| assistant | 4 | 4/4 (100%) | 4 | 67 | 209 | 0 | 0 | 0 | 0 | 0 |
| crisis | 5 | 5/5 (100%) | 7 | 33 | 170 | 0 | 0 | 0 | 0 | 0 |
| family_thread | 5 | 5/5 (100%) | 14 | 42 | 164 | 0 | 0 | 0 | 0 | 1 |
| greeting | 5 | 5/5 (100%) | 5 | 41 | 154 | 0 | 0 | 0 | 0 | 1 |
| main | 12 | 5/12 (42%) | 12 | 93 | 440 | 0 | 0 | 5 | 0 | 1 |
| offtopic | 4 | 4/4 (100%) | 5 | 34 | 106 | 0 | 0 | 0 | 0 | 0 |
| profile | 4 | 2/4 (50%) | 4 | 37 | 147 | 0 | 0 | 0 | 0 | 0 |
| followup | 4 | 4/4 (100%) | 8 | 130 | 561 | 0 | 0 | 0 | 0 | 3 |
| worry | 4 | 4/4 (100%) | 5 | 48 | 203 | 0 | 0 | 0 | 0 | 0 |
| **ALL** | 47 | 38/47 (81%) | 64 | 48 | 181 | 0 | 0 | 5 | 0 | 6 |

## Worst 10 answers

### m02 turn 0 (main), score 13

- question: Co robić, gdy usłyszę syreny alarmowe?
- panels: [chat_text], sources 0, 150 ms, ~29 tokens
- canned: false, opener: null, missing: [schron|ukry|budyn], banned: [], error: null

```text
Posłuchaj syreny alarmowej. Przejdź do karty ratunkowej. Sprawdź, czy rodzina wie, co robić.
```

### m11 turn 0 (main), score 12

- question: Jak udzielić pierwszej pomocy przy zatrzymaniu krążenia?
- panels: [call, chat_text, steps, bullets, steps], sources 3, 500 ms, ~93 tokens
- canned: false, opener: null, missing: [klatk], banned: [], error: null

```text
Zadzwoń pod 112.

Sprawdź, czy osoba jest nieprzytomna i nie oddycha prawidłowo.
Ocena ABCDE:

A – drogi oddechowe.
B – oddychanie.
C – krążenie.
D – stan neurologiczny.
E – ekspozycja.

Jeśli osoba ma do zatrzymania krążenia doszło w trakcie wysiłku fizycznego lub zabawy, natychmiast rozpocznij RKO.
```

### m01 turn 0 (main), score 12

- question: Jak przygotować się na brak prądu?
- panels: [chat_text, steps, chat_text], sources 2, 636 ms, ~143 tokens
- canned: false, opener: null, missing: [woda|wody], banned: [], error: null

```text
Przygotuj następujące rzeczy w przypadku długotrwałego braku prądu:

Przygotuj alternatywne źródła światła, takie jak latarki z zapasem baterii.
Przygotuj ogrzewanie, np. piecyk gazowy lub kominek.
Zabezpiecz łączność, np. radio na baterie lub krótkofalówki.
Naładuj powerbanki i włącz tryb oszczędzania energii w telefonie.
Przygotuj zapasy żywności gotowej do spożycia.
Zadbaj o zapasy domowe na minimum 3 dni.
Czy chcesz więcej o przygotowaniu na brak prądu?
```

### m06 turn 0 (main), score 12

- question: Jak zatamować krwotok?
- panels: [call, chat_text, steps, chat_text], sources 2, 690 ms, ~170 tokens
- canned: false, opener: null, missing: [112], banned: [], error: null

```text
Zatamowanie krwotoku zależy od jego stopnia.

Na krwawiące miejsce zastosuj silny, bezpośredni ucisk ręką.
Przyłóż opatrunek hemostatyczny bezpośrednio na krwawiące miejsce, a następnie zastosuj silny, bezpośredni ucisk ręką.
Jeśli krwawienie nie ustaje, załóż opaskę do tamowania krwotoków powyżej rany na ramieniu lub udzie, zapisując godzinę.
Jeśli nie możesz założyć opaski ani opatrunku, uciskaj bezpośrednio ranę dłonią lub tkaniną aż do zatrzymania krwotoku lub przybycia ratowników.
Czy chcesz listę czynności do wykonania w nagłej sytuacji?
```

### m09 turn 0 (main), score 12

- question: Ile wody trzeba zgromadzić na osobę?
- panels: [chat_text], sources 1, 169 ms, ~33 tokens
- canned: false, opener: null, missing: [3|trzy], banned: [], error: null

```text
Zgromadź wodę o długotrwałej przydatności do spożycia i wodę.Chcesz wiedzieć, jak zaplanować zapasy wody?
```

### m12 turn 0 (main), score 11

- question: Jak zdezynfekować wodę do picia?
- panels: [chat_text], sources 0, 193 ms, ~58 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Nie ma informacji w poradnikach dotyczących dezynfekowania wody do picia. Zawsze należy stosować wodę butelkowaną lub przefiltrowaną. Czy masz inne pytania dotyczące przygotowania zapasów?
```

### p04 turn 0 (profile), score 11

- question: Na którym piętrze mieszkam?
- panels: [chat_text], sources 1, 183 ms, ~47 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Nie znasz, na którym piętrze mieszkasz. Profil domu wskazuje, że mieszkanie znajduje się na parterze. Czy potrzebujesz pomocy z jakimiś innymi kwestiami?
```

### p03 turn 0 (profile), score 11

- question: Czy mam zwierzęta?
- panels: [chat_text], sources 1, 97 ms, ~19 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
W profilu domu jest pies. Czy pies jest zwierzęciem domowym?
```

### m07 turn 0 (main), score 11

- question: Pali się mieszkanie, co robić?
- panels: [call, steps], sources 0, 181 ms, ~25 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Wyłącz gaz i prąd.
Wykorzystaj koc gaśniczy.
Opuść mieszkanie.
Zadzwoń pod 112.
```

### c05 turn 0 (crisis), score 0

- question: Pokłóciłem się z mamą
- panels: [chat_text], sources 0, 111 ms, ~33 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Zrozumiałe, że sytuacja jest dla Ciebie trudna. Czy potrzebujesz informacji o tym, jak sobie z tym poradzić?
```

