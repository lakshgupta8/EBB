"""The synthesis kit (audio Stage 04, STYLE.md 23.1): one set of instruments for the whole game,
so every place sounds related. 44.1 kHz, stereo, every note from a seeded random stream.

    import synth
    part = synth.render("cittern", "D4/1 A4/1.5 G4/.5 F4/1 D4/2", bpm=66, pan=-0.3)
    room = synth.reverb(part, "flats")
    synth.save_ogg("demo", room, folder)

Families (each a function of frequency, seconds, velocity and a random stream, returning mono):
  plucked  cittern, harp, bass           Karplus-Strong strings, a body resonance, a pick
  reed     harmonium, concertina         additive reeds, two beating, a breath on the attack
  metal    ship_bell, hand_bell, buoy, glass, saltmere   modal partials (FM for the buoy)
  wood     frame_drum, wood_block, stone_marimba, hull   modal bars and membranes, a strike
  bowed    strings, bowed_glass, drone   band-limited saw through a body, slow bow, late vibrato
  voice    choir_ah, choir_oo, hum       a glottal source through vowel formants, an ensemble
  noise    surf, wind, breath, chain, rain

Notes are written as text, one part a line (see `parse`):
  "D4/1 A4/1.5 G4/.5 r/1 D3+A3/4@.6"  pitch(es) joined by +, / beats, @ velocity, r a rest
"""
import os
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import fftconvolve, lfilter, sosfilt, butter

SR = 44100
_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


# ----------------------------------------------------------------------------- basics
def hz(note):
    """'A4' -> 440.0; sharps '#', flats 'b' ('Eb3', 'F#2')."""
    step = _NAMES[note[0].upper()]
    i = 1
    while i < len(note) and note[i] in "#b":
        step += 1 if note[i] == "#" else -1
        i += 1
    octave = int(note[i:])
    return 440.0 * 2 ** ((12 * (octave + 1) + step - 69) / 12.0)


def secs(n):
    return np.arange(n) / SR


def env(n, a=0.005, d=0.0, s=1.0, r=0.05, hold=None):
    """Attack, decay to sustain, release over the last r seconds; n samples in all."""
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na, endpoint=False)
    if nd:
        e[na:na + nd] = np.linspace(1, s, len(e[na:na + nd]))
    if nr:
        e[-nr:] *= np.linspace(1, 0, min(nr, n))
    return e


def decay(n, t60):
    """An exponential that falls 60 dB in t60 seconds."""
    return 10 ** (-3 * secs(n) / max(t60, 1e-3))


def lowpass(x, f, order=2):
    return sosfilt(butter(order, min(f, SR * 0.45), "low", fs=SR, output="sos"), x)


def highpass(x, f, order=2):
    return sosfilt(butter(order, f, "high", fs=SR, output="sos"), x)


def bandpass(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, min(hi, SR * 0.45)], "band", fs=SR, output="sos"), x)


def peak(x, f, q, gain_db):
    """A peaking filter (RBJ): a body resonance or a formant."""
    a = 10 ** (gain_db / 40.0)
    w = 2 * np.pi * f / SR
    al = np.sin(w) / (2 * q)
    b = [1 + al * a, -2 * np.cos(w), 1 - al * a]
    den = [1 + al / a, -2 * np.cos(w), 1 - al / a]
    return lfilter(b, den, x)


def resonator(x, f, bw):
    """A two-pole resonance: a formant of width bw Hz, unity gain at its centre."""
    r = np.exp(-np.pi * bw / SR)
    c = -2 * r * np.cos(2 * np.pi * f / SR)
    return lfilter([1 - r], [1, c, r * r], x)


def additive(f, n, amps, ratios=None, phases=None, fm=None):
    """Sum of sine partials up to 16 kHz. fm: a per-sample frequency multiplier (vibrato)."""
    tt = secs(n)
    out = np.zeros(n)
    ph = np.cumsum(np.ones(n) * (fm if fm is not None else 1.0)) / SR if fm is not None else tt
    for k, amp in enumerate(amps):
        r = ratios[k] if ratios is not None else k + 1
        if f * r > 16000 or amp == 0:
            continue
        p0 = phases[k] if phases is not None else 0.0
        out += amp * np.sin(2 * np.pi * f * r * ph + p0)
    return out


