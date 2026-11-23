"""The Deep Hall's score (audio Stage 07; STYLE.md 23.3): C sharp harmonic minor at 54, a drowned nave.
The harmonium stands for the organ, its chords held under a drone and low fifths, all of it wet
with the Hall's own reverb; over it Maren's hum (STYLE.md 23.2: five notes, never the root), and
the choir answering. A fight brings a slow low drum and the bass, and the Sea under them; a high
tide, the closed choir. A (12 bars: the hum, the choir's answer) runs into B (12, the organ's own
line, darker, through D, the chord a semitone over the root), the breakdown (8, the hum alone,
slower) and A' (12, the choir's answer landing on C sharp): 44 bars, about three minutes.

The Ebb: in its first phase all four motifs come back broken, one after another (the Lamp on the
cittern, the Bell's toll on the Bell of Saltmere, Maren's hum, the Sea); in its second, the Lamp
held high on the harmonium against the Sea low on the strings. The kill: Maren's hum, at last,
comes home.

    python tools/gen_score_hall.py [--preview]
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
WET = ("hall", 0.35)

HUM = "G#4/4 B4/4 A4/6 F#4/2 E4/8"                  # Maren's: never the root
ANSWER = "G#4/4 C5/4 C#5/8 A4/4 G#4/4"
HOME = "G#4/4 C5/4 C#5/16"
ORGAN = ("C#5/2 E5/2 A5/3 G#5/1 F#5/4 C#5/2 A4/2 D5/2 F#5/2 A5/4 G#5/2 C5/2 D#5/4 "
         "E5/2 C#5/2 A4/2 F#4/2 G#4/2 C5/2 G#4/4")
SLOW_HUM = "G#4/6 B4/6 A4/8 F#4/4 E4/8"
SEA8 = "C#3/4 D3/4 D#3/4 E3/6 D#3/2 D3/4 C#3/8"
SEA4 = "C#3/4 D3/4 D#3/8"

A12 = "C#m C#m A A F#m F#m G# G# C#m A F#m G#"
B12 = "A A F#m F#m D D G# G# A F#m G# G#"
C8 = "C#m C#m C#m C#m A A G# G#"
BOSS1 = "C#m C#m D D C#m A G# G#"
BOSS2 = "C#m D C#m D A F#m G# G#"

DRUM = "C#2/2@.9 C#2/1@.35 C#2/1@.55"


def n(symbols):
    return len(symbols.split())


def bed(symbols):
    bars = n(symbols)
    return [("drone", f"C#2/{bars * 4}@.7", 0.0, 0.5, WET),
            ("harmonium", chords(symbols, 3, vel=0.4), -0.1, 0.45, WET),
            ("strings", chords(symbols, 2, fifths=True, vel=0.35), 0.15, 0.3, WET)]


def rhythm(symbols, drum=DRUM, row="4@.8"):
    return [("frame_drum", " ".join([drum] * n(symbols)), 0.2, 0.8, ("hall", 0.2)),
            ("bass", roots(symbols, row), -0.1, 0.7)]


def tide(symbols, voice="choir_oo"):
    return [(voice, chords(symbols, 3, vel=0.45), -0.25, 0.5, WET)]


SPEC = {
    "name": "music_hall", "folder": "hall", "bpm": 54, "first": "a",
    "sections": {
        "a": {"bars": 12, "next": "b", "stems": {
            "bed": bed(A12),
            "melody": [("hum", HUM + " r/24", -0.15, 0.9, WET),
                       ("choir_ah", "r/24 " + ANSWER, 0.25, 0.7, WET)],
            "rhythm": rhythm(A12),
            "danger": [("strings", SEA8 + " " + SEA4, 0.35, 0.45, WET)],
            "tide": tide(A12)}},
        "b": {"bars": 12, "next": "c", "stems": {
            "bed": bed(B12),
            "melody": [("harmonium", ORGAN, -0.2, 0.8, WET)],
            "rhythm": rhythm(B12),
            "danger": [("strings", SEA8 + " " + SEA4, 0.35, 0.45, WET)],
            "tide": tide(B12)}},
        "c": {"bars": 8, "next": "a2", "level": -3.0, "stems": {
            "bed": bed(C8),
            "melody": [("hum", SLOW_HUM, 0.0, 0.9, WET)],
            "rhythm": rhythm(C8, "C#2/4@.6", "4@.55"),
            "danger": [("strings", SEA8, 0.35, 0.4, WET)],
            "tide": tide(C8)}},
        "a2": {"bars": 12, "next": "a", "stems": {
            "bed": bed(A12),
            "melody": [("hum", HUM + " r/24", -0.15, 0.9, WET),
                       ("choir_ah", "r/24 " + HOME, 0.25, 0.7, WET)],
            "rhythm": rhythm(A12),
            "danger": [("strings", SEA8 + " " + SEA4, 0.35, 0.45, WET)],
            "tide": tide(A12)}},
        # The Ebb: the four motifs broken, one after another; then the Lamp against the Sea.
        "boss1": {"bars": 8, "level": 1.0, "stems": {
            "bed": bed(BOSS1),
            "melody": [("cittern", "C#4/1 G#4/1.5 F#4/.5 E4/1 C#3/2 r/2 r/24", -0.3, 0.85, WET),
                       ("saltmere", "r/8 G#3/2 E3/2 C3/4 r/16", 0.2, 0.6, WET),
                       ("hum", "r/16 G#4/2 B4/2 A4/3 F#4/1 E4/4 r/4", 0.0, 0.85, WET),
                       ("strings", "r/24 C#3/2 D3/1 D#3/1 E3/2 D3/2", 0.3, 0.7, WET)],
            "rhythm": [("frame_drum", " ".join(["C#2/.5@.9 C#2/.5@.4 C#2/.5@.6 C#2/.5@.4"] * 16), 0.2, 0.8, ("hall", 0.2)),
                       ("bass", roots(BOSS1, "1@.85 1@.5 1@.7 1@.5"), -0.1, 0.7)],
            "danger": [("strings", SEA8, 0.35, 0.6, WET)],
            "tide": tide(BOSS1, "choir_ah")}},
        "boss2": {"bars": 8, "level": 2.0, "stems": {
            "bed": bed(BOSS2),
            "melody": [("harmonium", "C#5/4 G#5/6 F#5/2 E5/4 C#5/8 r/8", -0.2, 0.9, WET),      # the Lamp
                       ("strings", "C#2/4 D2/4 D#2/4 E2/6 D#2/2 D2/4 C#2/8", 0.25, 0.9, WET)],  # the Sea
            "rhythm": [("frame_drum", " ".join(["C#2/.5@.95 C#2/.25@.4 C#2/.25@.5 C#2/.5@.8 C#2/.5@.45"] * 16), 0.2, 0.85, ("hall", 0.2)),
                       ("saltmere", "G#3/4@.7 E3/4@.6 C3/8@.7 G#3/4@.7 E3/4@.6 C3/8@.7", -0.25, 0.5, WET),
                       ("bass", roots(BOSS2, "1@.9 1@.6 1@.8 1@.6"), -0.1, 0.75)],
            "danger": [("strings", SEA8, 0.35, 0.7, WET)],
            "tide": tide(BOSS2, "choir_ah")}},
        "kill": {"bars": 2, "next": "a", "level": 1.0, "stems": {
            "bed": [("drone", "C#2/8@.6", 0.0, 0.5, WET), ("harmonium", "C#3+E3+G#3/8@.45", -0.1, 0.45, WET)],
            "melody": [("hum", "G#4/1 B4/1 A4/1 F#4/1 E4/1 D#4/1 C#4/2", 0.0, 0.9, WET)]}},
    },
}


def main():
    if "--preview" not in sys.argv:
        score.build(SPEC)
    amb = read(os.path.join(ROOT, "assets", "audio", "amb_hall_dry.ogg"))[1]
    amb = resample_poly(amb, 2, 1, axis=0) if len(amb) < 30 * 44100 else amb
    amb = np.repeat(amb, 2, axis=1) if amb.shape[1] == 1 else amb
    score.preview(SPEC, amb * 10 ** ((-15 + 11) / 20))


if __name__ == "__main__":
    main()
