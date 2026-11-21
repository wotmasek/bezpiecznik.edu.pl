#!/usr/bin/env bash
# Scene 1 "Lejek" (funnel) - rebuilds scena1_v1.mp4 from the source clips.
# Usage: ./render.sh          (intermediates go to _tmp/, deleted at the end; KEEP_TMP=1 keeps them)
set -euo pipefail
cd "$(dirname "$0")"

FF=~/bin/ffmpeg
TV=../../tv/ciete
AI=../../ai/gotowe
TMP=_tmp
OUT=scena1_v1.mp4
FPS=25
CUT=18.40     # film time where picture + sound hard-cut to black/silence (frame 460)
TOTAL=18.80   # 470 frames
mkdir -p "$TMP"

GRADE="eq=saturation=0.55:contrast=1.18:brightness=-0.06:gamma=0.88,curves=r='0/0 0.5/0.40 1/0.88':g='0/0 0.5/0.46 1/0.94':b='0/0.04 0.5/0.52 1/1',vignette=PI/4.5,noise=alls=7:allf=t"
TAME="curves=all='0/0 1/0.82'"   # extra for bright skies / white cards, pulls them to the AI shot's level

# ---------------------------------------------------------------- 1. shots
# shot <n> <source> <in (s)> <frames> <crop y on the 1920-wide scaled frame> <grade 1/0> [extra per-clip filter]
shot() {
  local g=""; [ "$6" = 1 ] && g=",$GRADE"; [ -n "${7:-}" ] && g="$g,$7"
  "$FF" -v error -y -ss "$3" -i "$2" -an \
    -vf "fps=$FPS,scale=1920:-2:flags=lanczos,crop=1920:804:0:$5$g,pad=1920:1080:0:138:black,setsar=1,format=yuv420p" \
    -frames:v "$4" -c:v libx264 -crf 10 -preset veryfast -r $FPS "$TMP/s$1.mp4"
  echo "file 's$1.mp4'" >> "$TMP/concat.txt"
}
: > "$TMP/concat.txt"
#     n   source                                                         in     fr  cropY grade  film time
shot 01 "$TV/11wrzesnia/02_abc_druga_maszyna_uderzenie.mp4"              0.60   60  518  1 "$TAME" #  0.00  plane in from the right, hits at ~1.6
shot 02 "$TV/11wrzesnia/01_nbc_druga_maszyna_kula_ognia.mp4"             4.75   50  400  1         #  2.40  fireball, NBC live
shot 03 "$TV/ukraina/02_sky_noc_wybuch_syreny_kijow.mp4"                 1.00   50  240  1         #  4.40  Kyiv night explosion at 4.73, Sky News
shot 04 "$TV/ukraina/01_tvp_alarm_przeciwlotniczy_kijow.mp4"             0.00   45  180  1         #  6.40
shot 05 "$TV/ukraina/03_ap_metro_schron_kijow.mp4"                       12.50  35  170  1         #  8.20
shot 06 "$TV/cyberatak/03_bbc-sky-i-bbc-poza-antena.mp4"                 4.60   32  176  1 "$TAME" #  9.60  IT outage, NOT an attack
shot 07 "$TV/blackout2025/02_tve-studio-gasnie-na-zywo.mp4"              3.76   30  150  1         # 10.88  flicker 11.48, black 11.72
shot 08 "$TV/powodz2024/04_stronie_tama_przerwana_tvn24.mp4"             5.00   24  138  1         # 12.08
shot 09 "$TV/powodz2024/01_gluchol_most_zerwany_tvn24.mp4"               17.00  20  220  1         # 13.04
shot 10 "$TV/drony2025/03_wyryki_zniszczony_dach_polsat.mp4"             16.00  17  120  1         # 13.84
shot 11 "$TV/pilne/01_polsat_alert_rcb_alarm_na_wschodzie.mp4"           1.50   14  60   1         # 14.52
shot 12 "$TV/pilne/frazy/02_pojawil_sie_alert_rcb_zagrozenie_atakiem_z_powietrza.mp4" 4.00 12 40 1 # 15.08
# ---- 15.56-18.40 RAMP + BREAKING POINT: 21 shots NOT used earlier in the scene, lengths keep the same decay as
#      shots 1-12 (... 17, 14, 12 ->) 10, 9, 8, 7, 6, 5, 4, 3, 3, 2, 2, 2, 2, then 8 single frames; each shot keeps its
#      own TV sound. "...na terytorium Polski" lands on the AI estate; then a hard cut to black + total silence.
#      Entry: source|in|frames|cropY|grade|extra
BURST=(
"$TV/drony2025/05_rzad_drony_zestrzelone_euronews.mp4|1.70|10|138|1|"
"$TV/drony2025/04_pole_slady_spalenia_pasek_tvn24.mp4|10.00|9|138|1|"
"$TV/pilne/03_tvn24_pasek_3-45_huk_3-50_syreny.mp4|6.70|8|200|1|"
"$TV/drony2025/01_noc_radiowozy_tvn24.mp4|6.00|7|138|1|"
"$AI/A_ulica_22_s1_mrok.mp4|1.20|6|140|0|"
"$TV/powodz2024/02_klodzko_most_rwaca_woda_tvn24.mp4|8.50|5|138|1|"
"$TV/powodz2024/06_gluchol_smiglowiec_zalane_ulice_polsat.mp4|0.50|4|138|1|"
"$TV/ukraina/05_reuters_nocny_atak_kijow_zapas.mp4|9.00|3|138|1|"
"$TV/11wrzesnia/04_fox5_kula_ognia_zapas.mp4|5.00|3|420|1|"
"$TV/ukraina/08_bbc_ciemnosc_po_atakach_na_siec_zapas.mp4|11.00|2|138|1|"
"$TV/cyberatak/04_bbc-tablica-odwolane-loty.mp4|3.70|2|138|1|"
"$TV/11wrzesnia/05_cnn_maszyna_okrazajaca_zapas.mp4|8.00|2|420|1|"
"$TV/zapasowe/03_aljazeera-baltyk-statki-kable.mp4|9.50|2|138|1|"
"$TV/ukraina/07_reuters_kijow_swit_po_ataku_zapas.mp4|14.70|1|138|1|"
"$TV/cyberatak/02_bbc-niebieskie-ekrany-lotnisko.mp4|13.30|1|138|1|"
"$TV/drony2025/07_mysliwiec_patrioty_tvn24.mp4|0.50|1|138|1|"
"$TV/11wrzesnia/07_cnn_chmura_pylu_manhattan.mp4|32.00|1|138|1|"
"$TV/blackout2025/03_sky-madryt-martwa-sygnalizacja.mp4|0.50|1|138|1|"
"$TV/zapasowe/04_guardian-kijow-ciemnosc.mp4|5.00|1|138|1|"
"$TV/ukraina/04_afp_kijow_pograzony_w_ciemnosci.mp4|14.00|1|138|1|"
"$TV/cyberatak/05_bbc-wannacry-mapa-ransomware.mp4|11.70|1|138|1|"
)
: > "$TMP/burst.txt"; i=0
for b in "${BURST[@]}"; do
  IFS='|' read -r src t fr cy gr ex <<< "$b"; i=$((i+1)); n=$(printf "13b%02d" $i)
  shot $n "$src" $t $fr $cy $gr "$ex"
  d=$(awk "BEGIN{printf \"%.3f\", $fr/$FPS}")
  if ~/bin/ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$src" | grep -q .; then
    "$FF" -v error -y -ss $t -t $d -i "$src" -vn -ac 2 -ar 48000 -c:a pcm_f32le "$TMP/ba$n.wav"
  else
    "$FF" -v error -y -f lavfi -i anullsrc=r=48000:cl=stereo -t $d -c:a pcm_f32le "$TMP/ba$n.wav"
  fi
  echo "file 'ba$n.wav'" >> "$TMP/burst.txt"
