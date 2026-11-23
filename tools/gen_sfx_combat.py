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
from scipy.signal import resample_poly

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
    # otherwise decide its level, so the peaks are limited, not the whole clip turned down; until it
    # holds, since limiting takes a little loudness with it.
    for _ in range(5):
        _, mom, _ = loudness(SR, x[:, None])
        if abs(TARGET[role] - mom) < 0.3:
            break
        x = synth.limit(x * 10 ** ((TARGET[role] - mom) / 20), -2.3, look_ms=1.5, release_ms=40.0)
    # The true peak (between the samples) as the audit reads it: a strike shorter than the 400 ms
    # window is set by its peak alone, and nothing may ring over -1 dBTP.
    tp = 20 * np.log10(np.abs(resample_poly(x, 4, 1)).max() + 1e-12)
    want = -1.5 if len(x) < 0.4 * SR else min(tp, -1.3)
    x = x * 10 ** ((want - tp) / 20)
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


# ----------------------------------------------------------------------------- the rest: helpers
def fit(x, n):
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def at(out, x, t, g=1.0):
    """Adds x into out from t seconds; returns out."""
    i = n_of(t)
    if i < len(out):
        out[i:i + len(x)] += x[:len(out) - i] * g
    return out


def clang(f, n, rng, t60=0.6, amp=1.0):
    """Struck iron: inharmonic, bright, a long ring."""
    s = synth._modal(f, n, [1.0, 2.76, 5.40, 8.93, 13.3], [t60, t60 * 0.7, t60 * 0.45, t60 * 0.3, t60 * 0.2],
                     [1.0, 0.7, 0.45, 0.25, 0.12], rng, 0.003)
    return (s + highpass(rng.uniform(-1, 1, n) * decay(n, 0.006), 2500) * 0.4) * amp


def bubbles(n, times, rng, f0=600, f1=1600, t60=0.04):
    """Bubbles: a sine each that rises as it closes."""
    out = np.zeros(n)
    m = n_of(0.08)
    tt = secs(m)
    for t in times:
        b = np.sin(2 * np.pi * np.cumsum(rng.uniform(f0, f1) * (1 + 2.0 * tt)) / SR) * decay(m, t60)
        at(out, b * rng.uniform(0.5, 1.0), t)
    return out


def grind(n, rng, lo=150, hi=900, rate=18):
    """Stone on stone: noise in the stone's band, jerking as it slips."""
    step = int(SR / rate)
    jerk = lowpass(np.repeat(rng.uniform(0.2, 1.0, n // step + 2), step)[:n], 60)
    return bandpass(rng.normal(0, 1, n), lo, hi) * jerk


def rush(n, rng, lo=200, hi=3000, shape=1.0):
    """Moving water: noise in a band, swelling as shaped."""
    return bandpass(rng.normal(0, 1, n), lo, hi) * (1 + 0.4 * lowpass(rng.normal(0, 1, n), 8)) * shape


def rumble(n, rng, f=80):
    return lowpass(rng.normal(0, 1, n), f, 4) * 4


def rise(n, p=2.0, over=None):
    """0 to 1 over `over` seconds (the whole clip by default), curved by p."""
    return np.clip(secs(n) / (over or n / SR), 0, 1) ** p


def inst(name, note, dur, vel, rng):
    """One note from the score's kit, mono."""
    return synth.INSTRUMENTS[name](synth.hz(note), dur, vel, rng)


# ----------------------------------------------------------------------------- the Harbour
def tell_anchor_slam(rng):   # the anchor dragged up and hoisted: iron scraping, a grunt, set
    n = n_of(0.85)
    scrape = bandpass(rng.normal(0, 1, n), 1200, 4500) * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 3.5 * secs(n)))) * rise(n, 1)
    out = scrape * 0.35 + synth.chain(0, 0.85, 0.8, rng)[:n] * 1.2
    at(out, fit(lowpass(synth.breath(0, 0.4, 0.8, rng), 600), n_of(0.5)), 0.35, 0.8)
    return at(out, clang(140, n_of(0.3), rng, 0.25), 0.72, 0.8)


def tell_anchor_chain(rng):  # the chain whirled overhead, faster each turn
    n = n_of(0.85)
    out = np.zeros(n)
    t, gap = 0.0, 0.3
    while t < 0.75:
        at(out, whoosh(n_of(gap * 0.9), 250, 900, rng, 0.7), t)
        at(out, synth.chain(0, 0.3, 0.5, rng)[:n_of(gap)], t + gap * 0.4, 0.8)
        t += gap
        gap *= 0.72
    return out


