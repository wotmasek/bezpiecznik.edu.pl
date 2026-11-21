#!/usr/bin/env bash
# Film v2: builds the AI POV pictures of scenes 3, 4 (after the rewind) and 4b -> out/sc3.mp4, out/sc4.mp4, out/sc4b.mp4
# (exact scene lengths; ../render_film.sh picks them up instead of the slates and adds sound, lektor and titles).
# No AI-generated phones (they read as AI): every phone moment is an extreme macro of a REAL screen capture
# (makro.py): Google on an emulated Pixel 7 + Chrome's real offline page (ui/record_google.py) and the Bezpiecznik
# design-system screens rendered at 3x (ui/ds_render.py). AI clips (gen.py) are only the rooms, light and people.
# pov.sh adds the eyes (head motion, natural blinks, refocus) and the body-camera look.
set -euo pipefail
cd "$(dirname "$0")"
FF=~/bin/ffmpeg; PY=~/ComfyUI/.venv/bin/python
S=out/sh; mkdir -p $S
G=ui/google; D=ui/ds
# finished shot: sh <src> <name> <start> <dur> [amp] [blinks] [wake] [cy] [prefilter]
sh() { ./pov.sh "$1" $S/$2.mp4 $3 $4 ${5:-1} "${6:-}" ${7:-0} ${8:-138} "${9:-null}"; }
# macro of a screen: mk <name> <x y w h tilt focus_y> <png:dur ...>   (then sh $S/<name>_m.mp4 ...)
mk() { local n=$1; shift; $PY makro.py $S/${n}_m.mp4 "$@"; }
shm() { POV_LIGHT=1 sh "$@"; }          # app screens: lighter vignette / edge blur so the UI reads
PIX="split[a0][c0];[c0]crop=56:60:322:342,scale=6:6,scale=56:60:flags=neighbor[p0];[a0][p0]overlay=322:342,split[a1][c1];[c1]crop=52:58:398:344,scale=5:6,scale=52:58:flags=neighbor[p1];[a1][p1]overlay=398:344,split[a2][c2];[c2]crop=46:54:488:352,scale=5:6,scale=46:54:flags=neighbor[p2];[a2][p2]overlay=488:352,split[a3][c3];[c3]crop=52:60:572:342,scale=5:6,scale=52:60:flags=neighbor[p3];[a3][p3]overlay=572:342,split[a4][c4];[c4]crop=54:64:815:338,scale=6:7,scale=54:64:flags=neighbor[p4];[a4][p4]overlay=815:338,split[a5][c5];[c5]crop=54:60:893:338,scale=6:6,scale=54:60:flags=neighbor[p5];[a5][p5]overlay=893:338,split[a6][c6];[c6]crop=50:64:988:332,scale=5:7,scale=50:64:flags=neighbor[p6];[a6][p6]overlay=988:332,split[a7][c7];[c7]crop=54:70:1078:296,scale=6:7,scale=54:70:flags=neighbor[p7];[a7][p7]overlay=1078:296,split[a8][c8];[c8]crop=74:90:1128:292,scale=8:10,scale=74:90:flags=neighbor[p8];[a8][p8]overlay=1128:292"   # 9 faces in the shelter, pixelated (source 1344x768)
# CPR: keep the person lying on the floor OUT of frame (no victims on screen): only the rescuer's huge shadow on the
# wall and his pumping silhouette, face pixelated (source 1344x768 coordinates)
CPRF="split[a][b];[b]crop=104:136:640:322,scale=10:13,scale=104:136:flags=neighbor[p];[a][p]overlay=640:322,crop=768:432:230:110"

want() { [ -z "${ONLY:-}" ] || [[ " $ONLY " == *" $1 "* ]]; }   # ONLY="sc3 sc4" builds just those

# Google typing: real keystroke timing, compressed 2.4x (frantic), ending on the suggestions
TYPING=$(python3 - <<'EOF'
L=[l.split() for l in open('ui/google/times.txt')]
sel=[l for l in L if 8<=int(l[0])<=36]
out=[]
for a,b in zip(sel,sel[1:]+[None]):
    d=(float(b[1])-float(a[1]))/2.4 if b else 0.4
    out.append(f"ui/google/{a[0]}.png:{max(0.04,round(d/0.04)*0.04):.2f}")
print(' '.join(out))
EOF
)

if want sc3; then
# ---------------------------------------------------------------- SCENE 3 · Brak połączenia (10.0 s; picture 0-8.3, then black under the title)
sh clips/room_s1.mp4 3a 0.30 1.92 1 "" 1                                   # eyes open: dark bedroom, siren outside
mk 3b 20 -210 880 495 -2.5 0.55 $TYPING; sh $S/3b_m.mp4 3b 0 2.20 0.9      # "syrena wyje gdzie sie schowac", real suggestions
sh clips/lamp_s1.mp4 3c 0.30 0.72 0.8                                      # the lamp dies
mk 3d1 -120 230 560 315 2.0 0.5 $G/037.png:0.70
mk 3d2 20 450 900 506 -1.5 0.5 $G/037.png:0.80
$FF -v error -y -i $S/3d1_m.mp4 -i $S/3d2_m.mp4 -filter_complex "[0:v][1:v]concat=n=2:v=1" -c:v libx264 -crf 10 $S/3d_m.mp4
sh $S/3d_m.mp4 3d 0 1.40 1.1 "0.62"                                        # Chrome's offline dinosaur, blink
sh clips/blinds_s1.mp4 3e 0.85 1.28 2.2                                    # light floods through the blinds, the view jerks
sh clips/floor_s1.mp4 3f 1.40 0.78 0.5                                     # the phone lies face down
$FF -v error -y -f lavfi -i "color=black:s=1920x1080:r=25:d=1.7" -c:v libx264 -crf 10 -pix_fmt yuv420p $S/3z.mp4

