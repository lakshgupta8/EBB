"""Combat sound (audio Stage 09; STYLE.md 23, laws 2-4): every enemy's windup heard and told apart,
hits that sound of what was hit, deaths by material, and each weapon its own set. 44.1 kHz mono
WAV (placed in the world), three variants where a sound comes often, each brought to its role's
loudness (23.4: tells -13, combat -15, a material's layer under a weapon's hit -18, momentary max).

The sample (the Flats and the gaff):
  tell_shellback   the shell ground round to slam: a scrape rising into two clacks
  tell_gull        the dive call: a shriek bent upward
  tell_wrack_crab  claws clicking faster and faster, then the charge
  tell_tidewisp    cold light gathering: glass rising, shivering quicker
  tell_netted_swing / tell_netted_throw   a drowned breath and a blade's whirl / the net spun twice
  tell_wreck_slam / tell_wreck_charge / tell_wreck_call   the hull groans and is lifted / the
                   timbers creak low and long / a deep hull knock, twice, calling
  hit_shell, hit_feather, hit_flesh, hit_wood, hit_light     a hit's body, by what was hit
  die_shell, die_feather, die_flesh, die_wood, die_light     how each kind of thing dies
  gaff_swing, gaff_heavy, gaff_hit, gaff_hook                the gaff: whoosh, the heavy, the bite, the throw

    python tools/gen_sfx_combat.py
"""
import os
import sys

import numpy as np
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth  # noqa: E402
from synth import SR, secs, decay, lowpass, highpass, bandpass, resonator, env  # noqa: E402
from audio_audit import loudness  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
TARGET = {"tell": -13.0, "combat": -15.0, "layer": -18.0}


def save(name, x, role):
    """Mono at its role's loudness (the loudest 400 ms), peaks under -1 dBFS, 16-bit WAV."""
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x)
    fade = min(len(x) // 4, int(0.01 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    # Measured as played (loudness() counts a mono clip on both speakers). A strike's peak would
    # otherwise decide its level, so the peaks are limited, not the whole clip turned down; twice,
    # since limiting takes a little loudness with it.
    for _ in range(2):
        _, mom, _ = loudness(SR, x[:, None])
        x = synth.limit(x * 10 ** ((TARGET[role] - mom) / 20), -1.5, look_ms=1.5, release_ms=40.0)
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))


def variants(name, fn, role, count=3, seed=1):
    for i in range(count):
        save(f"{name}_{i}" if count > 1 else name, fn(np.random.default_rng(seed * 100 + i)), role)


def n_of(s):
    return int(s * SR)


def whoosh(n, f0, f1, rng, width=0.6):
    """Air moved: noise through a band that slides from f0 to f1, loudest in the middle."""
    tt = np.linspace(0, 1, n)
    centre = f0 * (f1 / f0) ** tt
    x = rng.normal(0, 1, n)
    bands = np.geomspace(150, 8000, 14)
    out = np.zeros(n)
    for b in bands:
        w = np.exp(-(np.log(b / centre) / width) ** 2)
        out += resonator(x, b, b * 0.35) * w
    return out * np.sin(np.pi * tt) ** 1.5


def clicks(times, n, f, rng, ratios=(1.0, 2.7, 5.2), t60=0.025, amp=1.0):
    out = np.zeros(n)
    m = int(0.08 * SR)
    for t in times:
        i = int(t * SR)
        if i >= n:
            continue
        c = synth._modal(f * rng.uniform(0.9, 1.1), m, list(ratios), [t60, t60 * 0.6, t60 * 0.4], [1.0, 0.5, 0.25], rng)
        c += highpass(rng.uniform(-1, 1, m) * decay(m, 0.003), 3000) * 0.3
        out[i:i + m] += c[:n - i] * amp * rng.uniform(0.7, 1.0)
    return out


def creak(n, rate0, rate1, rng, modes=(180, 420, 950), bw=50):
    """Wood under load: stick-slip pulses at a sliding rate through the timber's resonances."""
    out = np.zeros(n)
    t, rate = 0.0, rate0
    dur = n / SR
    while t < dur:
        i = int(t * SR)
        out[i] += rng.uniform(0.5, 1.0)
        rate = rate0 + (rate1 - rate0) * (t / dur) + rng.uniform(-4, 4)
        t += 1.0 / max(rate, 5)
    return sum(resonator(out, f * rng.uniform(0.95, 1.05), bw) for f in modes) * 30


