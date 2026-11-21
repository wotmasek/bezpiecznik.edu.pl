# Eyelid overlays (1920x1080 RGBA PNG sequences): black lids with a soft curved edge, openness 0..1.
# blink = quick close/open (9 frames @25), wake = heavy eyes fluttering open (36 frames).
import os, numpy as np
from PIL import Image, ImageFilter
W, H = 1920, 1080
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
nx = (xx - W / 2) / (W / 2)
def lid(o):
    o = max(0.0, min(1.0, o))
    half = (H / 2 + 120) * o                       # half-height of the eye opening at the centre
    curve = (1 - 0.55 * nx ** 2)                   # lids curve towards the corners
    top = H / 2 - half * curve - 18 * (1 - o)      # upper lid comes down further than the lower one rises
    bot = H / 2 + half * curve * 0.85
    a = np.where((yy < top) | (yy > bot), 255, 0).astype(np.uint8)
    im = Image.fromarray(a).filter(ImageFilter.GaussianBlur(float(40 + 60 * (1 - o))))
    rgba = np.zeros((H, W, 4), np.uint8); rgba[..., 3] = np.array(im)
    return Image.fromarray(rgba, "RGBA")
seqs = {"blink": [1, .55, .12, 0, 0, .18, .5, .8, 1],
        "wake": [float(v) for v in np.interp(range(36), [0, 6, 10, 14, 19, 24, 30, 35], [0, .28, .12, .05, .45, .3, .8, 1])]}
for n, s in seqs.items():
    os.makedirs(n, exist_ok=True)
    for i, o in enumerate(s): lid(o).save(f"{n}/{i:03d}.png")
print("ok")
