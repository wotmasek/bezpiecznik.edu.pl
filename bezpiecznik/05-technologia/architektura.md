# Architektura

## Zasada

Bezpiecznik to natywna aplikacja mobilna na **Android i iOS**. Nie ma wersji webowej aplikacji (strona WWW służy tylko do pobrania, zob. [dystrybucja](dystrybucja.md)). Wszystko działa na telefonie. Sieć jest potrzebna tylko do pobrania i aktualizacji paczek: modelu AI, bazy wiedzy, map. Nie ma serwera z danymi użytkownika.

## Platformy i build

**Development na Androidzie. iOS ma się dać zbudować szybko z tego samego kodu.** Dlatego Flutter: jeden kod Dart na obie platformy, a wszystkie pakiety z tabeli niżej mają wsparcie Androida i iOS (sprawdzone na pub.dev 2026-11-21).

| Platforma | Rola | Uwagi |
|---|---|---|
| Android | Główna platforma developmentu, testów i demo | Minimum 6 GB RAM, zalecane 8 GB ([wymagania systemowe](wymagania-systemowe.md)). Dystrybucja w MVP: plik APK ([dystrybucja](dystrybucja.md)) |
| iOS | Szybki build z tego samego kodu, bez osobnej pracy nad funkcjami | Lokalne AI wymaga nowszych iPhone'ów z odpowiednią ilością pamięci. Build i podpis wymagają macOS + Xcode albo chmurowego CI z macOS (np. Codemagic, runnery macOS w GitHub Actions) oraz konta Apple Developer Program (TestFlight, podpisany build) |

**Zasady od pierwszego dnia, żeby iOS był tani:**

1. Żadnych pluginów tylko na Androida i żadnych własnych kanałów platformowych (platform channels) bez odpowiednika na iOS.
2. Job w CI na macOS: `flutter build ios --no-codesign` przy każdej zmianie. Sprawdza, że iOS się kompiluje, bez konta Apple.
3. Info.plist uzupełniany razem z AndroidManifest: lokalizacja (`NSLocationWhenInUseUsageDescription`), ruch dla kompasu (`NSMotionUsageDescription`, bez niego aplikacja się wywala), schematy `tel` i `sms` w `LSApplicationQueriesSchemes`, `UIBackgroundModes` → `audio` dla RKO w tle (na Androidzie odpowiednio usługa pierwszoplanowa), w P2 mikrofon i rozpoznawanie mowy.
4. Jedna przypięta wersja Fluttera dla całego projektu (pakiety mają różne minimalne wersje Fluttera i iOS).
5. AI, dźwięk i `tel:` testować na fizycznym iPhonie: symulator iOS nie dzwoni i liczy model tylko na CPU.
6. Konto Apple Developer Program założyć wcześniej, bo bez niego nie ma podpisanego buildu ani TestFlight.

## Warstwy

