# Bezpiecznik

Kryzysowy asystent offline. Bezpiecznik zamienia rozproszoną wiedzę państwa o bezpieczeństwie w jedną rozmowę, która działa bez internetu. Mówi, co zrobić teraz, podaje źródło z numerem strony i prowadzi do najbliższego punktu schronienia.

Ten folder to **przepis na aplikację**: jedyne źródło prawdy dla budującego. Gdy dwa pliki sobie przeczą, wygrywa nowsza decyzja z [dziennika decyzji](#dziennik-decyzji), a potem plik bardziej szczegółowy (ekran > funkcja > wizja). **Design system** decyduje o wyglądzie (kolory, typografia, wymiary komponentów); o zachowaniu i zawartości ekranów decyduje specyfikacja. Rozbieżności między nimi rozstrzyga sekcja [Odstępstwa od specyfikacji](08-design-system/komponenty.md), a opisy w `08-design-system/components/*` sprzeczne z rozstrzygnięciami (np. pigułka stanu, „dwa przyciski, nic więcej” w `CallPanel`) są nieaktualne.

## Jak czytać (kolejność dla budującego)

1. [Zasady](01-wizja/zasady.md): czego aplikacja nie może zrobić nigdy.
2. [Zakres MVP](07-hackathon/zakres-mvp.md): co budujemy w MVP (6 h z agentami), plan ścieżek i bramki. Ma pierwszeństwo przed rankingiem w sprawie etapu.
3. [Ekrany](03-ekrany/README.md): mapa nawigacji, elementy globalne, potem każdy ekran z kryteriami akceptacji.
4. [Ranking funkcji](02-funkcje/ranking.md): waga funkcji w produkcie (P0 → P1 → P2).
5. [Architektura](05-technologia/architektura.md): stos technologiczny i moduły.
6. [Design system](08-design-system/README.md): kolory, typografia, odstępy, ikony, ruch, komponenty (React jako wzorzec dla Fluttera) i [mapa ekran → komponenty](08-design-system/komponenty.md).

## Spis treści

**1. Wizja**
- [Po co jest Bezpiecznik](01-wizja/po-co.md) · [Dla kogo i w jakich sytuacjach](01-wizja/dla-kogo.md) · [Zasady: cele, nie-cele, anty-cele](01-wizja/zasady.md)

**2. Funkcje** (zachowanie i reguły)
- [Ranking wszystkich funkcji](02-funkcje/ranking.md)
- Czat: [Czat z Bezpiecznikiem](02-funkcje/01-czat/czat.md) · [Szablony w czacie: reguły](02-funkcje/01-czat/panele.md) · [Odpowiedzi tylko ze źródeł](02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md)
- Pierwsza pomoc (w czacie): [Karty ratunkowe](02-funkcje/02-pierwsza-pomoc/karty-ratunkowe.md) · [Instruktor RKO](02-funkcje/02-pierwsza-pomoc/instruktor-rko.md) · [Trening RKO](02-funkcje/02-pierwsza-pomoc/trening-rko.md)
- Mapa: [Mapa offline](02-funkcje/03-mapa/mapa.md) · [Punkty schronienia i pomocy](02-funkcje/03-mapa/punkty-schronienia.md) · [Trasy](02-funkcje/03-mapa/trasy.md) · [Kompas](02-funkcje/03-mapa/kompas.md) · [Paczki regionów](02-funkcje/03-mapa/paczki-regionow.md)
- Profil i plan: [Profil domu](02-funkcje/04-profil-i-plan/profil-domu.md) · [Plan 72 h](02-funkcje/04-profil-i-plan/plan-72h.md) · [Plecak ewakuacyjny](02-funkcje/04-profil-i-plan/plecak-ewakuacyjny.md)
- Alarm: [Przycisk SOS](02-funkcje/05-alarm/przycisk-sos.md) · [Panel alarmowy i Powiadom bliskich](02-funkcje/05-alarm/panel-alarmowy.md) · [Sygnał ratunkowy](02-funkcje/05-alarm/sygnal-ratunkowy.md) · [Sygnały alarmowe (syreny)](02-funkcje/05-alarm/sygnaly-alarmowe.md)
- W przyszłości: [Rozmowa głosowa](02-funkcje/08-w-przyszlosci/glos.md) · [Moduły terenowe](02-funkcje/08-w-przyszlosci/moduly-terenowe.md) · [Defibrylatory AED](02-funkcje/08-w-przyszlosci/aed.md)

**3. Ekrany** (wygląd, interakcje, teksty, kryteria akceptacji)
- [Przegląd, nawigacja, elementy globalne](03-ekrany/README.md)
- [Ekran 0: Pierwsze uruchomienie](03-ekrany/ekran-0-pierwsze-uruchomienie.md) · [Ekran 1: Czat](03-ekrany/ekran-1-czat.md) · [Ekran 2: Mapa](03-ekrany/ekran-2-mapa.md) · [Ekran 3: Ustawienia](03-ekrany/ekran-3-ustawienia.md) · [Ekran 4: Profil](03-ekrany/ekran-4-profil.md)
- [Panel 1: Panel boczny](03-ekrany/panel-1-boczny.md) · [Panel 2: Kontakt ze służbami](03-ekrany/panel-2-kontakt-ze-sluzbami.md)
- [Szablony w czacie: wygląd i pola JSON](03-ekrany/szablony-czatu.md)

**4. Dane**
- [Źródła wiedzy](04-dane/zrodla-wiedzy.md) · [Dane mapy](04-dane/dane-mapy.md) · [Kontrakty treści (JSON, DDL)](04-dane/kontrakty-tresci.md) · [Licencje i zgody](04-dane/licencje.md)

**5. Technologia**
- [Architektura](05-technologia/architektura.md) · [Lokalne AI](05-technologia/lokalne-ai.md) · [Mapa offline](05-technologia/mapa-offline.md) · [Prywatność i bezpieczeństwo](05-technologia/prywatnosc-i-bezpieczenstwo.md) · [Dystrybucja](05-technologia/dystrybucja.md)

**6. Ryzyka**
- [Ryzyka i otwarte kwestie](06-ryzyka/ryzyka-i-otwarte-kwestie.md) · [Krytyka planu 2026-11-21](06-ryzyka/krytyka-2026-11-21.md)

**7. Hackathon**
- [Zakres MVP](07-hackathon/zakres-mvp.md) · [Ograniczenia](07-hackathon/ograniczenia.md) · [Plan budowy](07-hackathon/plan-budowy.md) · [Scenariusz pokazu](07-hackathon/scenariusz-pokazu.md) · [Scenariusz filmu (76 s)](07-hackathon/scenariusz-filmu.md)

**8. Design system**
- [Przegląd i zasady](08-design-system/README.md) · [Mapa komponentów i odstępstwa od specyfikacji](08-design-system/komponenty.md) · [Tokeny](08-design-system/api/tokens.md) (`tokens.json`, `tokens.css`) · [Ruch](08-design-system/motion.md)

## Priorytety w skrócie

| Priorytet | Znaczenie |
|---|---|
| **P0** | Rdzeń. Bez tego aplikacja nie spełnia swojej obietnicy. |
| **P1** | Ważne uzupełnienie. Wyraźnie podnosi wartość, ale aplikacja działa bez tego. |
| **P2** | Rozwój. Wartościowe, ale wymaga dodatkowych danych, zgód lub pracy. |

## Dziennik decyzji

| Data | Decyzja | Szczegóły |
|---|---|---|
| 2026-11-21 | Czat jest ekranem głównym. Nie ma dolnego paska zakładek: w lewym górnym rogu pływająca wyspa (menu, mapa), w prawym górnym rogu SOS na każdym ekranie | [Ekrany](03-ekrany/README.md) |
| 2026-11-21 | Nie ma ekranów „Mój plan” ani „Poradniki”. Plan 72 h i plecak to odpowiedzi w czacie. Biblioteka PDF odpada | [Plan 72 h](02-funkcje/04-profil-i-plan/plan-72h.md) |
| 2026-11-21 | Karty ratunkowe i instruktor RKO działają w czacie (szablony `steps`, `animation`, `cpr`), bez modelu AI | [Karty ratunkowe](02-funkcje/02-pierwsza-pomoc/karty-ratunkowe.md) |
| 2026-11-21 | Cytat ze źródła to okno PDF w czacie z podświetlonym fragmentem, do powiększenia na pełny ekran | [Szablony](03-ekrany/szablony-czatu.md) |
| 2026-11-21 | Profil jest lokalny, bez konta. Zakłada się go przy pierwszym uruchomieniu, a edytuje w Ustawieniach. Służy jako kontekst dla AI | [Ekran 4](03-ekrany/ekran-4-profil.md) |
| 2026-11-21 | „Powiadom bliskich” to SMS do kontaktów ICE z lokalizacją, wysyłany przez użytkownika. Publicznego API do 112/CPR nie ma | [Panel 2](03-ekrany/panel-2-kontakt-ze-sluzbami.md) |
| 2026-11-21 | Zmiana nazwy „Ciche zgłoszenie” na „Powiadom bliskich”. Zasada 112: jedno dotknięcie SOS otwiera panel z 112 jako pierwszym przyciskiem, połączenie potwierdza system. Prywatność: „nic nie opuszcza telefonu bez twojej wyraźnej akcji”, w P2 przełącznik „Dołącz dane z profilu” (domyślnie włączony, do potwierdzenia) i link OSM zamiast Google Maps | [Zasady](01-wizja/zasady.md), [Panel 2](03-ekrany/panel-2-kontakt-ze-sluzbami.md), [Krytyka](06-ryzyka/krytyka-2026-11-21.md) |
| 2026-11-21 | Mapa w pełnym zakresie P0: warstwy, karta punktu, trasa piesza, kompas | [Ekran 2](03-ekrany/ekran-2-mapa.md) |
| 2026-11-21 | Stos: Flutter (Dart) i Gemma 4 E2B przez `flutter_edge_ai` (następca wycofanego `flutter_gemma`), zamiast React Native. Development na Androidzie, iOS z tego samego kodu | [Architektura](05-technologia/architektura.md) |
| 2026-11-21 | W MVP animacje GIF, Lottie później | [Ranking](02-funkcje/ranking.md) |
| 2026-11-21 | MVP: tylko statyczny serwer WWW z plikiem APK (i paczkami danych). Później strona w React | [Dystrybucja](05-technologia/dystrybucja.md) |

| 2026-11-21 | MVP = ok. 6 h z agentami. Żadna funkcja nie wypada, każda ma etap MVP albo po MVP. Scenariusz pokazu na razie nie wpływa na zakres | [Zakres MVP](07-hackathon/zakres-mvp.md) |
| 2026-11-21 | Model pisze odpowiedź, walidator sprawdza (z kontrolą zaprzeczeń) | [Odpowiedzi tylko ze źródeł](02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md) |
| 2026-11-21 | Metronom i głos RKO grają w tle podczas rozmowy z 112 | [Instruktor RKO](02-funkcje/02-pierwsza-pomoc/instruktor-rko.md) |
| 2026-11-21 | Hackathon w Szczecinie: prawdziwy GPS, symulowana pozycja tylko jako zapas | [Ograniczenia](07-hackathon/ograniczenia.md) |
| 2026-11-21 | Development na Androidzie, iOS z tego samego kodu; głosówki: Gemma 4 audio, zapas Whisper | [Architektura](05-technologia/architektura.md), [Rozmowa głosowa](02-funkcje/08-w-przyszlosci/glos.md) |
| 2026-11-21 | Dodany design system (kolory, typografia, komponenty, ruch; React jako wzorzec dla Fluttera) i mapa komponentów | [Design system](08-design-system/README.md), [Komponenty](08-design-system/komponenty.md) |
| 2026-11-21 | Odstępstwa design systemu rozstrzygnięte: (1) Panel 2 i szablon `call` = dwa przyciski po 80 px (Zadzwoń 112, Powiadom bliskich) + zwinięte „Więcej” (999 / 998 / 997, współrzędne, adres po MVP, AML, co powiedzieć); (2) odmowa „brak w źródłach” spokojna, bez 112 (`NoSource`), 112 tylko przy zagrożeniu życia | [Panel 2](03-ekrany/panel-2-kontakt-ze-sluzbami.md), [Odmowa](02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md#odmowa), [Odstępstwa](08-design-system/komponenty.md) |
| 2026-11-21 | (3) usunięty globalny wskaźnik stanu (offline · GPS · bateria), stan GPS i baterii na mapie, w `MapCard` i `CallPanel`; (4) MVP tylko motyw Ciemny, Kryzysowy / Jasny / Systemowy po MVP; (5) Panel boczny jak w ChatGPT (wiersze 44 px, bez godzin i ramek); (6) podświetlenie cytatu tokenem `highlight` zamiast żółtego tła | [Ekrany](03-ekrany/README.md), [Panel 1](03-ekrany/panel-1-boczny.md), [Ustawienia](03-ekrany/ekran-3-ustawienia.md), [Szablony](03-ekrany/szablony-czatu.md) |

Wartości domyślne czekające na potwierdzenie: [Ekrany: do potwierdzenia](03-ekrany/README.md).
