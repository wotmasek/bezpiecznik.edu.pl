# Mapa komponentów

Które komponenty składają każdy ekran ze specyfikacji (`03-ekrany`). Aplikacja powstaje we **Flutterze**: komponenty React w tym systemie są wzorcem wyglądu, stanów i wymiarów, a tokeny przenosi się do `ThemeData` / `ThemeExtension`. Nazwy komponentów są takie same jak w specyfikacji tam, gdzie specyfikacja je nadaje.

Priorytet demo: **●** występuje w scenariuszu pokazu · **○** potrzebne w aplikacji, poza sceną.

## Elementy globalne (`RootOverlay`)

| Komponent | Spec | Demo | Uwagi |
| --- | --- | --- | --- |
| `Logo` | znak B+ (opcjonalnie z nazwą) | ● | Na górze panelu bocznego sam znak, 36 px |
| `NavIsland` | wyspa: menu + mapa | ● | Pigułka z dwoma przyciskami 48 dp |
| `FloatingButton` | Wstecz / Zamknij | ● | Koło 48 dp, ta sama wysokość co wyspa |
| `SosButton` | SOS na każdym ekranie | ● | 56 dp, czerwony; przytrzymanie 800 ms wypełnia obwódkę |
| `CprIndicator` | wskaźnik RKO poza czatem | ○ | Na środku u góry innych ekranów |
| `Toast` | komunikaty | ○ | Zawsze na dole, nad polem wiadomości |
| `Dialog` | potwierdzenia | ○ | Aplikacyjny, nie systemowy (pod SOS) |
| `Sheet` | arkusze od dołu | ● | Wspólny dla mapy, P2, wyborów w ustawieniach; maks. 70% (P2: 92%) |

## E1 · Czat

| Komponent | Spec | Demo |
| --- | --- | --- |
| `QuickActions` | 4 szybkie przyciski, 2 × 2, min. 64 dp | ● |
| `Message` (user) | dymek po prawej | ● |
| `AnswerLabel` | etykieta wg `origin`: Karta ratunkowa · Z twojego profilu · Tryb bez AI | ● |
| `Thinking` | fazy „Szukam w źródłach…” → „Układam odpowiedź…” + szkielet | ● |
| `Composer` | rośnie do 4 linii, Enter = nowa linia, Wyślij ↔ Zatrzymaj | ● |
| `Notice` (wariant `banner`) | baner trybu bez AI z powodem | ○ |
| `JumpToLatest` | pigułka „↓ Nowa odpowiedź” | ○ |
| `NoSource` | odmowa (`refusal`) | ● |

### Szablony odpowiedzi (`TemplateRenderer`)

| Szablon | Komponent | Demo |
| --- | --- | --- |
| odpowiedź jako tekst (redesign 2026-11, styl ChatGPT) | `MdHeading`, `MdListItem`, `FootnoteMark`, wiersz akcji „Czytaj na głos” + „Źródła · n”, rozwijana lista źródeł. `PanelCard` tylko w narzędziach (`map`, `cpr`, `signal`) | ● |
| `steps` | `StepsPanel`: lista numerowana bez odhaczania, przypisy, zwijanie powyżej 5 kroków („Pokaż wszystkie kroki · n”) | ● |
| `bullets` | `BulletsPanel`: lista punktowana, przypisy | ● |
| `todo` | `TodoPanel`: okrągłe pola jak w ChatGPT, przekreślenie, licznik „n z m”; tylko przygotowania | ● |
| `form` | `FormPanel`: 1–3 pytania wyboru (`BzChip`), „Pomiń” / „Wyślij” → odpowiedzi jako wiadomość użytkownika | ● |
| `quote` | `QuotePanel`: wycinek strony z podświetleniem, „Powiększ” w rogu okna, podpis źródła pod oknem | ● |
| `map` | `MapCard`: mini mapa, odległość, kierunek, źródło punktu, „Prowadź” | ● |
| `call` | jeden przycisk **Zadzwoń 112** (`sos`, 56 dp) przypięty nad polem wpisywania na czas rozmowy z frazą ryzyka; w treści wiadomości nie ma karty | ● |
| `signal` | `SignalPanel`: dźwięk, latarka SOS, stroboskop, przerwa, licznik | ● |
| `cpr` | `CprCard` (przed startem) + `CprPinned` (działa) | ● |
| `animation` | `AnimationPanel`: pętla GIF, w ograniczonym ruchu pierwsza klatka + „Odtwórz” | ● |
| przypis / źródła | `FootnoteMark` `[n]` (jeden numer na stronę dokumentu) + pigułka „Źródła · n”; `SourceChip` zostaje w `cpr` | ● |
| przełącznik wariantu | `VariantChip`: cichy chip „Dorosły ⌄” w nagłówku wiadomości, menu z `✓` | ● |