| Warstwa | Technologia | Uwagi |
|---|---|---|
| Aplikacja | Flutter (Dart) | Jeden kod na Android i iOS |
| Stan i nawigacja | `riverpod`, `go_router` | |
| Lokalne AI | Gemma 4 E2B przez `flutter_edge_ai` (dawniej `flutter_gemma`, wycofany; LiteRT-LM, plik `.litertlm`) | Alternatywy: Gemma 4 E4B, Bielik 4.5B v3. Szczegóły: [lokalne AI](lokalne-ai.md) |
| Baza wiedzy | `sqlite3` 3.x (wbudowana SQLite przez hooki; `sqlite3_flutter_libs` jest wycofany), opcjonalnie `drift`. FTS5 i R*Tree są w domyślnych binarkach `sqlite3` (sprawdzone w dokumentacji hooka) | MVP: samo FTS5. Po MVP: wektory w tej samej bazie, podobieństwo liczone w Dart |
| Profil domu i historia czatów | `sqlite3` 3.x z SQLCipher lub SQLite3MultipleCiphers (opcja hooka; `sqlcipher_flutter_libs` jest wycofany), `flutter_secure_storage` (klucz) | Jedna szyfrowana baza użytkownika: profil i czaty |
| Mapa | `maplibre_gl` z lokalnymi kafelkami **MBTiles** (`mbtiles://`, działa na Androidzie i iOS; plik skopiować z assets na dysk, bo silnik nie czyta z paczki assets). PMTiles z pliku nie jest potwierdzone na iOS; zapasowo `flutter_map` + `vector_map_tiles` | Szczegóły: [mapa offline](mapa-offline.md) |
| Trasy | Własny graf dróg z OSM, A* w Dart | Graf w płaskich tablicach, podzielony na kafelki |
| Punkty i adresy | SQLite z indeksem R*Tree | Najbliższe punkty i najbliższy adres |
| GPS | `geolocator` | Działa bez sieci |
| Kompas | `sensors_plus` (magnetometr) | `flutter_compass` nie jest aktualizowany od ok. 2 lat. iOS wymaga `NSMotionUsageDescription` |
| Latarka | `torch_light` | Sygnał SOS |
| Ekran i wibracja | `wakelock_plus`, `HapticFeedback` | Ekran nie gaśnie przy RKO |
| Dźwięk | `audioplayers` | Metronom RKO, sygnał ratunkowy |
| Mowa | `flutter_tts` (synteza mowy systemu) | Polskie głosy zależą od telefonu |
| Połączenia i SMS | `url_launcher` (`tel:112`, `sms:`) | Systemowe okno wybierania numeru |
| PDF | `pdfrx` | Okno PDF w szablonie `quote`: skok do strony i podświetlenie cytowanego fragmentu. Podświetlenie wymaga prostokątów fragmentu (`rects`) zapisanych przy budowie bazy wiedzy |
| Wydruk planu (P2, później) | `pdf` + `printing` | Eksport planu 72 h |
| Animacje | GIF przez wbudowany widżet `Image` (MVP); `lottie` później | Szablon `animation` w kartach ratunkowych. Decyzja z 2026-11-21: w MVP GIF |
| Wygląd | Tokeny z [design systemu](../08-design-system/README.md) (`tokens.json`) przeniesione do `ThemeData` / `ThemeExtension`. Font Atkinson Hyperlegible Next (OFL) dołączony lokalnie jako asset, nigdy z Google Fonts. Ikony Lucide (ISC); pakiet Fluttera do wyboru i sprawdzenia na pub.dev | Komponenty React w design systemie to wzorzec wyglądu, stanów i wymiarów, nie kod do użycia |

Aktualne wersje pakietów i obsługę obu platform trzeba sprawdzić na pub.dev przed rozpoczęciem pracy.

## Przygotowanie danych (na komputerze)

| Zadanie | Narzędzie |
|---|---|
| Tekst z PDF z numerami stron i prostokątami fragmentów (do podświetlenia) | Python, `PyMuPDF` |
| Fragmenty i embeddingi | Python, ten sam model embeddingów co w aplikacji |
| Kafelki mapy | Planetiler, wycinki OSM z Geofabrik (Polska, zachodniopomorskie) |
| Graf tras | Python, `osmium` lub `pyrosm`, zapis do pliku binarnego |
| Punkty i adresy | Python, zapis do SQLite |

## Moduły aplikacji

```
lib/
  czat/            przepływ odpowiedzi, szablony, wiele czatów, tryb bez AI, okno PDF z podświetleniem
  ratunek/         karty ratunkowe, instruktor RKO, rozpoznawanie fraz
  mapa/            mapa, punkty, trasy, kompas, paczki regionów
  profil/          profil domu, reguły planu 72 h i plecaka
  onboarding/      pierwsze uruchomienie, pobieranie paczek
  alarm/           przycisk SOS, panel alarmowy, sygnał ratunkowy
  ustawienia/
  wspolne/         baza wiedzy, AI, czujniki, pobieranie paczek, motywy
```

## Priorytety pod obciążeniem

Gdy telefon jest przeciążony lub bateria niska, działają kolejno:

1. Przycisk SOS i panel alarmowy.
2. Karty ratunkowe i instruktor RKO.
3. Kompas i pozycja GPS.
4. Mapa i trasy.
5. Wyszukiwanie w bazie wiedzy.
6. Lokalne AI (pierwsze do wyłączenia).

## Paczki do pobrania

| Paczka | Kiedy | Rozmiar |
|---|---|---|
| Aplikacja z mapą uproszczoną Polski i kartami ratunkowymi | Instalacja (MVP: plik APK z serwera WWW, później sklepy) | Do zmierzenia |
| Baza wiedzy | Pierwsze uruchomienie | Do zmierzenia |
| Model AI (Gemma 4 E2B) | Pierwsze uruchomienie, opcjonalnie tylko Wi-Fi | 2,58 GB |
| Województwo szczegółowe | Pierwsze uruchomienie i na żądanie | Setki MB, do zmierzenia |

## Dystrybucja

Aplikację i paczki danych serwuje statyczny serwer WWW, bez logiki i danych użytkowników. Szczegóły: [dystrybucja](dystrybucja.md).