def pan(mono, p):
    """Constant power, p from -1 (left) to 1 (right)."""
    a = (p + 1) * np.pi / 4
    return np.stack([mono * np.cos(a), mono * np.sin(a)], axis=1)


def mix(*parts):
    """Sum stereo parts of any length."""
    n = max(len(p) for p in parts)
    out = np.zeros((n, 2))
    for p in parts:
        out[:len(p)] += p
    return out


# ----------------------------------------------------------------------------- plucked
def _ks(f, n, bright, t60, rng):
    """One Karplus-Strong string, tuned exactly by rendering a little sharp and resampling."""
    period = int(SR / f - 0.5)
    f_int = SR / (period + 0.5)
    m = int(n * f_int / f) + 2
    burst = rng.uniform(-1, 1, period)
    burst = lfilter([bright], [1, -(1 - bright)], burst)
    burst -= burst.mean()
    x = np.zeros(m)
    x[:period] = burst
    rho = 10 ** (-3 / (t60 * f_int))
    a = np.zeros(period + 2)
    a[0] = 1.0
    a[period] = -0.5 * rho
    a[period + 1] = -0.5 * rho
    y = lfilter([1.0], a, x)
    src = np.arange(n) * (f / f_int)
    return np.interp(src, np.arange(m), y)


def cittern(f, dur, vel, rng):
    """Two courses a few cents apart, a wooden body, the pick's click: Tam and the living."""
    n = int((dur + 1.6) * SR)
    s = _ks(f * 2 ** (3 / 1200), n, 0.55 + 0.2 * vel, 1.8, rng) + _ks(f * 2 ** (-3 / 1200), n, 0.5 + 0.2 * vel, 1.6, rng)
    s = peak(peak(s, 220, 1.5, 5), 520, 2.0, 3)
    pick = highpass(rng.uniform(-1, 1, n) * decay(n, 0.012), 2500) * 0.15
    return (s * 0.5 + pick) * vel * env(n, 0.001, r=0.08)


def harp(f, dur, vel, rng):
    """Softer and longer: the Cartographer, the reef's arpeggios."""
    n = int((dur + 3.0) * SR)
    s = _ks(f, n, 0.28 + 0.15 * vel, 3.2, rng)
    s = peak(s, 300, 1.0, 3)
    return s * vel * env(n, 0.002, r=0.3)


def bass(f, dur, vel, rng):
    """A muted low string under the hand: short, round."""
    n = int((dur + 0.4) * SR)
    s = _ks(f, n, 0.22, 0.7, rng)
    s = lowpass(s, 900)
    return s * 1.4 * vel * env(n, 0.003, r=0.12)


# ----------------------------------------------------------------------------- reed
def _reeds(f, n, amps, beat, rng, breath=0.05, swell=0.0):
    tt = secs(n)
    a = additive(f - beat / 2, n, amps, phases=rng.uniform(0, 6.28, len(amps)))
    b = additive(f + beat / 2, n, amps, phases=rng.uniform(0, 6.28, len(amps)))
    s = (a + b) * 0.5
    br = bandpass(rng.normal(0, 1, n), 900, 3200) * decay(n, 0.25) * breath
    bellows = 1 + swell * np.sin(2 * np.pi * 0.35 * tt + rng.uniform(0, 6.28))
    return (s * bellows + br)


def harmonium(f, dur, vel, rng):
    """The lighthouse's own: a reedy organ, warm, hardly moving. Home."""
    n = int((dur + 0.25) * SR)
    amps = [1.0 / (k ** 0.9) * (1.15 if k % 2 else 0.85) for k in range(1, 30)]
    s = _reeds(f, n, amps, 0.6, rng, 0.04, 0.03)
    s = lowpass(peak(s, 1100, 1.0, 3), 6000)
    return s * 0.35 * vel * env(n, 0.06, r=0.2)


