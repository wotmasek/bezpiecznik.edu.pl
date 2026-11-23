# Szablony w czacie

Odpowiedź asystenta w [czacie](ekran-1-czat.md) to lista szablonów (`panels[]`), a nie wolny tekst. W JSON szablon to element `panels[]`, a jego rodzaj to `panels[].type`. Ten plik jest kontraktem danych i wyglądu dla renderera `TemplateRenderer`.

## Zasady wspólne

### Wiadomość asystenta

Model zwraca tylko `{ "panels": [...] }` (format z [lokalne-ai.md](../05-technologia/lokalne-ai.md#format-odpowiedzi)) jako jeden obiekt, bez wywoływania narzędzi. Renderer nie pokazuje szablonów w kawałkach: w trakcie generowania (`status: generating`) jest szkielet, a po walidacji całego obiektu wszystkie szablony pojawiają się naraz. Aplikacja opakowuje to w wiadomość:

| Pole | Typ | Opis |
|---|---|---|
| `id` | string | Identyfikator wiadomości |
| `role` | `"assistant"` | Dla wiadomości użytkownika: `"user"` i pole `text` |
| `origin` | `rescue_card` · `rules` · `ai` · `no_ai` · `refusal` | Skąd pochodzi odpowiedź. Steruje etykietą nad wiadomością |
| `card_id` | string? | Dla `rescue_card`, np. `rko` |
| `intent` | string? | Dla odpowiedzi z [intencji](../04-dane/kontrakty-tresci.md#intencje), np. `shelter` |
| `status` | `generating` · `done` · `stopped` · `error` | Stan generowania |
| `selected_variant` | string? | Wybrany wariant, wspólny dla wszystkich szablonów wiadomości |
| `panels` | Panel[] | Szablony w kolejności wyświetlania |
| `text` | string? | Tylko dla `refusal`: tekst odmowy |
| `created_at` | ISO 8601 | Czas utworzenia |

**Wygląd (redesign 2026-11, styl ChatGPT).** Odpowiedź to tekst, nie karty: nagłówek szablonu (`step` 20/28), lista numerowana albo punktowana (`chat` 17/26, znacznik w kolumnie 28 dp, kolor `ink-200`), odstępy z tokenów. Ramek i tła nie mają szablony `steps`, `bullets`, `todo`, `quote` i `chat_text`. Ramkę ma tylko `form` (to kontrolki do wypełnienia) oraz narzędzia `map`, `cpr`, `signal`. Kolejność w wiadomości:

1. Wiersz nagłówka: etykieta `origin`, plakietka „Do weryfikacji”, a po prawej jeden [przełącznik wariantu](#warianty), gdy wiadomość ma warianty.
2. Szablony w kolejności `panels[]` (bez `call`, zob. [`call`](#call)).
3. Wiersz akcji: „Czytaj na głos” (pierwszy `steps` z `read_aloud`) i pigułka „Źródła · n” ([przypisy](#przypisy-i-lista-źródeł)).
4. Rozwinięta lista źródeł (po dotknięciu pigułki albo przypisu), notka, stopka karty ratunkowej.

Etykieta nad wiadomością według `origin`: `rescue_card` → „Karta ratunkowa”, `rules` → „Z twojego profilu” (brak etykiety, gdy wiadomość ma pole `intent`, [intencje](../04-dane/kontrakty-tresci.md#intencje)), `ai` → brak, `no_ai` → „Tryb bez AI: fragmenty źródeł”, `refusal` → brak (odmowa to spokojny komponent `NoSource`, bez 112; [odmowa](../02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md#odmowa)).

### Kto może użyć którego szablonu

| Szablon | Rodzaj | Model AI (`ai`) | Karta ratunkowa, reguły (`rescue_card`, `rules`) | Tryb bez AI (`no_ai`) |
|---|---|---|---|---|
| `steps` | treść | tak | tak | nie |
| `bullets` | treść | tak | tak | nie |
| `todo` | treść | tak (nie przy frazie ryzyka) | tak | nie |
| `form` | pytania | tak (nie przy frazie ryzyka) | nie | nie |
| `quote` | treść | tak | tak | tak (jedyny szablon treści) |
| `animation` | treść | **nie** | tak | nie |
| `cpr` | treść | **nie** | tak | nie |
| `map` | narzędzie | tak | tak | tak |
| `call` | narzędzie | tak | tak | tak |
| `signal` | narzędzie | tak | tak | tak |

`animation` i `cpr` występują tylko w kartach sprawdzonych przez człowieka, bo model nie uczestniczy w ścieżce zagrożenia życia ([odpowiedzi tylko ze źródeł](../02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md)).

### Reguły

1. Każdy szablon treści ma co najmniej jedno źródło (`source_id`). Każdy element `steps` i `bullets` ma własne `source_id`.
2. Szablon `call` pojawia się zawsze, gdy sytuacja może zagrażać życiu. Pilnuje tego aplikacja, nie model: dodaje `call` na początku wiadomości (ekran czatu przypina wtedy „Zadzwoń 112” nad polem wpisywania), gdy `origin = rescue_card` albo gdy wiadomość użytkownika (nie znalezione fragmenty) trafia na listę fraz ryzyka (np. pożar, gaz, wypadek, powódź, krwawi, nieprzytomny; plik [`assets/phrases/risk.json`](../04-dane/kontrakty-tresci.md#frazy-ryzyka)).
3. Najwyżej jeden `call` i jeden `cpr` w wiadomości. `call` zawsze jako pierwszy szablon.
4. `todo` i `form` nigdy przy frazie ryzyka: aplikacja zamienia `todo` na `bullets` i usuwa `form`. `form` zostaje tylko wtedy, gdy jest jedynym szablonem odpowiedzi.
5. Walidacja odpowiedzi modelu: nieznany `type` → szablon usunięty. Element bez istniejącego `source_id` albo bez pokrycia w fragmencie → element usunięty. Szablon treści bez elementów → usunięty. Brak szablonów treści po walidacji → wiadomość w trybie bez AI (`no_ai`, szablony `quote` z najlepszymi fragmentami).
6. Krótko: jeden element `steps` to jeden czasownik i jedna czynność, do 120 znaków.
7. Karty ratunkowe (`assets/cards/{card_id}.json`, [kontrakt](../04-dane/kontrakty-tresci.md)), reguły planu 72 h i plecaka, ich rekordy źródeł (bez plików PDF) i animacje są dołączone do aplikacji, a nie do pobieranych paczek. Działają zaraz po instalacji.

### Warianty

- Szablony `steps`, `animation`, `cpr` mogą mieć warianty (np. `adult` Dorosły, `child` Dziecko, `infant` Niemowlę).
- Wybór wariantu jest jeden na wiadomość (`selected_variant`). Przełącznik to cichy chip „Dorosły ⌄” w wierszu nagłówka wiadomości (`VariantChip`); dotknięcie otwiera małe menu z opcjami i `✓` przy wybranej. Zmiana przełącza wszystkie szablony wiadomości.
- Wszystkie szablony z wariantami w jednej wiadomości mają ten sam zbiór `id` wariantów (sprawdzane przy budowie kart).
- Domyślnie wybrany jest pierwszy wariant, chyba że fraza użytkownika nazywa dziecko lub niemowlę. Słowa z `variant_words` karty ([kontrakt karty](../04-dane/kontrakty-tresci.md#karta-ratunkowa)) ustawiają `selected_variant`: dziecko, dziecka, syn, córka → `child`; niemowlę, niemowlak, bobas, noworodek → `infant`. Gdy pasują słowa obu wariantów, wygrywa `infant` (*domyślne, do potwierdzenia*). Nie dobieramy wariantu z profilu.
- Pierwszeństwo fraz: „nieprzytomny i nie oddycha” i „nie oddycha” zawsze wygrywają z „nieprzytomny” (karta RKO, nie „Utrata przytomności”). Karta „Utrata przytomności” zaczyna się od kroku „Sprawdź oddech: patrz, słuchaj, czuj do 10 s” i przycisku „Nie oddycha → RKO”, który wstawia kartę RKO ([karty ratunkowe](../02-funkcje/02-pierwsza-pomoc/karty-ratunkowe.md#utrata-przytomności--rko)).
- Jeden wymiar wariantów, najwyżej 3 opcje. Drugi wymiar (np. przytomny / nieprzytomny przy zadławieniu) to osobny szablon `steps` z własnym tytułem, np. „Gdy straci przytomność”.

### Rekord źródła

`source_id` wskazuje rekord w bazie wiedzy ([źródła wiedzy](../04-dane/zrodla-wiedzy.md)). Format: `{dokument}-{rok}-s{strona}-f{nr}`, np. `poradnik-2025-s14-f3`. Renderer potrzebuje pól:

| Pole | Typ | Opis |
|---|---|---|
| `source_id` | string | Identyfikator fragmentu |
| `doc_id` | string | Identyfikator dokumentu |
| `doc_title` | string | Pełny tytuł, np. „Poradnik bezpieczeństwa” |
| `doc_short` | string | Krótka nazwa do chipu, np. „Poradnik bezp.” |
| `publisher` | string | Np. „RCB, MON, MSWiA” |
| `issued` | string | Data wydania, np. `2025` albo `2025-03` |
| `page_label` | string | Numer strony wydrukowany w dokumencie, np. `14` |
| `pdf_page` | int | Indeks strony w pliku PDF (od 1). Może różnić się od `page_label` |
| `pdf_file` | string | Ścieżka pliku PDF w paczce bazy wiedzy |
| `text` | string | Treść fragmentu |
| `rects` | number[][] | Prostokąty podświetlenia `[x, y, w, h]`, ułamki 0–1 strony, początek w lewym górnym rogu |

### Przypisy i lista źródeł

Elementy list nie mają już chipów pod każdym punktem. Źródła są ponumerowane w kolejności czytania: jeden numer na stronę dokumentu (`doc_id` + `page_label`), więc kilka fragmentów z tej samej strony to jeden przypis.

- Przypis `[n]` to mała pigułka (20 dp, `bg-300`, cyfra `ink-200`) na końcu ostatniego elementu ciągu elementów z tej samej strony. W zwiniętej liście stoi na ostatnim widocznym elemencie.
- Pod odpowiedzią pigułka „Źródła · n” (przycisk `secondary`, ikona książki). Dotknięcie jej albo dowolnego przypisu rozwija listę: `n  {doc_short} · s. {page_label}  ›`, wiersz min. 44 dp. Wiersz otwiera [podgląd PDF](#podgląd-pdf-pełny-ekran) pierwszego cytowanego fragmentu tej strony.
- `quote` nie dostaje numeru: ma własny podpis pod oknem.
- Etykieta przypisu dla czytnika: „Źródło {n}”; wiersza listy: „Źródło {n}: {doc_title}, strona {page_label}. Otwórz.”

`SourceChip` (`▸ {doc_short}, s. {page_label}`) zostaje w narzędziach, które go używają (np. `cpr`).

---

## `steps`

**Cel:** numerowane kroki do wykonania po kolei.

```json
{
  "type": "steps",
  "title": "Teraz",
  "read_aloud": false,
  "items": [
    { "text": "…", "source_id": "poradnik-2025-s14-f3" }
  ]
}
```

Z wariantami (zamiast `items`):

```json
{
  "type": "steps",
  "title": "RKO",
  "read_aloud": true,
  "variants": [
    { "id": "adult", "label": "Dorosły", "items": [ { "text": "…", "source_id": "prc-2025-s12-f1" } ] },
    { "id": "child", "label": "Dziecko", "items": [ … ] },
    { "id": "infant", "label": "Niemowlę", "items": [ … ] }
  ]
}
```

| Pole | Wymagane | Opis |
|---|---|---|
| `title` | tak | Do 30 znaków |
| `items` | gdy brak `variants` | Elementy `{ text, source_id }` |
| `variants` | nie | `{ id, label, items }[]` |
| `read_aloud` | nie | Pokazuje przycisk „Czytaj na głos”. `true` w kartach ratunkowych |
| `items[].card_link` | nie | `{ label, card_id }`: przycisk pod krokiem, wstawia kartę jako nową wiadomość z tym samym wariantem. Tylko w kartach ratunkowych ([kontrakt](../04-dane/kontrakty-tresci.md#karta-ratunkowa)) |

```
RKO                                    Dorosły ⌄
1. Upewnij się, że Ty, poszkodowany
   i świadkowie jesteście bezpieczni.
2. …
5. Włącz w telefonie tryb głośnomówiący… [1]
( ⌄ Pokaż wszystkie kroki · 43 )
( 🔊 Czytaj na głos )  ( 📖 Źródła · 1 )
```

**Interakcje**

- Lista numerowana, bez odhaczania (kroki w nagłej sytuacji czyta się po kolei, nie odhacza). Przypis → rozwija listę źródeł.
- Lista dłuższa niż 5 kroków jest zwinięta do 5 z przyciskiem „Pokaż wszystkie kroki · n”; po rozwinięciu „Zwiń”.
- Przełącznik wariantu jest w nagłówku wiadomości ([warianty](#warianty)).
- „Czytaj na głos” (wiersz akcji pod odpowiedzią) czyta kroki od pierwszego, po jednym (synteza mowy systemu, `pl-PL`). Drugie dotknięcie: „Zatrzymaj czytanie”. Kroki nie są czytane bez tego przycisku, także w kartach ratunkowych (komendy `cpr` mówi instruktor sam, zob. [`cpr`](#cpr)).

**Stany:** brak polskiego głosu w systemie → przycisk ukryty. Pole `items[].done` z zapisanych starszych wiadomości jest ignorowane.

## `bullets`

**Cel:** lista bez kolejności (czego unikać, znaczenia sygnałów, fakty).

```json
{
  "type": "bullets",
  "title": "Czego nie robić",
  "items": [
    { "text": "…", "source_id": "poradnik-2025-s22-f1" }
  ]
}
```

| Pole | Wymagane | Opis |
|---|---|---|
| `title` | nie | Do 30 znaków |
| `items` | tak | `{ text, source_id }[]` |

```
Czego nie robić
•  Pierwszy punkt.
•  Drugi punkt. [1]
```

Starsza forma `"checkable": true` jest czytana jako [`todo`](#todo).

## `todo`

**Cel:** lista do odhaczenia, **tylko do przygotowań** (plecak, zapasy, przygotowanie domu). Nigdy w sytuacji zagrożenia: przy frazie ryzyka aplikacja pokazuje te same elementy jako `bullets`.

```json
{
  "type": "todo",
  "title": "Do plecaka",
  "items": [
    { "text": "Woda pitna", "source_id": "psp-plecak-s2-f1", "kit_id": "psp_woda" }
  ]
}
```

| Pole | Wymagane | Opis |
|---|---|---|
| `title` | nie | Do 30 znaków |
| `items` | tak | `{ text, source_id, kit_id? }[]` |
| `items[].kit_id` | nie | Identyfikator rzeczy w profilu (`supplies.kit[].id`) |

```
Do plecaka                         2 z 46
◉  ~~Regularnie przyjmowane leki~~
○  Środki przeciwbólowe
…
○  Rękawiczki nitrylowe [1]
( ⌄ Pokaż wszystkie · 46 )
```

**Wygląd:** okrągłe pole 20 dp (obrys `line-200` 1,5 dp); zaznaczone: wypełnione `ink-100` z `✓`, tekst `ink-300` przekreślony. Cały wiersz (min. 44 dp) przełącza stan; przypis nie przełącza. Licznik „{n} z {m}” po prawej od nagłówka. Lista dłuższa niż 8 jest zwinięta.

**Stan:** na razie zapisany w wiadomości (`done`); docelowo w profilu (`supplies.kit[]`: `id`, `checked`, `checkedAt`, [profil](ekran-4-profil.md)), tak by ta sama rzecz w innej wiadomości miała ten sam stan, a usunięcie czatu nie kasowało plecaka.

## `form`

**Cel:** zanim odpowie, asystent dopytuje 1–3 krótkimi pytaniami wyboru, gdy pytanie jest zbyt ogólne, by odpowiedzieć ze źródeł. Nigdy przy frazie ryzyka.

```json
{
  "type": "form",
  "questions": [
    { "text": "Kto mieszka w domu?", "multiple": true, "options": ["Dorośli", "Dzieci", "Osoby starsze", "Zwierzęta"] },
    { "text": "Czym ogrzewasz dom?", "options": ["Prąd", "Gaz", "Piec na drewno lub węgiel", "Miejskie"] }
  ]
}
```

| Pole | Wymagane | Opis |
|---|---|---|
| `questions` | tak | 1–3 pytania |
| `questions[].text` | tak | Do 90 znaków |
| `questions[].options` | tak | 2–5 opcji, każda do 40 znaków |
| `questions[].multiple` | nie | `true`: można wybrać kilka („Możesz wybrać kilka”) |

```
┌──────────────────────────────┐
│ Kto mieszka w domu?          │
│ Możesz wybrać kilka          │
│ (Dorośli)(Dzieci)(Starsi)…   │
│                              │
│ Czym ogrzewasz dom?          │
│ (Prąd)(Gaz)(Piec)(Miejskie)  │
│              Pomiń [Wyślij]  │
└──────────────────────────────┘
```

**Interakcje:** opcje to chipy (`BzChip`). „Wyślij” (aktywne, gdy jest co najmniej jedna odpowiedź) wysyła odpowiedzi jako wiadomość użytkownika: „Kto mieszka w domu: Dorośli, Dzieci. Czym ogrzewasz dom: Gaz.” i zamyka formularz. „Pomiń” tylko zamyka formularz. Zamknięty formularz znika; odpowiedzi zostają jako dymek użytkownika.

## `map`

**Cel:** najbliższy punkt z odległością i czasem, wejście do prowadzenia na mapie.

Model podaje tylko cel:

```json
{ "type": "map", "target": "nearest_shelter" }
```

| `target` | Rodzaje punktów ([punkty schronienia](../02-funkcje/03-mapa/punkty-schronienia.md)) |
|---|---|
| `nearest_shelter` | Schron, ukrycie, miejsce doraźnego schronienia |
| `nearest_hospital` | Szpital i SOR |
| `nearest_fire_station` | Jednostka PSP lub OSP |
| `nearest_water` | Punkt poboru wody |
| `nearest_pharmacy` | Apteka |

Aplikacja wylicza przy każdym wyświetleniu (nie zapisuje w wiadomości): `point { id, kind, name, address, lat, lon, confirmed, source, verified_at }` ([schemat punktów](../04-dane/kontrakty-tresci.md#baza-punktów)), `distance_m`, `duration_min`, `bearing_deg`, `straight_line` (bool), `from { lat, lon, at, last_known }`. Przelicza ponownie, gdy pozycja zmieni się o ponad 50 m.

```
┌ Najbliższy schron ───────────┐
│ ┌──────────────────────────┐ │
│ │  ●ty · · · · · ·  S      │ │
│ │     (mini mapa)          │ │
│ └──────────────────────────┘ │
│ S  Schron · ul. Długa 5      │
│    450 m · 6 min pieszo   ↗  │
│ ▸ KG PSP · zweryf. 03.2026   │
│ [         Prowadź          ] │
└──────────────────────────────┘
```

**Interakcje**

- Mini mapa jest nieinteraktywna (bez przesuwania i powiększania; nie przechwytuje przewijania czatu). Rysuje ją ten sam silnik mapy offline z wyłączonymi gestami. Pokazuje pozycję, punkt i linię prostą.
- Dotknięcie mini mapy → [Mapa](ekran-2-mapa.md) wyśrodkowana na punkcie, bez trasy.
- „Prowadź” → Mapa w trybie trasy: parametry `{ mode: "route", target_point_id }`.
- Chip źródła punktu → dymek ze źródłem i datą weryfikacji (punkt nie ma PDF).

**Stany**

| Stan | Wygląd |
|---|---|
| Punkt niepotwierdzony | Inny symbol, dopisek „niepotwierdzony” |
| Dane starsze niż próg | „Dane sprzed {n} mies.” |
| Poza mapą szczegółową | `straight_line = true`: „450 m w linii prostej · ok. 6 min”, bez trasy po ulicach |
| Brak świeżego GPS | Liczone od ostatniej znanej pozycji: „Od ostatniej pozycji ({HH:MM})” |
| Brak jakiejkolwiek pozycji | Bez odległości i czasu: „Nie znam twojej pozycji.” Przycisk „Pokaż na mapie” zamiast „Prowadź” |
| Brak punktów tego rodzaju w danych | Zamiast szablonu tekst: „Brak takich punktów w pobranych danych mapy.” |

## `animation`

**Cel:** krótka pętla pokazująca ruch (np. ułożenie dłoni przy RKO). Tylko w kartach ratunkowych.

```json
{
  "type": "animation",
  "variants": { "adult": "rko-adult-hands", "child": "rko-child-hands", "infant": "rko-infant-fingers" },
  "caption": "Ułożenie dłoni",
  "source_id": "prc-2025-s14-f2"
}
```

| Pole | Wymagane | Opis |
|---|---|---|
| `animation_id` | gdy brak `variants` | Plik `assets/animations/{animation_id}.gif` i pierwsza klatka `{animation_id}.png` |
| `variants` | nie | Mapa `id wariantu → animation_id` |
| `caption` | tak | Podpis i etykieta dla czytnika ekranu |
| `source_id` | tak | Źródło |

Format: GIF. Później Lottie: to samo pole, renderer wybiera po rozszerzeniu pliku.

```
┌ Ułożenie dłoni ──────────────┐
│ ┌──────────────────────────┐ │
│ │        (GIF, pętla)      │ │
│ └──────────────────────────┘ │
│ ▸ PRC/ERC 2025, s. 14        │
└──────────────────────────────┘
```

**Interakcje:** dotknięcie zatrzymuje i wznawia pętlę.

**Stany:** motyw kryzysowy albo ograniczenie ruchu → pierwsza klatka i przycisk „Odtwórz” (bez autostartu). Brak pliku → szablon ukryty, błąd w logu.

## `call`

**Cel:** jedno dotknięcie do 112, gdy sytuacja może zagrażać życiu.

```json
{ "type": "call" }
```

Brak pól od modelu. Aplikacja nie rysuje `call` w treści wiadomości: gdy ostatnia tura rozmowy (ostatnie pytanie i odpowiedzi na nie) ma frazę ryzyka (wiadomość z `risk` albo odpowiedź z `call`), ekran czatu przypina nad polem wpisywania jeden przycisk **Zadzwoń 112** (`sos`, 56 dp, pełna szerokość, ikona telefonu i napis wyśrodkowane). Przycisk jest widoczny już w trakcie generowania odpowiedzi. Po kolejnym pytaniu zostaje, dopóki trwa odpowiedź; jeśli nowa odpowiedź nie zaleca 112, znika 4 s po jej pojawieniu się (zwinięcie `durationBase`), a odpowiedź z ryzykiem przypina go od razu z powrotem. Po otwarciu rozmowy z historii stan wynika od razu z ostatniej tury.

```
( 📞  Zadzwoń 112 )
[ Zapytaj, co zrobić…        ↑ ]
```

**Interakcje:** dotknięcie → systemowe wybieranie 112. Bez kontaktów ICE, SMS, linii GPS i „Więcej” w czacie: pełny [Panel 2](panel-2-kontakt-ze-sluzbami.md) (SMS do bliskich, pozycja, 999/998/997) otwiera przycisk SOS.

## `signal`

**Cel:** zwrócić na siebie uwagę ratowników, gdy nie da się zadzwonić. Zachowanie według [sygnału ratunkowego](../02-funkcje/05-alarm/sygnal-ratunkowy.md).

```json
{ "type": "signal", "modes": ["sound", "flashlight", "screen"] }
```

| Pole | Wymagane | Opis |
|---|---|---|
| `modes` | nie | Podzbiór `sound`, `flashlight`, `screen`. Domyślnie wszystkie |

```
┌ Sygnał ratunkowy ────────────┐
│ [ Dźwięk              ( ○) ] │
│ [ Latarka SOS         ( ○) ] │
│ [ Stroboskop ekranu   ( ○) ] │
│ Przerwa: [0] [10 s] [30 s]   │
│ Działa 05:12 · bateria 61%   │
│ (−3% od włączenia)           │
└──────────────────────────────┘
```

**Interakcje i zasady**

- Każdy tryb włącza się osobno przełącznikiem.
- **Dźwięk:** dołączony plik `assets/sounds/signal-sos` w pętli, głośność odtwarzacza 1.0, gra także przy wyciszonym telefonie (iOS). Gdy system pozwala odczytać głośność i jest niższa niż maksimum: „Podgłośnij telefon do maksimum.”
- **Latarka SOS:** alfabet Morse'a `··· ––– ···`. Jednostka 200 ms: kropka 1, kreska 3, przerwa w literze 1, między literami 3, po całym SOS 7 jednostek, potem wybrana przerwa.
- **Stroboskop ekranu:** przed pierwszym włączeniem w sesji dialog ostrzegawczy. Pełny ekran (warstwa 3, pod SOS) w rytmie Morse'a jak latarka: biały = włączone, czerwony = wyłączone. Najwyżej 3 błyski na sekundę. Jasność ekranu na maksimum na czas stroboskopu, potem przywrócona. Dotknięcie w dowolnym miejscu wyłącza stroboskop.
- **Przerwa** między powtórzeniami: 0, 10 s, 30 s, 60 s. Domyślnie 10 s.
- Ekran nie gaśnie, dopóki działa którykolwiek tryb. Sygnały działają tylko z aplikacją na pierwszym planie.
- Licznik: czas działania, bieżąca bateria i spadek od włączenia.

**Stany:** brak latarki lub odmowa uprawnienia → przełącznik wyłączony, tekst „Latarka niedostępna.” Bateria ≤ 10% → toast „Bateria 10%. Sygnał szybko ją rozładuje.” (bez wyłączania).

## `quote`

**Cel:** pokazać oryginalny fragment źródła bez wychodzenia z czatu. Małe okno ze stroną PDF i podświetlonym (podkreślonym) cytowanym fragmentem.

```json
{ "type": "quote", "source_id": "poradnik-2025-s14-f3" }
```

| Pole | Wymagane | Opis |
|---|---|---|
| `source_id` | tak | Fragment do pokazania |
| `title` | nie | Domyślnie „Źródło” |

```
┌──────────────────────────────┐
│ …tekst strony…               │
│ ▓▓▓▓ cytowany fragment ▓▓▓▓  │
│ ▓▓▓▓▓▓▓▓▓▓▓                  │
│              ( ⤢ Powiększ )  │
└──────────────────────────────┘
ERC 2025, Pierwsza pomoc · s. 12
```

**Wygląd i zasady**

- Okno: wycinek strony `pdf_page` wokół sumy prostokątów `rects` z marginesem, pełna szerokość dymka, wysokość do 200 dp. Fragment podświetlony tokenem `highlight` (ochra `signal`) i podkreślony.
- Okno nie ma gestów (przewijanie czatu działa normalnie).
- Strona rysowana z pliku PDF albo z wcześniej wyrenderowanego obrazu strony w paczce bazy wiedzy. Wybór należy do buildera; kontrakt (`pdf_file`, `pdf_page`, `rects`) jest ten sam.
- Etykieta dla czytnika ekranu: pełny `text` fragmentu.

**Interakcje:** „Powiększ” (pigułka w prawym dolnym rogu okna, w środku strony) albo dotknięcie okna → podgląd PDF. Pod oknem podpis `{doc_short} · s. {page_label}`.

**Stany:** puste `rects` → górna część strony bez podświetlenia i pełny `text` pod oknem. Brak pliku PDF → sam `text` i dopisek „Nie mogę otworzyć pliku PDF. Pokazuję tekst fragmentu.”

## `cpr`

**Cel:** instruktor RKO w czacie, żeby ratownik patrzył na poszkodowanego, a nie na telefon. Zachowanie według [instruktora RKO](../02-funkcje/02-pierwsza-pomoc/instruktor-rko.md). Tylko w karcie RKO.

```json
{
  "type": "cpr",
  "source_id": "prc-2025-s14-f1",
  "rate_bpm": 110,
  "rescuer_change_s": 120,
  "variants": [
    { "id": "adult", "label": "Dorosły", "compressions": 30, "breaths": 2, "initial_breaths": 0, "breath_phase_s": 10 }
  ],
  "voice": {
    "compress": "Uciskaj",
    "breaths": "Dwa oddechy",
    "aed": "Niech ktoś przyniesie AED",
    "change": "Zmiana ratownika"
  },
  "aed_card_id": "aed"
}
```

Wartości `compressions`, `breaths`, `initial_breaths`, `breath_phase_s` dla każdego wariantu pochodzą z karty sprawdzonej przez ratownika według wytycznych PRC/ERC 2025. Builder nie wpisuje ich z pamięci. Wartości w przykładzie dotyczą tylko formatu.

| Pole | Opis |
|---|---|
| `rate_bpm` | Tempo metronomu, w zakresie 100–120 |
| `rescuer_change_s` | Co ile sekund przypomnienie o zmianie ratownika |
| `variants[]` | Proporcje dla wariantu: uciśnięcia i oddechy w cyklu, oddechy na start, czas fazy oddechów |
| `voice` | Teksty komend głosowych |
| `aed_card_id` | Karta z instrukcją AED wstawiana przyciskiem „Jak użyć AED” |

### Wygląd w wiadomości (przed startem)

```
┌ Instruktor RKO ──────────────┐
│ Dorosły · 110/min · 30:2     │
│ [  ▶ Zacznij uciskanie     ] │
│ ▸ PRC/ERC 2025, s. 14        │
└──────────────────────────────┘
```

### Wygląd przypięty (działa)

Po starcie instruktor przenosi się nad pole wiadomości i zostaje tam przy przewijaniu czatu. W wiadomości zostaje skrót „Instruktor RKO działa ↓”.

```
├──────────────────────────────┤
│ RKO · Dorosły      ● ● ● ●   │
│        UCISKAJ  17 / 30      │
│ Czas 03:42   Zmiana za 0:18  │
│ Poproś kogoś o AED     [ ✓ ] │
│ [Jak użyć AED]               │
│ [  Pauza  ]    [ Zakończ  ]  │
├──────────────────────────────┤
│ [ Opisz sytuację...    ] (➤) │
└──────────────────────────────┘
```

Z otwartą klawiaturą: jedna linia `UCISKAJ 17/30 · 03:42 · [Pauza]`.

### Zachowanie

- **Fazy cyklu:** `initial_breaths` (gdy > 0) → uciśnięcia `1…compressions` (licznik rośnie z każdym uderzeniem) → faza oddechów „2 ODDECHY” z odliczaniem `breath_phase_s` i przyciskiem „Dalej” (wcześniejszy powrót) → kolejny cykl. Licznik cykli rośnie.
- **Metronom:** odstęp `60000 / rate_bpm` ms, liczony od monotonicznego czasu startu (bez sumowania `setInterval`, żeby nie dryfował). Każde uderzenie: krótki dźwięk z dołączonego pliku i lekka wibracja. Kropki `● ● ● ●` pulsują w rytmie (to funkcja, nie ozdoba: działa też w motywie kryzysowym).
- **Głos:** komendy z `voice` tylko przy zmianie fazy, nie na każde uderzenie. Wyłączony głos w Ustawieniach → bez głosu, reszta bez zmian.
- **Stoper:** czas od pierwszego startu, liczony ze znaczników czasu (pauza go nie zatrzymuje). Po powrocie z tła pokazuje poprawny czas.
- **Zmiana ratownika:** co `rescuer_change_s`: komenda głosowa, mocna wibracja, baner na 5 s. Stale widoczne „Zmiana za m:ss”.
- **AED:** przy starcie komenda `voice.aed` i linia „Poproś kogoś o AED”. `✓` ukrywa przypomnienie; bez tego wraca ono przy każdej zmianie ratownika. „Jak użyć AED” wstawia do czatu kartę `aed_card_id` jako nową wiadomość; instruktor zostaje przypięty. Gdy pliku karty `aed_card_id` nie ma w assets (MVP: karta AED jest po MVP), przycisk jest ukryty.
- **Pauza:** zatrzymuje metronom i liczniki, stoper biegnie dalej. Przycisk zmienia się na „Wznów”.
- **Zakończ:** dialog aplikacji „Zakończyć RKO?” z przyciskami „Zakończ RKO” i „Wróć”. Po zakończeniu w wiadomości podsumowanie „Zakończono · czas 12:05 · 9 cykli” i przycisk „Zacznij od nowa”.
- **Ekran nie gaśnie** od startu do zakończenia (także w pauzie).
- **Jedna sesja w aplikacji.** Start drugiego `cpr` przewija do przypiętego i pokazuje toast „Instruktor RKO już działa.” Sesja trwa po zmianie czatu i po wyjściu z ekranu czatu (wtedy u góry [wskaźnik RKO](README.md#elementy-globalne)). Systemowy Wstecz nie kończy sesji.
- **Zmiana wariantu w trakcie:** licznik zaczyna nowy cykl z proporcjami nowego wariantu, stoper biegnie dalej.

**Stany:** przed startem · działa · pauza · zakończony. Brak polskiego głosu w systemie → jednorazowy baner „Głos niedostępny na tym telefonie. Instruktor działa z dźwiękiem i wibracją.”

---

## Podgląd PDF (pełny ekran)

`PdfViewer`. Otwierany z chipu źródła albo z „Powiększ” w `quote`. Parametry: `{ source_id }`.

```
┌──────────────────────────────┐
│(✕) Poradnik bezp. s. 14 (SOS)│
│                              │
│  ┌────────────────────────┐  │
│  │ …                      │  │
│  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓      │  │
│  │ ▓▓▓▓▓▓▓▓ (fragment)    │  │
│  │ …                      │  │
│  └────────────────────────┘  │
│                              │
│ RCB, MON, MSWiA · wyd. 2025  │
│ s. 14 (str. pliku 16 z 96)   │
│         [ ‹ ]   [ › ]        │
└──────────────────────────────┘
```

| Element | Zachowanie |
|---|---|
| `✕` (miejsce przycisku Wstecz) | Zamyka podgląd, wraca do czatu w tym samym miejscu przewinięcia. Systemowy Wstecz działa tak samo |
| Strona | Otwiera się na `pdf_page`, przewinięta tak, żeby podświetlenie było widoczne. Powiększanie palcami, przesuwanie |
| Podświetlenie | `rects` tylko na stronie docelowej |
| `‹` `›` | Poprzednia / następna strona |
| Stopka | Wydawca, data wydania, numer strony z dokumentu i strona pliku |
| SOS | Widoczny jak na każdym ekranie |

**Stany:** brak pliku albo błędna suma kontrolna → tekst fragmentu i „Nie mogę otworzyć pliku PDF. Pokazuję tekst fragmentu.” Paczka bazy wiedzy niepobrana (np. karta ratunkowa zaraz po instalacji) → to samo.

---

## Przykład: karta RKO jako wiadomość

Wstawiana bez modelu po frazie „nie oddycha” albo po szybkim przycisku „Ktoś nie oddycha”.

```json
{
  "role": "assistant",
  "origin": "rescue_card",
  "card_id": "rko",
  "selected_variant": "adult",
  "panels": [
    { "type": "call" },
    { "type": "cpr", "source_id": "prc-2025-s14-f1", … },
    { "type": "steps", "title": "RKO", "read_aloud": true, "variants": [ … ] },
    { "type": "animation", "caption": "Ułożenie dłoni", "variants": { … }, "source_id": "prc-2025-s14-f2" }
  ]
}
```

`call` przypina „Zadzwoń 112” nad polem wpisywania; instruktor `cpr` stoi przed listą kroków, żeby „Start” nie był pod 43 krokami. Pod każdą wiadomością `rescue_card` aplikacja dopisuje: „Ta instrukcja nie zastępuje połączenia z 112.”

## Kryteria akceptacji

- [ ] Odpowiedź modelu z nieznanym `type`, z `animation` albo z `cpr` jest odrzucana na etapie walidacji.
- [ ] Element `steps` z nieistniejącym `source_id` nie jest wyświetlany.
- [ ] Gdy po walidacji nie zostaje żaden szablon treści, wiadomość pokazuje szablony `quote` z etykietą „Tryb bez AI: fragmenty źródeł”.
- [ ] Każda wiadomość `rescue_card` zaczyna się od `call` (przypięte „Zadzwoń 112” nad polem wpisywania) i kończy tekstem „Ta instrukcja nie zastępuje połączenia z 112.”
- [ ] Pytanie zawierające „pożar” dostaje `call`, nawet gdy model go nie zwrócił.
- [ ] Rozmowa bez frazy ryzyka nie pokazuje przycisku „Zadzwoń 112”.
- [ ] Po odpowiedzi z ryzykiem i kolejnej odpowiedzi bez niego przycisk „Zadzwoń 112” znika po 4 s; kolejna odpowiedź z ryzykiem pokazuje go od razu.
- [ ] Karta RKO pokazuje 5 kroków i „Pokaż wszystkie kroki · 43”; żaden krok nie ma pola odhaczenia.
- [ ] Przypis i pigułka „Źródła · n” rozwijają listę źródeł; wiersz listy otwiera podgląd PDF.
- [ ] `todo` przy frazie ryzyka wyświetla się jako `bullets`; `form` przy frazie ryzyka nie pojawia się.
- [ ] „Wyślij” w `form` wysyła odpowiedzi jako wiadomość użytkownika i chowa formularz.
- [ ] Zmiana wariantu na „Niemowlę” przełącza naraz `steps`, `animation` i `cpr` w tej samej wiadomości.
- [ ] Stan odhaczenia `todo` przetrwa zamknięcie i ponowne otwarcie aplikacji.
- [ ] Wiersz listy źródeł otwiera podgląd PDF na `pdf_page` z podświetlonym fragmentem; `✕` wraca do czatu w to samo miejsce.
- [ ] `quote` pokazuje wycinek strony z podświetleniem; przewijanie palcem po oknie przewija czat.
- [ ] `map` bez pozycji GPS nie pokazuje odległości, tylko „Nie znam twojej pozycji.”
- [ ] „Prowadź” otwiera Mapę w trybie trasy do tego samego punktu.
- [ ] Metronom `cpr` po 10 minutach różni się od zegara o mniej niż 1 uderzenie.
- [ ] Przypięty `cpr` zostaje widoczny przy przewinięciu czatu na samą górę.
- [ ] „Zakończ” w `cpr` wymaga potwierdzenia; systemowy Wstecz nie kończy sesji.
- [ ] Ekran nie gaśnie przez 5 minut działania `cpr` i `signal`.
- [ ] Stroboskop nie włącza się bez potwierdzenia ostrzeżenia i nie przekracza 3 błysków na sekundę; SOS jest widoczny nad stroboskopem.
- [ ] Latarka nadaje `··· ––– ···` z jednostką 200 ms.
- [ ] Karta RKO działa w trybie samolotowym na świeżej instalacji bez pobranych paczek.

## Powiązane funkcje

- [Panele w czacie](../02-funkcje/01-czat/panele.md)
- [Czat z Bezpiecznikiem](../02-funkcje/01-czat/czat.md)
- [Odpowiedzi tylko ze źródeł](../02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md)
- [Karty ratunkowe](../02-funkcje/02-pierwsza-pomoc/karty-ratunkowe.md)
- [Instruktor RKO](../02-funkcje/02-pierwsza-pomoc/instruktor-rko.md)
- [Punkty schronienia i pomocy](../02-funkcje/03-mapa/punkty-schronienia.md)
- [Trasy](../02-funkcje/03-mapa/trasy.md)
- [Panel alarmowy](../02-funkcje/05-alarm/panel-alarmowy.md)
- [Sygnał ratunkowy](../02-funkcje/05-alarm/sygnal-ratunkowy.md)
- [Lokalne AI](../05-technologia/lokalne-ai.md)
- [Źródła wiedzy](../04-dane/zrodla-wiedzy.md)
