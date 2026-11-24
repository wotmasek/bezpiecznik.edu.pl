#!/usr/bin/env bash
cd "$(dirname "$0")"; export SERIAL=d1529237
A="$HOME/Android/Sdk/platform-tools/adb -s $SERIAL"
(while true; do $A shell input keyevent KEYCODE_SHIFT_LEFT; sleep 10; done) & KEEP=$!
(while true; do v=$($A shell dumpsys meminfo pl.edu.bezpiecznik.bezpiecznik 2>/dev/null | awk '/TOTAL PSS:/{print $3}'); a=$($A shell cat /proc/meminfo | awk '/MemAvailable/{print $2}'); echo "$(date +%s) $v $a" >> ram_batch.log; sleep 4; done) & RAM=$!
$A shell screenrecord --bit-rate 4000000 --time-limit 180 /sdcard/rm_1.mp4 & 
./batch.sh
kill $KEEP $RAM 2>/dev/null; $A shell pkill -INT screenrecord; sleep 3; $A pull /sdcard/rm_1.mp4 rec_01.mp4 >/dev/null 2>&1
echo ALLDONE >> log.txt
