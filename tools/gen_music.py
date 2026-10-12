"""Procedural music for EBB: slow modal pads, a sparse plucked melody and a low drone, one
loop per place, plus a pulse for the bosses. Everything is synthesised; run from gen_audio.
"""
import numpy as np

from gen_audio import SR, save, lowpass, noise, loopable

# Modes as semitone steps from the root.
MODES = {
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "aeolian": [0, 2, 3, 5, 7, 8, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "harmonic": [0, 2, 3, 5, 7, 8, 11],
    "phrygian_dom": [0, 1, 4, 5, 7, 8, 10],
}

# name: (root Hz, mode, bpm, bars, chord degrees (0-based), melody density, boss pulse)
TRACKS = {
    "music_hub": (110.0, "dorian", 58, 8, [0, 5, 2, 6], 0.35, False),
    "music_flats": (73.42, "aeolian", 66, 8, [0, 5, 3, 4], 0.45, False),
    "music_streets": (82.41, "phrygian", 72, 8, [0, 1, 5, 0], 0.5, False),
    "music_hall": (69.30, "harmonic", 54, 8, [0, 3, 5, 6], 0.3, False),
    "music_boss": (87.31, "phrygian_dom", 112, 16, [0, 1, 0, 6], 0.7, True),
    # Later tracks go at the end: the seed is the position, so older loops stay byte-identical.
    "music_harbour": (65.41, "dorian", 62, 8, [0, 3, 4, 5], 0.4, False),
    # The deeper half of the night gets its own boss pulse: slower, lower, meaner.
    "music_deep": (61.74, "harmonic", 96, 16, [0, 6, 1, 5], 0.55, True),
    # M7: the rock with the Choir singing on it (the hub loop, warmer, a voice on top), and
    # the still sea after Walk out (nearly nothing: a drone and a note now and then).
    "music_hub_choir": (110.0, "dorian", 58, 8, [0, 5, 2, 6], 0.55, False),
    "music_still": (98.0, "aeolian", 48, 8, [0, 0, 5, 0], 0.15, False),
    # M8: the title's own theme (the lamp turning, nothing decided yet), and the two
    # epilogues that are not the still sea: the lamp kept lit, and the water let in.
    "music_title": (87.31, "dorian", 52, 8, [0, 4, 5, 2], 0.3, False),
    "music_keep": (98.0, "dorian", 56, 8, [0, 4, 0, 5], 0.4, False),
    "music_break": (77.78, "phrygian", 62, 8, [0, 5, 1, 4], 0.35, False),
    # Map Stage 11l: the reef road, the water moving again: dorian like the harbour but higher,
    # quicker and busier, the chords climbing off the root instead of settling (rendered alone by
    # tools/gen_reef_audio.py, so nothing above is remade).
    "music_reef": (92.50, "dorian", 68, 8, [0, 6, 4, 3], 0.5, False),
}


def freq(root, mode, degree, octave=0):
    steps = MODES[mode]
    o, d = divmod(degree, len(steps))
    return root * 2 ** (octave + o + steps[d] / 12.0)


def pad_note(f, n, tt):
    """Two detuned sines and a soft third harmonic, slow tremolo."""
    det = 1.004
    x = (np.sin(2 * np.pi * f * tt) + np.sin(2 * np.pi * f * det * tt)
         + 0.25 * np.sin(2 * np.pi * f * 3 * tt + 0.3))
    x *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.21 * tt + f)
    return x / 2.5


def pluck(f, n, bright=0.5):
    tt = np.arange(n) / SR
    env = np.exp(-tt * 3.2)
    x = np.sin(2 * np.pi * f * tt) + bright * 0.5 * np.sin(2 * np.pi * 2 * f * tt) * np.exp(-tt * 6)
    x += 0.15 * np.sin(2 * np.pi * 3 * f * tt) * np.exp(-tt * 9)
    return x * env


def kick(n):
    tt = np.arange(n) / SR
    f = 110 * np.exp(-tt * 18) + 38
    phase = np.cumsum(2 * np.pi * f / SR)
    return np.sin(phase) * np.exp(-tt * 9)


