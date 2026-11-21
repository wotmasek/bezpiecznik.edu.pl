#!/usr/bin/env bash
# POV finish for one AI clip -> 1920x1080 25 fps, picture in the 2.39:1 frame (804 px), black bars.
# pov <in> <out> <start s> <dur s> [motion amp] [blink times "t1,t2"] [wake 0|1] [crop top cy] [pre-filters, e.g. face pixelation]
# 1) povfx.py: head motion (random spline + tremor + roll), natural blinks with defocus/refocus and exposure dip.
# 2) body-camera look after the Bodycam/Unrecord games (realism = real-camera degradation): barrel lens with dark
#    rounded corners, blurred edges, halation bloom, teal-black shadows, low saturation, chromatic fringe, grain, vignette.
set -euo pipefail
in=$1 out=$2 ss=$3 du=$4 amp=${5:-1} bl=${6:-} wk=${7:-0} cy=${8:-138} ex=${9:-null}
D=$(cd "$(dirname "$0")" && pwd)
# POV_LIGHT=1 (app screen macros): lighter vignette and less edge blur so the UI reads, same look otherwise
if [ "${POV_LIGHT:-0}" = 1 ]; then VIG="PI/3.9"; EB="lut=c0=val*0.6"; else VIG="PI/3"; EB="null"; fi
tmp="${out%.mp4}_eye.mp4"
~/ComfyUI/.venv/bin/python "$D/povfx.py" "$in" "$tmp" --ss "$ss" --du "$du" --amp "$amp" --blinks "$bl" --vf "$ex" \
  --seed $(( $(cksum <<< "$out" | cut -d' ' -f1) % 1000 )) $([ "$wk" = 1 ] && echo --wake)
"$HOME/bin/ffmpeg" -v error -y -i "$tmp" -loop 1 -i "$D/fx/edgeblur.png" -filter_complex "
 [0:v]format=gbrp,lenscorrection=k1=0.08:k2=0.02:i=bilinear,scale=1980:-2,crop=1920:1080,split[a][b];
 [b]gblur=sigma=9,format=gbrap[bl];[1:v]format=gray,$EB,setpts=PTS-STARTPTS[m];[bl][m]alphamerge[blm];[a][blm]overlay=shortest=1:format=gbrp[e];
 [e]split[c][d];[d]gblur=sigma=24,curves=all='0/0 0.55/0.32 1/1'[gl];[c][gl]blend=all_mode=screen:all_opacity=0.34,
 curves=r='0/0.02 0.5/0.42 1/0.92':g='0/0.025 0.5/0.45 1/0.94':b='0/0.045 0.5/0.48 1/0.95',
 eq=saturation=0.68:contrast=1.05:brightness=0.0:gamma=1.15,
 rgbashift=rh=-4:bh=4,noise=alls=20:allf=t+u,vignette=angle=$VIG:mode=forward,
 crop=1920:804:0:$cy,pad=1920:1080:0:138:black,setsar=1,format=yuv420p[v]" \
 -map "[v]" -an -t "$du" -c:v libx264 -crf 14 -preset veryfast "$out"
rm -f "$tmp"
