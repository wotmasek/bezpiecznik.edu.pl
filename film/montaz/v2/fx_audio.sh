#!/usr/bin/env bash
# POV sound layer for the AI scenes -> out/sc3_fx.wav (10.0 s), out/sc4_fx.wav (10.8 s, after the rewind),
# out/sc4b_fx.wav (6.56 s). ../render_film.sh mixes them over its bed (siren, heart, blast, lektor).
# Found-footage rule: the believable POV is carried by close natural sound (breath, taps, steps, the door), so every
# AI shot keeps the sound MiniMax H3 generated with it, cut exactly like the picture (shot times = build_v2.sh), plus
# synthesized details placed by fx_syn.py: phone taps on the REAL keystroke times of the Google capture, the phone
# hitting the floor, UI taps on the app, a heartbeat on the run to the shelter, and in 4b a 110/min pulse (the app's
# own CPR metronome tempo) that drives the montage and stops dead on the cut to scene 5.
set -euo pipefail
cd "$(dirname "$0")"
FF=~/bin/ffmpeg; C=clips; ST="aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo"
mkdir -p out/fx
~/ComfyUI/.venv/bin/python fx_syn.py

# seg <input idx> <src start> <dur> <film s> <gain dB> [extra filters]
seg() { echo "[$1:a]atrim=start=$2:duration=$3,asetpts=PTS-STARTPTS,$ST,afade=t=in:d=0.03,afade=t=out:st=$(awk "BEGIN{printf \"%.3f\", $3-0.08}"):d=0.08,volume=$5dB${6:+,$6},adelay=delays=$(echo "$4*1000/1" | bc):all=1"; }
# mix <out> <dur> <file...> -- <graph line...>   (silent full-length anchor first: adelay+amix pts gotcha)
mix() { local out=$1 dur=$2; shift 2; local ins=() n=0 g lab
  while [ "$1" != "--" ]; do ins+=(-i "$1"); shift; done; shift
  g="aevalsrc=0:s=48000:d=$dur,$ST[z];"; lab="[z]"
  for l in "$@"; do g+="$l[s$n];"; lab+="[s$n]"; n=$((n+1)); done
  $FF -v error -y "${ins[@]}" -filter_complex "$g${lab}amix=inputs=$((n+1)):normalize=0:duration=first,alimiter=limit=0.7:level=false" \
    -t $dur -c:a pcm_s16le out/$out.wav; }

# SCENE 3 · shots: 0 room | 1.92 Google typing | 4.12 lamp | 4.84 offline | 6.24 blinds | 7.52 floor | 8.30 black
mix sc3_fx 10.0 $C/room_s1.flac $C/phone_s1.flac $C/lamp_s1.flac $C/blinds_s1.flac $C/floor_s1.flac out/fx/sc3_syn.wav -- \
  "$(seg 0 0.30 1.92 0 -1)" \
  "$(seg 1 0.20 2.20 1.92 3 'highpass=f=150')" \
  "$(seg 2 0.30 0.72 4.12 2)" \
  "$(seg 1 1.00 1.40 4.84 3 'highpass=f=150')" \
  "$(seg 3 0.85 1.28 6.24 4)" \
  "$(seg 4 1.40 0.78 7.52 -2)" \
  "[5:a]$ST"

# SCENE 4 · shots: 0 "Co się dzieje?" | 2.0 status bar | 2.7 shelter card | 4.6 stairs | 5.6 compass | 7.2 door | 9.8 shelter
mix sc4_fx 10.8 $C/phone2_s1.flac $C/stairs_s1.flac $C/door_s1.flac $C/shelter_s1.flac $C/phone3_s1.flac out/fx/sc4_syn.wav -- \
  "$(seg 0 0.10 2.70 0 0 'highpass=f=150')" \
  "$(seg 4 0.10 1.90 2.70 0 'highpass=f=150')" \
  "$(seg 1 1.40 1.00 4.60 4)" \
  "$(seg 1 2.40 0.62 5.60 3)" \
  "$(seg 4 1.20 1.00 6.20 1 'highpass=f=150')" \
  "$(seg 2 0.20 2.60 7.20 3)" \
  "$(seg 3 0.20 1.00 9.80 -3)" \
  "[5:a]$ST"

# SCENE 4b · shots: 0 table | 1.0 insulin | 2.16 shelter | 3.16 "Zadzwoń 112" | 4.36 CPR shadow | 5.36 UCISKAJ
mix sc4b_fx 6.56 $C/table_s1.flac $C/shelter_s1.flac $C/cpr_s1.flac out/fx/sc4b_syn.wav -- \
  "$(seg 0 0.40 1.00 0 8)" \
  "$(seg 1 1.40 1.00 2.16 -4)" \
  "$(seg 2 0.40 1.00 4.36 -3)" \
  "[3:a]$ST"
for s in sc3 sc4 sc4b; do echo "${s}_fx $(~/bin/ffprobe -v error -show_entries format=duration -of csv=p=0 out/${s}_fx.wav)"; done