def tell_mooring(rng):       # the chain unwound from his arm, link over link, then pulled taut
    n = n_of(0.7)
    out = np.zeros(n)
    for t0 in np.linspace(0, 0.5, 9):
        at(out, clang(rng.uniform(2200, 3000), n_of(0.06), rng, 0.04, 0.5), t0 + rng.uniform(0, 0.01))
    return at(out, clang(1700, n_of(0.2), rng, 0.15), 0.55, 1.2)


def tell_deckhand(rng):      # the cutlass drawn along the shield's rim: steel sliding upward
    n = n_of(0.6)
    ph = 2 * np.pi * np.cumsum(2400 * 2 ** (secs(n) / 0.5 * 0.6)) / SR
    ring = (np.sin(ph) + 0.4 * np.sin(2.76 * ph)) * (0.3 + rng.normal(0, 0.15, n)) * rise(n, 1, 0.45)
    slide = bandpass(rng.normal(0, 1, n), 3000, 9000) * rise(n, 1, 0.5) * 0.6
    return at(ring * 0.5 + slide, thump(n_of(0.2), 70, 0.08, rng), 0.0, 1.2)


def tell_barnacle(rng):      # the crust shifting: a thousand small clicks gathering
    n = n_of(0.6)
    times = np.sort(rng.uniform(0, 1, 45) ** 0.5 * 0.55)
    return clicks(times, n, 3800, rng, ratios=(1.0, 1.9, 3.3), t60=0.006, amp=0.5) + \
        bandpass(rng.normal(0, 1, n), 2000, 7000) * rise(n, 2) * 0.25


def tell_chainmother_sweep(rng):   # the chain dragged across the deck
    n = n_of(1.1)
    return synth.chain(0, 1.1, 1.0, rng)[:n] * 1.4 * (0.5 + 0.5 * rise(n, 1)) + \
        bandpass(rng.normal(0, 1, n), 600, 2500) * rise(n, 2) * 0.4 + rumble(n, rng, 120) * rise(n, 1) * 0.5


def tell_chainmother_drop(rng):    # the winch paying out, pawl by pawl
    n = n_of(1.0)
    out = np.zeros(n)
    for k, t0 in enumerate(np.arange(0, 0.85, 0.085)):
        at(out, clang(900 + 30 * k, n_of(0.12), rng, 0.06, 0.8), t0)
    return out + creak(n, 30, 45, rng, (140, 330, 700), 30) * 0.4


def tell_chainmother_haul(rng):    # the winch thrown into reverse: the pawl racing
    n = n_of(0.8)
    out = np.zeros(n)
    t, gap = 0.0, 0.08
    while t < 0.7:
        at(out, clang(1300 + 600 * t, n_of(0.08), rng, 0.04, 0.7), t)
        t += gap
        gap = max(0.025, gap * 0.85)
    return out + synth.chain(0, 0.8, 0.6, rng)[:n]


def tell_chainmother_slam(rng):    # the jib lifted: iron groaning under its own weight
    n = n_of(1.0)
    groan = resonator(creak(n, 25, 60, rng, (90, 210, 470, 1100), 20), 600, 400) * rise(n, 1, 0.7)
    return groan + np.sin(2 * np.pi * np.cumsum(55 + 30 * secs(n)) / SR) * 0.5 * rise(n, 1)


def tell_chainmother_call(rng):    # the crane's horn, the harbour answering in chains
    n = n_of(1.3)
    tt = secs(n)
    horn = resonator(sum((1 / k) * np.sin(2 * np.pi * 73 * k * tt) for k in range(1, 9)), 400, 300) * env(n, 0.15, r=0.3)
    return at(horn * 1.2, synth.chain(0, 0.8, 0.8, rng)[:n_of(0.8)], 0.4)


# ----------------------------------------------------------------------------- the Reef
def tell_coral_crab(rng):    # a coral head cracks open; slow, heavy pinching
    n = n_of(0.7)
    crack = clicks(np.sort(rng.uniform(0, 0.08, 4)), n, 1400, rng, ratios=(1.0, 3.1, 6.3), t60=0.03, amp=1.2)
    grit = bandpass(rng.normal(0, 1, n), 2000, 7000) * decay(n, 0.12) * 0.4
    return crack + grit + clicks([0.3, 0.45, 0.58], n, 1000, rng, ratios=(1.0, 2.2, 3.7), t60=0.04)


def tell_polyp_swarm(rng):   # the crowns open: wet pops climbing
    n = n_of(0.7)
    out = bubbles(n, np.sort(rng.uniform(0, 1, 14) ** 0.7 * 0.6), rng, 500, 900, 0.05)
    out += bubbles(n, np.sort(rng.uniform(0.35, 0.65, 8)), rng, 1200, 2200, 0.03)
    return out + bandpass(rng.normal(0, 1, n), 800, 3000) * rise(n, 2) * 0.2


