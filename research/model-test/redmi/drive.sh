#!/usr/bin/env bash
# Tiny adb driver for screenshots: tap <label-substring> | shot <name> | type <text> | dump
A="$HOME/Android/Sdk/platform-tools/adb -s ${SERIAL:?set SERIAL}"
D=$(dirname "$0")
case "$1" in
  dump) $A shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; $A shell cat /sdcard/ui.xml | grep -oE '(content-desc|text)="[^"]+"[^>]*bounds="[^"]+"' ;;
  tap)
    $A shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    b=$($A shell cat /sdcard/ui.xml | python3 -c "
import sys,re
x=sys.stdin.read()
for m in re.finditer(r'<node [^>]*>', x):
    n=m.group(0)
    t=re.search(r'(?:text|content-desc)=\"([^\"]*)\"', n)
    if any('$2' in v for v in re.findall(r'(?:text|content-desc)=\"([^\"]*)\"', n)):
        bb=re.search(r'bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"', n)
        if bb:
            a=list(map(int,bb.groups())); print((a[0]+a[2])//2,(a[1]+a[3])//2); break")
    [ -z "$b" ] && { echo "not found: $2"; exit 1; }
    $A shell input tap $b ;;
  type) $A shell input text "$(echo "$2" | sed 's/ /%s/g')" ;;
  shot) $A exec-out screencap -p > "$D/$2.png" ;;
esac
