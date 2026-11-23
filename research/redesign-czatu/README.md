# Redesign komponentów czatu (2026-11-23)

Zrzuty z emulatora (Pixel, 1080×2400, `-gpu host`) gałęzi `redesign/chat-components`.
Przed = `polish/after/` (stan `main` przed redesignem). Porównania: `compare/`. Demo 78 s: `demo.mp4`.
Makiety (ChatGPT-style): https://claude.ai/artifact/GRtC2b6hhSPQhQZEcH6RzX

`drive.sh` — mały sterownik adb (tap po etykiecie, zrzut, dump). Galeria szablonów (debug):
`adb shell am start -n pl.edu.bezpiecznik.bezpiecznik/.MainActivity --es route /gallery/templates`.
