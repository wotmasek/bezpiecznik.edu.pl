# Ekran 1 · Czat

`ChatScreen`. Ekran główny aplikacji. Elementy globalne (wyspa, SOS, warstwy): [README](README.md#elementy-globalne). Szablony odpowiedzi: [szablony w czacie](szablony-czatu.md).

## Cel

Użytkownik opisuje sytuację własnymi słowami albo dotyka szybkiego przycisku i od razu dostaje instrukcję złożoną z szablonów, ze źródłem przy każdym kroku. W zagrożeniu życia karta ratunkowa pojawia się natychmiast, bez modelu AI.

## Wejście / wyjście

| Wejście | Stan ekranu |
|---|---|
| Start aplikacji (zimny start), koniec E0 | Nowy pusty czat |
| P1 → „Nowy czat” | Nowy pusty czat |
| P1 → czat z listy | Ten czat, przewinięty na koniec |
| Powrót z E2, E3, PV, z tła | Ten sam czat, to samo miejsce przewinięcia |

| Wyjście | Dokąd |
|---|---|
| `≡` na wyspie, przesunięcie od lewej krawędzi | P1 Panel boczny |
| `▦` na wyspie | E2 Mapa |
| SOS dotknięcie / przytrzymanie | P2 / systemowe wybieranie 112 |
| `map`: „Prowadź” / dotknięcie mini mapy | E2 w trybie trasy / E2 wyśrodkowana na punkcie |
| Wiersz listy źródeł, `quote` → „Powiększ” | PV Podgląd PDF |
| `call`: „Zadzwoń 112” (numery w „Więcej”) / „Powiadom bliskich” | Systemowe wybieranie numeru / systemowe okno SMS |

## Układ

Pusty czat:

```
┌──────────────────────────────┐
│[≡ ▦]                    (SOS)│
│                              │
│        Co się dzieje?        │
│                              │
│ ┌────────────┐┌────────────┐ │
│ │ Ktoś nie   ││ Brak prądu │ │
│ │ oddycha    ││            │ │
│ └────────────┘└────────────┘ │
│ ┌────────────┐┌────────────┐ │
│ │ Alarm /    ││ Ewakuacja  │ │
│ │ schron     ││            │ │
│ └────────────┘└────────────┘ │
│                              │
│  Działa bez internetu.       │
│  Nie zastępuje 112.          │
│                              │
│ [ Opisz sytuację...    ] (➤) │
└──────────────────────────────┘
```

Odpowiedź (`origin: ai`):

```
┌──────────────────────────────┐
│[≡ ▦]                    (SOS)│
│      ┌─────────────────────┐ │
│      │ Blackout, niemowlę, │ │
│      │ 7. piętro           │ │
│      └─────────────────────┘ │
│ ┌ Teraz ───────────────────┐ │
│ │┃1. …                  [ ]│ │
│ │┃   ▸ Poradnik bezp., s.14│ │
│ │ 2. …                  [✓]│ │
│ │    ▸ Nim nadejdzie…, s. 9│ │
│ └──────────────────────────┘ │
│ ┌ Najbliższy schron ───────┐ │
│ │ (mini mapa)              │ │
│ │ 450 m · 6 min pieszo  ↗  │ │
│ │ ▸ KG PSP      [ Prowadź ]│ │
│ └──────────────────────────┘ │
│ [ Opisz sytuację...    ] (➤) │
└──────────────────────────────┘
```

AI generuje:

```
┌──────────────────────────────┐
│[≡ ▦]                    (SOS)│
│      ┌─────────────────────┐ │
│      │ Jak przechować      │ │
│      │ insulinę bez prądu? │ │
│      └─────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │ Szukam w źródłach…       │ │
│ │ ░░░░░░░░░░░░░░░░         │ │
│ │ ░░░░░░░░░░               │ │
│ └──────────────────────────┘ │
│                              │
│(■) [ Opisz sytuację... ] (➤) │
└──────────────────────────────┘
```

Karta RKO z przypiętym instruktorem (`origin: rescue_card`):

```
┌──────────────────────────────┐
│[≡ ▦]                    (SOS)│
│          ┌─────────────────┐ │
│          │ Ktoś nie oddycha│ │
│          └─────────────────┘ │
│ Karta ratunkowa              │
│ ┌ Wezwij pomoc ────────────┐ │
│ │ [     Zadzwoń 112      ] │ │
│ │ [  Powiadom bliskich   ] │ │
│ │ Więcej                 ▾ │ │
│ └──────────────────────────┘ │
│ ┌ RKO ─────────────────────┐ │
│ │[Dorosły][Dziecko][Niem.] │ │
│ │┃1. …                  [ ]│ │
├──────────────────────────────┤
│ RKO · Dorosły      ● ● ● ●   │
│        UCISKAJ  17 / 30      │
│ Czas 03:42   Zmiana za 0:18  │
│ [  Pauza  ]    [ Zakończ  ]  │
├──────────────────────────────┤
│ [ Opisz sytuację...    ] (➤) │
└──────────────────────────────┘
```

Wiadomości użytkownika: dymek po prawej. Odpowiedzi: szablony na całą szerokość, po lewej. Nad listą wiadomości jest margines na wyspę i SOS (treść przewija się pod nimi; pod elementami pływającymi delikatny gradient tła).

## Elementy

| Element | Zachowanie |
|---|---|
| Wyspa `NavIsland`, SOS | Jak w [README](README.md#elementy-globalne) |
| Nagłówek pustego czatu | „Co się dzieje?” Tylko w pustym czacie |
| Szybkie przyciski `QuickActions` | Siatka 2 × 2, każdy min. 64 dp wysokości. Dotknięcie = wysłanie etykiety jako wiadomości użytkownika i odpowiedź bez AI (tabela niżej). Znikają po pierwszej wiadomości. *Zestaw domyślny, do potwierdzenia* |
| Lista wiadomości `MessageList` | Wirtualizowana. Po nowej odpowiedzi przewija do **początku** odpowiedzi, nie na dół. Gdy użytkownik czyta wyżej, nie przewija, tylko pokazuje przycisk „↓ Nowa odpowiedź” |
| Dymek użytkownika | Tekst jak wpisany. Przytrzymanie → „Kopiuj” |
| Odpowiedź asystenta | Etykieta według `origin`, potem szablony. Szczegóły: [szablony](szablony-czatu.md) |
| Przypięty `cpr` | Nad polem wiadomości, gdy działa instruktor RKO. Szczegóły: [`cpr`](szablony-czatu.md#cpr) |
| Pole wiadomości `ChatInput` | Wiele linii, rośnie do 4 linii, potem przewija. Limit 1000 znaków. Enter = nowa linia |
| Wyślij `(➤)` | Nieaktywny, gdy pole puste lub same spacje. Widoczny zawsze, także w trakcie generowania: wysłanie niepustej wiadomości przerywa bieżące generowanie i uruchamia przepływ od kroku 2 |
| Zatrzymaj `(■)` | Tylko w trakcie generowania: mały przycisk po lewej stronie pola wiadomości (cel dotyku 48 dp). Przerywa generowanie bez wysyłania |

### Szybkie przyciski

| Przycisk | Odpowiedź (`origin`) |
|---|---|
| Ktoś nie oddycha | Karta RKO (`rescue_card`, `card_id: rko`) |
| Brak prądu | Plan 72 h, wariant blackout, z profilu (`rules`) |
| Alarm / schron | Plan 72 h, wariant alarm i schronienie (`rules`) + `map` `nearest_shelter` |
| Ewakuacja | Plan 72 h, wariant ewakuacja (`rules`) + plecak `todo` + `map` `nearest_shelter` |

### Przepływ po wysłaniu wiadomości

1. Pierwsza wiadomość w pustym czacie zapisuje czat (wcześniej czat nie istnieje w bazie) i ustawia tytuł.
2. **Wykrycie zagrożenia życia.** Dopasowanie przybliżone fraz kart ratunkowych (odporne na literówki). Trafienie → wiadomość karty w mniej niż 1 s, bez modelu. Koniec przepływu. Kilka trafień → karta o najwyższym priorytecie (kolejność tabeli w [kartach ratunkowych](../02-funkcje/02-pierwsza-pomoc/karty-ratunkowe.md)), a pod nią przyciski pozostałych, np. „Też: Krwotok”.
3. **Intencje, plan i plecak.** Frazy intencji („schron”, „gdzie iść”, „szpital”, „woda”; [`intents.json`](../04-dane/kontrakty-tresci.md#intencje)) → szablon `map` z reguł (`rules`, pole `intent`), bez modelu i bez progu. Frazy typu „plan 72 h”, „co przygotować”, „plecak” → odpowiedź z reguł i profilu (`rules`), bez modelu.
4. **Wyszukiwanie** w bazie wiedzy. Poniżej progu pewności → `refusal` z tekstem z [odpowiedzi tylko ze źródeł](../02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md).
5. **Model** (gdy działa) dostaje fragmenty i kontekst ([czat](../02-funkcje/01-czat/czat.md#kontekst-przekazywany-asystentowi)). Do modelu idzie bieżące pytanie i poprzednie pytanie w tym czacie (*domyślne, do potwierdzenia*). Model zwraca jeden obiekt JSON ([format](../05-technologia/lokalne-ai.md#format-odpowiedzi)); w trakcie generowania widać szkielet, a wszystkie szablony pojawiają się naraz po walidacji.
6. **Tryb bez AI:** zamiast modelu wiadomość `no_ai` z szablonami `quote` (do 3 najlepszych fragmentów).
7. Aplikacja dodaje `call`, gdy sytuacja może zagrażać życiu ([reguła 2](szablony-czatu.md#reguły)).

W trakcie generowania przycisk `(➤)` zostaje aktywny obok `(■)`. Niepusta wiadomość wysłana w trakcie generowania przerywa bieżące generowanie (status `stopped`, dopisek „Przerwano.”) i przechodzi przepływ od kroku 2. Dzięki temu fraza zagrożenia życia nigdy nie czeka na model.

### Dane

| Encja | Pola |
|---|---|
| `Chat` | `id`, `title`, `created_at`, `updated_at`, `messages[]` |
| `Message` | jak w [szablonach](szablony-czatu.md#wiadomość-asystenta); wiadomość użytkownika: `id`, `role: "user"`, `text`, `created_at` |

- Zapis lokalny, w tej samej bazie użytkownika co profil (szyfrowanie po MVP). Nic nie opuszcza telefonu bez twojej akcji.
- `title` = pierwsza wiadomość użytkownika: obcięte spacje, zwinięte białe znaki, przycięta do 40 znaków na granicy słowa, z „…” gdy przycięta. Bez AI. Nie zmienia się później.
- `updated_at` = czas ostatniej wiadomości. Według niego sortuje P1.
- Zimny start zawsze otwiera nowy pusty czat. Powrót z tła zostawia bieżący czat.

## Stany

| Stan | Zachowanie |
|---|---|
| Pusty | Nagłówek, szybkie przyciski, notka, pole wiadomości. Czat nie jest zapisany |
| Model się ładuje (pierwsze pytanie po starcie) | Zamiast „Szukam w źródłach…”: „Uruchamiam model. Pierwsza odpowiedź trwa dłużej.” Karty i reguły działają bez czekania |
| AI generuje | Szkielet odpowiedzi z fazą „Szukam w źródłach…”, potem „Układam odpowiedź…”. Przyciski `(■)` Zatrzymaj (po lewej) i `(➤)` Wyślij. Brak odpowiedzi modelu po 20 s → odpowiedź jak w trybie bez AI z dopiskiem „Model nie odpowiedział na czas. Pokazuję fragmenty źródeł.” (*20 s domyślne, do potwierdzenia*) |
| Zatrzymano | Wiadomość ze statusem `stopped` bez szablonów (odpowiedź niezwalidowana jest odrzucana), dopisek „Przerwano.” |
| Tryb bez AI | Cienki baner u góry listy: „Tryb bez AI. Pokazuję fragmenty źródeł.” z powodem. Dotknięcie → E3 (sekcja AI i bateria) |
| Offline | Bez zmian w działaniu. Bez osobnego wskaźnika |
| Brak GPS | Kontekst bez pozycji. Szablony `map` i `call` pokazują własne stany. Bez banera |
| Niska bateria (≤ `settings.lowBatteryPct`, domyślnie 20%) | Gdy w E3 ustawiono tryb automatyczny: przejście w tryb bez AI i jednorazowy toast |
| Odmowa (`refusal`) | Spokojny komponent `NoSource` z jednym z dwóch tekstów: „brak w źródłach” albo „poza tematem”. Obie bez 112; 112 pojawia się tylko przez szablon `call` przy frazie ryzyka ([odpowiedzi tylko ze źródeł](../02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md#odmowa)) |
| Błąd: baza wiedzy niepobrana lub uszkodzona | Działają karty ratunkowe i szybkie przyciski. Inne pytania → dymek „Baza wiedzy nie jest pobrana. Działają karty ratunkowe i szybkie przyciski.” |
| Błąd: model się nie załadował | Trwałe przejście w tryb bez AI na tę sesję, baner z powodem |
| Błąd: zapis rozmowy | Toast „Nie mogę zapisać rozmowy. Brak miejsca w telefonie.” Rozmowa działa dalej w pamięci |

## Teksty

| Miejsce | Tekst |
|---|---|
| Nagłówek pustego czatu | Co się dzieje? |
| Szybkie przyciski | Ktoś nie oddycha · Brak prądu · Alarm / schron · Ewakuacja |
| Notka pustego czatu | Działa bez internetu. Nie zastępuje 112. |
| Podpowiedź w polu | Opisz sytuację… |
| Etykieta przycisku wysyłania | Wyślij |
| Etykieta przycisku zatrzymania | Zatrzymaj |
| Faza wyszukiwania | Szukam w źródłach… |
| Faza generowania | Układam odpowiedź… |
| Ładowanie modelu | Uruchamiam model. Pierwsza odpowiedź trwa dłużej. |
| Limit czasu | Model nie odpowiedział na czas. Pokazuję fragmenty źródeł. |
| Przerwanie | Przerwano. |
| Przycisk nowej odpowiedzi | ↓ Nowa odpowiedź |
| Baner bez AI | Tryb bez AI. Pokazuję fragmenty źródeł. |
| Powód: bateria | Niski poziom baterii. |
| Powód: model | Model się nie załadował. |
| Powód: ustawienia | Wyłączone w ustawieniach. |
| Toast baterii | Bateria {n}%. Przełączam na tryb bez AI, żeby oszczędzać energię. |
| Odmowa: brak w źródłach | Nie wiem. Moje źródła tego nie opisują. Zapytaj lekarza, farmaceutę albo właściwą instytucję. |
| Odmowa: poza tematem | Pomagam tylko w sytuacjach kryzysowych i bezpieczeństwie. Tego nie opisują moje źródła. |
| Brak bazy wiedzy | Baza wiedzy nie jest pobrana. Działają karty ratunkowe i szybkie przyciski. |
| Dopisek karty ratunkowej | Ta instrukcja nie zastępuje połączenia z 112. |
| Etykieta `rescue_card` | Karta ratunkowa |
| Etykieta `rules` | Z twojego profilu |
| Przycisk dodatkowej karty | Też: {nazwa karty} |
| Błąd zapisu | Nie mogę zapisać rozmowy. Brak miejsca w telefonie. |
| Kopiowanie | Kopiuj |

## Kryteria akceptacji

- [ ] Zimny start otwiera pusty czat z „Co się dzieje?” i czterema szybkimi przyciskami.
- [ ] Pusty czat, z którego wyjdziesz bez wysłania wiadomości, nie pojawia się w P1.
- [ ] Po pierwszej wiadomości czat jest w P1 z tytułem równym tej wiadomości (przyciętej do 40 znaków).
- [ ] „Ktoś nie oddycha” wstawia kartę RKO w mniej niż 1 s w trybie samolotowym, z wyłączonym modelem.
- [ ] Wpisanie „nie oddyhca” (literówka) wstawia kartę RKO bez udziału modelu.
- [ ] W trakcie generowania widoczne są `(■)` po lewej stronie pola i aktywny `(➤)`; nie trzeba najpierw zatrzymywać generowania.
- [ ] Fraza zagrożenia życia wysłana w trakcie generowania przerywa generowanie i od razu wstawia kartę.
- [ ] W trakcie generowania widać szkielet; szablony odpowiedzi modelu pojawiają się naraz, po walidacji.
- [ ] Pytanie spoza tematu („Jak naprawić agregat?”) daje odmowę „poza tematem” (bez 112), a model nie jest uruchamiany.
- [ ] Po nowej odpowiedzi widoczny jest jej pierwszy szablon (lista nie przewija się na sam dół).
- [ ] Przy baterii ≤ `settings.lowBatteryPct` i trybie automatycznym kolejne pytanie dostaje odpowiedź `no_ai` z banerem.
- [ ] Przypięty instruktor RKO jest widoczny przy przewijaniu i przy otwartej klawiaturze (wersja jednoliniowa).
- [ ] SOS i wyspa nie przesuwają się po otwarciu klawiatury i nie są niczym zasłonięte.
- [ ] Powrót z Mapy przywraca to samo miejsce przewinięcia.
- [ ] Czytnik ekranu odczytuje szybkie przyciski, wyślij, menu, mapę i SOS z etykietami.

## Powiązane funkcje

- [Czat z Bezpiecznikiem](../02-funkcje/01-czat/czat.md)
- [Panele w czacie](../02-funkcje/01-czat/panele.md)
- [Odpowiedzi tylko ze źródeł](../02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md)
- [Karty ratunkowe](../02-funkcje/02-pierwsza-pomoc/karty-ratunkowe.md)
- [Instruktor RKO](../02-funkcje/02-pierwsza-pomoc/instruktor-rko.md)
- [Plan 72 h](../02-funkcje/04-profil-i-plan/plan-72h.md)
- [Plecak ewakuacyjny](../02-funkcje/04-profil-i-plan/plecak-ewakuacyjny.md)
- [Profil domu](../02-funkcje/04-profil-i-plan/profil-domu.md)
- [Przycisk SOS](../02-funkcje/05-alarm/przycisk-sos.md)
- [Lokalne AI](../05-technologia/lokalne-ai.md)
