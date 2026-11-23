# Minimalne wymagania systemowe

Ten plik jest źródłem prawdy dla wymagań sprzętowych. Inne pliki (architektura, lokalne AI, strona pobierania) odsyłają tutaj i nie podają własnych liczb.

Decyzja właściciela (2026-11-23): celujemy w telefon z **6 GB RAM**, a cała aplikacja z modelem, bazą wiedzy i mapami mieści się w **5–10 GB** miejsca. Pamięć zajętą przez Android i inne aplikacje pomijamy w budżecie; uwzględnia ją tylko testowanie na prawdziwym telefonie.

## Wymagania

| | Minimum | Zalecane |
|---|---|---|
| System | Android 11 (API 30; wymóg LiteRT dla modelu `.litertlm`) | Android 13 lub nowszy |
| RAM | 6 GB | 8 GB lub więcej |
| Wolne miejsce | 5 GB (aplikacja, model, baza wiedzy, mapa jednego województwa) | 10 GB (mapy całej Polski i zapas na aktualizacje) |
| Procesor | 64-bit ARM (arm64-v8a) | Z GPU obsługiwanym przez LiteRT (szybsze odpowiedzi) |
| Lokalizacja | GPS (mapa, najbliższy schron) | GPS i kompas |
| Internet | Tylko do pobrania aplikacji i paczek | Wi-Fi przy pierwszym uruchomieniu |

Bez internetu działa wszystko po pobraniu paczek. Bez pobranego modelu działa „Tryb bez AI”: karty ratunkowe, fragmenty źródeł, mapa i SOS.

## Budżet miejsca

| Składnik | Rozmiar | Skąd liczba |
|---|---|---|
| Aplikacja (APK release, z mapą zachodniopomorskiego i PDF poradników) | 239 MB | Zmierzone 2026-11-23 |
| Model Gemma 4 E2B (`gemma-4-E2B-it.litertlm`) | 2,59 GB | Zmierzone na telefonie 2026-11-23 |
| Baza wiedzy (`kb.sqlite`) i punkty (`points.sqlite`) | 0,4 MB | Zmierzone 2026-11-23 |
| Paczki map szczegółowych (cała Polska) | 2,6 GB | Ekran ustawień, 2026-11-23 |
| **Razem** | **≈ 5,4 GB** | Z mapami całej Polski; z jednym województwem ≈ 2,9 GB |

Indeks wektorowy bazy wiedzy (planowany) i model do embeddingów doliczyć po wyborze; budżet 10 GB ma na nie zapas.

## Budżet pamięci RAM

| | Wartość | Skąd liczba |
|---|---|---|
| Aplikacja z załadowanym modelem, w trakcie rozmowy | ≈ 2,5 GB (PSS) | Pixel 9, `dumpsys meminfo`, 2026-11-23, CPU, kontekst 2048 tokenów |
| Kontekst modelu | 2048 tokenów | Obecna konfiguracja (`kModelContextTokens`) |

Większe okno kontekstu (historia rozmowy i wyniki narzędzi) zwiększa pamięć podręczną KV. Ile kosztuje 4096 i 8192 tokenów oraz jak to zmniejszyć (kwantyzacja KV, GPU, ponowne użycie promptu systemowego), wpisujemy tu po pomiarze. Research: 2026-11-23, w toku.

## Szybkość (zmierzone)

| Telefon | RAM | Backend | Czas do pełnej odpowiedzi |
|---|---|---|---|
| Pixel 9 (Tensor G4) | 12 GB | CPU, kontekst 2048 | 5–45 s; rozmowa 6–11 s, odpowiedź z poradników 15–45 s |

Brakuje pomiaru na telefonie z 6 GB RAM. To warunek, żeby uznać minimum za potwierdzone.

## Do potwierdzenia

- Test na telefonie z 6 GB RAM: ładowanie modelu, odpowiedź, czy system nie zamyka aplikacji w tle.
- Kontekst 4096 i 8192 tokenów: RAM i czas na CPU i GPU.
- Strona pobierania i opis w sklepie podają wymagania z tej tabeli.
