# Extreme close-up of a phone screen "filmed" by the eye/camera: a small region of real screen captures is magnified
# so the RGB subpixels show, tilted in perspective, with a shallow focal band (the rest falls out of focus), screen
# glow and a raised black level. Too close and too optical to read as a screen recording.
# python makro.py out.mp4 x y w h tilt_deg focus_y <png:dur> [<png:dur> ...]
#   x y w h: region of the screen capture (pixels; y may be negative = dark bezel above); output 1920x1080 @25
import sys, subprocess, numpy as np, cv2

def main():
    out = sys.argv[1]; x, y, w, h = map(int, sys.argv[2:6]); tilt = float(sys.argv[6]); fy = float(sys.argv[7])
    seq = [(p.rsplit(":", 1)[0], float(p.rsplit(":", 1)[1])) for p in sys.argv[8:]]
    W, H = 1920, 1080
    enc = subprocess.Popen(["/home/weak/bin/ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgr24", "-s",
        f"{W}x{H}", "-r", "25", "-i", "-", "-c:v", "libx264", "-crf", "10", "-pix_fmt", "yuv420p", out], stdin=subprocess.PIPE)
    k = 3                                                   # each screen pixel -> k x k, then an RGB stripe mask
    stripe = np.zeros((k, k, 3), np.float32)
    for c, ch in enumerate([2, 1, 0]): stripe[:, c, ch] = 1.0   # BGR order: R | G | B columns
    stripe[k - 1, :, :] *= 0.55                               # dark row between pixel rows
    yy = np.linspace(-1, 1, H, dtype=np.float32)[:, None]
    depth = np.abs(yy - (fy * 2 - 1))                        # distance from the focal band
    t_total = 0.0
    for path, dur in seq:
        img = cv2.imread(path)
        pad = 400
        canvas = np.full((img.shape[0] + 2 * pad, img.shape[1] + 2 * pad, 3), (28, 26, 25), np.uint8)  # bezel / dark glass
        canvas[pad:pad + img.shape[0], pad:pad + img.shape[1]] = img
        reg = canvas[pad + y:pad + y + h, pad + x:pad + x + w].astype(np.float32)
        big = cv2.resize(reg, (w * k, h * k), interpolation=cv2.INTER_NEAREST)
        big = big * np.tile(stripe, (h, w, 1)) * 2.2
        big = cv2.GaussianBlur(big, (0, 0), 0.7)
        big = cv2.resize(big, (int(W * 1.25), int(H * 1.25)), interpolation=cv2.INTER_AREA)
        # perspective: the phone is tilted away at the top, slightly rotated
        bh, bw = big.shape[:2]
        src = np.float32([[0, 0], [bw, 0], [bw, bh], [0, bh]])
        dx = bw * 0.06
        dst = np.float32([[dx, 0], [bw - dx, 0], [bw, bh], [0, bh]])
        Mp = cv2.getPerspectiveTransform(src, dst)
        R = cv2.getRotationMatrix2D((bw / 2, bh / 2), tilt, 1.0); R = np.vstack([R, [0, 0, 1]])
        M = np.float32([[1, 0, -(bw - W) / 2], [0, 1, -(bh - H) / 2], [0, 0, 1]]) @ R @ Mp
        fr = cv2.warpPerspective(big, M, (W, H), borderValue=(20, 19, 18))
        # shallow depth of field: blend 3 blur levels by distance from the focal band
        b1 = cv2.GaussianBlur(fr, (0, 0), 4); b2 = cv2.GaussianBlur(fr, (0, 0), 12)
        a1 = np.clip(depth / 0.35, 0, 1)[..., None]; a2 = np.clip((depth - 0.35) / 0.5, 0, 1)[..., None]
        fr = fr * (1 - a1) + b1 * a1; fr = fr * (1 - a2) + b2 * a2
        glow = cv2.GaussianBlur(fr, (0, 0), 30)
        fr = fr + 0.35 * glow + 10                              # screen glow, raised black of a lit LCD
        n = int(round(dur * 25))
        f8 = np.clip(fr, 0, 255).astype(np.uint8).tobytes()
        for _ in range(n): enc.stdin.write(f8)
        t_total += dur
    enc.stdin.close(); enc.wait()

main()
