# Film, wersja robocza v1 (cięcie 60 s): co jest, a czego brakuje

Plik: `film_v1.mp4`, 59,9 s, 1920×1080, 25 kl/s. Budowa: `./render_film.sh` (scena 1 ma własny `scena1/render.sh`).
Ujęcia, których jeszcze nie ma, to czarne plansze „DO NAGRANIA” w dokładnym miejscu i czasie. Dźwięk jest już docelowy, więc po wstawieniu nagrania wystarczy podmienić planszę w odpowiedniej sekcji skryptu i puścić go ponownie.

## Budżet 60 s

Gotowe sceny (1, 2, 5) zostają w całości. Sceny 3, 4 i 4b są skrócone do najkrótszych czytelnych ujęć. To propozycja do decyzji.

| Scena | Czas w filmie | Długość | Było | Stan |
|---|---|---|---|---|
| 1 · Lejek | 0:00,0–0:18,8 | 18,8 s | 18,1 s | Gotowa. Na końcu nowy punkt przełamania: 1 s błysków po 3 → 1 klatce, potem czerń i cisza |
| 2 · Pytanie | 0:18,8–0:21,8 | 3,0 s | 3,5 s | Gotowa: „A GDYBY TO BYŁO TUTAJ?” i lektor |
| 3 · Brak połączenia | 0:21,8–0:31,8 | 10,0 s | 16,5 s | Gotowe: „POZA ZASIĘGIEM.” i dźwięk. Do nagrania: 3.1 + 3.2 (2,5 s), lampka gaśnie (1 s), „Brak połączenia” (2,5 s), 3.3 błysk (1,5 s), 3.4 upadek telefonu (0,8 s) |
| 4 · Jeszcze raz | 0:31,8–0:43,3 | 11,5 s | 22 s | Gotowe: przewijanie (0,7 s, samo ze sceny 3), lektor, dźwięk. Do nagrania: 4.2 (2 s), 4.1 offline (0,7 s), pytanie (1 s), karta „Teraz” + PDF (3 s), schron i kompas (2,5 s), 4.4 drzwi (1,6 s). **Klatka schodowa 4.3 wycięta** |
| 4b · Odpowiedzi | 0:43,3–0:49,9 | 6,6 s | 15 s | 4 mikrosceny po 1,64 s (3 uderzenia przy 110 BPM): woda, insulina, SOS, RKO. **Mikroscena z mapą do szpitala (4b.3) wycięta.** Brak muzyki |
| 5 · Plansza | 0:49,9–0:59,9 | 10,0 s | 13 s | Gotowa: „INTERNET ZNIKA PIERWSZY. / BEZPIECZNIK ZOSTAJE.”, „POZA ZASIĘGIEM SIECI. / W ZASIĘGU RĘKI.” (każda linia z lektorem, pauzy lektora skrócone), na końcu sam znak z logotypem |

Co wycięto, żeby zmieścić się w minucie: klatkę schodową (4.3), mapę do szpitala (4b.3), drugie „Spróbuj ponownie”, dopisek „Działa bez internetu · Nie zastępuje 112” z ostatniego ekranu, dłuższe pauzy lektora. Każdą z tych rzeczy da się przywrócić kosztem innej.

## Typografia

Krój filmu: Inter Display (statyczne pliki w `plansze/fonts/`), rozstrzelone wersaliki na planszach, zwykły zapis w napisach na dolnym pasie sceny 1. Logotyp „Bezpiecznik” zostaje w kroju marki (Atkinson Hyperlegible Next ExtraBold), zgodnie z zasadami logo.

## Dźwięk (syntetyczny, poza lektorem, sceną 1 i hukiem)

- **Syrena:** ogłoszenie alarmu to ciągły, modulowany dźwięk, odwołanie to ciągły, jednostajny dźwięk. Opis sprawdzony w Poradniku bezpieczeństwa RCB, s. 53. Syrena brzmi „zza okna”: odfiltrowane pasmo i echo od bloków.
- **Scena 3:** syrena narasta od 0 s, serce przyspiesza z 85 do 140 BPM (3,5–6 s). Pół sekundy ciszy, potem błysk, daleki huk (prawdziwe nagranie wybuchu z Kijowa, Reuters) i pisk w uszach. Na 8,3 s cięcie do ciszy, zostaje sam pisk pod „POZA ZASIĘGIEM.”.
- **Scena 4:** odwrócony dźwięk przewijania, syrena cicho w tle i lektor „Jeszcze raz. Tym razem wiesz, co zrobić.”. Od 4,4 s ciepły akord zamiast drona. Na 9,9 s syrena przechodzi w odwołanie alarmu.
- **Sceny 4b i 5:** ton odwołania cichnie do zera. W scenie 5 lektor mówi hasło.
- **Lektor:** `film/lektor/lektor_v1_elevenlabs_tomasz-z.mp3`.
- **Głośność całości:** −18,3 LUFS, true peak −1,9 dBTP. Scena 1 zostaje na −16 LUFS, reszta jest celowo ciszej. Ostateczne wyrównanie robimy, gdy będą wszystkie nagrania.

## Do zdobycia poza nagraniami

- Muzyka do sceny 4b, 110 BPM (tylko 6,6 s).
- Odgłosy, które najlepiej nagrać przy zdjęciach: stukanie w ekran, oddech, upadek telefonu, płacz niemowlęcia (4b.2).
