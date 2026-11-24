#!/usr/bin/env bash
# ask.sh <id> "<ascii text>" : types into the composer, sends, waits for the answer, saves shot + text dump.
A="$HOME/Android/Sdk/platform-tools/adb -s 47270DLAQ00421"
D=$(dirname "$0"); id=$1; q=$2
$A shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
xy=$($A shell cat /sdcard/ui.xml | python3 -c "
import sys,re
x=sys.stdin.read()
m=re.search(r'class=\"android.widget.EditText\"[^>]*bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"',x)
if m: a=list(map(int,m.groups())); print((a[0]+a[2])//2,(a[1]+a[3])//2)")
$A shell input tap $xy; sleep 0.5
$A shell input text "$(printf '%s' "$q" | sed 's/ /%s/g; s/[?]/\\?/g; s/[(]/\\(/g; s/[)]/\\)/g; s/[,]/,/g')"
sleep 0.5; "$D/drive.sh" tap "Wyślij" >/dev/null; t0=$(date +%s)
sleep 3
for i in $(seq 1 60); do
  $A shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  x=$($A shell cat /sdcard/ui.xml)
  echo "$x" | grep -qE 'Zatrzymaj|Szukam|Układam|Uruchamiam' || break
  sleep 2
done
echo "[$id] ${q}  (~$(( $(date +%s)-t0 )) s)" | tee -a "$D/log.txt"
$A shell cat /sdcard/ui.xml | python3 -c "
import sys,re,html
x=sys.stdin.read()
vals=[html.unescape(v) for v in re.findall(r'(?:content-desc|text)=\"([^\"]+)\"',x)]
skip={'Menu','Mapa','Wyślij','Pokaż na mapie'}
print('\n'.join('  | '+v.replace('\n',' / ') for v in vals if v not in skip and not v.startswith('SOS')))" | tee -a "$D/log.txt"
$A exec-out screencap -p > "$D/$id.png"
