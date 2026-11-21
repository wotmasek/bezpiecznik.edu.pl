# First-person "eyes" layer for an AI clip: natural head motion, eyelid blinks with defocus/refocus and exposure dip.
# python povfx.py in.mp4 out.mp4 --ss S --du D [--amp PX] [--blinks t1,t2] [--wake] [--seed N] [--vf FILTERS]
#
# Blink model (human spontaneous blink, high-speed eyelid studies): whole blink ~300-400 ms, closing ~40% faster
# than opening, full closure only 10-50 ms; the upper lid does almost all of the travel, the lower lid ~15%;
# the image dips darker (shadows go first) while closing; the eye rolls up during closure (Bell's phenomenon),
# so the view drifts a few px; after opening the eye needs ~0.2-0.3 s to re-acquire focus.
# Head motion: band-limited random drift (spline through random keys) + small physiological tremor + slight roll,
# never periodic sines.
import argparse, subprocess, numpy as np, cv2

W, H, FPS = 1920, 1080, 25
IW, IH = 2016, 1134                      # decode oversize: 5% margin for the motion

def spline(n, every, rng, sd):
    """Catmull-Rom spline through random keys, one value per frame."""
    k = rng.normal(0, sd, n // every + 4)
    out = np.empty(n)
    for i in range(n):
        u = i / every; j = int(u) + 1; f = u - int(u)
        p0, p1, p2, p3 = k[j - 1], k[j], k[j + 1], k[j + 2]
        out[i] = 0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f ** 3)
    return out

def tremor(n, rng, sd):
    x = rng.normal(0, 1, n + 20)
    x = np.convolve(x, cv2.getGaussianKernel(9, 1.6).ravel(), "same")[10:10 + n]
    return x / (x.std() + 1e-6) * sd

# openness per frame @25 fps
BLINK = [1, .5, .08, 0, .22, .48, .72, .88, .97, 1]
WAKE = list(np.interp(np.arange(48), [0, 8, 14, 18, 22, 30, 36, 41, 47],
                      [0, 0, .32, .26, .08, .12, .62, .55, 1]))

def lid_mask(o, nx, yy, rng_lash):
    """Alpha (0..1) of the eyelids for openness o. Upper lid travels, lower lid barely moves; both are curved."""
    yc = H * 0.64                                               # lids meet low in the view
    top = yc - (yc + 180) * o * (1 - 0.45 * nx ** 2)             # upper lid: almost all the travel
    bot = yc + (H - yc + 160) * min(1.0, o * 4) * (1 - 0.3 * nx ** 2) ** -1   # lower lid only rises at the very end
    edge = 70 + 150 * (1 - o)                                   # lid edge is right at the eye: always very soft
    a_top = np.clip((top - yy) / edge + 0.5, 0, 1)
    a_bot = np.clip((yy - bot) / edge + 0.5, 0, 1)
    lash = np.exp(-((yy - top) / (18 + 30 * (1 - o))) ** 2) * 0.35 * (o < 0.98)   # dark lash fringe under the lid edge
    return np.clip(np.maximum(a_top, a_bot) + lash * rng_lash, 0, 1)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inp"); ap.add_argument("out")
    ap.add_argument("--ss", type=float, default=0); ap.add_argument("--du", type=float, required=True)
    ap.add_argument("--amp", type=float, default=1.0)
    ap.add_argument("--blinks", default="")
    ap.add_argument("--wake", action="store_true")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--vf", default="null")
    a = ap.parse_args()
    n = int(round(a.du * FPS)); rng = np.random.default_rng(a.seed)
    dec = subprocess.Popen([f"/home/weak/bin/ffmpeg", "-v", "error", "-ss", str(a.ss), "-t", str(a.du + 0.2), "-i", a.inp,
        "-vf", f"fps={FPS},{a.vf},scale={IW}:{IH}:flags=lanczos", "-f", "rawvideo", "-pix_fmt", "bgr24", "-"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    enc = subprocess.Popen(["/home/weak/bin/ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgr24",
        "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-crf", "10", "-preset", "veryfast",
        "-pix_fmt", "yuv420p", a.out], stdin=subprocess.PIPE)
    # head motion (px at 1920) and roll (deg)
    dx = a.amp * (spline(n, 11, rng, 9) + tremor(n, rng, 1.2))
    dy = a.amp * (spline(n, 13, rng, 7) + tremor(n, rng, 1.0))
    rot = a.amp * spline(n, 17, rng, 0.35)
    # eyelid openness, defocus sigma, exposure per frame
    o = np.ones(n); sig = np.zeros(n)
    events = ([(0, WAKE, 9.0)] if a.wake else []) + [(int(round(float(t) * FPS)), BLINK, 4.0) for t in a.blinks.split(",") if t]
    for f0, prof, smax in events:
        for i, v in enumerate(prof):
            if 0 <= f0 + i < n: o[f0 + i] = min(o[f0 + i], v)
        opened = f0 + len(prof) - 1
        for i in range(f0, min(n, opened + 14)):
            x = (i - opened) / FPS
            s = smax * (1 - o[i]) if i < opened else smax * 0.75 * np.exp(-x / 0.11) + 1.2 * np.exp(-((x - 0.22) / 0.06) ** 2)
            sig[i] = max(sig[i], s)
        for i, v in enumerate(prof):                       # Bell's phenomenon: view sinks a little while closed
            if 0 <= f0 + i < n: dy[f0 + i] += 10 * (1 - v)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32); nx = (xx - W / 2) / (W / 2)
    lash_tex = 0.7 + 0.3 * cv2.resize(rng.random((H // 40, W // 6)).astype(np.float32), (W, H))
    for i in range(n):
        raw = dec.stdout.read(IW * IH * 3)
        if len(raw) < IW * IH * 3: break
        f = np.frombuffer(raw, np.uint8).reshape(IH, IW, 3)
        M = cv2.getRotationMatrix2D((IW / 2, IH / 2), rot[i], 1.0)
        M[0, 2] += dx[i] - (IW - W) / 2; M[1, 2] += dy[i] - (IH - H) / 2
        g = cv2.warpAffine(f, M, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
        if sig[i] > 0.3: g = cv2.GaussianBlur(g, (0, 0), sig[i])
        g = g.astype(np.float32)
        c = 1 - o[i]
        if c > 0:                                          # shadows fall off first while the lids close
            g = 255 * (g / 255) ** (1 + 1.2 * c) * (1 - 0.35 * c)
            m = lid_mask(o[i], nx, yy, lash_tex)[..., None]
            lid = np.array([4, 5, 9], np.float32) * (0.5 + g.mean() / 60)     # lids glow faintly warm in light
            g = g * (1 - m) + lid * m
        enc.stdin.write(np.clip(g, 0, 255).astype(np.uint8).tobytes())
    enc.stdin.close(); enc.wait(); dec.stdout.close(); dec.wait()

main()
