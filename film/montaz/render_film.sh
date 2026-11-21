#!/usr/bin/env bash
# Whole-film working cut: scene 1 (scena1/scena1_v1.mp4) + scenes 2, 3, 4, 4b, 5 built here.
# Shots that are not filmed yet are black slates ("DO NAGRANIA") at their exact time and length,
# so the timing and the sound design are already final. Replace a slate with footage in the
# scene section below once the recording exists, then re-run.
# Usage: ./render_film.sh   (KEEP_TMP=1 keeps _tmp_film/)
set -euo pipefail
export LC_ALL=C   # decimal points in printf/bc
cd "$(dirname "$0")"

FF=~/bin/ffmpeg
FILM=..
TMP=_tmp_film
OUT=film_v1.mp4
FPS=25
LEKTOR=$FILM/lektor/lektor_v1_elevenlabs_tomasz-z.mp3
mkdir -p "$TMP"

# ---------------------------------------------------------------- text layers (Chrome -> transparent PNG)
for l in s2 s3 s5a1 s5a2 s5b1 s5b2 lockup; do
  google-chrome --headless=new --no-sandbox --disable-gpu --hide-scrollbars --user-data-dir="$PWD/$TMP/chrome" \
    --default-background-color=00000000 --window-size=1920,1080 --virtual-time-budget=3000 \
    --screenshot="$PWD/$TMP/$l.png" "file://$PWD/plansze/plansze.html?layer=$l" 2>/dev/null
done

# ---------------------------------------------------------------- shared sound sources (all synthesized)
# Polish siren signals (RCB Poradnik bezpieczeństwa, s. 53): alarm = continuous MODULATED tone, all-clear = continuous STEADY tone.
SIREN_MOD="st(0,2*PI*(475*t-145*4/(2*PI)*cos(2*PI*t/4)));0.6*sin(ld(0))+0.3*sin(2*ld(0))+0.18*sin(3*ld(0))+0.1*sin(4*ld(0))"
SIREN_CONT="st(0,2*PI*560*t);0.6*sin(ld(0))+0.3*sin(2*ld(0))+0.18*sin(3*ld(0))+0.1*sin(4*ld(0))"
OUTSIDE="highpass=f=250,lowpass=f=1800,aecho=0.8:0.6:70|190:0.35|0.22"
heart() { # heart <bpm start> <bpm end> <duration>
  echo "st(0,($1*t+($2-$1)*t*t/(2*$3))/60);st(1,60/($1+($2-$1)*t/$3));st(2,(ld(0)-floor(ld(0)))*ld(1));st(3,ld(2)-0.3*ld(1));\
sin(2*PI*52*ld(2))*exp(-ld(2)/0.075)+0.35*sin(2*PI*104*ld(2))*exp(-ld(2)/0.04)\
+gte(ld(3),0)*(0.7*sin(2*PI*46*ld(3))*exp(-ld(3)/0.065)+0.25*sin(2*PI*92*ld(3))*exp(-ld(3)/0.035))"; }
# real explosion sound (Reuters, Kyiv; no narration): transient at +0.05 s, ~3 s rumble
BLAST="$FILM/tv/raw/ukraina/rjkzy0l2U00_x.mp4"
TINNITUS="0.035*(1-exp(-t/0.05))*exp(-t/2.5)*sin(2*PI*7600*t)"
PAD="(0.5+0.1*sin(2*PI*0.25*t))*(sin(2*PI*110*t)+0.8*sin(2*PI*138.59*t)+0.7*sin(2*PI*164.81*t)+0.4*sin(2*PI*220*t))"
ST="aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo"
lek() { # lek <src in> <dur> <film ms> <gain dB> <label>: a lektor line from the ElevenLabs take
  echo "[L]atrim=start=$1:duration=$2,asetpts=PTS-STARTPTS,aresample=48000,$ST,volume=$4dB,afade=t=in:d=0.02,areverse,afade=t=in:d=0.05,areverse,adelay=delays=$3:all=1[$5];"; }