def tell_reef_ray(rng):      # wingtips curled into the current: a swell drawn up, one beat
    n = n_of(0.75)
    swell = rush(n, rng, 150, 1200, rise(n, 2, 0.6) * env(n, 0.01, r=0.1))
    return at(swell * 1.2, thump(n_of(0.3), 55, 0.12, rng), 0.5)


def tell_reefwarden(rng):    # the helmet's breath, the lead boot set down
    n = n_of(0.8)
    hiss = bandpass(rng.normal(0, 1, n), 2500, 8000) * env(n, 0.15, r=0.15) * 0.4
    burble = bubbles(n, np.sort(rng.uniform(0.0, 0.4, 10)), rng, 300, 600, 0.06) * 0.6
    boot = clang(180, n_of(0.4), rng, 0.2, 0.8) + thump(n_of(0.4), 50, 0.15, rng)
    return at(hiss + burble, boot, 0.5)


def tell_reefwarden_surge(rng):  # the sea let into his suit: water roaring behind the visor
    n = n_of(1.0)
    bub = bubbles(n, np.sort(rng.uniform(0.2, 0.95, 20)), rng, 250, 700, 0.06) * 0.7
    return rush(n, rng, 120, 2000, rise(n, 1.5)) * 1.2 + bub + rumble(n, rng, 90) * rise(n, 1) * 0.6


def tell_tidewall_slam(rng):     # the wall leans back: stone grinding, rising
    n = n_of(1.0)
    return grind(n, rng, 120, 800, 14) * rise(n, 1, 0.8) * 1.4 + rumble(n, rng, 70) * rise(n, 1) * 0.6


def tell_tidewall_stone(rng):    # stones worked loose from its face, rattling
    n = n_of(0.9)
    out = clicks(np.sort(rng.uniform(0.0, 0.8, 24)), n, 700, rng, ratios=(1.0, 2.6, 4.9), t60=0.04, amp=0.5)
    return out + grind(n, rng, 300, 1500, 25) * 0.8


def tell_tidewall_breach(rng):   # the breach in its chest roaring open
    n = n_of(1.1)
    return rush(n, rng, 100, 3500, rise(n, 1.2)) * 1.3 + grind(n, rng, 120, 600, 10) * 0.5 + rumble(n, rng, 60) * 0.8 * rise(n, 1)


def tell_tidewall_turn(rng):     # the whole wall sliding along its line
    n = n_of(1.1)
    return grind(n, rng, 80, 500, 8) * 1.4 * env(n, 0.2, r=0.15) + rumble(n, rng, 50) * 0.8


def tell_tidewall_call(rng):     # two stones knocked together, deep, and the sea behind
    n = n_of(1.3)
    out = np.zeros(n)
    for t0 in (0.0, 0.45):
        at(out, inst("stone_marimba", "G2", 0, 1.0, rng)[:n_of(0.5)] + thump(n_of(0.5), 80, 0.2, rng) * 0.7, t0)
    return out + fit(synth.surf(0, 1.3, 0.6, rng), n) * 0.5 + grind(n, rng, 200, 900, 12) * env(n, 0.1, r=0.3) * 0.5


# ----------------------------------------------------------------------------- the Streets
def tell_bell_ringer(rng):   # the hand bell lifted, its clapper knocking against a palm
    n = n_of(0.75)
    out = np.zeros(n)
    for t0 in (0.05, 0.3, 0.5):
        at(out, inst("hand_bell", "E5", 0.3, 0.6, rng)[:n_of(0.25)] * decay(n_of(0.25), 0.08), t0)
    return out + fit(lowpass(synth.breath(0, 0.6, 0.6, rng), 900), n) * 0.5


def tell_still_citizen(rng):     # stone cracking: the statue coming loose
    n = n_of(0.6)
    crack = clicks(np.sort(rng.uniform(0, 0.15, 5)), n, 900, rng, ratios=(1.0, 2.6, 5.1), t60=0.03, amp=1.2)
    return crack + grind(n, rng, 200, 1200, 30) * env(n, 0.05, r=0.2) * 0.9


def tell_swimmer(rng):       # the jaw opened: a wet throaty rattle rising
    n = n_of(0.6)
    buzz = np.sign(np.sin(2 * np.pi * np.cumsum(90 + 80 * secs(n) / 0.6) / SR)) * 0.4
    throat = resonator(buzz, 700, 300) * 2 + bandpass(rng.normal(0, 1, n), 400, 2500) * 0.3
    return throat * rise(n, 1, 0.4) + bubbles(n, np.sort(rng.uniform(0, 0.5, 6)), rng, 400, 900) * 0.5


