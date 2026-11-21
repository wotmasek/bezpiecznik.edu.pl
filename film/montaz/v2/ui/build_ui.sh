#!/usr/bin/env bash
# Builds the phone-screen clips (904x1968, 24 fps) that get composited onto the green phone screens.
set -euo pipefail
cd "$(dirname "$0")"
FF=~/bin/ffmpeg
mkdir -p png out
shot() { google-chrome --headless=new --no-sandbox --disable-gpu --hide-scrollbars --user-data-dir="$PWD/png/chrome" \
  --window-size=904,1968 --virtual-time-budget=1500 --screenshot="$PWD/png/$1.png" "file://$PWD/browser.html?$2" 2>/dev/null; }
# scene 3: frantic typing (1 char per ~1.5 frames), spinner, then the offline page with two taps on "Spróbuj ponownie"
: > png/search.txt
for n in $(seq 0 29); do f=$(printf "t%02d" $n); shot $f "s=type&n=$n"; d=0.0625; [ $n -eq 29 ] && d=0.25
  echo "file '$f.png'" >> png/search.txt; echo "duration $d" >> png/search.txt; done
for n in $(seq 0 23); do f=$(printf "l%02d" $n); shot $f "s=load&n=$n"; echo "file '$f.png'" >> png/search.txt; echo "duration 0.0417" >> png/search.txt; done
echo "file 'l23.png'" >> png/search.txt
shot off0 "s=off&n=0"; shot off1 "s=off&n=1"
printf "file 'off0.png'\nduration 0.8\nfile 'off1.png'\nduration 0.2\nfile 'off0.png'\nduration 0.5\nfile 'off1.png'\nduration 0.2\nfile 'off0.png'\nduration 1.3\nfile 'off0.png'\n" > png/offline.txt
for c in search offline; do
  "$FF" -v error -y -f concat -safe 0 -i png/$c.txt -vf "fps=24,format=yuv420p" -c:v libx264 -crf 12 out/ui_$c.mp4
done
# Bezpiecznik screens straight from the storyboard animation: crop the phone screen (452x984 at 358,48)
A=~/Pobrane/ciemny_pokoj_v2.mp4
seg() { "$FF" -v error -y -ss $2 -t $3 -i "$A" -vf "crop=452:984:358:48,scale=904:1968:flags=lanczos,fps=24,format=yuv420p" -an -c:v libx264 -crf 12 out/ui_$1.mp4; }
seg home     20.6 1.2   # "Co się dzieje?" with offline badge
seg pradu     8.0 6.0   # typing "nie ma prądu co robić" -> answer card with sources
seg wody     15.8 4.4   # "nie ma wody" -> answer + 72 h water note
seg schron   21.6 2.2   # nearest shelter on the offline map
seg plecak   23.6 2.6   # "Zanim wyjdziesz" checklist
seg kompas   27.0 1.6   # compass 350 m
seg oddech   32.6 1.6   # "Ktoś nie oddycha" rescue card
seg rko      36.0 1.6   # UCISKAJ 14/30 metronome
seg lek      39.2 3.4   # "jaki lek dać psu" -> "Nie mam tego w oficjalnych źródłach"
echo done