def concertina(f, dur, vel, rng):
    """Brighter, two reeds tuned apart so it beats: the harbour's work."""
    n = int((dur + 0.15) * SR)
    amps = [1.0 / (k ** 0.7) for k in range(1, 30)]
    s = _reeds(f, n, amps, f * 0.006, rng, 0.07, 0.06)
    s = lowpass(peak(s, 1800, 1.2, 4), 8000)
    return s * 0.3 * vel * env(n, 0.03, r=0.12)


# ----------------------------------------------------------------------------- struck metal
def _modal(f, n, ratios, t60s, amps, rng, detune=0.002):
    out = np.zeros(n)
    tt = secs(n)
    for r, t60, a in zip(ratios, t60s, amps):
        fr = f * r * (1 + rng.uniform(-detune, detune))
        if fr > 16000:
            continue
        out += a * np.sin(2 * np.pi * fr * tt) * decay(n, t60)  # from zero: a strike, not a step
    return out


def ship_bell(f, dur, vel, rng):
    """A bronze bell: the hum an octave down, the minor third that makes it a bell. Time; warning."""
    n = int(max(dur, 4.5) * SR)
    s = _modal(f, n, [0.5, 1.0, 1.19, 1.5, 2.0, 2.5, 2.66, 3.01, 4.17],
               [5.0, 4.0, 3.0, 2.4, 2.0, 1.4, 1.2, 0.9, 0.6], [0.5, 0.8, 0.6, 0.3, 0.5, 0.2, 0.2, 0.15, 0.08], rng)
    strike = highpass(rng.uniform(-1, 1, n) * decay(n, 0.02), 1500) * 0.3
    return (s + strike) * 0.5 * vel * env(n, 0.001, r=0.05)


def hand_bell(f, dur, vel, rng):
    """Small and clear (the fundamental and its twelfth): Wren's bells."""
    n = int(max(dur, 2.5) * SR)
    s = _modal(f, n, [1.0, 3.0, 4.18, 5.43], [2.2, 1.2, 0.7, 0.5], [1.0, 0.45, 0.2, 0.1], rng, 0.001)
    return s * 0.45 * vel * env(n, 0.001, r=0.05)


def buoy(f, dur, vel, rng):
    """A buoy's bell, rocked: FM, the brightness falling as it rings."""
    n = int(max(dur, 3.0) * SR)
    tt = secs(n)
    index = 3.0 * decay(n, 0.8) + 0.3
    s = np.sin(2 * np.pi * f * tt + index * np.sin(2 * np.pi * f * 1.41 * tt)) * decay(n, 2.5)
    return s * 0.4 * vel * env(n, 0.001, r=0.05)


def glass(f, dur, vel, rng):
    """Struck glass, high and pure: Pell's salt-glass, the reef's light."""
    n = int(max(dur, 3.0) * SR)
    s = _modal(f, n, [1.0, 2.32, 4.25, 6.63], [2.8, 1.6, 0.9, 0.5], [1.0, 0.35, 0.15, 0.08], rng, 0.0005)
    return s * 0.35 * vel * env(n, 0.001, r=0.05)


def saltmere(f, dur, vel, rng):
    """The Bell of Saltmere: huge, low, its hum beating against itself, never quite in tune."""
    n = int(max(dur, 8.0) * SR)
    s = _modal(f, n, [0.5, 0.503, 1.0, 1.183, 1.506, 2.0, 2.52, 2.67, 3.0],
               [9.0, 9.0, 7.0, 5.0, 3.5, 3.0, 2.0, 1.6, 1.2], [0.5, 0.4, 0.8, 0.7, 0.3, 0.5, 0.2, 0.2, 0.1], rng, 0.004)
    strike = lowpass(rng.uniform(-1, 1, n) * decay(n, 0.05), 3000) * 0.35
    return (s + strike) * 0.35 * vel * env(n, 0.002, r=0.1)