def tell_choir(rng):         # a breath drawn, and one held note swelling
    n = n_of(1.0)
    note = inst("choir_ah", "A4", 0.75, 1.0, rng)[:n_of(0.7)] * rise(n_of(0.7), 1.5)
    out = at(np.zeros(n), fit(lowpass(synth.breath(0, 0.3, 0.9, rng), 1800), n_of(0.35)), 0.0)
    return at(out, note, 0.3, 2.0)


def tell_bell_toll(rng):     # the Bell lifted on his back: its hum woken, bronze groaning
    n = n_of(1.2)
    hum = lowpass(fit(inst("saltmere", "D3", 1.2, 0.5, rng), n), 600) * rise(n, 2) * 2.5
    return hum + creak(n, 20, 40, rng, (90, 200, 450), 25) * 0.5


def tell_bell_swing(rng):    # the rope creaks, the bell swung back, its lip just singing
    n = n_of(0.9)
    lip = fit(inst("ship_bell", "D4", 0.9, 0.3, rng), n) * rise(n, 2) * 0.5
    return creak(n, 40, 80, rng, (300, 700, 1500), 60) * 0.6 + lip + whoosh(n, 200, 700, rng, 0.8) * 0.6


def tell_bell_peal(rng):     # the clapper rattled against the bell, muffled, faster
    n = n_of(1.0)
    out = np.zeros(n)
    t, gap = 0.0, 0.16
    while t < 0.9:
        at(out, clang(rng.uniform(380, 420), n_of(0.15), rng, 0.08, 0.6), t)
        t += gap
        gap = max(0.04, gap * 0.82)
    return lowpass(out, 2500) * 1.3


# ----------------------------------------------------------------------------- the Hall
def tell_lamplighter_kindle(rng):  # a match struck, a flame catching and drawing
    n = n_of(0.7)
    strike = bandpass(rng.normal(0, 1, n_of(0.08)), 2000, 8000) * decay(n_of(0.08), 0.03)
    flame = bandpass(rng.normal(0, 1, n), 200, 1500) * rise(n, 1, 0.5) * 0.8
    crackle = clicks(np.sort(rng.uniform(0.15, 0.65, 10)), n, 4000, rng, ratios=(1.0, 1.7, 2.9), t60=0.006, amp=0.3)
    return at(flame + crackle, strike, 0.0, 1.5)


def tell_lamplighter_throw(rng):   # the lamp swung round on its chain, flame roaring
    n = n_of(0.75)
    out = np.zeros(n)
    for t0 in (0.0, 0.35):
        at(out, whoosh(n_of(0.35), 200, 900, rng, 0.9), t0, 1.2)
    return out + bandpass(rng.normal(0, 1, n), 150, 900) * 0.4 + synth.chain(0, 0.75, 0.4, rng)[:n] * 0.6


def tell_tallow(rng):        # hot wax at the boil: bubbling, a hiss rising
    n = n_of(0.8)
    bub = bubbles(n, np.sort(rng.uniform(0, 0.75, 22)), rng, 150, 400, 0.06)
    return bub * 1.3 + bandpass(rng.normal(0, 1, n), 3000, 9000) * rise(n, 1.5) * 0.4


def tell_deep_maw(rng):      # the floor shudders: a low rumble rising and a wet throat
    n = n_of(0.9)
    shudder = rumble(n, rng, 70) * rise(n, 1) * (1 + 0.6 * np.sin(2 * np.pi * 9 * secs(n)))
    throat = bandpass(rng.normal(0, 1, n), 200, 900) * rise(n, 2) * 0.6
    return shudder * 0.9 + throat + bubbles(n, np.sort(rng.uniform(0.3, 0.85, 14)), rng, 150, 400, 0.07)


def tell_keeper_shade(rng):  # your own swing, played backwards and drowned
    n = n_of(0.55)
    w = whoosh(n, 2000, 600, rng)[::-1]
    ring = clang(rng.uniform(600, 700), n, rng, 0.3, 0.5)[::-1] * 0.6
    return lowpass(w + ring, 2400) * 1.2 + rumble(n, rng, 100) * rise(n, 1) * 0.4


def tell_ebb_wave(rng):      # the sea drawing back down the shingle before it comes in
    n = n_of(1.1)
    back = rush(n, rng, 300, 5000, (1 - rise(n, 1)) * env(n, 0.05, r=0.05))
    rattle = clicks(np.sort(rng.uniform(0.1, 0.9, 25)), n, 2500, rng, ratios=(1.0, 2.4), t60=0.01, amp=0.2)
    return back * 1.1 + rattle + rumble(n, rng, 60) * rise(n, 1) * 0.8


