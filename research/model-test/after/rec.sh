#!/usr/bin/env bash
# Records the phone screen in 170 s pieces until stopped (kill the script), then pulls them.
A="$HOME/Android/Sdk/platform-tools/adb -s 47270DLAQ00421"; D=$(dirname "$0"); i=0
trap 'exit 0' TERM INT
while true; do
  i=$((i+1)); $A shell screenrecord --bit-rate 4000000 --time-limit 170 /sdcard/rb_$i.mp4
  $A pull /sdcard/rb_$i.mp4 "$D/rec_$(printf %02d $i).mp4" >/dev/null 2>&1
done
