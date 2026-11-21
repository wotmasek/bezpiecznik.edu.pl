# Green-screen phone compositor: finds the green phone screen in every frame of an AI plate, warps the UI clip
# onto it with the matching perspective, keeps whatever covers the screen (thumb) on top, despills green.
# Usage: python comp.py plate.mp4 ui.mp4 out.mp4 [plate_start_s] [dur_s] [ui_start_s] [ui_speed]
import sys, subprocess, numpy as np, cv2

def frames(path, w=None, h=None):
    cap = cv2.VideoCapture(path)
    while True:
        ok, f = cap.read()
        if not ok: return
        yield f

def quad(mask):
    cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not cnts: return None
    c = max(cnts, key=cv2.contourArea)
    if cv2.contourArea(c) < 2000: return None
    # all green blobs together (the thumb can split the screen), fitted with a rotated rectangle:
    # POV perspective on a hand-held phone is mild, and a rectangle cannot shear like a free quad
    pts = np.vstack([k for k in cnts if cv2.contourArea(k) > 300])
    ap = cv2.boxPoints(cv2.minAreaRect(cv2.convexHull(pts)))
    p = ap.reshape(4, 2).astype(np.float32)
    # order: top-left, top-right, bottom-right, bottom-left (UI is portrait, screen roughly upright)
    s, d = p.sum(1), np.diff(p, axis=1).ravel()
    return np.array([p[np.argmin(s)], p[np.argmin(d)], p[np.argmax(s)], p[np.argmax(d)]], np.float32)

def main():
    plate, ui, out = sys.argv[1:4]
    p0 = float(sys.argv[4]) if len(sys.argv) > 4 else 0
    dur = float(sys.argv[5]) if len(sys.argv) > 5 else 99
    u0 = float(sys.argv[6]) if len(sys.argv) > 6 else 0
    speed = float(sys.argv[7]) if len(sys.argv) > 7 else 1
    P = list(frames(plate)); U = list(frames(ui))
    a, n = int(round(p0 * 24)), int(round(dur * 24))
    P = P[a:a + n]
    h, w = P[0].shape[:2]
    uh, uw = U[0].shape[:2]
    src = np.array([[0, 0], [uw, 0], [uw, uh], [0, uh]], np.float32)
    enc = subprocess.Popen(["/home/weak/bin/ffmpeg", "-v", "error", "-y", "-f",
        "rawvideo", "-pix_fmt", "bgr24", "-s", f"{w}x{h}", "-r", "24", "-i", "-", "-c:v", "libx264", "-crf", "12",
        "-pix_fmt", "yuv420p", out], stdin=subprocess.PIPE)
    prev = None
    for i, f in enumerate(P):
        hsv = cv2.cvtColor(f, cv2.COLOR_BGR2HSV)
        m = cv2.inRange(hsv, (35, 150, 120), (90, 255, 255))
        m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
        q = quad(cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8)))
        if q is None: q = prev
        elif prev is not None: q = 0.6 * q + 0.4 * prev          # damp corner jitter
        prev = q
        g = f.astype(np.float32)
        u = U[min(int(u0 * 24 + i * speed), len(U) - 1)]
        # spill replacement: the green light of the screen on hands/duvet becomes the light of the real UI
        spill = np.clip(g[..., 1] - np.maximum(g[..., 0], g[..., 2]), 0, None)
        glow = np.clip(u.mean() / 255 * 1.6, 0.12, 1.0)
        g[..., 1] -= spill
        g += spill[..., None] * glow * np.array([0.95, 0.93, 0.88], np.float32)  # BGR: neutral, slightly cool
        if q is not None:
            u = cv2.GaussianBlur(u, (0, 0), 0.8)
            H = cv2.getPerspectiveTransform(src, q)
            wu = cv2.warpPerspective(u, H, (w, h), flags=cv2.INTER_LANCZOS4)
            inside = cv2.warpPerspective(np.full((uh, uw), 255, np.uint8), H, (w, h))
            alpha = cv2.GaussianBlur(cv2.bitwise_and(m, inside), (0, 0), 1.2).astype(np.float32)[..., None] / 255
            g = g * (1 - alpha) + wu.astype(np.float32) * alpha
        enc.stdin.write(np.clip(g, 0, 255).astype(np.uint8).tobytes())
    enc.stdin.close(); enc.wait()

main()
