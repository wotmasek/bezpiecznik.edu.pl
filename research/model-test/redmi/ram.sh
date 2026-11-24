#!/usr/bin/env bash
# Samples PSS of the app every 3 s: "<epoch_ms> <pss_kb>"
while true; do
  v=$($HOME/Android/Sdk/platform-tools/adb -s d1529237 shell dumpsys meminfo pl.edu.bezpiecznik.bezpiecznik 2>/dev/null | awk '/TOTAL PSS:/{print $3}')
  [ -n "$v" ] && echo "$(date +%s%3N) $v"
  sleep 3
done
