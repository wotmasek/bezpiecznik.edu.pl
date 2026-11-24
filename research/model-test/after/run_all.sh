#!/usr/bin/env bash
cd "$(dirname "$0")"
A="$HOME/Android/Sdk/platform-tools/adb -s 47270DLAQ00421"
(while true; do $A shell input keyevent KEYCODE_WAKEUP; sleep 20; done) & KEEP=$!
./rec.sh & REC=$!
./batch.sh
kill $REC $KEEP 2>/dev/null; $A shell pkill -INT screenrecord; sleep 4
for f in $($A shell ls /sdcard/ | grep -o 'rb_[0-9]*\.mp4'); do n=${f#rb_}; n=${n%.mp4}; [ -f rec_$(printf %02d $n).mp4 ] || $A pull /sdcard/$f rec_$(printf %02d $n).mp4 >/dev/null; done
echo ALLDONE >> log.txt
