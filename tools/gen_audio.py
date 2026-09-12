"""Procedural audio for EBB: an ambient sea loop and every sound effect, as 16-bit WAV.

Everything is synthesised (noise, filters, envelopes, FM) so nothing external is needed.
Run:  python tools/gen_audio.py
"""
import os

import numpy as np
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
SR = 22050
rng = np.random.default_rng(7)


def save(name, data, gain=1.0):
    data = np.asarray(data, dtype=np.float64) * gain
    peak = np.max(np.abs(data)) or 1.0
    if peak > 0.98:
        data = data / peak * 0.98
    pcm = (data * 32767).astype(np.int16)
    import wave
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def env(n, attack, decay, sustain=0.0, release=0.0, hold=0.0):
    """ADSR-ish envelope over n samples (seconds for each stage)."""
    a, d, h, r = [int(SR * x) for x in (attack, decay, hold, release)]
    s = max(0, n - a - d - h - r)
    parts = [
        np.linspace(0, 1, max(a, 1)),
        np.linspace(1, sustain, max(d, 1)),
        np.full(max(h, 0), sustain),
        np.full(s, sustain),
        np.linspace(sustain, 0, max(r, 1)),
    ]
    e = np.concatenate(parts)[:n]
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e


def noise(n):
    return rng.standard_normal(n)


def lowpass(x, cutoff, order=2):
    b, a = signal.butter(order, cutoff / (SR / 2), btype="low")
    return signal.lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = signal.butter(order, cutoff / (SR / 2), btype="high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    return signal.lfilter(b, a, x)


def sweep(n, f0, f1, curve=1.0):
    """Sine with frequency sweeping f0 -> f1."""
    k = np.linspace(0, 1, n) ** curve
    f = f0 + (f1 - f0) * k
    phase = np.cumsum(2 * np.pi * f / SR)
    return np.sin(phase)


def loopable(x, fade=0.5):
    """Crossfade the tail into the head so the loop point is seamless."""
    n = int(SR * fade)
    head, tail = x[:n].copy(), x[-n:].copy()
    ramp = np.linspace(0, 1, n)
    x = x[:-n]
    x[:n] = tail * (1 - ramp) + head * ramp
    return x


# ----------------------------------------------------------------------------- ambience
def build_sea():
    """48 s bed. Swells come from three incommensurate slow LFOs plus a random walk, so the
    pattern never audibly repeats inside the loop; the loop point is crossfaded."""
    dur = 48.0
    n = int(SR * dur)
    tt = t(dur)
    walk = lowpass(noise(n), 0.15, 1)
    walk = walk / (np.max(np.abs(walk)) or 1.0)
    swell = (0.5
             + 0.22 * np.sin(2 * np.pi * 0.083 * tt)
             + 0.16 * np.sin(2 * np.pi * 0.031 * tt + 1.1)
             + 0.12 * np.sin(2 * np.pi * 0.137 * tt + 2.4)
             + 0.25 * walk)
    swell = np.clip(swell, 0.12, 1.0) ** 1.7
    surf = lowpass(noise(n), 700, 2) * swell
    wash = bandpass(noise(n), 1200, 4500, 2) * np.clip(swell - 0.45, 0, 1) * 1.4
    gust = 0.35 + 0.25 * np.sin(2 * np.pi * 0.047 * tt + 0.7) + 0.2 * np.sin(2 * np.pi * 0.173 * tt) + 0.2 * walk
    wind = bandpass(noise(n), 250, 1200, 2) * np.clip(gust, 0.08, 1.0) * 0.3
    hum = 0.05 * np.sin(2 * np.pi * 42 * tt) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.023 * tt))
    mix = surf * 0.9 + wash * 0.45 + wind + hum
    save("ambient_sea", loopable(mix, 2.0), 0.7)


