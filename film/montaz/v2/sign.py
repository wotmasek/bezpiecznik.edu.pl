# Puts a real "SCHRON" sign onto the blank white plate of the AI shelter door: the plate is found in every frame
# (bright, unsaturated, rectangular), the sign is warped onto it and lit like the plate (brightness, softness).
# python sign.py in.mp4 out.mp4
import sys, subprocess, numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont

def sign_img(w=600, h=300):
    im = Image.new("RGB", (w, h), (236, 236, 230)); d = ImageDraw.Draw(im)
    f = ImageFont.truetype("/home/weak/Dokumenty/bezpiecznik/Bezpiecznik/film/montaz/plansze/fonts/InterDisplay-SemiBold.ttf", 118)
    d.rectangle([14, 14, w - 15, h - 15], outline=(30, 30, 30), width=8)
    tw = d.textlength("SCHRON", font=f); d.text(((w - tw) / 2, 70), "SCHRON", font=f, fill=(25, 25, 25))
    return cv2.cvtColor(np.array(im), cv2.COLOR_RGB2BGR)

def main():
    inp, out = sys.argv[1:3]
    cap = cv2.VideoCapture(inp); fps = cap.get(cv2.CAP_PROP_FPS)
    w, h = int(cap.get(3)), int(cap.get(4))
    enc = subprocess.Popen(["/home/weak/bin/ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgr24", "-s", f"{w}x{h}",
        "-r", str(fps), "-i", "-", "-c:v", "libx264", "-crf", "10", "-pix_fmt", "yuv420p", out], stdin=subprocess.PIPE)
    S = sign_img(); sh, sw = S.shape[:2]
    src = np.float32([[0, 0], [sw, 0], [sw, sh], [0, sh]])
    prev = None; pg = None; pts = None
    while True:
        ok, f = cap.read()
        if not ok: break
        g = cv2.cvtColor(f, cv2.COLOR_BGR2GRAY)
        q = None
        if prev is None:                       # detect the plate once (bright, unsaturated, rectangular)
            hsv = cv2.cvtColor(f, cv2.COLOR_BGR2HSV)
            m = cv2.morphologyEx(cv2.inRange(hsv, (0, 0, 150), (180, 45, 255)), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
            cnts, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            for c in sorted(cnts, key=cv2.contourArea, reverse=True)[:3]:
                r = cv2.minAreaRect(c); rw, rh = r[1]
                if cv2.contourArea(c) > 2500 and rw * rh > 0 and cv2.contourArea(c) / (rw * rh) > 0.8:
                    p = cv2.boxPoints(r); s_, d_ = p.sum(1), np.diff(p, axis=1).ravel()
                    q = np.float32([p[np.argmin(s_)], p[np.argmin(d_)], p[np.argmax(s_)], p[np.argmax(d_)]]); break
        elif pts is not None and len(pts) >= 8:  # planar tracking: features on the door around the plate -> homography
            nxt, st, _ = cv2.calcOpticalFlowPyrLK(pg, g, pts, None, winSize=(31, 31), maxLevel=4)
            good = st.ravel() == 1
            if good.sum() >= 8:
                Hm, inl = cv2.findHomography(pts[good], nxt[good], cv2.RANSAC, 3.0)
                if Hm is not None:
                    q = cv2.perspectiveTransform(prev.reshape(-1, 1, 2), Hm).reshape(4, 2).astype(np.float32)
                    pts = nxt[good].reshape(-1, 1, 2)
        draw = q is not None
        if q is not None and prev is not None:
            # snap to the detected plate when it is clearly there (fixes scale drift of the tracker)
            hsv = cv2.cvtColor(f, cv2.COLOR_BGR2HSV)
            m = cv2.morphologyEx(cv2.inRange(hsv, (0, 0, 150), (180, 45, 255)), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
            cnts, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            pa = cv2.contourArea(q.reshape(-1, 1, 2)); cx, cy = q.mean(0)
            for c in cnts:
                a = cv2.contourArea(c)
                if not (0.6 * pa < a < 2.0 * pa) or cv2.pointPolygonTest(c, (float(cx), float(cy)), False) < 0: continue
                hull = cv2.convexHull(c); ap = cv2.approxPolyDP(hull, 0.04 * cv2.arcLength(hull, True), True)
                if len(ap) == 4 and a / cv2.contourArea(hull) > 0.9:
                    p_ = ap.reshape(4, 2).astype(np.float32); s_, d_ = p_.sum(1), np.diff(p_, axis=1).ravel()
                    q = np.float32([p_[np.argmin(s_)], p_[np.argmin(d_)], p_[np.argmax(s_)], p_[np.argmax(d_)]]); pts = None
                    break
            # only draw while a bright plate is really under the sign (stops a floating sign once the door swings)
            mk = np.zeros(f.shape[:2], np.uint8); cv2.fillConvexPoly(mk, q.astype(np.int32), 255)
            draw = (mk > 0).any() and hsv[..., 2][mk > 0].mean() > 135 and hsv[..., 1][mk > 0].mean() < 60
        if q is not None:
            # (re)seed features on the door around the plate
            mask = np.zeros_like(g); c = q.mean(0); big = (q - c) * 2.2 + c
            cv2.fillConvexPoly(mask, big.astype(np.int32), 255)
            if pts is None or len(pts) < 40:
                pts = cv2.goodFeaturesToTrack(g, 200, 0.01, 6, mask=mask)
            if q[:, 0].max() < 0 or q[:, 0].min() > w or q[:, 1].max() < 0 or q[:, 1].min() > h: q = None
        pg = g
        if q is not None:
            prev = q
        if q is not None and draw:
            H = cv2.getPerspectiveTransform(src, q)
            ws = cv2.warpPerspective(S, H, (w, h), flags=cv2.INTER_AREA)
            inside = cv2.warpPerspective(np.full((sh, sw), 255, np.uint8), H, (w, h))
            plate = f[inside > 0].astype(np.float32).mean(0) if (inside > 0).any() else np.array([200, 200, 200])
            ws = cv2.GaussianBlur(ws, (0, 0), 1.0).astype(np.float32) * (plate / 236.0)   # lit like the plate
            a = cv2.GaussianBlur(inside, (0, 0), 1.0).astype(np.float32)[..., None] / 255
            f = (f * (1 - a) + ws * a).astype(np.uint8)
        enc.stdin.write(f.tobytes())
    enc.stdin.close(); enc.wait()

main()