def hat(n):
    tt = np.arange(n) / SR
    from gen_audio import highpass
    return highpass(noise(n), 5000, 2) * np.exp(-tt * 40) * 0.5


def make_track(name, root, mode, bpm, bars, chords, density, boss, seed):
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    dur = beat * 4 * bars
    n = int(SR * dur)
    tt = np.arange(n) / SR
    mix = np.zeros(n)

    # Pads: one chord per two bars (per bar for the boss), overlapping half a second.
    bars_per_chord = 1 if boss else 2
    chord_len = beat * 4 * bars_per_chord
    fade = int(SR * 0.6)
    for ci in range(bars * 4 // (4 * bars_per_chord)):
        deg = chords[ci % len(chords)]
        s = int(ci * chord_len * SR)
        e = min(n, int((ci + 1) * chord_len * SR) + fade)
        seg_t = tt[s:e]
        seg = np.zeros(e - s)
        for k, (off, octv) in enumerate(((0, 1), (2, 1), (4, 1), (0, 2))):
            seg += pad_note(freq(root, mode, deg + off, octv), e - s, seg_t) * (0.8 if k < 3 else 0.35)
        env = np.ones(e - s)
        env[:fade] = np.linspace(0, 1, fade)
        env[-fade:] *= np.linspace(1, 0, fade)
        mix[s:e] += seg * env * 0.22

    # Drone: the root, two octaves down, breathing.
    mix += 0.12 * np.sin(2 * np.pi * root * 0.5 * tt) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.07 * tt))

    # Melody: pentatonic steps (degrees 0 2 3 4 6 of the mode), mostly stepwise.
    pent = [0, 2, 3, 4, 6]
    cur = 2
    step_n = int(SR * beat)
    for b in range(bars * 4 * 2):  # eighth notes
        if rng.random() > density:
            continue
        cur = int(np.clip(cur + rng.choice([-2, -1, -1, 0, 1, 1, 2]), 0, len(pent) * 2 - 1))
        o, d = divmod(cur, len(pent))
        f = freq(root, mode, pent[d], 3 + o)
        s = int(b * step_n * 0.5)
        ln = int(SR * beat * rng.choice([1.0, 1.5, 2.0]))
        e = min(n, s + ln)
        vel = rng.uniform(0.35, 0.7)
        mix[s:e] += pluck(f, e - s, bright=0.3 if not boss else 0.8)[: e - s] * vel * 0.28

    # Bass: root of the chord on the bar (boss: every beat, with the drum).
    for b in range(bars * 4):
        if not boss and b % 4 != 0:
            continue
        deg = chords[(b // (4 * bars_per_chord)) % len(chords)]
        f = freq(root, mode, deg, 0)
        s = int(b * beat * SR)
        ln = int(SR * (beat * 3.5 if not boss else beat * 0.9))
        e = min(n, s + ln)
        seg_t = np.arange(e - s) / SR
        env = np.exp(-seg_t * (0.6 if not boss else 3.0)) * np.minimum(1.0, seg_t * 40)
        mix[s:e] += (np.sin(2 * np.pi * f * seg_t) + 0.3 * np.sin(2 * np.pi * 2 * f * seg_t)) * env * (0.22 if not boss else 0.32)

    if boss:
        kn = int(SR * 0.35)
        hn = int(SR * 0.08)
        for b in range(bars * 4):
            s = int(b * beat * SR)
            if b % 2 == 0:
                mix[s:s + kn] += kick(kn)[: n - s] * 0.55
            hs = s + int(beat * SR * 0.5)
            if hs + hn < n:
                mix[hs:hs + hn] += hat(hn) * 0.25
            if b % 4 == 3:
                e = min(n, s + kn)
                mix[s:e] += kick(e - s) * 0.4
        # a tremolo pulse on the whole thing, like the hall breathing faster
        mix *= 0.85 + 0.15 * np.sin(2 * np.pi * (bpm / 60.0) * tt)

    mix = lowpass(mix, 3800, 2)
    save(name, loopable(mix, 1.2), 0.6)


def build_music():
    for i, (name, spec) in enumerate(TRACKS.items()):
        make_track(name, *spec, seed=100 + i)
