#!/usr/bin/env bash
# Emits one line per finished H3 clip and builds a graded preview with its generated sound: podglad/<name>.mp4
V=/home/weak/Dokumenty/bezpiecznik/Bezpiecznik/film/montaz/v2
O=$HOME/ComfyUI/output/bz2
cd $V
while true; do
  for d in $O/c_*_s1; do
    [ -d "$d" ] || continue
    n=$(basename $d); n=${n#c_}; n=${n%_s1}
    [ -f podglad/$n.mp4 ] && continue
    a=$(ls $d/a_*.flac 2>/dev/null | head -1); [ -n "$a" ] || continue
    [ "$(ls $d/f_*.png 2>/dev/null | wc -l)" -ge 73 ] || continue
    sleep 2
    ~/bin/ffmpeg -v error -y -framerate 24 -pattern_type glob -i "$d/f_*.png" -c:v libx264 -crf 12 -pix_fmt yuv420p podglad/_$n.mp4 \
      && ./pov.sh podglad/_$n.mp4 podglad/_${n}_pov.mp4 0 3.0 1 "" 0 >/dev/null 2>&1 \
      && ~/bin/ffmpeg -v error -y -i podglad/_${n}_pov.mp4 -i "$a" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -shortest podglad/$n.mp4 \
      && echo "READY $n $V/podglad/$n.mp4" || echo "FAILED $n"
    rm -f podglad/_$n.mp4 podglad/_${n}_pov.mp4
  done
  grep -h -i "error" clips.log 2>/dev/null | sort -u | sed 's/^/CLIPS-LOG /' | while read l; do grep -qxF "$l" podglad/.seen 2>/dev/null || { echo "$l"; echo "$l" >> podglad/.seen; }; done
  sleep 10
done
