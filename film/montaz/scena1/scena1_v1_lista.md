# Scena 1 · Lejek, v1: lista montażowa

Plik: `scena1_v1.mp4`, 18,80 s (470 klatek), 1920×1080, 25 kl/s, obraz 1920×804 (2,39:1) między czarnymi pasami. Budowa: `./render.sh`.

Ścieżki źródeł względem `film/tv/ciete/` (AI: `film/ai/gotowe/`). Crop Y = przesunięcie okna 804 px w pionie na klatce przeskalowanej do szerokości 1920 (SD 4:3 → 1920×1440, 16:9 → 1920×1080). Czasy fraz w źródle to czasy w pliku frazy. Napisy stoją na dolnym czarnym pasie, nie na obrazie (Inter Display Regular 42 px).

| # | Czas w filmie | Źródło | In–out w źródle | Crop Y | Dźwięk (fraza / audio) | Napis PL |
|---|---|---|---|---|---|---|
| 1 | 0:00,00–0:02,40 | `11wrzesnia/02_abc_druga_maszyna_uderzenie.mp4` (ABC) | 0,60–3,00 | 518 / 1440 | Dron i serce od pierwszej klatki, narastający „odwrócony wybuch” (prawdziwy huk z Reutersa puszczony wstecz) aż do cięcia na 2,40. Samolot wlatuje z prawej i uderza ok. 1,6 s. Od 2,65 „Oh my god.” (ABC, 3,25–4,20) | - |
| 2 | 0:02,40–0:04,40 | `11wrzesnia/01_nbc_druga_maszyna_kula_ognia.mp4` (NBC) | 4,75–6,75 | 400 / 1440 | Na cięciu 2,40 prawdziwy huk (Reuters). „Oh my god.”; od 3,40 „Oh, another one just hit.” (NBC, 0,36–1,56) | „O mój Boże.” 2,72–3,40; „Uderzył kolejny!” 3,44–4,40 |
| 3 | 0:04,40–0:06,40 | `ukraina/02_sky_noc_wybuch_syreny_kijow.mp4` (Sky News, BREAKING NEWS) | 1,00–3,00 | 240 | Syreny alarmowe nad Kijowem (dźwięk z klipu, 1,00–3,30, bez mowy). Wybuch w kadrze o 4,73; pod nim prawdziwy huk wybuchu z nagrania Reutersa z Kijowa | - |
| 4 | 0:06,40–0:08,20 | `ukraina/01_tvp_alarm_przeciwlotniczy_kijow.mp4` (TVP Info) | 0,00–1,80 | 180 | „Słychać było syrenę.” + syreny (synchron, 0,00–1,46) | - (PL) |
| 5 | 0:08,20–0:09,60 | `ukraina/03_ap_metro_schron_kijow.mp4` (AP) | 12,50–13,90 | 170 | Od 9,15 wchodzi fraza z ujęcia 6 (dźwięk wyprzedza obraz) | „Wyłączyło część kanałów TV” od 9,19 |
| 6 | 0:09,60–0:10,88 | `cyberatak/03_bbc-sky-i-bbc-poza-antena.mp4` (BBC, plansza Sky News) | 4,60–5,88 | 176 (+ przyciemnienie bieli) | `cyberatak/frazy/06_knocking-some-tv-channels-off-air.mp4` 3,40–5,98: „knocking some TV channels off air” | „Wyłączyło część kanałów TV” do 11,60 |
| 7 | 0:10,88–0:12,08 | `blackout2025/02_tve-studio-gasnie-na-zywo.mp4` (TVE) | 3,76–4,96 | 150 | Koniec frazy BBC; od 11,65 `blackout2025/frazy/04_millions-were-left-without-power.mp4` 1,05–2,85: „Millions were left without power”. Światła migoczą o 11,48, czerń od 11,72 | „Miliony ludzi bez prądu” 11,68–13,30 |
| 8 | 0:12,08–0:13,04 | `powodz2024/04_stronie_tama_przerwana_tvn24.mp4` (TVN24) | 5,00–5,96 | 138 | „Millions…”; od 12,60 `powodz2024/frazy/04_z_minuty_na_minute_coraz_gorzej.mp4` 1,80–3,80: „Z minuty na minutę jest coraz gorzej.” | „Miliony ludzi bez prądu” |
| 9 | 0:13,04–0:13,84 | `powodz2024/01_gluchol_most_zerwany_tvn24.mp4` (TVN24) | 17,00–17,80 | 220 | „…jest coraz gorzej.” | „Miliony ludzi bez prądu” (do 13,30) |
| 10 | 0:13,84–0:14,52 | `drony2025/03_wyryki_zniszczony_dach_polsat.mp4` (Polsat News) | 16,00–16,68 | 120 | Od 14,00 `drony2025/frazy/03_obce_drony_wtargnely_na_terytorium_polski.mp4` 3,30–6,53: „drony wtargnęły na terytorium Polski.” | - (PL) |
| 11 | 0:14,52–0:15,08 | `pilne/01_polsat_alert_rcb_alarm_na_wschodzie.mp4` (Polsat News) | 1,50–2,06 | 60 | „drony wtargnęły na…”; od 14,85 `pilne/frazy/02_pojawil_sie_alert_rcb_zagrozenie_atakiem_z_powietrza.mp4` 2,38–3,46: „alert RCB” | - (PL) |
| 12 | 0:15,08–0:15,56 | `pilne/frazy/02_pojawil_sie_alert_rcb_zagrozenie_atakiem_z_powietrza.mp4` (telefon, ALERT RCB) | 4,00–4,48 | 40 | „alert RCB” + „…na terytorium” | - (PL) |
| 13–33 | 0:15,56–0:18,40 | **Rampa i punkt przełamania:** 21 ujęć, których wcześniej w scenie nie było (drony zestrzelone, lej w polu, „OK. 3:45 HUK I BŁYSK”, radiowozy nocą, blokowisko AI, most w Kłodzku, zalane ulice, Kijów, Fox 5, Charków, tablice odwołanych lotów, CNN, statek straży, Patriot, chmura pyłu, Madryt, mapa). Długości dalej maleją tak jak w ujęciach 1–12: 10, 9, 8, 7, 6, 5, 4, 3, 3, 2, 2, 2, 2, potem 8 × 1 klatka | lista w `render.sh` (`BURST`) | jak w źródłach | Każde ujęcie ma własny dźwięk z telewizji: cicho pod „…terytorium Polski.” (kończy się 17,06), od 17,26 pełna głośność. Pod spodem serce 170 → 240 BPM i huk z Kijowa wstecz, urwany na cięciu | - |
| - | 0:18,40–0:18,80 | czerń | - | - | pełna cisza (twarde cięcie, 10 ms rampy przeciw trzaskowi) | - |

