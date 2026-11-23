"""The Reef's score (audio Stage 07; STYLE.md 23.3): F sharp dorian in 6/8, a dotted crotchet at 68
(written in eighths at 204), the water moving: Hale's rising theme on the stone marimba over a
drone and harp arpeggios that never stop, like the current. A fight brings a lilting frame drum
and the bass, and the Sea under them on low strings; a high tide, the closed choir. A (24 bars:
Hale's theme and its answer, again with glass an octave up, then eight bars of glass alone) runs
into B (32, a brighter tune in E), the breakdown (16, Hale's rise on glass, very slow) and A'
(24): 96 bars, about three minutes.

The Tidewall: stone struck for the drum, the harp's arpeggio rising with the current; in its
second phase the current is turned, so the arpeggio falls, and each surge is a swell on the
strings and the choir. The kill finishes Hale's rise.

    python tools/gen_score_reef.py [--preview]
"""
import os
import sys

import numpy as np
from scipy.signal import resample_poly

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score  # noqa: E402
from score import chords, roots  # noqa: E402
from audio_audit import read  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAR = 6  # eighths

# Hale's theme (STYLE.md 23.2: rising), its answer, and the answer landing home.
HALE = "F#4/1 A4/1 B4/1 C#5/1 E5/2 F#5/6 E5/2 C#5/1 B4/2 A4/1 B4/6"
ANSWER = "A4/1 B4/1 C#5/1 E5/1 F#5/2 G#5/6 F#5/2 E5/1 C#5/2 B4/1 C#5/6"
HOME = "A4/1 B4/1 C#5/1 E5/1 F#5/2 G#5/6 F#5/2 E5/1 C#5/2 B4/1 F#4/6"
BRIGHT = ("B4/2 E5/1 G#5/3 F#5/2 E5/1 B4/3 C#5/2 E5/1 G#5/2 E5/1 A4/6 "
          "B4/2 E5/1 G#5/3 B5/3 F#5/3 E5/2 C#5/1 A4/3 B4/6")
SEA = "F#3/6 G3/6 G#3/6 A3/9 G#3/3 G3/6 F#3/12"

A8 = "F#m F#m A B A E F#m C#m"
B8 = "E B C#m A E B A B"
C8 = "F#m F#m A A B B F#m F#m"
BOSS1 = "F#m F#m G F#m F#m D E C#"
BOSS2 = "F#m G F#m G D E C# C#"

DRUM = "A2/3@.85 A2/2@.5 A2/1@.6"


def n(symbols):
    return len(symbols.split())


def rest(bars):
    return f"r/{bars * BAR}"


def ripple(symbols, octave=3, vel=0.4, falling=False):
    """The current: each bar's chord run up through two octaves in eighths (or down, turned)."""
    out = []
    for s in symbols.split():
        r, t, f = score.chord_notes(s, octave)
        run = [r, t, f, r + 12, t + 12, f + 12]
        if falling:
            run = run[::-1]
        for k, m in enumerate(run):
            out.append(f"{score.note(m)}/1@{vel if k == 0 else vel * 0.7:.2f}")
    return " ".join(out)


def bed(symbols):
    bars = n(symbols)
    return [("drone", f"F#2/{bars * BAR}@.7", 0.0, 0.5),
            ("strings", chords(symbols, 2, beats=BAR, fifths=True, vel=0.4), 0.1, 0.3),
            ("harp", ripple(symbols), 0.3, 0.45)]


def rhythm(symbols, drum=DRUM, row="3@.8 3@.55"):
    k = n(symbols)
    return [("frame_drum", " ".join([drum] * k), 0.2, 0.8), ("bass", roots(symbols, row), -0.1, 0.7)]


def tide(symbols, voice="choir_oo"):
    return [(voice, chords(symbols, 3, beats=BAR, vel=0.45), -0.25, 0.5)]