def build_gull():
    for i, (f0, f1, dur) in enumerate(((1900, 1400, 0.32), (1700, 1250, 0.4), (2100, 1500, 0.26))):
        n = int(SR * dur)
        base = sweep(n, f0, f1, 0.6)
        vib = np.sin(2 * np.pi * 28 * t(dur)) * 0.4
        x = base * (1 + 0.5 * vib) + 0.35 * sweep(n, f0 * 2, f1 * 2, 0.6)
        x *= env(n, 0.02, 0.1, 0.6, 0.12)
        x = bandpass(x, 800, 6000, 1)
        save("gull_%d" % i, x, 0.5)


# ----------------------------------------------------------------------------- sfx
def build_sfx():
    # swing: short, soft noise whoosh. Three variants so repeated attacks do not sound like a loop.
    for v, (lo, hi, dur, f0) in enumerate(((600, 2600, 0.16, 800), (500, 2200, 0.19, 650), (700, 3000, 0.14, 950))):
        n = int(SR * dur)
        x = bandpass(noise(n), lo, hi, 2) * env(n, 0.015, dur * 0.6, 0.0, 0.04)
        x += 0.2 * sweep(n, f0, f0 * 0.35, 1.0) * env(n, 0.005, dur * 0.5)
        save("swing_%d" % v, x, 0.35)

    # heavy: longer, lower whoosh with weight
    n = int(SR * 0.32)
    x = bandpass(noise(n), 250, 1800, 2) * env(n, 0.02, 0.2, 0.0, 0.08)
    x += 0.5 * sweep(n, 400, 90, 1.2) * env(n, 0.01, 0.25)
    save("heavy", x, 0.7)

    # hit: thud + click, three variants
    for v, (fc, f0, dur) in enumerate(((600, 240, 0.16), (500, 200, 0.18), (750, 280, 0.14))):
        n = int(SR * dur)
        x = lowpass(noise(n), fc, 2) * env(n, 0.002, dur * 0.5)
        x += 0.8 * sweep(n, f0, f0 * 0.25, 1.5) * env(n, 0.001, dur * 0.55)
        x += 0.3 * highpass(noise(n), 3000, 2) * env(n, 0.001, 0.02)
        save("hit_%d" % v, x, 0.7)

    # crit / crack: brighter snap with a shimmer
    n = int(SR * 0.3)
    x = highpass(noise(n), 2000, 2) * env(n, 0.001, 0.05)
    x += 0.6 * sweep(n, 1800, 2600, 0.5) * env(n, 0.005, 0.2) * np.sin(2 * np.pi * 60 * t(0.3))
    x += 0.6 * sweep(n, 200, 50, 1.5) * env(n, 0.001, 0.12)
    save("crit", x, 0.8)

    # dash: quick airy whoosh upward
    n = int(SR * 0.14)
    x = bandpass(noise(n), 1200, 5000, 2) * env(n, 0.005, 0.1)
    x += 0.25 * sweep(n, 300, 900, 0.8) * env(n, 0.005, 0.08)
    save("dash", x, 0.5)

    # hurt: low thump with a grunt-ish band
    n = int(SR * 0.28)
    x = 0.9 * sweep(n, 180, 45, 1.5) * env(n, 0.002, 0.2)
    x += 0.5 * bandpass(noise(n), 200, 700, 2) * env(n, 0.005, 0.15)
    save("hurt", x, 0.9)

    # pickup: two-note blip
    n = int(SR * 0.16)
    tt = t(0.16)
    x = np.sin(2 * np.pi * 880 * tt) * env(n, 0.002, 0.06)
    x[n // 2:] += np.sin(2 * np.pi * 1320 * tt[: n - n // 2]) * env(n - n // 2, 0.002, 0.07)
    save("pickup", x, 0.4)

    # pearl: brighter chime with harmonic
    n = int(SR * 0.4)
    tt = t(0.4)
    x = (np.sin(2 * np.pi * 1568 * tt) + 0.5 * np.sin(2 * np.pi * 2352 * tt)) * env(n, 0.002, 0.3)
    save("pearl", x, 0.4)

    # door: stone grind then a soft chime
    n = int(SR * 0.7)
    x = lowpass(noise(n), 350, 2) * env(n, 0.02, 0.25, 0.3, 0.2)
    tt = t(0.7)
    chime = (np.sin(2 * np.pi * 523 * tt) + 0.6 * np.sin(2 * np.pi * 784 * tt)) * env(n, 0.15, 0.4)
    save("door", x * 0.8 + chime * 0.5, 0.7)

    # clear: rising three-note motif
    dur = 0.9
    n = int(SR * dur)
    tt = t(dur)
    x = np.zeros(n)
    for i, f in enumerate((392, 523, 659)):
        s = int(SR * 0.18 * i)
        seg = np.sin(2 * np.pi * f * tt[: n - s]) * env(n - s, 0.01, 0.35)
        x[s:] += seg
    save("clear", x, 0.45)

    # altar: shimmering chord
    n = int(SR * 1.2)
    tt = t(1.2)
    x = np.zeros(n)
    for f in (440, 554, 659, 880):
        x += np.sin(2 * np.pi * f * tt + 0.3 * np.sin(2 * np.pi * 5 * tt)) * env(n, 0.05, 0.9)
    save("altar", x, 0.4)

    # buy: coin-ish double click
    n = int(SR * 0.2)
    tt = t(0.2)
    x = np.sin(2 * np.pi * 2200 * tt) * env(n, 0.001, 0.04)
    x[n // 3:] += np.sin(2 * np.pi * 2900 * tt[: n - n // 3]) * env(n - n // 3, 0.001, 0.06)
    save("buy", x, 0.4)

    # flare: boom + long shimmer
    n = int(SR * 1.0)
    tt = t(1.0)
    x = 1.0 * sweep(n, 120, 30, 1.5) * env(n, 0.002, 0.5)
    x += 0.5 * lowpass(noise(n), 400, 2) * env(n, 0.002, 0.3)
    x += 0.35 * bandpass(noise(n), 3000, 8000, 2) * env(n, 0.05, 0.8) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * tt))
    save("flare", x, 0.9)

    # riptide: reversed whoosh (rising, then a soft pop)
    n = int(SR * 0.45)
    x = bandpass(noise(n), 400, 4000, 2) * env(n, 0.3, 0.05, 0.0, 0.1)
    x += 0.4 * sweep(n, 200, 1200, 1.0) * env(n, 0.3, 0.1)
    save("riptide", x, 0.6)

    # hook throw: whip + chain
    n = int(SR * 0.25)
    x = highpass(noise(n), 1500, 2) * env(n, 0.002, 0.08)
    x += 0.5 * sweep(n, 1200, 400, 1.0) * env(n, 0.01, 0.15)
    save("hook", x, 0.55)

    # splash: water hit
    n = int(SR * 0.35)
    x = bandpass(noise(n), 800, 4500, 2) * env(n, 0.01, 0.25)
    x += 0.4 * lowpass(noise(n), 300, 2) * env(n, 0.002, 0.1)
    save("splash", x, 0.6)

    # enemy death: crunch + low pop, two variants
    for v, (fc, f0) in enumerate(((900, 300), (700, 220))):
        n = int(SR * 0.3)
        x = lowpass(noise(n), fc, 2) * env(n, 0.002, 0.18)
        x += 0.7 * sweep(n, f0, f0 * 0.23, 1.5) * env(n, 0.002, 0.15)
        save("death_%d" % v, x, 0.7)

    # boss roar: low FM growl
    dur = 1.1
    n = int(SR * dur)
    tt = t(dur)
    x = np.sin(2 * np.pi * 70 * tt + 3.0 * np.sin(2 * np.pi * 23 * tt)) * env(n, 0.05, 0.7, 0.3, 0.3)
    x += 0.4 * lowpass(noise(n), 500, 2) * env(n, 0.05, 0.8)
    save("roar", x, 0.9)

    # ui move / confirm
    n = int(SR * 0.08)
    save("ui", np.sin(2 * np.pi * 1200 * t(0.08)) * env(n, 0.001, 0.05), 0.3)


