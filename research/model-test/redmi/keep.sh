#!/usr/bin/env bash
# Pokes user activity on the Redmi every 10 s (Shift key: no text, no taps). Stop with: kill $(cat keep.pid)
echo $$ > "$(dirname "$0")/keep.pid"
while true; do $HOME/Android/Sdk/platform-tools/adb -s d1529237 shell input keyevent KEYCODE_SHIFT_LEFT; sleep 10; done