def tell_ebb_pull(rng):      # the undertow: a low suck, falling
    n = n_of(0.9)
    suck = np.sin(2 * np.pi * np.cumsum(160 * 2 ** (-secs(n) / 0.9)) / SR) * env(n, 0.1, r=0.1) * 0.6
    return suck + rush(n, rng, 100, 900, rise(n, 1)) * 0.9


def tell_ebb_slam(rng):      # water lifted into a column: rushing upward
    n = n_of(1.0)
    up = bandpass(rng.normal(0, 1, n), 800, 6000) * rise(n, 3) * 0.6
    tone = np.sin(2 * np.pi * np.cumsum(60 + 60 * secs(n)) / SR) * rise(n, 1) * 0.4
    return rush(n, rng, 200, 2500, rise(n, 1.5)) + up + tone


def tell_ebb_surge(rng):     # a swell from the deep, Maren's lantern glass shivering in it
    n = n_of(1.1)
    shiver = fit(inst("glass", "F#5", 1.1, 0.4, rng), n) * (1 + 0.6 * np.sin(2 * np.pi * 11 * secs(n))) * rise(n, 1)
    return rumble(n, rng, 90) * env(n, 0.5, r=0.2) * 1.2 + shiver + rush(n, rng, 200, 1500, rise(n, 1)) * 0.6


def tell_ebb_call(rng):      # the Sea's voice: the drowned moaning under the water
    n = n_of(1.3)
    moan = fit(inst("choir_oo", "D3", 1.3, 1.0, rng), n) + fit(inst("choir_oo", "Eb3", 1.3, 0.6, rng), n)
    return lowpass(moan, 900) * 2 * env(n, 0.3, r=0.3) + fit(synth.surf(0, 1.3, 0.5, rng), n) * 0.5


# ----------------------------------------------------------------------------- materials (the rest)
def hit_metal(rng):
    n = n_of(0.4)
    return clang(rng.uniform(500, 650), n, rng, 0.25, 0.8) + thump(n, 110, 0.04, rng) * 0.4


def hit_stone(rng):
    n = n_of(0.2)
    return clicks([0.0], n, rng.uniform(500, 650), rng, ratios=(1.0, 2.6, 5.1), t60=0.03, amp=1.3) + \
        bandpass(rng.normal(0, 1, n), 1500, 6000) * decay(n, 0.03) * 0.5 + thump(n, 90, 0.04, rng) * 0.6


def hit_coral(rng):
    n = n_of(0.2)
    return clicks(np.sort(rng.uniform(0, 0.03, 4)), n, rng.uniform(1600, 2000), rng, ratios=(1.0, 3.1, 6.3), t60=0.02, amp=0.9) + \
        bandpass(rng.normal(0, 1, n), 3000, 9000) * decay(n, 0.05) * 0.4


def hit_wax(rng):
    n = n_of(0.25)
    return thump(n, 75, 0.06, rng) + lowpass(rng.normal(0, 1, n), 1200) * decay(n, 0.05) * 0.6 + \
        bandpass(rng.normal(0, 1, n), 4000, 9000) * decay(n, 0.12) * 0.15


def hit_water(rng):
    n = n_of(0.3)
    splash = bandpass(rng.normal(0, 1, n), 500, 5000) * decay(n, 0.09)
    return splash + bubbles(n, np.sort(rng.uniform(0.01, 0.12, 5)), rng, 500, 1100) * 0.6 + thump(n, 70, 0.05, rng) * 0.5


def die_metal(rng):
    n = n_of(1.4)
    out = np.zeros(n)
    for t0 in np.sort(rng.uniform(0, 0.7, 6)):
        at(out, clang(rng.uniform(250, 900), n_of(0.7), rng, rng.uniform(0.2, 0.5), rng.uniform(0.4, 1.0)), t0)
    return at(out, thump(n_of(0.5), 50, 0.2, rng), 0.3)


def die_stone(rng):
    n = n_of(1.0)
    out = clicks(np.sort(rng.uniform(0, 0.5, 14)), n, 650, rng, ratios=(1.0, 2.6, 5.1), t60=0.04, amp=0.9)
    return out + grind(n, rng, 150, 1200, 20) * decay(n, 0.4) * 0.8 + thump(n, 55, 0.3, rng) * 0.7


def die_coral(rng):
    n = n_of(0.8)
    out = clicks(np.sort(rng.uniform(0, 0.4, 18)), n, 1800, rng, ratios=(1.0, 3.1, 6.3), t60=0.025, amp=0.7)
    return out + bandpass(rng.normal(0, 1, n), 2500, 9000) * decay(n, 0.2) * 0.5


def die_wax(rng):
    n = n_of(1.2)
    sizzle = bandpass(rng.normal(0, 1, n), 3000, 9000) * env(n, 0.02, r=0.5) * decay(n, 1.0) * 0.5
    slump = at(np.zeros(n), thump(n_of(0.5), 50, 0.25, rng), 0.25)
    return sizzle + slump + bubbles(n, np.sort(rng.uniform(0.2, 1.0, 12)), rng, 150, 350, 0.06)