# ----------------------------------------------------------------------------- wood and stone
def frame_drum(f, dur, vel, rng):
    """A hand on a skin: the membrane's modes, the pitch dropping as it settles. The rhythm layer."""
    n = int(0.9 * SR)
    tt = secs(n)
    out = np.zeros(n)
    bend = 1 + 0.12 * np.exp(-tt / 0.03)
    for r, t60, a in zip([1.0, 1.59, 2.14, 2.30, 2.65, 2.92], [0.45, 0.25, 0.18, 0.16, 0.12, 0.1], [1.0, 0.5, 0.35, 0.3, 0.2, 0.15]):
        out += a * np.sin(2 * np.pi * f * r * np.cumsum(bend) / SR) * decay(n, t60)
    slap = bandpass(rng.uniform(-1, 1, n), 400, 4000) * decay(n, 0.03 + 0.03 * (1 - vel)) * 0.5
    return (out * 0.6 + slap) * vel


def wood_block(f, dur, vel, rng):
    """A dry knock: the clock of the harbour's work."""
    n = int(0.3 * SR)
    s = _modal(f, n, [1.0, 2.58, 4.1], [0.09, 0.05, 0.03], [1.0, 0.4, 0.2], rng)
    click = highpass(rng.uniform(-1, 1, n) * decay(n, 0.004), 2000) * 0.3
    return (s + click) * 0.6 * vel


def stone_marimba(f, dur, vel, rng):
    """Tuned stone bars under a soft mallet: Hale's, the reef."""
    n = int(1.6 * SR)
    s = _modal(f, n, [1.0, 2.76, 5.4, 8.9], [0.9, 0.25, 0.08, 0.04], [1.0, 0.3, 0.12, 0.05], rng, 0.001)
    mallet = lowpass(rng.uniform(-1, 1, n) * decay(n, 0.008), 2500) * 0.25
    return (s + mallet) * 0.55 * vel


def hull(f, dur, vel, rng):
    """Timbers struck in a hull: a low hollow knock. The Wreck's drum."""
    n = int(1.0 * SR)
    s = _modal(f, n, [1.0, 2.31, 3.72, 5.2], [0.35, 0.15, 0.08, 0.05], [1.0, 0.45, 0.25, 0.1], rng, 0.01)
    thud = lowpass(rng.uniform(-1, 1, n) * decay(n, 0.04), 700) * 0.6
    return (s + thud) * 0.6 * vel


# ----------------------------------------------------------------------------- bowed
def _bow(f, n, rng, body=(280, 950, 2400), vib_at=0.45, vib=0.004, bright=1.0):
    tt = secs(n)
    onset = np.clip((tt - vib_at) / 0.6, 0, 1)
    fm = 1 + vib * onset * np.sin(2 * np.pi * (5.2 + rng.uniform(-0.3, 0.3)) * tt + rng.uniform(0, 6.28)) \
        + 0.0008 * np.sin(2 * np.pi * 0.7 * tt + rng.uniform(0, 6.28))
    amps = [(1.0 / k) * (1.0 if k < 6 else bright) for k in range(1, 48)]
    s = additive(f, n, amps, fm=fm, phases=rng.uniform(0, 6.28, len(amps)))
    for fc, g in zip(body, (6, 4, 3)):
        s = peak(s, fc, 1.4, g)
    hiss = highpass(rng.normal(0, 1, n), 3000) * 0.012
    return s + hiss


def strings(f, dur, vel, rng):
    """Low strings, three players a few cents apart: the sea, the danger layer, Aldous."""
    n = int((dur + 0.5) * SR)
    s = sum(_bow(f * 2 ** (c / 1200), n, rng, bright=0.7) for c in (-6, 0, 5)) / 3
    s = lowpass(s, 5000)
    return s * 0.3 * vel * env(n, 0.35, r=0.45)


def bowed_glass(f, dur, vel, rng):
    """Glass bowed at its rim: a pure tone that swells and shivers. The drowned's light."""
    n = int((dur + 1.0) * SR)
    tt = secs(n)
    trem = 1 + 0.08 * np.sin(2 * np.pi * 3.1 * tt)
    s = additive(f, n, [1.0, 0.25, 0.08], ratios=[1.0, 2.32, 4.25]) * trem
    return s * 0.35 * vel * env(n, 0.8, r=0.9)