fi
if want sc4; then
# ---------------------------------------------------------------- SCENE 4 · Jeszcze raz (10.8 s after the 0.7 s rewind)
mk 4a1 0 230 1170 658 1.5 0.45 $D/ScreensChat_0.png:1.10                 # eyes open again: "Co się dzieje?"
mk 4a2 -125 907 900 506 -2 0.5 $D/ScreensChat_0.png:1.10                  # ...the eye drops to "Alarm / schron"
$FF -v error -y -i $S/4a1_m.mp4 -i $S/4a2_m.mp4 -filter_complex "[0:v][1:v]concat=n=2:v=1" -c:v libx264 -crf 10 $S/4a_m.mp4
shm $S/4a_m.mp4 4a 0 2.00 0.9 "0"
mk 4b 560 -60 610 343 -2 0.45 $D/ScreensChat_0.png:1.0; shm $S/4b_m.mp4 4b 0 0.70 0.7     # 03:41, airplane mode: offline
mk 4c -230 1690 1430 804 -1.5 0.45 $D/ScreensMap_0.png:2.2; shm $S/4c_m.mp4 4c 0 1.90 0.9      # nearest shelter, "Prowadź"
sh clips/stairs_s1.mp4 4d 1.40 1.00 1.6                                    # running down the stairwell
NEEDLE=$(for i in 00 01 02 03 04 05 06 07 08 09 10; do printf "$D/rot_$i.png:0.08 "; done)
mk 4e1 48 712 996 560 2 0.5 $NEEDLE                                       # compass needle swings and settles
mk 4e2 48 1239 996 560 -1 0.5 $D/rot_12.png:0.80                          # 350 m
$FF -v error -y -i $S/4e1_m.mp4 -i $S/4e2_m.mp4 -filter_complex "[0:v][1:v]concat=n=2:v=1" -c:v libx264 -crf 10 $S/4e_m.mp4
shm $S/4e_m.mp4 4e 0 1.60 1.3
sh clips/door_sign_s1.mp4 4f 0.20 2.60 1.0 "2.2"                                # the shelter door opens, all-clear starts
sh clips/shelter_s1.mp4 4g 0.20 1.00 0.7 "" 0 138 "$PIX"                  # inside: people waiting (faces pixelated)

fi
if want sc4b; then
# ---------------------------------------------------------------- SCENE 4b · Każde zagrożenie dostaje odpowiedź (6.56 s = 3 beats)
sh clips/table_s1.mp4 5a 0.40 1.00 0.9                                     # packing water, insulin, documents
mk 5b 0 990 1170 658 -1.5 0.40 $D/ScreensChat_1.png:1.5; shm $S/5b_m.mp4 5b 0 1.16 0.8      # "Przełóż insulinę…" + source
sh clips/shelter_s1.mp4 5c 1.40 1.00 0.7 "0.0" 0 138 "$PIX,crop=700:394:300:220"   # punch-in: not the same frame as 4g
mk 5d 0 1830 1170 658 1.5 0.45 $D/ScreensPanels_0.png:1.5; shm $S/5d_m.mp4 5d 0 1.20 0.8    # "Zadzwoń 112"
sh clips/cpr_s1.mp4 5e 0.40 1.00 0.6 "" 0 138 "$CPRF"                  # shadow doing chest compressions
mk 5f -166 1481 1500 844 -1 0.5 $D/cnt_00.png:0.32 $D/cnt_01.png:0.28 $D/cnt_02.png:0.32 $D/cnt_03.png:0.40
shm $S/5f_m.mp4 5f 0 1.20 0.8       # "UCISKAJ 15 -> 18 / 30", ticking at 110/min

fi
cat_scene() { local out=$1 dur=$2; shift 2; local in="" f="" i=0
  for s in "$@"; do in="$in -i $S/$s.mp4"; f="$f[$i:v]"; i=$((i+1)); done
  $FF -v error -y $in -filter_complex "${f}concat=n=$i:v=1,fps=25,format=yuv420p[v]" -map "[v]" -t $dur \
    -c:v libx264 -crf 14 -preset slow out/$out.mp4; }
want sc3 && cat_scene sc3 10.0 3a 3b 3c 3d 3e 3f 3z
want sc4 && cat_scene sc4 10.8 4a 4b 4c 4d 4e 4f 4g
want sc4b && cat_scene sc4b 6.56 5a 5b 5c 5d 5e 5f
for s in sc3 sc4 sc4b; do [ -f out/$s.mp4 ] && echo "$s $(~/bin/ffprobe -v error -show_entries format=duration -of csv=p=0 out/$s.mp4)"; done