def sea(bars):
    return " ".join([SEA] * (bars // 8))


def up(text, semis=12):
    """The same line an octave (or so) higher."""
    out = []
    for tok in text.split():
        p, rest_ = tok.split("/", 1)
        if p != "r":
            midi = round(12 * np.log2(score.synth.hz(p) / 440.0) + 69) + semis
            p = score.note(midi)
        out.append(p + "/" + rest_)
    return " ".join(out)


SPEC = {
    "name": "music_reef", "folder": "reef", "bpm": 204, "bar_beats": BAR, "first": "a",
    "sections": {
        "a": {"bars": 24, "next": "b", "stems": {
            "bed": bed(" ".join([A8] * 3)),
            "melody": [("stone_marimba", " ".join([HALE, ANSWER, HALE, ANSWER, rest(8)]), -0.25, 0.9),
                       ("glass", " ".join([rest(8), up(HALE), up(ANSWER), "F#5/12 E5/12 C#5/12 B4/12"]), 0.3, 0.5)],
            "rhythm": rhythm(" ".join([A8] * 3)),
            "danger": [("strings", sea(24), 0.35, 0.45)],
            "tide": tide(" ".join([A8] * 3))}},
        "b": {"bars": 32, "next": "c", "stems": {
            "bed": bed(" ".join([B8] * 4)),
            "melody": [("stone_marimba", " ".join([BRIGHT, BRIGHT, rest(8), BRIGHT]), -0.25, 0.9),
                       ("glass", " ".join([rest(16), "G#5/12 B5/12 A5/12 F#5/12", rest(8)]), 0.3, 0.5)],
            "rhythm": rhythm(" ".join([B8] * 4)),
            "danger": [("strings", sea(32), 0.35, 0.45)],
            "tide": tide(" ".join([B8] * 4))}},
        "c": {"bars": 16, "next": "a2", "level": -3.0, "stems": {
            "bed": bed(C8 + " " + C8),
            "melody": [("glass", "F#5/6 A5/6 B5/6 C#6/12 E6/6 F#6/12 " + rest(8), 0.15, 0.8)],
            "rhythm": rhythm(C8 + " " + C8, "A2/3@.6 A2/3@.3", "6@.55"),
            "danger": [("strings", sea(16), 0.35, 0.4)],
            "tide": tide(C8 + " " + C8)}},
        "a2": {"bars": 24, "next": "a", "stems": {
            "bed": bed(" ".join([A8] * 3)),
            "melody": [("stone_marimba", " ".join([HALE, ANSWER, HALE, HOME, rest(8)]), -0.25, 0.9),
                       ("glass", " ".join([rest(8), up(HALE), up(HOME), "F#5/24 C#5/24"]), 0.3, 0.5)],
            "rhythm": rhythm(" ".join([A8] * 3)),
            "danger": [("strings", sea(24), 0.35, 0.45)],
            "tide": tide(" ".join([A8] * 3))}},
        # The Tidewall: stone for the drum, the current rising; turned in the second phase.
        "boss1": {"bars": 8, "level": 1.0, "stems": {
            "bed": [("drone", "F#2/48@.7", 0.0, 0.5), ("strings", chords(BOSS1, 2, beats=BAR, fifths=True, vel=0.45), 0.1, 0.35)],
            "melody": [("harp", ripple(BOSS1, 3, 0.6), 0.3, 0.75),
                       ("stone_marimba", "F#4/1 A4/1 B4/1 C#5/1 E5/2 F#5/6 r/12 F#4/1 A4/1 B4/1 C#5/1 D5/2 C#5/6 r/12", -0.25, 0.7)],
            "rhythm": [("stone_marimba", " ".join(["F#2/1@.95 F#2/1@.4 C#3/1@.7 F#2/1@.9 F#2/1@.4 C#3/1@.6"] * 8), 0.0, 0.8),
                       ("frame_drum", " ".join([DRUM] * 8), 0.2, 0.7),
                       ("bass", roots(BOSS1, "3@.85 3@.6"), -0.1, 0.7)],
            "danger": [("strings", SEA, 0.35, 0.6)],
            "tide": tide(BOSS1, "choir_ah")}},
        "boss2": {"bars": 8, "level": 2.0, "stems": {
            "bed": [("drone", "F#2/48@.7", 0.0, 0.5), ("strings", chords(BOSS2, 2, beats=BAR, fifths=True, vel=0.45), 0.1, 0.35)],
            "melody": [("harp", ripple(BOSS2, 3, 0.65, falling=True), 0.3, 0.75),
                       ("strings", "F#3/12@.9 G3/12@.9 F#3/12@.9 G3/12@.9", -0.2, 0.75),   # the surges
                       ("choir_ah", "F#4+A4+C#5/12 G4+B4+D5/12 F#4+A4+C#5/12 G4+B4+D5/12", 0.25, 0.45)],
            "rhythm": [("stone_marimba", " ".join(["F#2/1@1 C#3/1@.5 F#2/1@.8 F#2/1@.95 C#3/1@.5 F#2/1@.8"] * 8), 0.0, 0.85),
                       ("frame_drum", " ".join(["A2/1@.95 A2/1@.5 A2/1@.7 A2/1@.95 A2/1@.5 A2/1@.7"] * 8), 0.2, 0.75),
                       ("bass", roots(BOSS2, "2@.85 1@.6 2@.8 1@.6"), -0.1, 0.75)],
            "danger": [("strings", SEA, 0.35, 0.7)],
            "tide": tide(BOSS2, "choir_ah")}},
        "kill": {"bars": 2, "next": "a", "level": 1.0, "stems": {
            "bed": [("drone", "F#2/12@.6", 0.0, 0.5), ("strings", "F#3+C#4/12@.5", 0.1, 0.35)],
            "melody": [("stone_marimba", "F#4/1 A4/1 B4/1 C#5/1 E5/2 F#5/6", -0.25, 0.9)]}},
    },
}


def main():
    if "--preview" not in sys.argv:
        score.build(SPEC)
    amb = read(os.path.join(ROOT, "assets", "audio", "amb_reef_dry.ogg"))[1]
    amb = resample_poly(amb, 2, 1, axis=0) if len(amb) < 30 * 44100 else amb
    amb = np.repeat(amb, 2, axis=1) if amb.shape[1] == 1 else amb
    score.preview(SPEC, amb * 10 ** ((-15 + 11) / 20))


if __name__ == "__main__":
    main()
