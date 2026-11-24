# Conversation eval: final2

| category | cases | pass | turns | median tokens | median ms | canned refusals | banned openers | missing must_include | banned hits | over target |
|---|---|---|---|---|---|---|---|---|---|---|
| assistant | 4 | 4/4 (100%) | 4 | 54 | 170 | 0 | 0 | 0 | 0 | 0 |
| crisis | 5 | 5/5 (100%) | 7 | 42 | 202 | 0 | 0 | 0 | 0 | 1 |
| family_thread | 5 | 5/5 (100%) | 14 | 34 | 140 | 0 | 0 | 0 | 0 | 0 |
| greeting | 5 | 5/5 (100%) | 5 | 38 | 132 | 0 | 0 | 0 | 0 | 1 |
| main | 12 | 7/12 (58%) | 12 | 80 | 325 | 0 | 0 | 3 | 0 | 0 |
| offtopic | 4 | 4/4 (100%) | 5 | 40 | 148 | 0 | 0 | 0 | 0 | 0 |
| profile | 4 | 3/4 (75%) | 4 | 30 | 116 | 0 | 0 | 1 | 0 | 0 |
| followup | 4 | 3/4 (75%) | 8 | 140 | 591 | 0 | 0 | 0 | 2 | 3 |
| worry | 4 | 4/4 (100%) | 5 | 40 | 187 | 0 | 0 | 0 | 0 | 0 |
| **ALL** | 47 | 40/47 (85%) | 64 | 47 | 173 | 0 | 0 | 4 | 2 | 5 |

## Worst 10 answers

### m01 turn 0 (main), score 13

- question: Jak przygotować się na brak prądu?
- panels: [chat_text, steps], sources 0, 468 ms, ~112 tokens
- canned: false, opener: null, missing: [woda|wody], banned: [], error: null

```text
Przygotowanie na brak prądu obejmuje:

Przygotowanie alternatywnych źródeł światła (latarki z zapasem baterii).
Przygotowanie ogrzewania (piecyk gazowy lub olejowy, kominek).
Przygotowanie łączności (radio na baterie, krótkofalówki, CB radio).
Rozważenie zakupu agregatu prądotwórczego.
Naładowanie powerbanków i włączenie trybu oszczędzania energii w telefonie.
```

### u02 turn 0 (followup), score 12

- question: Co robić, gdy usłyszę syreny alarmowe?
- panels: [chat_text], sources 3, 475 ms, ~132 tokens
- canned: false, opener: null, missing: [], banned: [RKO], error: null

```text
Jeśli usłyszysz ogłoszenie alarmu, natychmiast przerwij wszystko i posłuchaj komunikatów ze źródeł takich jak radio, telewizja, internet lub poinformowania na telefonie komórkowym. W Polsce istnieją dwa rodzaje sygnałów alarmowych: ogłoszenie alarmu to ciągły, modulowany dźwięk syreny trwający 3 minuty. W przypadku powodzi należy dowiedzieć się, jak działa lokalny system ostrzegania i edukować najbliższych członków rodziny.
```

### u02 turn 1 (followup), score 12

- question: a jak jestem w pracy?
- panels: [chat_text], sources 2, 276 ms, ~69 tokens
- canned: false, opener: null, missing: [], banned: [RKO], error: null

```text
Jeśli jesteś w pracy, należy słuchać komunikatów z mediów, takich jak radio czy telewizja, oraz monitorować Alerty RCB na telefonie komórkowym. Bądź na bieżąco z informacjami, aby wiedzieć, jak reagować na sygnały alarmowe.
```

### p04 turn 0 (profile), score 12

- question: Na którym piętrze mieszkam?
- panels: [chat_text], sources 0, 112 ms, ~30 tokens
- canned: false, opener: null, missing: [parter], banned: [], error: null

```text
Nie wiadomo, na którym piętrze mieszkasz. Czy masz jakieś pytania dotyczące zabezpieczeń w domu?
```

### m11 turn 0 (main), score 12

- question: Jak udzielić pierwszej pomocy przy zatrzymaniu krążenia?
- panels: [call, chat_text, steps], sources 3, 691 ms, ~150 tokens
- canned: false, opener: null, missing: [klatk], banned: [], error: null

```text
Zadzwoń pod 112.

Sprawdź, czy osoba jest nieprzytomna i nie oddycha prawidłowo.
Rozpocznij ocenę ABCDE: drogi oddechowe (A), oddychanie (B), krążenie (C), stan neurologiczny (D), ekspozycja (E).
Jeśli osoba wydaje się oddychać (sapanie, uciekanie powietrza), nie zakładaj, że oddycha prawidłowo.
Jeśli doszło do zatrzymania krążenia w trakcie wysiłku fizycznego, natychmiast rozpocznij resuscytację krążeniowo-oddechową (RKO).
Użyj karty ratunkowej, aby wykonać odpowiednie czynności.
```

### m02 turn 0 (main), score 12

- question: Co robić, gdy usłyszę syreny alarmowe?
- panels: [chat_text], sources 3, 284 ms, ~80 tokens
- canned: false, opener: null, missing: [schron|ukry|budyn], banned: [], error: null

```text
Włącz radio lub telewizję, aby poznać informacje o sytuacji. Pobierz aplikację RSO, aby być na bieżąco z zagrożeniami. Jeśli mieszkasz na terenie zalewowym, dowiedz się więcej na temat powodzi na stronach internetowych z informacjami. Chcesz więcej o powodzi?
```

### m07 turn 0 (main), score 11

- question: Pali się mieszkanie, co robić?
- panels: [call, steps], sources 0, 252 ms, ~48 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Wyłącz zasilanie w głównym rozdzielaczu.
Wykorzystaj koc gaśniczy do gaszenia małego pożaru.
Jeśli pożar się rozprzestrzenia, natychmiast zadzwoń pod 112.
```

### m12 turn 0 (main), score 11

- question: Jak zdezynfekować wodę do picia?
- panels: [chat_text], sources 0, 176 ms, ~48 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Nie ma informacji w poradnikach o dezynfekcji wody do picia. Zaleca się stosowanie wody butelkowanej lub gotowanie wody. Chcesz więcej o zapasach wodnych?
```

### c04 turn 1 (crisis), score 0

- question: Mam atak paniki, nie mogę oddychać
- panels: [call, chat_text], sources 0, 296 ms, ~104 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Weź głęboki wdech nosem, a następnie powoli wypuść powietrze ustami. Powtórz to kilka razy, skupiając się na spokojnym oddechu. Czy jesteś w bezpiecznym miejscu? Skontaktuj się z telefonami zaufania pod 116 oraz 123, lub pod 112.

Zadzwoń pod 116 123 (telefon zaufania dla dorosłych). Jeśli jesteś w niebezpieczeństwie, dzwoń pod 112.
```

### c05 turn 0 (crisis), score 0

- question: Pokłóciłem się z mamą
- panels: [chat_text], sources 0, 95 ms, ~25 tokens
- canned: false, opener: null, missing: [], banned: [], error: null

```text
Zrozumiałe, to musi być trudne uczucie. Czy potrzebujesz wsparcia w inny sposób?
```