def die_water(rng):
    n = n_of(1.3)
    fall = rush(n, rng, 200, 4000, env(n, 0.03, r=0.6) * decay(n, 0.8)) * 1.3
    return fall + bubbles(n, np.sort(rng.uniform(0.1, 1.0, 16)), rng, 300, 900, 0.05) * 0.6 + rumble(n, rng, 80) * decay(n, 0.5)


# ----------------------------------------------------------------------------- the five other weapons
def knife_stab(rng):     # a short, close slit of air
    n = n_of(0.12)
    return whoosh(n, rng.uniform(1800, 2200), rng.uniform(4500, 5500), rng, 0.5) + \
        clicks([0.005], n, 5200, rng, ratios=(1.0, 2.4), t60=0.01, amp=0.15)


def knife_hit(rng):      # the blade in: a sharp snick
    n = n_of(0.14)
    return clicks([0.0], n, rng.uniform(3500, 4200), rng, ratios=(1.0, 2.2, 3.6), t60=0.02, amp=0.9) + thump(n, 130, 0.03, rng) * 0.4


def knife_cut(rng):      # the fourth: a long drawn cut
    n = n_of(0.3)
    slice_ = bandpass(rng.normal(0, 1, n), 2500, 9000) * np.exp(-((secs(n) - 0.06) / 0.05) ** 2)
    return fit(knife_hit(rng), n) + slice_ * 0.9


def knife_net(rng):      # the net cast: cord rushing out and spreading
    n = n_of(0.5)
    cord = bandpass(rng.normal(0, 1, n), 2000, 6000) * np.abs(np.sin(2 * np.pi * 9 * secs(n))) * env(n, 0.05, r=0.2) * 0.3
    return whoosh(n, 400, 1600, rng, 0.9) + cord


def harpoon_fire(rng):   # the spring let go: a twang and the bolt away
    n = n_of(0.35)
    twang = np.sin(2 * np.pi * np.cumsum(220 * (1 + 0.3 * np.exp(-secs(n) / 0.03))) / SR) * decay(n, 0.12)
    return twang * 0.8 + thump(n, 80, 0.05, rng) * 0.8 + whoosh(n, 1500, 600, rng, 0.6) * 0.5


def harpoon_hit(rng):    # the bolt in deep: a heavy thunk
    n = n_of(0.22)
    return thump(n, 75, 0.08, rng) + clicks([0.0], n, 900, rng, ratios=(1.0, 2.5), t60=0.03, amp=0.6)


def harpoon_reload(rng):  # a crank drawn back, the bolt seated
    n = n_of(0.45)
    out = np.zeros(n)
    for t0 in (0.0, 0.07, 0.14, 0.21):
        at(out, clang(rng.uniform(1600, 1800), n_of(0.05), rng, 0.02, 0.4), t0)
    return at(out, clang(900, n_of(0.15), rng, 0.06), 0.32)


def harpoon_tether(rng):  # the tethered bolt away, line hissing off the reel
    n = n_of(0.6)
    hiss = bandpass(rng.normal(0, 1, n), 3000, 8000) * env(n, 0.01, r=0.3) * 0.4
    reel = clicks(np.arange(0.05, 0.5, 0.03), n, 2600, rng, ratios=(1.0, 2.1), t60=0.006, amp=0.15)
    return fit(harpoon_fire(rng), n) + hiss + reel


def harpoon_drag(rng):    # the line jerked taut
    n = n_of(0.3)
    taut = np.sin(2 * np.pi * np.cumsum(140 * (1 + 0.5 * np.exp(-secs(n) / 0.05))) / SR) * decay(n, 0.15)
    return taut + creak(n, 80, 30, rng, (300, 800), 60) * 0.3


def kbell_swing(rng):     # the keeper's bell swung like a hammer: air, its lip faintly singing
    n = n_of(0.35)
    lip = fit(inst("hand_bell", "B4", 0.35, 0.15, rng), n) * np.sin(np.pi * secs(n) / 0.35)
    return whoosh(n, 350, 1200, rng, 0.8) * 1.2 + lip


def kbell_slam(rng):      # down onto the floor: a thud and the bell ringing out
    n = n_of(1.0)
    return thump(n, 60, 0.15, rng) * 1.2 + fit(inst("hand_bell", "B4", 1.0, 0.8, rng), n) + rumble(n, rng, 120) * decay(n, 0.3)


def kbell_hit(rng):       # the bronze on a body: a clonk
    n = n_of(0.3)
    return clang(rng.uniform(450, 520), n, rng, 0.12, 0.8) + thump(n, 100, 0.05, rng) * 0.7