Uwagi:
- Ujęcie 6 i fraza z folderu `cyberatak/` pokazują **awarię systemów IT z lipca 2024 (wadliwa aktualizacja CrowdStrike)**. Nazwa folderu pochodzi z archiwum materiałów. W filmie nigdzie nie nazywamy tego cyberatakiem: napis brzmi „Wyłączyło część kanałów TV”, a pasek BBC mówi „Worldwide IT outage”.
- Wszystkie ujęcia TV mają korekcję z briefu. Ujęcia 1 i 6 dostały dodatkowo `curves=all='0/0 1/0.82'`, które przygasza jasne niebo i białą planszę. Ujęcie AI ma już własną mroczną korekcję.
- Huki (2,40 i 4,73) i narastanie przed nimi to prawdziwe nagranie wybuchu z Kijowa (`tv/raw/ukraina/rjkzy0l2U00_x.mp4`, 8,15–11,35 s, bez narracji). Syntetyczny huk z wcześniejszej wersji usunięty.
- Podkład jest zsyntetyzowany w ffmpeg. Dron to tony 41/55/82/110,6 Hz ze wzrostem wysokości o 3% plus brązowy szum (dolnoprzepustowy 180 Hz), z rosnącą głośnością. Serce to para uderzeń 52 Hz („lub”) i 46 Hz („dub”), tempo liniowo od 70 do 140 BPM. Podkład jest ściszany pod mową przez `sidechaincompress`, a na końcu idą limiter i dwuprzebiegowy `loudnorm` (tryb liniowy).
- Odstępstwa od pierwotnego briefu (decyzje zleceniodawcy z 21.11): długość 18,8 s zamiast ok. 14 s, 13 ujęć plus seria przełamania zamiast 10–12 ujęć, napisy na dolnym pasie zamiast nad nim.

## Jak rośnie napięcie

Lejek idzie od świata do „tutaj”. Najpierw widzimy samolot nadlatujący nad Nowy Jork i kulę ognia, a krzyk prezenterów „Oh my god… another one just hit” wybija widza z fotela. Wybuch przechodzi w wybuch: nocny Kijów rozświetla kula ognia, wyją syreny, a polski reporter mówi, że słychać syrenę. Potem telewizja sama znika z anteny, a studio TVE gaśnie na żywo, migocze i robi się czarne. W Polsce woda, drony i ALERT RCB idą w ujęciach coraz krótszych (od 2,4 s do 0,5 s), a polskie głosy zaczynają na siebie zachodzić. Pod spodem cały czas narasta dron, a serce przyspiesza z 70 do 140 uderzeń. Ostatnie słowa „…na terytorium Polski” padają nad zwykłym blokowiskiem, w którym gasną światła. Potem przychodzi punkt przełamania: przez sekundę wszystkie katastrofy wracają naraz, w błyskach po jednej klatce, coraz szybciej, aż obraz i dźwięk urywają się do czerni i ciszy, z której pada pytanie lektora.
