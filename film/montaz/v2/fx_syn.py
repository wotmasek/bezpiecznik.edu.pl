# Synthesized detail sounds for the AI scenes, placed on the timeline (times = build_v2.sh shot starts):
# out/fx/sc3_syn.wav, sc4_syn.wav, sc4b_syn.wav (48 kHz stereo).
import numpy as np, wave
SR = 48000
rng = np.random.default_rng(3)

def save(name, x):
    x = np.clip(x, -1, 1); y = (np.stack([x, x], 1) * 32767).astype(np.int16)
    with wave.open(f"out/fx/{name}.wav", "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(y.tobytes())

def env(dur, tau): t = np.arange(int(SR * dur)) / SR; return t, np.exp(-t / tau)

def tap(g):            # fingertip on glass: tiny click + soft low knock, slightly different every time
    t, e = env(0.06, 0.002)
    n = np.convolve(rng.normal(0, 1, len(t)) * e, np.ones(6) / 6, "same")
    f = 160 + rng.uniform(-25, 25)
    return g * (0.3 * n + 0.35 * np.sin(2 * np.pi * f * t) * np.exp(-t / 0.012))

def thud():            # phone falls face down on a wooden floor: hit + small bounce
    t, _ = env(0.5, 1)
    x = 0.9 * np.sin(2 * np.pi * 70 * t) * np.exp(-t / 0.05) + 0.45 * rng.normal(0, 1, len(t)) * np.exp(-t / 0.008)
    b = int(SR * 0.11); x[b:] += 0.3 * np.sin(2 * np.pi * 95 * t[:len(t) - b]) * np.exp(-t[:len(t) - b] / 0.025)
    return 0.8 * x

def beat(g):           # heartbeat "lub-dub" (felt more than heard)
    t, _ = env(0.45, 1)
    lub = np.sin(2 * np.pi * 52 * t) * np.exp(-t / 0.06)
    d = int(SR * 0.16); dub = np.zeros_like(t); dub[d:] = 0.7 * np.sin(2 * np.pi * 46 * t[:len(t) - d]) * np.exp(-t[:len(t) - d] / 0.05)
    return g * (lub + dub)

def pulse(g):          # 4b drive: sub kick + dry tick
    t, _ = env(0.4, 1)
    kick = np.sin(2 * np.pi * (46 + 44 * np.exp(-t / 0.03)) * t) * np.exp(-t / 0.10)
    tick = rng.normal(0, 1, len(t)) * np.exp(-t / 0.004) * 0.14
    return g * (kick + tick)

def place(total, events):
    buf = np.zeros(int(SR * total) + SR)
    for t0, snd in events:
        i = int(t0 * SR); buf[i:i + len(snd)] += snd
    return buf[:int(SR * total)]

# scene 3: one tap per keystroke of the real Google capture (cut compressed 2.4x from capture frame 008), phone drop
L = [l.split() for l in open("ui/google/times.txt")]; sel = [l for l in L if 8 <= int(l[0]) <= 36]
t, keys = 0.0, []
for a, b in zip(sel, sel[1:]):
    t += max(0.04, round((float(b[1]) - float(a[1])) / 2.4 / 0.04) * 0.04); keys.append(t)   # frame b appears at t
ev = [(1.92 + k - 0.03, tap(0.35)) for k in keys if k < 2.2]
ev += [(7.52, thud())]
save("sc3_syn", place(10.0, ev))

# scene 4: taps on the app (tile "Alarm / schron", "Prowadź"), heartbeat on the run, gone when the door opens
ev = [(1.05, tap(0.45)), (2.62, tap(0.45)), (3.9, tap(0.4))]
bt, bpm = 4.4, 100.0
while bt < 8.2:
    ev.append((bt, beat(0.55))); bpm += 4; bt += 60 / bpm
save("sc4_syn", place(10.8, ev))

# scene 4b: 110/min pulse from the first frame to the last, UI taps on the screen cuts
ev = [(i * 60 / 110, pulse(0.6 if i % 2 == 0 else 0.42)) for i in range(int(6.56 / (60 / 110)) + 1)]
ev += [(1.0, tap(0.4)), (3.16, tap(0.4)), (5.36, tap(0.4))]
save("sc4b_syn", place(6.56, ev))
print("syn ok")