# slate events: slate <start> <end> <shot id> <description>
SLATES=""
slate() { SLATES+="Dialogue: 0,$(ts $1),$(ts $2),Slate,,0,0,0,,{\\fnDejaVu Sans Mono\\fs30\\c&H6BA6C9&}$3 · DO NAGRANIA\\N{\\fs14} \\N{\\fnDejaVu Sans\\fs42\\c&H9DA5A9&}$4"$'\n'; }
ts() { printf "0:00:%05.2f" "$1"; }   # scenes are < 60 s
write_ass() { cat > "$1" <<EOF
[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Slate,DejaVu Sans,42,&H00E6ECEE,&H00E6ECEE,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,0,0,5,200,200,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
$SLATES
EOF
SLATES=""; }
SUBS="subtitles=f=%s:fontsdir=/usr/share/fonts/truetype/dejavu"   # slates only (temporary boards)
ENC="-c:v libx264 -crf 16 -preset slow -pix_fmt yuv420p -r $FPS -c:a pcm_s16le -ar 48000 -ac 2"
LIMIT="alimiter=limit=0.8:attack=5:release=60:level=false"
# v2 (AI POV) pictures: when v2/out/<scene>.mp4 exists it replaces the black slates of that scene (built by v2/build_v2.sh)
pic()    { if [ -f "$1" ]; then echo "-i $1"; else echo "-f lavfi -i color=black:s=1920x1080:r=$FPS:d=$2"; fi; }
# v2 POV sound layer (v2/fx_audio.sh): addfx <mkv> <fx wav> <gain dB> mixes it under the scene's own sound
addfx() { [ -f "$2" ] || return 0
  "$FF" -v error -y -i "$1" -i "$2" -filter_complex "[1:a]$ST,volume=$3dB[f];[0:a]$ST[b];[b][f]amix=inputs=2:normalize=0:duration=first,$LIMIT[a]" \
    -map 0:v -map "[a]" -c:v copy -c:a pcm_s16le "${1%.mkv}_fx.mkv" && mv "${1%.mkv}_fx.mkv" "$1"; }
slates() { if [ -f "$1" ]; then echo "fps=$FPS"; else printf "$SUBS" "$2"; fi; }

# Budget: whole film <= 60 s. Scene 1 (18.8 s) + 2 + 5 are fixed; scenes 3, 4, 4b are cut to the shortest readable takes.
# ================================================================ SCENE 2 · Pytanie (3.0 s)
D2=3.0
"$FF" -v error -y -f lavfi -i "color=black:s=1920x1080:r=$FPS:d=$D2" -loop 1 -t $D2 -i "$TMP/s2.png" -i "$LEKTOR" \
  -filter_complex "[1:v]format=rgba,fade=t=in:st=0.15:d=0.6:alpha=1,fade=t=out:st=2.6:d=0.35:alpha=1[t];[0:v][t]overlay=format=auto,format=yuv420p[v];
  [2:a]anull[L];$(lek 0.00 2.55 300 4.0 a1)
  aevalsrc=exprs='$SIREN_MOD':s=48000:d=0.9,$OUTSIDE,lowpass=f=900,volume='0.10*t/0.9':eval=frame,adelay=delays=2100:all=1,$ST[j];
  aevalsrc=exprs=0:s=48000:d=$D2,$ST[z];[z][a1][j]amix=inputs=3:normalize=0:duration=first,$LIMIT[a]" \
  -map "[v]" -map "[a]" -t $D2 $ENC "$TMP/sc2.mkv"

# ================================================================ SCENE 3 · Brak połączenia (10 s)
D3=10.0
slate 0.0 2.5 "3.1 + 3.2" "Dłoń w ciemności, na pasku 03:12. Google: kciuk wpisuje „syrena wyje gdzie sie schowac”"
slate 2.5 3.5 "3.2" "Kółko ładowania. Lampka mruga i gaśnie"
slate 3.5 6.0 "3.1" "„Brak połączenia z internetem”. Kciuk dwa razy stuka „Spróbuj ponownie”"
slate 6.0 7.5 "3.3" "Pół sekundy ciszy. Błysk latarki za żaluzjami (6,4 s), kamera lekko szarpnięta"
slate 7.5 8.3 "3.4" "Telefon wypada z ręki ekranem w dół"
write_ass "$TMP/sc3.ass"
"$FF" -v error -y $(pic v2/out/sc3.mp4 $D3) -loop 1 -t $D3 -i "$TMP/s3.png" \
  -filter_complex "[1:v]format=rgba,fade=t=in:st=8.5:d=0.4:alpha=1,fade=t=out:st=9.6:d=0.4:alpha=1[t];
  [0:v][t]overlay=format=auto,$(slates v2/out/sc3.mp4 "$TMP/sc3.ass"),format=yuv420p[v]" \
  -map "[v]" -t $D3 -c:v libx264 -crf 12 -preset veryfast -pix_fmt yuv420p "$TMP/sc3v.mkv"
"$FF" -v error -y -i "$BLAST" -filter_complex "
  aevalsrc=exprs='$SIREN_MOD':s=48000:d=6,$OUTSIDE,volume='0.10+0.30*min(t/5,1)':eval=frame,afade=t=out:st=5.96:d=0.04,$ST[s1];
  aevalsrc=exprs='$(heart 85 140 2.5)':s=48000:d=2.5,volume=0.45,afade=t=out:st=2.46:d=0.04,adelay=delays=3500:all=1,$ST[h];
  [0:a]atrim=start=8.15:duration=3.2,asetpts=PTS-STARTPTS,aresample=48000,$ST,lowpass=f=400,volume=-2dB,adelay=delays=6350:all=1[bm];
  aevalsrc=exprs='$TINNITUS':s=48000:d=3.55,adelay=delays=6450:all=1,$ST[tn];
  aevalsrc=exprs='$SIREN_MOD':s=48000:d=1.4,$OUTSIDE,lowpass=f=700,volume=0.25,afade=t=in:d=0.4,afade=t=out:st=1.36:d=0.04,adelay=delays=6900:all=1,$ST[s2];
  aevalsrc=exprs=0:s=48000:d=$D3,$ST[z];
  [z][s1][h][bm][tn][s2]amix=inputs=6:normalize=0:duration=first,$LIMIT[a]" -map "[a]" -c:a pcm_s16le "$TMP/sc3a.wav"
"$FF" -v error -y -i "$TMP/sc3v.mkv" -i "$TMP/sc3a.wav" -map 0:v -map 1:a -c:v copy -c:a pcm_s16le "$TMP/sc3.mkv"
addfx "$TMP/sc3.mkv" v2/out/sc3_fx.wav 3

# ================================================================ SCENE 4 · Jeszcze raz (11.5 s)
D4=11.5
# 0-0.7 s: tape rewind of scene 3 (0-8.3 s reversed); follows scene 3 automatically once it is filmed
"$FF" -v error -y -t 8.3 -i "$TMP/sc3.mkv" -filter_complex "
  [0:v]reverse,setpts=(PTS-STARTPTS)*0.7/8.3,fps=$FPS,noise=alls=12:allf=t,format=yuv420p[v];
  [0:a]areverse,asetrate=569143,aresample=48000,$ST,volume=0.6,afade=t=out:st=0.62:d=0.08[a]" \
  -map "[v]" -map "[a]" -t 0.7 $ENC "$TMP/sc4rew.mkv"
# times below are relative to scene time 0.7 (after the rewind); staircase 4.3 dropped for the 60 s cut
slate 0.0 2.0  "4.2" "Ta sama dłoń w tym samym kadrze co 3.2. Na ekranie Bezpiecznik"
slate 2.0 2.7  "4.1" "Zbliżenie: ikona trybu samolotowego (offline)"
slate 2.7 3.7  "4.1" "To samo pytanie, wpisane tak samo jak w Google"
slate 3.7 6.7  "4.1" "Karta „Teraz”: kroki i chip źródła, dotknięcie otwiera PDF"
slate 6.7 9.2  "4.1" "„Najbliższy schron”, kciuk: „Prowadź”, strzałka kompasu"
slate 9.2 10.8 "4.4" "Drzwi do schronu z oznaczeniem, dłoń je otwiera"
write_ass "$TMP/sc4.ass"
"$FF" -v error -y $(pic v2/out/sc4.mp4 10.8) -i "$LEKTOR" -filter_complex "
  [0:v]$(slates v2/out/sc4.mp4 "$TMP/sc4.ass"),format=yuv420p[v];
  [1:a]anull[L];$(lek 3.95 3.28 200 1.0 lk)
  aevalsrc=exprs='$SIREN_MOD':s=48000:d=9.2,$OUTSIDE,lowpass=f=1100,volume=0.12,afade=t=in:d=0.3,afade=t=out:st=9.16:d=0.04,$ST[s];
  aevalsrc=exprs='$SIREN_CONT':s=48000:d=1.6,$OUTSIDE,lowpass=f=1100,volume=0.12,afade=t=in:d=0.08,adelay=delays=9200:all=1,$ST[c];
  aevalsrc=exprs='$PAD':s=48000:d=7.1,lowpass=f=900,volume=0.05,afade=t=in:d=2,afade=t=out:st=6.1:d=1,adelay=delays=3700:all=1,$ST[p];
  aevalsrc=exprs=0:s=48000:d=10.8,$ST[z];[z][lk][s][c][p]amix=inputs=5:normalize=0:duration=first,$LIMIT[a]" \
  -map "[v]" -map "[a]" -t 10.8 $ENC "$TMP/sc4rest.mkv"
addfx "$TMP/sc4rest.mkv" v2/out/sc4_fx.wav -4
"$FF" -v error -y -i "$TMP/sc4rew.mkv" -i "$TMP/sc4rest.mkv" -filter_complex "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[v][a]" \
  -map "[v]" -map "[a]" $ENC "$TMP/sc4.mkv"

# ================================================================ SCENE 4b · Każde zagrożenie dostaje odpowiedź (6.56 s = 4 x 3 beats at 110 BPM)
D4B=6.56
slate 0.00 1.64 "4b.1 + 4b.6" "Woda pod drzwiami → karta „Teraz” ze źródłem PSP"
slate 1.64 3.28 "4b.2 + 4b.6" "Lodówka po ciemku, pen z insuliną → plan 72 h"
slate 3.28 4.92 "4b.4 + 4b.6" "Kciuk na SOS → latarka SOS w ciemności"
slate 4.92 6.56 "4b.5 + 4b.6" "RKO na manekinie → karta RKO z metronomem. Muzyka 110 BPM: brak"
write_ass "$TMP/sc4b.ass"
"$FF" -v error -y $(pic v2/out/sc4b.mp4 $D4B) -filter_complex "
  [0:v]$(slates v2/out/sc4b.mp4 "$TMP/sc4b.ass"),format=yuv420p[v];
  aevalsrc=exprs='$SIREN_CONT':s=48000:d=2,$OUTSIDE,lowpass=f=1100,volume=0.12,afade=t=out:st=0:d=2,$ST[c];
  aevalsrc=exprs=0:s=48000:d=$D4B,$ST[z];[z][c]amix=inputs=2:normalize=0:duration=first[a]" \
  -map "[v]" -map "[a]" -t $D4B $ENC "$TMP/sc4b.mkv"
addfx "$TMP/sc4b.mkv" v2/out/sc4b_fx.wav 0

# ================================================================ SCENE 5 · Plansza (10 s): two lines per beat, each with its lektor phrase, then only the logo
# lektor pauses tightened: the four phrases are placed separately (src cuts in the silences of the take)
D5=10.0
"$FF" -v error -y -f lavfi -i "color=black:s=1920x1080:r=$FPS:d=$D5" \
  -loop 1 -t $D5 -i "$TMP/s5a1.png" -loop 1 -t $D5 -i "$TMP/s5a2.png" -loop 1 -t $D5 -i "$TMP/s5b1.png" -loop 1 -t $D5 -i "$TMP/s5b2.png" \
  -loop 1 -t $D5 -i "$TMP/lockup.png" -i "$LEKTOR" \
  -filter_complex "
  [1:v]format=rgba,fade=t=in:st=0.30:d=0.5:alpha=1,fade=t=out:st=3.95:d=0.35:alpha=1[a1];
  [2:v]format=rgba,fade=t=in:st=2.30:d=0.4:alpha=1,fade=t=out:st=3.95:d=0.35:alpha=1[a2];
  [3:v]format=rgba,fade=t=in:st=4.40:d=0.5:alpha=1,fade=t=out:st=7.90:d=0.40:alpha=1[b1];
  [4:v]format=rgba,fade=t=in:st=6.40:d=0.4:alpha=1,fade=t=out:st=7.90:d=0.40:alpha=1[b2];
  [5:v]format=rgba,fade=t=in:st=8.35:d=0.5:alpha=1,fade=t=out:st=9.60:d=0.40:alpha=1[lu];
  [0:v][a1]overlay=format=auto[o1];[o1][a2]overlay=format=auto[o2];[o2][b1]overlay=format=auto[o3];[o3][b2]overlay=format=auto[o4];
  [o4][lu]overlay=format=auto,format=yuv420p[v];
  [6:a]asplit=4[L1][L2][L3][L4];
  $(lek 8.17 1.69 300 3.0 l1 | sed 's/^\[L\]/[L1]/')
  $(lek 10.35 1.62 2300 3.0 l2 | sed 's/^\[L\]/[L2]/')
  $(lek 12.71 1.62 4400 3.0 l3 | sed 's/^\[L\]/[L3]/')
  $(lek 14.95 1.48 6400 3.0 l4 | sed 's/^\[L\]/[L4]/')
  aevalsrc=exprs='$SIREN_CONT':s=48000:d=5,$OUTSIDE,lowpass=f=1100,volume=0.08,afade=t=out:st=0:d=5,$ST[c];
  aevalsrc=exprs=0:s=48000:d=$D5,$ST[z];[z][l1][l2][l3][l4][c]amix=inputs=6:normalize=0:duration=first,$LIMIT[a]" \
  -map "[v]" -map "[a]" -t $D5 $ENC "$TMP/sc5.mkv"

# ================================================================ ASSEMBLY
"$FF" -v error -y -i scena1/scena1_v1.mp4 -i "$TMP/sc2.mkv" -i "$TMP/sc3.mkv" -i "$TMP/sc4.mkv" -i "$TMP/sc4b.mkv" -i "$TMP/sc5.mkv" \
  -filter_complex "[0:a]aresample=48000,$ST[a0];[1:a]$ST[a1];[2:a]$ST[a2];[3:a]$ST[a3];[4:a]$ST[a4];[5:a]$ST[a5];
  [0:v]setsar=1[v0];[1:v]setsar=1[v1];[2:v]setsar=1[v2];[3:v]setsar=1[v3];[4:v]setsar=1[v4];[5:v]setsar=1[v5];
  [v0][a0][v1][a1][v2][a2][v3][a3][v4][a4][v5][a5]concat=n=6:v=1:a=1[v][a]" \
  -map "[v]" -map "[a]" -c:v libx264 -crf 16 -preset slow -pix_fmt yuv420p -r $FPS -c:a aac -b:a 256k -ar 48000 -movflags +faststart "$OUT"

# master: brick-wall limiter so the whole film stays under -1 dBTP (scene levels stay as mixed)
"$FF" -v error -y -i "$OUT" -af "aresample=192000,alimiter=limit=0.80:attack=2:release=60:level=false,aresample=48000" \
  -c:v copy -c:a aac -b:a 256k -movflags +faststart "$TMP/master.mp4" && mv "$TMP/master.mp4" "$OUT"

# contact sheet: one frame per second
"$FF" -v error -y -i "$OUT" -vf "fps=1,scale=192:108,tile=10x6" -frames:v 1 -q:v 3 film_v1_kadry.jpg

[ "${KEEP_TMP:-0}" = 1 ] || rm -rf "$TMP"
echo "done: $OUT"