def drone(f, dur, vel, rng):
    """The floor: a bowed low note, dark, breathing, never attacking."""
    n = int((dur + 1.5) * SR)
    tt = secs(n)
    s = sum(_bow(f * 2 ** (c / 1200), n, rng, bright=0.4, vib=0.0) for c in (-4, 4)) / 2
    s = lowpass(s, 1400) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.09 * tt + rng.uniform(0, 6.28)))
    return s * 0.4 * vel * env(n, 1.5, r=1.5)


# ----------------------------------------------------------------------------- voice
VOWELS = {
    # formant centre Hz, bandwidth Hz, gain: an alto's "ah", "oo", and a hum through the nose
    "ah": [(800, 80, 1.0), (1150, 90, 0.5), (2800, 120, 0.12), (3500, 130, 0.08)],
    "oo": [(350, 60, 1.0), (650, 80, 0.3), (2600, 120, 0.03), (3300, 150, 0.02)],
    "mm": [(250, 60, 1.0), (1100, 200, 0.04), (2400, 200, 0.02)],
}


def _voice(f, n, vowel, rng, vib=0.006):
    tt = secs(n)
    onset = np.clip((tt - 0.25) / 0.5, 0, 1)
    fm = 1 + vib * onset * np.sin(2 * np.pi * (5.4 + rng.uniform(-0.4, 0.4)) * tt + rng.uniform(0, 6.28)) \
        + 0.002 * lowpass(rng.normal(0, 1, n), 6)
    src = additive(f, n, [1.0 / (k ** 1.1) for k in range(1, 60)], fm=fm)
    src += lowpass(rng.normal(0, 1, n), 5000) * 0.02  # breath
    return sum(g * resonator(src, fc, bw) for fc, bw, g in VOWELS[vowel])


def _choir(f, dur, vel, rng, vowel):
    n = int((dur + 0.6) * SR)
    voices = [_voice(f * 2 ** (c / 1200), n, vowel, rng) for c in (-9, -3, 4, 10)]
    return sum(voices) / 4 * vel * env(n, 0.25, r=0.5)


def choir_ah(f, dur, vel, rng):
    """Four drowned voices, wordless, open: the Choir, the Hall."""
    return _choir(f, dur, vel, rng, "ah") * 0.45


def choir_oo(f, dur, vel, rng):
    """The same four, closed: the sea's chorus under a place."""
    return _choir(f, dur, vel, rng, "oo") * 0.6


def hum(f, dur, vel, rng):
    """One voice humming, close: Maren."""
    n = int((dur + 0.4) * SR)
    return _voice(f, n, "mm", rng, vib=0.004) * 0.5 * vel * env(n, 0.12, r=0.3)


# ----------------------------------------------------------------------------- noise
def surf(f, dur, vel, rng):
    """One wave: the swell, the break, the drain back through the shingle. f is ignored."""
    n = int(max(dur, 5.0) * SR)
    tt = secs(n)
    shape = np.clip(tt / (n / SR * 0.45), 0, 1) ** 2 * decay(n, n / SR * 0.9)
    body = lowpass(rng.normal(0, 1, n), 900) * shape
    hiss = highpass(rng.normal(0, 1, n), 2500) * shape ** 2 * 0.4
    drain = bandpass(rng.normal(0, 1, n), 3000, 9000) * np.clip((tt - n / SR * 0.5) / 0.5, 0, 1) * decay(n, 1.8) * 0.15
    return (body + hiss + drain) * 0.5 * vel


def wind(f, dur, vel, rng):
    """Wind over the rock: noise through a band that wanders."""
    n = int(max(dur, 4.0) * SR)
    tt = secs(n)
    x = rng.normal(0, 1, n)
    bands = [resonator(x, c, 140) for c in (380, 650, 1100)]
    w = [0.5 + 0.5 * np.sin(2 * np.pi * r * tt + rng.uniform(0, 6.28)) for r in (0.11, 0.17, 0.07)]
    gust = 0.6 + 0.4 * lowpass(rng.normal(0, 1, n), 0.8) / 0.05
    out = sum(b * g for b, g in zip(bands, w)) * np.clip(gust, 0.2, 1.4)
    return out * 2.0 * vel * env(n, 1.0, r=1.0)


