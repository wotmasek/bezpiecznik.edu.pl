# Renders the Bezpiecznik design-system screen mockups (ScreensChat/Map/Panels previews, React bundle) at 3x and saves
# every phone screen as a crisp PNG: ui/ds/<Screen>_<n>.png (1170x2532), for the macro close-ups of the app.
# Run: uv run --with playwright python ui/ds_render.py
import os
from playwright.sync_api import sync_playwright
DS = "/home/weak/Wideo/wotmasek_video_editing_studio/design_systems/Bezpiecznik"
R = "/home/weak/Wideo/wotmasek_video_editing_studio/projects/2026-10-18-alicja-wilk-4-mp-seniorow/edit/remotion/node_modules"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ds")
HEAD = f'''<link rel="stylesheet" href="file://{DS}/tokens.css"><link rel="stylesheet" href="file://{DS}/components/bundle.css">
<script src="file://{R}/react/umd/react.production.min.js"></script><script src="file://{R}/react-dom/umd/react-dom.production.min.js"></script>
<script src="file://{DS}/components/bundle.js"></script>'''
import sys as _s
if len(_s.argv) < 2: 
  with sync_playwright() as p:
    b = p.chromium.launch(channel="chrome", args=["--allow-file-access-from-files"])
    pg = b.new_page(viewport={"width": 1500, "height": 1000}, device_scale_factor=3)
    pg.on("console", lambda m: m.type == "error" and print("console:", m.text))
    for scr in ["ScreensChat", "ScreensMap", "ScreensPanels"]:
        src = open(f"{DS}/components/{scr}/preview.html").read().replace("<head>", "<head>" + HEAD, 1).replace("14:32", "03:41").replace("distance: 450", "distance: 350").replace("450, bearing", "350, bearing").replace("450, time", "350, time").replace("350, bearing: 315", "350, bearing: 45")
        path = f"{OUT}/{scr}.html"; open(path, "w").write(src)
        pg.goto("file://" + path); pg.wait_for_timeout(1500)
        phones = pg.locator(".phone")
        caps = pg.locator(".phone-cap")
        for i in range(phones.count()):
            phones.nth(i).screenshot(path=f"{OUT}/{scr}_{i}.png")
            print(scr, i, caps.nth(i).inner_text() if i < caps.count() else "")
    b.close()

# ---- animation frames (run: ... ds_render.py anim): compass needle settling onto the bearing, CPR counter ticking
import sys
if len(sys.argv) > 1 and sys.argv[1] == "anim":
    ROT = [78, 64, 50, 40, 33, 28, 26, 28, 31, 33, 33, 32, 32]          # damped settle, one value per 2 frames
    CNT = [15, 16, 17, 18]                                               # 110/min -> ~0.55 s per compression
    with sync_playwright() as p:
        b = p.chromium.launch(channel="chrome", args=["--allow-file-access-from-files"])
        pg = b.new_page(viewport={"width": 1500, "height": 1000}, device_scale_factor=3)
        for scr, key, vals, idx, tag in [("ScreensMap", "rotation: 32", ROT, 2, "rot"), ("ScreensChat", "count: 17", CNT, 2, "cnt")]:
            base = open(f"{DS}/components/{scr}/preview.html").read().replace("<head>", "<head>" + HEAD, 1).replace("14:32", "03:41")
            base = base.replace("distance: 450", "distance: 350").replace("450, bearing", "350, bearing").replace("450, time", "350, time").replace("350, bearing: 315", "350, bearing: 45")
            for i, v in enumerate(vals):
                path = f"{OUT}/{scr}_{tag}.html"; open(path, "w").write(base.replace(key, key.split(":")[0] + f": {v}"))
                pg.goto("file://" + path); pg.wait_for_timeout(700)
                pg.locator(".phone").nth(idx).screenshot(path=f"{OUT}/{tag}_{i:02d}.png")
        b.close()
    print("anim frames done")
