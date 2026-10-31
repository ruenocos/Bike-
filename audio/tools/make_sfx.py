"""Writes the greybox sound effects in audio/sfx/ (all synthesized here, no
samples: original, no licence strings attached). Loops carry a WAV 'smpl'
loop so Godot imports them looping. Re-run after tweaking a recipe:
    python -I audio/tools/make_sfx.py
"""
import math
import os
import random
import struct

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sfx")


def write(name, samples, loop=False):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s / peak * 0.9)) * 32767)) for s in samples)
    fmt = struct.pack("<HHIIHH", 1, 1, RATE, RATE * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(data)) + data
    if loop:
        smpl = struct.pack("<IIIIIIIII", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<IIIIII", 0, 0, 0, len(samples) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)
    print(name, "%.2f s" % (len(samples) / RATE))


def noise(n, seed):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(x, cutoff):
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    y, out = 0.0, []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def bandpass(x, freqs, q=4.0):
    """State-variable band-pass; freqs = one cutoff per sample (sweeps)."""
    low = band = 0.0
    out = []
    for s, f in zip(x, freqs):
        k = 2.0 * math.sin(math.pi * min(f, RATE / 6) / RATE)
        low += k * band
        high = s - low - band / q
        band += k * high
        out.append(band)
    return out


def loopify(x, fade):
    """Crossfades the tail into the head so the loop has no click."""
    n = len(x) - fade
    out = x[:n]
    for i in range(fade):
        t = i / fade
        out[i] = x[i] * t + x[n + i] * (1.0 - t)
    return out


def env(n, attack, decay):
    return [min(1.0, i / max(1, attack * RATE)) * math.exp(-i / (decay * RATE)) for i in range(n)]


def tone(n, freq_fn, seed=0):
    phase, out = 0.0, []
    for i in range(n):
        phase += 2.0 * math.pi * freq_fn(i / RATE) / RATE
        out.append(math.sin(phase))
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def scale(x, g):
    return [s * g for s in x]


def mul(a, b):
    return [p * q for p, q in zip(a, b)]


# Wind: soft noise with a slow gust swell; pitch/volume/filter follow speed in game.
n = RATE * 4
wind = lowpass(lowpass(noise(n + RATE // 2, 1), 900), 1400)
gust = [0.7 + 0.3 * math.sin(2 * math.pi * i / (n) * 2) for i in range(n + RATE // 2)]
write("wind_loop.wav", loopify(mul(wind, gust), RATE // 2), loop=True)

# Rolling: low gritty hum of tyres on dirt.
n = RATE * 2
grit = bandpass(noise(n + RATE // 4, 2), [220.0] * (n + RATE // 4), 1.5)
hum = tone(n + RATE // 4, lambda t: 70.0)
write("roll_loop.wav", loopify(mix(scale(grit, 1.0), scale(hum, 0.15)), RATE // 4), loop=True)

# Collapse: deep rumble with a slow tremolo.
n = RATE * 4
deep = lowpass(lowpass(noise(n + RATE // 2, 3), 120), 160)
trem = [0.6 + 0.4 * math.sin(2 * math.pi * 3.0 * i / RATE) for i in range(n + RATE // 2)]
write("collapse_loop.wav", loopify(mix(mul(deep, trem), scale(tone(n + RATE // 2, lambda t: 38.0), 0.05)), RATE // 2), loop=True)

# Grind: metallic screech (inharmonic partials + hiss), jittery.
n = RATE * 1.5
n = int(n)
rng = random.Random(4)
partials = [tone(n + RATE // 4, (lambda f: (lambda t: f * (1.0 + 0.004 * math.sin(t * 37))))(f)) for f in (1830.0, 2710.0, 3960.0)]
jitter = lowpass([rng.uniform(0.5, 1.0) for _ in range(n + RATE // 4)], 30)
hiss = bandpass(noise(n + RATE // 4, 5), [5000.0] * (n + RATE // 4), 2.0)
write("grind_loop.wav", loopify(mul(mix(*partials, scale(hiss, 2.0)), jitter), RATE // 4), loop=True)

# Landing thumps.
def thump(dur, f0, f1, seed):
    m = int(RATE * dur)
    body = mul(tone(m, lambda t: f1 + (f0 - f1) * math.exp(-t * 30)), env(m, 0.002, dur / 4))
    click = mul(lowpass(noise(m, seed), 3000), env(m, 0.0005, 0.015))
    return mix(body, scale(click, 0.5))

m = int(RATE * 0.7)
chime = mul(mix(tone(m, lambda t: 1318.5), scale(tone(m, lambda t: 1975.5), 0.6)), env(m, 0.003, 0.18))
write("land_perfect.wav", mix(thump(0.35, 120, 48, 6), scale(chime, 0.35)))
write("land_good.wav", thump(0.3, 110, 50, 7))
m = int(RATE * 0.45)
scrape = mul(bandpass(noise(m, 8), [1400.0 - 1600.0 * i / m for i in range(m)], 3.0), env(m, 0.01, 0.12))
write("land_sketchy.wav", mix(thump(0.3, 100, 45, 9), scale(scrape, 1.6)))

# Crash: low impact, crunchy noise, rattling clicks.
m = int(RATE * 0.8)
rng = random.Random(10)
clicks = [rng.uniform(-1, 1) if rng.random() < 0.004 * math.exp(-i / (0.25 * RATE)) * 40 else 0.0 for i in range(m)]
crunch = mul(lowpass(noise(m, 11), 2200), env(m, 0.002, 0.18))
write("crash.wav", mix(thump(0.6, 90, 35, 12), scale(crunch, 1.2), scale(lowpass(clicks, 4000), 2.0)))

# Trick whoosh: noise through a band-pass that sweeps up and back.
m = int(RATE * 0.4)
sweep = [600.0 + 2600.0 * math.sin(math.pi * i / m) for i in range(m)]
whoosh = mul(bandpass(noise(m, 13), sweep, 2.5), [math.sin(math.pi * i / m) ** 1.5 for i in range(m)])
write("trick.wav", whoosh)

# Combo banked: two-note ding.
m = int(RATE * 0.5)
d1 = mul(tone(m, lambda t: 880.0), env(m, 0.003, 0.12))
d2 = [0.0] * int(RATE * 0.08) + mul(tone(m, lambda t: 1318.5), env(m, 0.003, 0.18))
write("banked.wav", mix(d1, d2))

# Sprint start: rising three-note arpeggio (perfect start).
notes = []
for k, f in enumerate((659.3, 880.0, 1318.5)):
    m = int(RATE * 0.35)
    notes.append([0.0] * int(RATE * 0.07 * k) + mul(tone(m, (lambda ff: lambda t: ff)(f)), env(m, 0.003, 0.12)))
write("start_go.wav", mix(*notes))