## PV · Podgląd PDF

`PdfHeader` (Zamknij, tytuł, SOS) · strona z podświetleniem (`QuotePanel` w trybie pełnym) · stopka z wydawcą i stronami · `Button` ‹ ›. Demo: ●.

## E2 · Mapa

| Komponent | Spec | Demo |
| --- | --- | --- |
| `MapMarker` | symbol rodzaju; potwierdzony (pełny) / niepotwierdzony (pusty, przerywany, „?”); grupa z liczbą | ● |
| `UserDot` | kropka z wachlarzem kierunku, okrąg dokładności, szara z wiekiem bez fixu | ● |
| `FloatingButton` | ◎ wyśrodkuj | ● |
| `Button` „Warstwy”, „Najbliższy schron” | | ● |
| `DetailIndicator` | ● Mapa szczegółowa / ○ Poza mapą szczegółową + Pobierz | ○ |
| `PointSheet` | karta punktu w arkuszu | ● |
| `NearestList` | 3 najbliższe schronienia ze strzałkami | ● |
| `LayersSheet` | przełączniki warstw (`ListRow` + `Switch`) | ○ |
| `RouteBanner` | następny manewr u góry | ● |
| `RouteBar` | pozostała odległość, Kroki, Kompas, Zakończ | ● |
| `CompassView` | pełnoekranowa strzałka, odległość, kierunek świata, współrzędne | ● |
| `Notice` (wariant `bar`) | brak GPS, kalibracja, brak punktów, niska bateria | ○ |

## P1 · Panel boczny

`ChatDrawer` w stylu panelu ChatGPT: logo na górze, bez ramek, „Nowy czat” jako wiersz z ikoną, sekcje Dziś / Wczoraj / data, wiersze z samym tytułem (bez godzin), bieżący czat zaznaczony tłem, notka o prywatności, wiersz Ustawienia. Demo: ○.

## P2 · Kontakt ze służbami

`CallPanel` (`sheet`): dwa przyciski po 80 px — **Zadzwoń 112** i **Powiadom bliskich** (SMS z lokalizacją). Demo: ●.

## E0 · Pierwsze uruchomienie

`StepHeader` (Krok n z 4, postęp) · `Notice` (wariant `warning`: „Nie zastępuje 112”) · `PackageRow` (pole wyboru, nazwa, rozmiar, stan, pasek postępu, Ponów) · `ListRow` + `Switch` (Tylko przez Wi-Fi) · `Button`. Demo: ○.

## E3 · Ustawienia

`SectionHeader` · `ListRow` (etykieta, wartość, strzałka) · `Switch` · `Segmented` (rozmiar tekstu) · `PackageRow` · `Button` `danger` · `Sheet` z listą opcji · `Dialog`. Demo: ○.

## E4 · Profil

`StepHeader` · `QuestionStep` (Tak / Nie / Pomiń) · `TextField` · `ChoiceChips` (jedno- i wielokrotny wybór) · `Segmented` (trójstanowe Tak / Nie) · `ListRow` z podsumowaniem sekcji · `Toast` z „Cofnij”. Demo: ○.

## Odstępstwa od specyfikacji (rozstrzygnięte 2026-11-21)