def breath(f, dur, vel, rng):
    """In and out, close: the drowned breathing."""
    n = int(max(dur, 2.4) * SR)
    tt = secs(n)
    shape = np.sin(np.pi * np.clip(tt / (n / SR), 0, 1)) ** 2
    s = bandpass(rng.normal(0, 1, n), 500, 2500) * shape
    return resonator(s, 900, 300) * 1.5 * vel


def chain(f, dur, vel, rng):
    """Links rattling: many small metal clicks, bunched."""
    n = int(max(dur, 1.2) * SR)
    out = np.zeros(n)
    k = int(30 + 40 * vel)
    for t0 in np.sort(rng.beta(1.2, 2.5, k)) * (n - SR // 10):
        m = SR // 12
        click = _modal(rng.uniform(1800, 4200), m, [1.0, 2.7, 5.1], [0.05, 0.03, 0.02], [1.0, 0.5, 0.3], rng)
        out[int(t0):int(t0) + m] += click * rng.uniform(0.3, 1.0)
    return out * 0.3 * vel


def rain(f, dur, vel, rng):
    """Drops on water and stone: a hiss and many small plinks."""
    n = int(max(dur, 4.0) * SR)
    out = highpass(rng.normal(0, 1, n), 4000) * 0.05
    for t0 in rng.uniform(0, n - SR // 10, int(60 * n / SR * vel)):
        m = SR // 25
        out[int(t0):int(t0) + m] += np.sin(2 * np.pi * rng.uniform(1500, 3500) * secs(m) * (1 + secs(m) * 8)) * decay(m, 0.02) * rng.uniform(0.05, 0.25)
    return out * vel


INSTRUMENTS = {
    "cittern": cittern, "harp": harp, "bass": bass,
    "harmonium": harmonium, "concertina": concertina,
    "ship_bell": ship_bell, "hand_bell": hand_bell, "buoy": buoy, "glass": glass, "saltmere": saltmere,
    "frame_drum": frame_drum, "wood_block": wood_block, "stone_marimba": stone_marimba, "hull": hull,
    "strings": strings, "bowed_glass": bowed_glass, "drone": drone,
    "choir_ah": choir_ah, "choir_oo": choir_oo, "hum": hum,
    "surf": surf, "wind": wind, "breath": breath, "chain": chain, "rain": rain,
}


# ----------------------------------------------------------------------------- space
# t60 s, pre-delay ms, early reflections (ms, gain), high-frequency damping (0 bright, 1 dark),
# width, a chorus on the tail. STYLE.md 23.6.
SPACES = {
    "rock": (0.5, 8, [(11, 0.35), (19, 0.25), (31, 0.15)], 0.6, 0.6, False),
    "flats": (0.6, 20, [(45, 0.12)], 0.4, 1.0, False),
    "harbour": (0.9, 15, [(110, 0.32), (190, 0.14)], 0.5, 0.8, False),
    "reef": (1.2, 25, [(27, 0.2), (53, 0.12)], 0.75, 1.0, True),
    "streets": (1.6, 18, [(14, 0.3), (23, 0.28), (37, 0.2), (61, 0.12)], 0.45, 0.9, False),
    "hall": (4.0, 45, [(38, 0.25), (71, 0.2), (113, 0.16), (160, 0.12)], 0.35, 1.0, False),
}


def impulse(space, seed=11):
    """A stereo impulse response for a place: early reflections, then a tail of noise that falls
    by its t60 and loses its top faster than its body."""
    t60, pre, early, damp, width, chorus = SPACES[space]
    rng = np.random.default_rng(seed)
    n = int((t60 * 1.2 + pre / 1000) * SR)
    ir = np.zeros((n, 2))
    p = int(pre * SR / 1000)
    tail_n = n - p
    tt = secs(tail_n)
    for ch in range(2):
        nz = rng.normal(0, 1, tail_n)
        lo = lowpass(nz, 1500) * decay(tail_n, t60)
        hi = highpass(nz, 1500) * decay(tail_n, t60 * (1 - 0.7 * damp))
        tail = (lo + hi) * np.clip(tt / 0.02, 0, 1)
        if chorus:
            tail *= 1 + 0.25 * np.sin(2 * np.pi * (0.7 + 0.2 * ch) * tt)
        ir[p:, ch] = tail
    side = (ir[:, 0] - ir[:, 1]) * 0.5 * width
    mid = (ir[:, 0] + ir[:, 1]) * 0.5
    ir[:, 0], ir[:, 1] = mid + side, mid - side
    ir /= np.sqrt(np.sum(ir ** 2) / 2)
    for ms, g in early:
        i = int(ms * SR / 1000)
        ir[i, 0] += g * (1.0 if ms % 2 else 0.7)
        ir[i, 1] += g * (0.7 if ms % 2 else 1.0)
    return ir


def reverb(x, space, wet=0.25):
    """The part in the place: dry plus wet."""
    ir = impulse(space)
    if x.ndim == 1:
        x = pan(x, 0.0)
    w = np.stack([fftconvolve(x[:, 0], ir[:, 0]), fftconvolve(x[:, 1], ir[:, 1])], axis=1)
    out = np.zeros_like(w)
    out[:len(x)] = x
    return out + w * wet


# ----------------------------------------------------------------------------- notes
def parse(text):
    """'D4/1 A4/1.5 r/.5 D3+A3/4@.6' -> [(onset beats, [Hz], beats, velocity)]."""
    out, at = [], 0.0
    for tok in text.split():
        vel = 0.8
        if "@" in tok:
            tok, v = tok.split("@")
            vel = float(v)
        pitch, beats = tok.split("/")
        beats = float(beats)
        if pitch != "r":
            out.append((at, [hz(p) for p in pitch.split("+")], beats, vel))
        at += beats
    return out


def render(instrument, text, bpm=60, pan_to=0.0, seed=1, gain=1.0):
    """One part, its notes from text, on one instrument, as stereo."""
    fn = INSTRUMENTS[instrument]
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    notes = parse(text)
    parts = []
    for at, freqs, beats, vel in notes:
        for f in freqs:
            m = fn(f, beats * beat, vel, rng)
            i = int(at * beat * SR)
            buf = np.zeros(i + len(m))
            buf[i:] = m
            parts.append(buf)
    n = max(len(p) for p in parts)
    mono = np.zeros(n)
    for p in parts:
        mono[:len(p)] += p
    return pan(mono * gain, pan_to)


def limit(x, ceiling_db=-7.0, look_ms=5.0, release_ms=80.0):
    """A look-ahead peak limiter: the gain falls before a peak arrives and recovers slowly, so a
    few strikes do not decide the level of a whole part."""
    from scipy.ndimage import maximum_filter1d
    ceil = 10 ** (ceiling_db / 20)
    lvl = np.abs(x).max(axis=1) if x.ndim == 2 else np.abs(x)
    look = max(1, int(look_ms * SR / 1000))
    want = np.minimum(1.0, ceil / np.maximum(maximum_filter1d(lvl, 2 * look + 1), 1e-9))
    rel = np.exp(-1.0 / (release_ms * SR / 1000))
    g = lfilter([1 - rel], [1, -rel], want)  # recover slowly...
    g = np.minimum(g, want)                  # ...but never let a peak through
    g = -maximum_filter1d(-g, 2 * look + 1)  # and start falling before it
    return x * (g[:, None] if x.ndim == 2 else g)


# ----------------------------------------------------------------------------- files
def save_ogg(name, x, folder, quality=5):
    """Stereo float to Ogg Vorbis through ffmpeg."""
    os.makedirs(folder, exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    tmp = os.path.join(tempfile.gettempdir(), name + "_synth.wav")
    wavfile.write(tmp, SR, pcm)
    out = os.path.join(folder, name + ".ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality), out], check=True)
    os.remove(tmp)
    return out