def kbell_toll(rng):      # rung: a long clear toll, the hum under it
    n = n_of(1.8)
    return fit(inst("hand_bell", "E5", 1.8, 1.0, rng), n) + fit(inst("ship_bell", "E4", 1.8, 0.4, rng), n)


def line_crack(rng):      # the line cracked out: a whistle and a snap
    n = n_of(0.22)
    snap = highpass(rng.uniform(-1, 1, n_of(0.02)) * decay(n_of(0.02), 0.003), 2000) * 1.5
    return at(at(np.zeros(n), whoosh(n_of(0.15), 1200, 4500, rng, 0.5), 0.0), snap, 0.13)


def line_hit(rng):        # the lead on a body: a small dense thwack
    n = n_of(0.16)
    return clicks([0.0], n, rng.uniform(1100, 1300), rng, ratios=(1.0, 2.9), t60=0.015, amp=0.8) + thump(n, 120, 0.03, rng) * 0.7


def line_throw(rng):      # the sinker thrown: line whizzing off the reel
    n = n_of(0.5)
    reel = clicks(np.arange(0.0, 0.45, 0.022), n, 3000, rng, ratios=(1.0, 2.3), t60=0.005, amp=0.25)
    return reel + whoosh(n, 600, 2200, rng, 0.7) * 0.8


def line_sink(rng):       # the weight down: a heavy dull drop
    n = n_of(0.5)
    return thump(n, 55, 0.15, rng) * 1.3 + bandpass(rng.normal(0, 1, n), 300, 1500) * decay(n, 0.06) * 0.6


def lantern_arc(rng):     # an arc of light: a flame swung, the glass chiming
    n = n_of(0.3)
    crackle = clicks(np.sort(rng.uniform(0, 0.25, 5)), n, 4500, rng, ratios=(1.0, 1.7), t60=0.005, amp=0.15)
    return whoosh(n, 300, 1100, rng, 1.0) * 1.1 + fit(inst("glass", "C#6", 0.3, 0.2, rng), n) + crackle


def lantern_hit(rng):     # light on a body: a sizzle
    n = n_of(0.2)
    return bandpass(rng.normal(0, 1, n), 2500, 9000) * decay(n, 0.08) * 0.8 + thump(n, 140, 0.03, rng) * 0.5 + \
        fit(inst("glass", "G#6", 0.2, 0.15, rng), n)


def lantern_throw(rng):   # the beacon thrown: a flame spinning away
    n = n_of(0.4)
    return whoosh(n, 400, 1600, rng, 1.0) * (1 + 0.5 * np.sin(2 * np.pi * 14 * secs(n)))


def lantern_beacon(rng):  # where it lands: glass, and a flame blooming
    n = n_of(1.0)
    bloom = bandpass(rng.normal(0, 1, n), 150, 1500) * env(n, 0.08, r=0.6) * decay(n, 0.8)
    return bloom * 1.2 + fit(inst("glass", "C#6", 1.0, 0.6, rng), n) + fit(inst("glass", "G#6", 1.0, 0.4, rng), n)