1. **Odmowa a 112.** Spec: odmowa brzmi „Nie wiem. Moje źródła tego nie opisują. Zadzwoń pod 112.”, także w scenariuszu pokazu (pytanie o dawkę leku dla psa). Decyzja z 21.11 w tym systemie: 112 tylko przy zagrożeniu życia, odmowa to spokojny `NoSource` z sugestią, gdzie szukać. Do zmiany w `ekran-1-czat.md`, `szablony-czatu.md` i `scenariusz-pokazu.md`.
   **Rozstrzygnięcie:** 112 tylko przy możliwym zagrożeniu życia. Odmowa „brak w źródłach” jest spokojna, bez 112: „Nie wiem. Moje źródła tego nie opisują. Zapytaj lekarza, farmaceutę albo właściwą instytucję.” (`NoSource`). „Poza tematem” bez 112. Przy frazie ryzyka aplikacja dodaje `call`. Spec zaktualizowana.
2. **Motywy.** Spec przewiduje motywy Systemowy, Jasny, Ciemny i Kryzysowy. System ma na razie tylko Ciemny. Kryzysowy (czarne tło, wyższy kontrast, bez animacji) to mała zmiana w tokenach; Jasny to osobny projekt palety.
   **Rozstrzygnięcie:** MVP ma tylko motyw Ciemny (wiersz „Motyw” ukryty). Kryzysowy, Jasny i Systemowy po MVP.
3. **Pigułka stanu usunięta.** Spec (elementy globalne): `StatusPill` „offline · GPS · bateria” na środku u góry E1 i E2. Decyzja 21.11: usunięta — za dużo informacji. Stan GPS pokazują tam, gdzie ma znaczenie, `MapCard`, `CallPanel` i `Notice` na mapie.
   **Rozstrzygnięcie:** `StatusPill` usunięta ze specyfikacji. Stan GPS i baterii jest na mapie (`Notice`), w `MapCard` i w `CallPanel`.
4. **Panel SOS: dwa przyciski.** Spec P2 ma pozycję (współrzędne, DMS, adres), 112, 999 / 998 / 997, notki, ciche zgłoszenie i sygnał. Decyzja 21.11: tylko **Zadzwoń 112** i **Powiadom bliskich** (SMS z lokalizacją). Współrzędne i numery służb usunięte — ludzie ich nie rozumieją, a 112 łączy ze wszystkimi i przekazuje lokalizację (AML). Ten sam układ ma szablon `call` w czacie.
   **Rozstrzygnięcie:** na wierzchu dwa przyciski po 80 px (**Zadzwoń 112**, **Powiadom bliskich**) z przełącznikiem „Dołącz dane z profilu”; pod spodem zwinięty wiersz „Więcej” (domyślnie zamknięty): 999 / 998 / 997, współrzędne (dziesiętne i DMS), najbliższy adres (po MVP), notka AML, „Co powiedzieć dyspozytorowi”. Dotyczy `CallPanel` `sheet` (Panel 2). W czacie od 23.11 jest tylko przycisk „Zadzwoń 112” przypięty nad polem wpisywania (redesign: minimalizm, mniej informacji).
5. **Panel boczny.** Spec P1: godzina przy każdym czacie, „Nowy czat” 56 dp, wiersz 56 dp. Decyzja 21.11: bez godzin, układ jak w ChatGPT — wiersze 44 px, bez ramek.
   **Rozstrzygnięcie:** układ jak w ChatGPT przyjęty w `panel-1-boczny.md` (logo 36 px, „Nowy czat” jako wiersz z ikoną, wiersze 44 px bez godzin i ramek, bieżący czat zaznaczony tłem).
6. **Podświetlenie cytatu.** Spec: „żółte tło ok. 40%”. System używa ochry `signal` (`highlight`), żeby nie dokładać koloru; na stronie PDF wygląda jak zakreślacz.
   **Rozstrzygnięcie:** token `highlight` (ochra `signal`) zamiast „żółtego tła ok. 40%”.
