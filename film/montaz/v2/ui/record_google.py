# Real Google search on an emulated Pixel 7 (Chromium device emulation, Polish locale): the query is typed like a
# frightened person types it (fast, one typo fixed), suggestions appear, Enter is pressed with the network gone,
# and Chrome shows its real offline page. Every state is a full-resolution screenshot (1080x2400) with its time,
# so the clip can be assembled crisp: ui/google/NNN.png + ui/google/times.txt
# Run: uv run --with playwright python ui/record_google.py
import os, time
from playwright.sync_api import sync_playwright

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "google")
os.makedirs(OUT, exist_ok=True)
QUERY = [("syrena wyje gdize", 0.075), ("\b\b\b", 0.09), ("zie sie schowac", 0.07)]
shots = []
def snap(page, t0, tag=""):
    i = len(shots)
    page.screenshot(path=f"{OUT}/{i:03d}.png")
    shots.append((i, time.time() - t0, tag))

with sync_playwright() as p:
    b = p.chromium.launch(channel="chrome", args=["--lang=pl"])
    dev = dict(p.devices["Pixel 7"]); dev.pop("default_browser_type", None)
    ctx = b.new_context(**dev, locale="pl-PL", timezone_id="Europe/Warsaw")
    page = ctx.new_page()
    page.goto("https://www.google.pl/", wait_until="networkidle")
    for label in ["Odrzuć wszystko", "Zaakceptuj wszystko"]:
        btn = page.get_by_role("button", name=label)
        if btn.count():
            btn.first.click(); page.wait_for_timeout(1500); break
    box = page.locator("textarea[name=q], input[name=q]").first
    box.click(); page.wait_for_timeout(800)
    t0 = time.time(); snap(page, t0, "focus")
    for text, dt in QUERY:
        for ch in text:
            if ch == "\b": page.keyboard.press("Backspace")
            else: page.keyboard.type(ch)
            page.wait_for_timeout(int(dt * 1000)); snap(page, t0, ch)
    page.wait_for_timeout(700); snap(page, t0, "suggest")
    ctx.set_offline(True)
    page.keyboard.press("Enter")
    page.wait_for_timeout(1500); snap(page, t0, "offline")
    page.wait_for_timeout(500); snap(page, t0, "offline2")
    b.close()
with open(f"{OUT}/times.txt", "w") as f:
    for i, t, tag in shots: f.write(f"{i:03d} {t:.3f} {tag}\n")
print("shots", len(shots))