done
"$FF" -v error -y -f concat -safe 0 -i "$TMP/burst.txt" -c:a pcm_f32le "$TMP/burst.wav"
"$FF" -v error -y -f lavfi -i "color=black:s=1920x1080:r=$FPS" -frames:v 10 \
  -c:v libx264 -crf 10 -preset veryfast -pix_fmt yuv420p "$TMP/s14.mp4"           # 18.40-18.80 black
echo "file 's14.mp4'" >> "$TMP/concat.txt"

"$FF" -v error -y -f concat -safe 0 -i "$TMP/concat.txt" -c copy "$TMP/picture.mp4"

# ---------------------------------------------------------------- 2. subtitles (PL, only for non-Polish speech)
# Subtitles sit centred in the bottom letterbox bar (y 942-1080), never over the picture (user decision 2026-11-21)
cat > "$TMP/subs.ass" <<'EOF'
[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Sub,Inter Display Regular,42,&H00F2F2F2,&H00F2F2F2,&H00000000,&H00000000,0,0,0,0,100,100,0.6,0,1,0,0,2,100,100,48,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:02.72,0:00:03.40,Sub,,0,0,0,,{\fad(80,0)}O mój Boże.
Dialogue: 0,0:00:03.44,0:00:04.40,Sub,,0,0,0,,{\fad(0,120)}Uderzył kolejny!
Dialogue: 0,0:00:09.19,0:00:11.60,Sub,,0,0,0,,{\fad(100,100)}Wyłączyło część kanałów TV
Dialogue: 0,0:00:11.68,0:00:13.30,Sub,,0,0,0,,{\fad(80,140)}Miliony ludzi bez prądu
EOF

# ---------------------------------------------------------------- 3. sound
# Voices, each trimmed on word boundaries (word times from whisper large-v3):
#   n  input                         src in  dur   film pos  gain   fade-out
v() { echo "[$1:a]atrim=start=$2:duration=$3,asetpts=PTS-STARTPTS,aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,volume=$5dB,afade=t=in:d=0.02,areverse,afade=t=in:d=$6,areverse,adelay=delays=$4:all=1[v$1];"; }
# Blasts: real explosion sound from Reuters Kyiv footage (raw/ukraina/rjkzy0l2U00, 8.15-11.35 s, no narration):
# reversed as a riser into the NBC fireball cut (2.40), then forward hits at 2.40 and under the Sky explosion (4.73).
T=$CUT
HEART="st(0,(70*t+35*t*t/$T)/60);st(1,60/(70+70*t/$T));st(2,(ld(0)-floor(ld(0)))*ld(1));st(3,ld(2)-0.3*ld(1));\
(0.75+0.25*t/$T)*(sin(2*PI*52*ld(2))*exp(-ld(2)/0.075)+0.35*sin(2*PI*104*ld(2))*exp(-ld(2)/0.04)\
+gte(ld(3),0)*(0.7*sin(2*PI*46*ld(3))*exp(-ld(3)/0.065)+0.25*sin(2*PI*92*ld(3))*exp(-ld(3)/0.035)))"
# breaking-point heart: 170 -> 240 BPM over the 1.04 s flash-cut
HEARTFAST="st(0,(170*t+70*t*t/(2*1.04))/60);st(1,60/(170+70*t/1.04));st(2,(ld(0)-floor(ld(0)))*ld(1));st(3,ld(2)-0.3*ld(1));\
sin(2*PI*52*ld(2))*exp(-ld(2)/0.05)+0.35*sin(2*PI*104*ld(2))*exp(-ld(2)/0.03)+gte(ld(3),0)*0.7*sin(2*PI*46*ld(3))*exp(-ld(3)/0.045)"
DRONE="st(0,t+0.03*t*t/$T);(0.35+0.65*pow(t/$T,1.8))*(0.5*sin(2*PI*41.2*ld(0))+0.35*sin(2*PI*55*ld(0))\
+0.2*sin(2*PI*82.4*ld(0))+0.12*sin(2*PI*110.6*ld(0)))"

{
v 0 3.25 0.95 2650  0.0 0.25   # ABC    "Oh my god."
v 1 0.36 1.20 3400  0.0 0.10   # NBC    "Oh, another one just hit."
v 2 1.00 2.30 4400  2.0 0.60   # Sky    Kyiv air-raid sirens (no speech), synced to shot 3
v 3 0.00 1.46 6400  1.6 0.05   # TVP    "Słychać było syrenę." (+ sirens), synced
v 4 3.40 2.58 9150  1.5 0.08   # BBC    "knocking some TV channels off air"
v 5 1.05 1.80 11650 1.6 0.06   # euronews "Millions were left without power"
v 6 1.80 2.00 12600 1.0 0.08   # TVN24  "Z minuty na minutę jest coraz gorzej."
v 7 3.30 3.23 14000 1.6 0.03   # TVN24  "drony wtargnęły na terytorium Polski." ("Polski" ends src 6.50 -> film 17.20)
v 8 2.38 1.08 14850 0.0 0.06   # Polsat "alert RCB"
cat <<EOF
aevalsrc=exprs=0:s=48000:d=$T,aformat=sample_fmts=fltp:channel_layouts=stereo[z];
[z][v0][v1][v2][v3][v4][v5][v6][v7][v8]amix=inputs=10:normalize=0:duration=first,asplit[vox][sc];
aevalsrc=exprs='$HEART':s=48000:d=$T,volume=0.42,aformat=sample_fmts=fltp:channel_layouts=stereo[heart];
aevalsrc=exprs='$DRONE':s=48000:d=$T,volume=0.30,aformat=sample_fmts=fltp:channel_layouts=stereo[tone];
anoisesrc=color=brown:r=48000:a=0.6:d=$T,lowpass=f=180,highpass=f=28,volume='0.08+0.5*pow(t/$T,2)':eval=frame,aformat=sample_fmts=fltp:channel_layouts=stereo[rumble];
[heart][tone][rumble]amix=inputs=3:normalize=0[bed];
[9:a]atrim=start=8.15:duration=3.2,asetpts=PTS-STARTPTS,aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,asplit=4[x1][x2][x3][x4];
[x1]areverse,atrim=start=0.75,asetpts=PTS-STARTPTS,volume=-1dB,afade=t=in:d=0.6[rise];
[x2]volume=-3dB,adelay=delays=2350:all=1[hit1];
[x3]adelay=delays=4680:all=1[hit2];
aevalsrc=exprs=0:s=48000:d=$T,aformat=sample_fmts=fltp:channel_layouts=stereo[z2];
[x4]areverse,atrim=start=1.8,asetpts=PTS-STARTPTS,afade=t=in:d=0.5,adelay=delays=17050:all=1[rise2];
[10:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,volume='if(lt(t,1.70),0.22,1.6)':eval=frame,adelay=delays=15560:all=1[bn];
aevalsrc=exprs='$HEARTFAST':s=48000:d=1.04,volume=0.7,aformat=sample_fmts=fltp:channel_layouts=stereo,adelay=delays=17360:all=1[hf];
[z2][rise][hit1][hit2][rise2][bn][hf]amix=inputs=7:normalize=0:duration=first[fx];
[bed][sc]sidechaincompress=threshold=0.012:ratio=10:attack=10:release=300[bedd];
[bedd][vox][fx]amix=inputs=3:normalize=0:duration=first,alimiter=limit=0.35:attack=5:release=60:level=false[mix]
EOF
} > "$TMP/audio.graph"

"$FF" -v error -y \
  -i "$TV/11wrzesnia/02_abc_druga_maszyna_uderzenie.mp4" \
  -i "$TV/11wrzesnia/01_nbc_druga_maszyna_kula_ognia.mp4" \
  -i "$TV/ukraina/02_sky_noc_wybuch_syreny_kijow.mp4" \
  -i "$TV/ukraina/01_tvp_alarm_przeciwlotniczy_kijow.mp4" \
  -i "$TV/cyberatak/frazy/06_knocking-some-tv-channels-off-air.mp4" \
  -i "$TV/blackout2025/frazy/04_millions-were-left-without-power.mp4" \
  -i "$TV/powodz2024/frazy/04_z_minuty_na_minute_coraz_gorzej.mp4" \
  -i "$TV/drony2025/frazy/03_obce_drony_wtargnely_na_terytorium_polski.mp4" \
  -i "$TV/pilne/frazy/02_pojawil_sie_alert_rcb_zagrozenie_atakiem_z_powietrza.mp4" \
  -i "../../tv/raw/ukraina/rjkzy0l2U00_x.mp4" \
  -i "$TMP/burst.wav" \
  -filter_complex_script "$TMP/audio.graph" -map "[mix]" -c:a pcm_f32le "$TMP/mix.wav"

# two-pass loudnorm: -16 LUFS, true peak target -1.5 dBTP (margin for AAC), then hard cut + silence
"$FF" -nostats -i "$TMP/mix.wav" -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json -f null - 2> "$TMP/ln1.txt"
m() { grep "\"$1\"" "$TMP/ln1.txt" | sed -E 's/.*: "([^"]+)".*/\1/'; }
LN="loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=$(m input_i):measured_TP=$(m input_tp):measured_LRA=$(m input_lra):measured_thresh=$(m input_thresh):offset=$(m target_offset):linear=true:print_format=json"
"$FF" -nostats -y -i "$TMP/mix.wav" \
  -af "$LN,aresample=48000,afade=t=out:st=$(echo "$CUT - 0.01" | bc):d=0.01,apad=whole_dur=$TOTAL,atrim=0:$TOTAL" \
  -c:a pcm_s16le "$TMP/audio.wav" 2> "$TMP/ln2.txt"
grep normalization_type "$TMP/ln2.txt"

# ---------------------------------------------------------------- 4. burn subtitles, encode, mux
"$FF" -v error -y -i "$TMP/picture.mp4" -i "$TMP/audio.wav" \
  -vf "subtitles=$TMP/subs.ass:fontsdir=../plansze/fonts" \
  -map 0:v -map 1:a -c:v libx264 -crf 16 -preset slow -pix_fmt yuv420p -r $FPS \
  -c:a aac -b:a 256k -ar 48000 -ac 2 -t $TOTAL -movflags +faststart "$OUT"

# ---------------------------------------------------------------- 5. contact sheet (one frame every 0.5 s)
"$FF" -v error -y -i "$OUT" -vf "fps=2,scale=384:216,tile=6x6" -frames:v 1 -q:v 3 scena1_v1_kadry.jpg

[ "${KEEP_TMP:-0}" = 1 ] || rm -rf "$TMP"
echo "done: $OUT"