def build_sfx_m4():
    # stab: short bright tick with a little air, three variants (the knife is fast)
    for v, (f0, dur) in enumerate(((1400, 0.09), (1200, 0.1), (1600, 0.08))):
        n = int(SR * dur)
        x = highpass(noise(n), 2500, 2) * env(n, 0.001, dur * 0.5)
        x += 0.5 * sweep(n, f0, f0 * 0.4, 1.0) * env(n, 0.002, dur * 0.6)
        save("stab_%d" % v, x, 0.4)

    # net: rope whip then a soft slap
    n = int(SR * 0.4)
    x = bandpass(noise(n), 900, 3500, 2) * env(n, 0.005, 0.12)
    tail = lowpass(noise(n), 500, 2) * env(n, 0.001, 0.15)
    x[n // 3:] += tail[: n - n // 3] * 0.8
    save("net", x, 0.55)

    # bell: a real toll, partials of a minor-third bell with a long ring
    dur = 2.4
    n = int(SR * dur)
    tt = t(dur)
    x = np.zeros(n)
    for f, a, d in ((220, 1.0, 1.6), (293, 0.6, 1.3), (440, 0.5, 1.0), (587, 0.35, 0.8), (880, 0.2, 0.5), (1320, 0.12, 0.35)):
        x += a * np.sin(2 * np.pi * f * tt) * np.exp(-tt / d)
    x += 0.4 * lowpass(noise(n), 800, 2) * env(n, 0.001, 0.05)
    save("bell", x, 0.7)

    # wake: stone cracking as a statue moves
    n = int(SR * 0.3)
    x = lowpass(noise(n), 1200, 2) * env(n, 0.002, 0.08)
    for k in range(4):
        s = int(SR * 0.05 * k)
        seg = highpass(noise(n - s), 1800, 2) * env(n - s, 0.001, 0.03)
        x[s:] += 0.6 * seg
    x += 0.5 * sweep(n, 160, 60, 1.5) * env(n, 0.002, 0.2)
    save("wake", x, 0.7)

    # kindle: warm rising whoosh with a flicker
    n = int(SR * 0.6)
    tt = t(0.6)
    x = bandpass(noise(n), 500, 2500, 2) * env(n, 0.15, 0.3) * (0.7 + 0.3 * np.sin(2 * np.pi * 14 * tt))
    x += 0.4 * sweep(n, 300, 700, 0.8) * env(n, 0.1, 0.35)
    save("kindle", x, 0.5)

    # rescue: a soft ascending four-note motif with breath
    dur = 1.4
    n = int(SR * dur)
    tt = t(dur)
    x = np.zeros(n)
    for i, f in enumerate((523, 659, 784, 1046)):
        s = int(SR * 0.2 * i)
        x[s:] += np.sin(2 * np.pi * f * tt[: n - s]) * env(n - s, 0.02, 0.6)
    x += 0.15 * bandpass(noise(n), 2000, 6000, 2) * env(n, 0.3, 0.8)
    save("rescue", x, 0.45)


def build_sfx_m4b():
    # harpoon: sharp thwip with a metallic ring
    n = int(SR * 0.22)
    x = highpass(noise(n), 2500, 2) * env(n, 0.001, 0.05)
    x += 0.6 * sweep(n, 1900, 500, 1.2) * env(n, 0.002, 0.12)
    x += 0.3 * np.sin(2 * np.pi * 3200 * t(0.22)) * env(n, 0.001, 0.15)
    save("harpoon", x, 0.6)

    # reload: two clicks
    n = int(SR * 0.3)
    x = np.zeros(n)
    for s0 in (0.0, 0.14):
        i = int(SR * s0)
        seg = highpass(noise(n - i), 1500, 2) * env(n - i, 0.001, 0.03)
        x[i:] += seg
    save("reload", x, 0.5)

    # lantern swing: airy whoosh with a glassy chime
    n = int(SR * 0.2)
    tt = t(0.2)
    x = bandpass(noise(n), 900, 4000, 2) * env(n, 0.01, 0.12)
    x += 0.3 * np.sin(2 * np.pi * 2093 * tt) * env(n, 0.005, 0.15)
    save("lantern", x, 0.35)

    # beacon: soft bloom
    n = int(SR * 0.7)
    tt = t(0.7)
    x = (np.sin(2 * np.pi * 523 * tt) + 0.5 * np.sin(2 * np.pi * 1046 * tt)) * env(n, 0.12, 0.5)
    x += 0.2 * bandpass(noise(n), 2000, 6000, 2) * env(n, 0.2, 0.4)
    save("beacon", x, 0.4)

    # bite: deep wet snap
    n = int(SR * 0.3)
    x = lowpass(noise(n), 900, 2) * env(n, 0.002, 0.1)
    x += 0.9 * sweep(n, 220, 40, 1.6) * env(n, 0.001, 0.2)
    x += 0.4 * highpass(noise(n), 3000, 2) * env(n, 0.001, 0.02)
    save("bite", x, 0.8)

    # the ebb: a very low, slow surge with a voice in it
    dur = 1.6
    n = int(SR * dur)
    tt = t(dur)
    x = np.sin(2 * np.pi * 48 * tt + 2.5 * np.sin(2 * np.pi * 7 * tt)) * env(n, 0.1, 1.0, 0.4, 0.4)
    x += 0.5 * lowpass(noise(n), 300, 2) * env(n, 0.2, 1.2)
    x += 0.25 * np.sin(2 * np.pi * 96 * tt) * env(n, 0.3, 0.9)
    save("ebb", x, 0.9)

    # wave: long rolling whoosh
    n = int(SR * 0.8)
    x = bandpass(noise(n), 300, 2500, 2) * env(n, 0.15, 0.4, 0.2, 0.2)
    x += 0.3 * sweep(n, 200, 500, 0.8) * env(n, 0.1, 0.5)
    save("wave", x, 0.6)


def build_sfx_m6():
    # chain: a short rattle of links
    n = int(SR * 0.3)
    x = np.zeros(n)
    rng = np.random.default_rng(6)
    for i in range(9):
        s0 = int(SR * (0.022 * i + rng.uniform(0, 0.008)))
        ln = int(SR * 0.05)
        if s0 + ln >= n:
            break
        seg = bandpass(noise(ln), 1800 + rng.uniform(-400, 400), 6000, 2) * env(ln, 0.001, 0.03)
        seg += 0.4 * np.sin(2 * np.pi * (2400 + 200 * i) * t(0.05)) * env(ln, 0.001, 0.02)
        x[s0:s0 + ln] += seg
    save("chain", x, 0.5)

    # creak: timber under strain
    n = int(SR * 0.6)
    tt = t(0.6)
    x = np.sin(2 * np.pi * (110 + 40 * np.sin(2 * np.pi * 3 * tt)) * tt + 3 * np.sin(2 * np.pi * 37 * tt)) * env(n, 0.05, 0.4, 0.3, 0.2)
    x += 0.3 * lowpass(noise(n), 600, 2) * env(n, 0.05, 0.5)
    save("creak", x, 0.5)


def main():
    build_sea()
    build_gull()
    build_sfx()
    build_sfx_m4()
    build_sfx_m4b()
    build_sfx_m6()
    import gen_music
    gen_music.build_music()
    print("wrote audio to", OUT)


if __name__ == "__main__":
    main()