SAMPLE = [  # (name, fn, role, variants)
    ("tell_shellback", tell_shellback, "tell", 3), ("tell_gull", tell_gull, "tell", 3),
    ("tell_wrack_crab", tell_wrack_crab, "tell", 3), ("tell_tidewisp", tell_tidewisp, "tell", 3),
    ("tell_netted_swing", tell_netted_swing, "tell", 3), ("tell_netted_throw", tell_netted_throw, "tell", 3),
    ("tell_wreck_slam", tell_wreck_slam, "tell", 2), ("tell_wreck_charge", tell_wreck_charge, "tell", 2),
    ("tell_wreck_call", tell_wreck_call, "tell", 2),
    ("hit_shell", hit_shell, "layer", 3), ("hit_feather", hit_feather, "layer", 3), ("hit_flesh", hit_flesh, "layer", 3),
    ("hit_wood", hit_wood, "layer", 3), ("hit_light", hit_light, "layer", 3),
    ("die_shell", die_shell, "combat", 2), ("die_feather", die_feather, "combat", 2), ("die_flesh", die_flesh, "combat", 2),
    ("die_wood", die_wood, "combat", 2), ("die_light", die_light, "combat", 2),
    ("gaff_swing", gaff_swing, "combat", 4), ("gaff_heavy", gaff_heavy, "combat", 2), ("gaff_hit", gaff_hit, "combat", 3),
    ("gaff_hook", gaff_hook, "combat", 2),
]
REST = [
    ("tell_anchor_slam", tell_anchor_slam, "tell", 3), ("tell_anchor_chain", tell_anchor_chain, "tell", 3),
    ("tell_mooring", tell_mooring, "tell", 3), ("tell_deckhand", tell_deckhand, "tell", 3),
    ("tell_barnacle", tell_barnacle, "tell", 3),
    ("tell_chainmother_sweep", tell_chainmother_sweep, "tell", 2), ("tell_chainmother_drop", tell_chainmother_drop, "tell", 2),
    ("tell_chainmother_haul", tell_chainmother_haul, "tell", 2), ("tell_chainmother_slam", tell_chainmother_slam, "tell", 2),
    ("tell_chainmother_call", tell_chainmother_call, "tell", 2),
    ("tell_coral_crab", tell_coral_crab, "tell", 3), ("tell_polyp_swarm", tell_polyp_swarm, "tell", 3),
    ("tell_reef_ray", tell_reef_ray, "tell", 3), ("tell_reefwarden", tell_reefwarden, "tell", 2),
    ("tell_reefwarden_surge", tell_reefwarden_surge, "tell", 2),
    ("tell_tidewall_slam", tell_tidewall_slam, "tell", 2), ("tell_tidewall_stone", tell_tidewall_stone, "tell", 2),
    ("tell_tidewall_breach", tell_tidewall_breach, "tell", 2), ("tell_tidewall_turn", tell_tidewall_turn, "tell", 2),
    ("tell_tidewall_call", tell_tidewall_call, "tell", 2),
    ("tell_bell_ringer", tell_bell_ringer, "tell", 3), ("tell_still_citizen", tell_still_citizen, "tell", 3),
    ("tell_swimmer", tell_swimmer, "tell", 3), ("tell_choir", tell_choir, "tell", 2),
    ("tell_bell_toll", tell_bell_toll, "tell", 2), ("tell_bell_swing", tell_bell_swing, "tell", 2),
    ("tell_bell_peal", tell_bell_peal, "tell", 2),
    ("tell_lamplighter_kindle", tell_lamplighter_kindle, "tell", 3), ("tell_lamplighter_throw", tell_lamplighter_throw, "tell", 3),
    ("tell_tallow", tell_tallow, "tell", 3), ("tell_deep_maw", tell_deep_maw, "tell", 3),
    ("tell_keeper_shade", tell_keeper_shade, "tell", 3),
    ("tell_ebb_wave", tell_ebb_wave, "tell", 2), ("tell_ebb_pull", tell_ebb_pull, "tell", 2),
    ("tell_ebb_slam", tell_ebb_slam, "tell", 2), ("tell_ebb_surge", tell_ebb_surge, "tell", 2),
    ("tell_ebb_call", tell_ebb_call, "tell", 2),
    ("hit_metal", hit_metal, "layer", 3), ("hit_stone", hit_stone, "layer", 3), ("hit_coral", hit_coral, "layer", 3),
    ("hit_wax", hit_wax, "layer", 3), ("hit_water", hit_water, "layer", 3),
    ("die_metal", die_metal, "combat", 2), ("die_stone", die_stone, "combat", 2), ("die_coral", die_coral, "combat", 2),
    ("die_wax", die_wax, "combat", 2), ("die_water", die_water, "combat", 2),
    ("knife_stab", knife_stab, "combat", 4), ("knife_hit", knife_hit, "combat", 3), ("knife_cut", knife_cut, "combat", 2),
    ("knife_net", knife_net, "combat", 2),
    ("harpoon_fire", harpoon_fire, "combat", 3), ("harpoon_hit", harpoon_hit, "combat", 3),
    ("harpoon_reload", harpoon_reload, "combat", 2), ("harpoon_tether", harpoon_tether, "combat", 2),
    ("harpoon_drag", harpoon_drag, "combat", 2),
    ("kbell_swing", kbell_swing, "combat", 3), ("kbell_slam", kbell_slam, "combat", 2), ("kbell_hit", kbell_hit, "combat", 3),
    ("kbell_toll", kbell_toll, "combat", 2),
    ("line_crack", line_crack, "combat", 4), ("line_hit", line_hit, "combat", 3), ("line_throw", line_throw, "combat", 2),
    ("line_sink", line_sink, "combat", 2),
    ("lantern_arc", lantern_arc, "combat", 4), ("lantern_hit", lantern_hit, "combat", 3),
    ("lantern_throw", lantern_throw, "combat", 2), ("lantern_beacon", lantern_beacon, "combat", 2),
]


def main():
    """All of it, or only the names starting with any argument given."""
    only = sys.argv[1:]
    for name, fn, role, k in SAMPLE + REST:
        if not only or any(name.startswith(o) for o in only):
            variants(name, fn, role, k)
    print("combat sounds written")


if __name__ == "__main__":
    main()
