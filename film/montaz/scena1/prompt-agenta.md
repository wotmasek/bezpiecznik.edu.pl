You are a film editor. Cut **scene 1 only** of a short hackathon film: a ~14-second opening montage of real TV news footage that builds tension until it snaps to silence. No narrator, no music, no app footage. All source material is already collected and documented; your job is the edit, the sound design, and proving the result is right.

## Context (read first)
- Film script (Polish): `/home/weak/Dokumenty/bezpiecznik/Bezpiecznik/bezpiecznik/07-hackathon/scenariusz-filmu.md`. Read "Scena 1 · Lejek", "Przekaz" and "Ujęcia AI".
- Footage index with a proposed shot order: `/home/weak/Dokumenty/bezpiecznik/Bezpiecznik/film/tv/README.md`.
- Per-topic manifests with in/out points, spoken phrases, Polish subtitle text and ratings: `/home/weak/Dokumenty/bezpiecznik/Bezpiecznik/film/tv/*.md`.
- Cut clips (≈3 s handles on both sides): `film/tv/ciete/<topic>/*.mp4`. Phrase clips: `film/tv/ciete/<topic>/frazy/*.mp4`. Full sources: `film/tv/raw/<topic>/`.
- Final shot (AI-generated, already dark-graded): `/home/weak/Dokumenty/bezpiecznik/Bezpiecznik/film/ai/gotowe/A_ulica_22_s1_mrok.mp4` (Polish housing estate at night, street lights and windows go dark one after another).

## The idea you must deliver
A **funnel**: each shot is closer to the viewer than the previous one. World (9/11) → war next door (Ukraine) → Europe (systems fail, blackout) → Poland (flood 2024, drones 2025, ALERT RCB) → "here" (the AI estate going dark). The viewer must feel the threat approaching, not watch random disasters.

## Hard requirements
1. **Length** 14 s (13–16 s accepted). Output 1920×1080, 25 fps, H.264 (`-crf 16`), AAC 48 kHz stereo.
2. **Cinema frame:** active picture 1920×804 (2.39:1) centred, black bars top and bottom. Every source is scaled to fill 1920 wide and cropped vertically to 804. Pick the crop offset **per clip** so the key action stays in frame. This matters for the 4:3 SD 9/11 clips (640×480), where the tower impact sits in the upper part of the frame.
3. **Rhythm** of 10–12 shots, accelerating: the first shots ≈2 s, the last ones ≈0.5 s. Hard cuts only. No dissolves, no transitions, no zooms or Ken Burns.
4. **Look:** dark and consistent. Grade every TV shot to match the AI shot, starting from this filter and adjusting per clip only if needed: `eq=saturation=0.55:contrast=1.18:brightness=-0.06:gamma=0.88,curves=r='0/0 0.5/0.40 1/0.88':g='0/0 0.5/0.46 1/0.94':b='0/0.04 0.5/0.52 1/1',vignette=PI/4.5,noise=alls=7:allf=t`. Keep the original channel logos and tickers (CNN, ABC, TVN24, Polsat, „PILNE”, „ALERT RCB”). They are the authenticity.
5. **Ending:** the last shot is the AI estate going dark. Hard cut to full black and **total silence** for the final ≈0.5 s.
6. **Sound design** (no music, no narrator):
   - Overlapping real news audio from the clips plus 3–5 selected phrases from `frazy/`. The phrases should get denser and overlap more towards the end. Mix Polish and English; at least one Polish phrase must land in the Polish part of the funnel.
   - Underneath: a low **rising drone** and a **heartbeat that accelerates** (≈70 → ≈140 BPM). No sound effects exist on disk; synthesise both with ffmpeg (`aevalsrc`, `anoisesrc`, filters). Heartbeat = a "lub-dub" pair of short, low (≈45–60 Hz) decaying thumps. Drone = low tones plus filtered noise with rising volume and a slight pitch rise.
   - Keep phrases intelligible: duck the bed under speech (`sidechaincompress` or volume automation).
   - Loudness: integrated ≈ −16 LUFS, true peak ≤ −1 dBTP (`loudnorm`, two-pass). Then the hard cut to silence.
7. **Subtitles:** Polish subtitles only for non-Polish speech that is audible in the mix (take the text from the manifests: one line, ≤40 characters). White, DejaVu Sans Bold (`/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf`), placed inside the picture area just above the bottom bar, never on the bars. Use an ASS file and the `subtitles` filter (this ffmpeg has libass, but **no drawtext**).
8. **Content limits:** no victims, no bodies, no people falling (9/11 included). Do not label the July 2024 CrowdStrike outage as a cyberattack anywhere.

## Tools
- `~/bin/ffmpeg`, `~/bin/ffprobe` (static 7.0.2: libx264, aac, libass, xfade, loudnorm, sidechaincompress, aevalsrc, anoisesrc). Do not install anything.
- Build everything with one reproducible script, `render.sh`: per-shot trimmed and graded intermediates, then a concat, then the audio mix, then a mux. Re-running it must rebuild the film from the source files.

## Work folder (only write here)
`/home/weak/Dokumenty/bezpiecznik/Bezpiecznik/film/montaz/scena1/`
- `scena1_v1.mp4`: the result.
- `render.sh`: the build script.
- `scena1_v1_lista.md` (in Polish): edit decision list. One table row per shot: order, timecode in the film, source file, in–out in the source, crop offset, which phrase/audio plays, subtitle text. Then 3–5 sentences on how the tension builds.
- `scena1_v1_kadry.jpg`: contact sheet with one frame every 0.5 s of the result.
- `_tmp/`: intermediates. Never use `/tmp`. Delete `_tmp/` when done, but keep `render.sh` able to recreate it.
Never modify or delete anything in `film/tv/`, `film/ai/` or `bezpiecznik/`.

## Verification before you report (mandatory)
1. `ffprobe` the result: 1920×1080, 25 fps, duration 13–16 s, one audio stream.
2. Look at `scena1_v1_kadry.jpg` (Read tool). Check: letterbox present everywhere, no shot cropped so the key action is lost, no victims, subtitles readable and inside the picture, grade consistent, last frames black.
3. Measure loudness (`loudnorm` with `print_format=summary`) and silence at the end (`silencedetect`). Report the numbers.
4. If any check fails, fix it and re-check. Do not report a version you have not checked.

## Final report (your last message, in Polish)
The path to every file you created, the shot list in short form, the loudness numbers, what you would improve in v2, and anything you could not do. A report without file paths and measured numbers counts as not done.