def thump(n, f, t60, rng):
    tt = secs(n)
    bend = f * (1 + 0.5 * np.exp(-tt / 0.02))
    return np.sin(2 * np.pi * np.cumsum(bend) / SR) * decay(n, t60) + lowpass(rng.normal(0, 1, n), 300) * decay(n, 0.04) * 0.5


# ----------------------------------------------------------------------------- tells
def tell_shellback(rng):
    n = n_of(0.75)
    tt = secs(n)
    scrape = bandpass(rng.normal(0, 1, n), 250, 1400) * np.clip(tt / 0.55, 0, 1) ** 2 * (1 + 0.5 * np.sin(2 * np.pi * 23 * tt))
    groan = np.sin(2 * np.pi * (60 + 25 * tt) * tt) * np.clip(tt / 0.5, 0, 1) * 0.6
    clack = clicks([0.52, 0.62], n, rng.uniform(650, 800), rng, t60=0.06, amp=2.0)
    return scrape * 0.5 + groan + clack


def tell_gull(rng):
    n = n_of(0.55)
    tt = secs(n)
    f = rng.uniform(1500, 1700) * (1 + 0.6 * (tt / 0.55) ** 1.5) * (1 + 0.03 * np.sin(2 * np.pi * 28 * tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = sum((1 / k) * np.sin(k * ph) for k in range(1, 7))
    s = resonator(s, 2600, 900) * 3 + resonator(s, 4200, 1200)
    rasp = bandpass(rng.normal(0, 1, n), 2000, 6000) * 0.15
    return (s + rasp) * env(n, 0.03, r=0.12)


def tell_wrack_crab(rng):
    n = n_of(0.65)
    times, t, gap = [], 0.0, 0.11
    while t < 0.6:
        times.append(t)
        t += gap
        gap = max(0.025, gap * 0.8)
    return clicks(times, n, rng.uniform(2600, 3200), rng, ratios=(1.0, 2.3, 4.1), t60=0.015) + \
        bandpass(rng.normal(0, 1, n), 800, 3000) * np.linspace(0, 0.3, n)


def tell_tidewisp(rng):
    n = n_of(0.8)
    tt = secs(n)
    f = rng.uniform(1100, 1250) * 2 ** (tt / 0.8 * 7 / 12)
    trem = 1 + 0.5 * np.sin(2 * np.pi * np.cumsum(6 + 30 * tt / 0.8) / SR)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = (np.sin(ph) + 0.3 * np.sin(2.32 * ph) + 0.1 * np.sin(4.25 * ph)) * trem
    sparkle = clicks(rng.uniform(0.3, 0.75, 6), n, 5200, rng, ratios=(1.0, 1.5, 2.0), t60=0.04, amp=0.15)
    return s * np.clip(tt / 0.6, 0, 1) ** 1.5 * 0.7 + sparkle


def tell_netted_swing(rng):
    n = n_of(0.6)
    breath = synth.breath(0, 0.5, 0.8, rng)[:n]
    breath = np.pad(lowpass(breath, 1200), (0, max(0, n - len(breath))))[:n]
    whirl = np.pad(whoosh(n_of(0.3), 500, 2500, rng), (n_of(0.3), 0))[:n]
    return breath * 1.2 + whirl * 0.8


def tell_netted_throw(rng):
    n = n_of(0.75)
    a = whoosh(n_of(0.3), 300, 1200, rng, 0.8)
    b = whoosh(n_of(0.3), 400, 1800, rng, 0.8)
    out = np.zeros(n)
    out[:len(a)] += a
    out[n_of(0.32):n_of(0.32) + len(b)] += b * 1.3
    rope = bandpass(rng.normal(0, 1, n), 1500, 5000) * np.abs(np.sin(2 * np.pi * 6.5 * secs(n))) * 0.15
    return out + rope


def tell_wreck_slam(rng):
    n = n_of(1.0)
    tt = secs(n)
    groan = creak(n, 35, 90, rng, (110, 260, 600), 30) * np.clip(tt / 0.8, 0, 1)
    lift = lowpass(rng.normal(0, 1, n), 400) * np.clip(tt / 0.9, 0, 1) ** 3 * 0.8
    return groan + lift


def tell_wreck_charge(rng):
    n = n_of(1.0)
    tt = secs(n)
    low = creak(n, 25, 25, rng, (80, 170, 330), 25)
    knock = np.zeros(n)
    for t0 in (0.0, 0.45, 0.8):
        i = n_of(t0)
        k = synth.hull(70, 0.5, 0.9, rng)[:n - i]
        knock[i:i + len(k)] += k
    return low * (0.6 + 0.4 * tt) + knock * 0.8


def tell_wreck_call(rng):
    n = n_of(1.2)
    out = np.zeros(n)
    for t0 in (0.0, 0.5):
        k = synth.hull(45, 0.9, 1.0, rng)
        i = n_of(t0)
        out[i:i + len(k)] += k[:n - i]
    return out + lowpass(synth.breath(0, 1.2, 0.6, rng)[:n], 500) * 0.6


# ----------------------------------------------------------------------------- hits
def hit_shell(rng):
    n = n_of(0.18)
    return clicks([0.0], n, rng.uniform(800, 1000), rng, t60=0.05, amp=1.5) + thump(n, 120, 0.06, rng) * 0.5


def hit_feather(rng):
    n = n_of(0.25)
    puff = bandpass(rng.normal(0, 1, n), 500, 4000) * decay(n, 0.06)
    flutter = bandpass(rng.normal(0, 1, n), 1500, 6000) * np.abs(np.sin(2 * np.pi * 40 * secs(n))) * decay(n, 0.12) * 0.4
    return puff + flutter


def hit_flesh(rng):
    n = n_of(0.25)
    tt = secs(n)
    body = thump(n, 90, 0.08, rng)
    wet = bandpass(rng.normal(0, 1, n), 300, 1800) * decay(n, 0.05)
    drip = np.sin(2 * np.pi * np.cumsum(900 * (1 - 0.6 * np.clip(tt / 0.08, 0, 1))) / SR) * decay(n, 0.05) * 0.3
    return body + wet * 0.8 + drip


def hit_wood(rng):
    n = n_of(0.35)
    return synth.hull(rng.uniform(100, 130), 0.3, 1.0, rng)[:n] + clicks([0.0], n, 1400, rng, t60=0.02, amp=0.5)


def hit_light(rng):
    n = n_of(0.35)
    return synth.glass(rng.uniform(1800, 2200), 0.3, 0.8, rng)[:n] + \
        highpass(rng.normal(0, 1, n), 3000) * decay(n, 0.03) * 0.4


# ----------------------------------------------------------------------------- deaths
def die_shell(rng):
    n = n_of(0.6)
    crack = clicks(np.sort(rng.uniform(0, 0.25, 7)), n, rng.uniform(700, 1100), rng, t60=0.04, amp=1.2)
    crunch = bandpass(rng.normal(0, 1, n), 1000, 6000) * decay(n, 0.12) * 0.5
    return crack + crunch + thump(n, 80, 0.15, rng) * 0.6


def die_feather(rng):
    n = n_of(0.8)
    tt = secs(n)
    f = 1700 * (1 - 0.45 * np.clip(tt / 0.5, 0, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    cry = resonator(sum((1 / k) * np.sin(k * ph) for k in range(1, 6)), 2400, 900) * 2 * env(n, 0.02, r=0.4) * decay(n, 0.6)
    puffs = np.zeros(n)
    for t0 in np.sort(rng.uniform(0, 0.5, 5)):
        p = hit_feather(rng)
        i = n_of(t0)
        puffs[i:i + len(p)] += p[:n - i] * 0.5
    return cry + puffs


def die_flesh(rng):
    n = n_of(1.0)
    sigh = lowpass(synth.breath(0, 0.9, 0.8, rng)[:n], 900)
    sigh = np.pad(sigh, (0, max(0, n - len(sigh))))[:n]
    slump = np.zeros(n)
    s = thump(n_of(0.4), 60, 0.2, rng)
    slump[n_of(0.45):n_of(0.45) + len(s)] += s
    splash = np.zeros(n)
    w = bandpass(rng.normal(0, 1, n_of(0.3)), 400, 3000) * decay(n_of(0.3), 0.1)
    splash[n_of(0.47):n_of(0.47) + len(w)] += w * 0.6
    return sigh * 0.9 + slump + splash


def die_wood(rng):
    n = n_of(1.6)
    out = creak(n, 60, 20, rng, (140, 320, 700), 40) * np.linspace(1, 0.2, n)
    for t0 in np.sort(rng.uniform(0.2, 1.1, 6)):
        k = synth.hull(rng.uniform(55, 110), 0.5, rng.uniform(0.6, 1.0), rng)
        i = n_of(t0)
        out[i:i + len(k)] += k[:n - i]
    return out


def die_light(rng):
    n = n_of(0.9)
    tt = secs(n)
    f = 1800 * 2 ** (-tt / 0.9 * 12 / 12)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) + 0.3 * np.sin(2.32 * ph)) * decay(n, 0.7) * (1 + 0.4 * np.sin(2 * np.pi * 14 * tt))


# ----------------------------------------------------------------------------- the gaff
def gaff_swing(rng):
    n = n_of(0.22)
    w = whoosh(n, rng.uniform(700, 900), rng.uniform(2200, 2800), rng)
    rattle = clicks([0.01], n, 3400, rng, ratios=(1.0, 2.9, 5.4), t60=0.02, amp=0.25)
    return w + rattle


def gaff_heavy(rng):
    n = n_of(0.42)
    w = whoosh(n, rng.uniform(300, 380), rng.uniform(1300, 1600), rng, 0.8)
    grunt = lowpass(synth.breath(0, 0.3, 0.7, rng)[:n], 700)
    grunt = np.pad(grunt, (0, max(0, n - len(grunt))))[:n] * 0.4
    return w * 1.3 + grunt + clicks([0.02], n, 3000, rng, t60=0.025, amp=0.3)


def gaff_hit(rng):
    n = n_of(0.16)
    bite = clicks([0.0], n, rng.uniform(2000, 2400), rng, ratios=(1.0, 2.4, 3.9), t60=0.03, amp=1.2)
    return bite + thump(n, 95, 0.05, rng) * 0.7


def gaff_hook(rng):
    n = n_of(0.45)
    zip_ = whoosh(n_of(0.2), 1500, 5000, rng, 0.5)
    out = np.zeros(n)
    out[:len(zip_)] += zip_
    out += clicks([0.2, 0.23], n, 1800, rng, ratios=(1.0, 2.6, 4.4), t60=0.05, amp=0.9)
    return out


def main():
    for name, fn in [("tell_shellback", tell_shellback), ("tell_gull", tell_gull), ("tell_wrack_crab", tell_wrack_crab),
                     ("tell_tidewisp", tell_tidewisp), ("tell_netted_swing", tell_netted_swing),
                     ("tell_netted_throw", tell_netted_throw)]:
        variants(name, fn, "tell", 3)
    for name, fn in [("tell_wreck_slam", tell_wreck_slam), ("tell_wreck_charge", tell_wreck_charge),
                     ("tell_wreck_call", tell_wreck_call)]:
        variants(name, fn, "tell", 2)
    for name, fn in [("hit_shell", hit_shell), ("hit_feather", hit_feather), ("hit_flesh", hit_flesh),
                     ("hit_wood", hit_wood), ("hit_light", hit_light)]:
        variants(name, fn, "layer", 3)
    for name, fn in [("die_shell", die_shell), ("die_feather", die_feather), ("die_flesh", die_flesh),
                     ("die_wood", die_wood), ("die_light", die_light)]:
        variants(name, fn, "combat", 2)
    for name, fn, k in [("gaff_swing", gaff_swing, 4), ("gaff_heavy", gaff_heavy, 2), ("gaff_hit", gaff_hit, 3),
                        ("gaff_hook", gaff_hook, 2)]:
        variants(name, fn, "combat", k)
    print("combat sounds written")


if __name__ == "__main__":
    main()
