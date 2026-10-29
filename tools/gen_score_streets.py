"""The Drowned Streets' score (audio Stage 07; STYLE.md 23.3): E phrygian at 72, the town that sank
with its bell still in the tower. The Bell's toll is the pulse (STYLE.md 23.2: three falling notes,
B, G, then E flat where E should be), struck on the Bell of Saltmere under a drone and low
fifths; the tune is a worn music box, each note a little off, answered by drowned voices. A fight
brings the frame drum and the bass, and the Sea under them; a high tide, the closed choir. A
(16 bars: the tune, its answer ending on the toll's wrong note, the voices taking the tune) runs
into B (16, higher, the music box and then the choir), the breakdown (8, the music box running
down, the tolls alone) and A' (16, the answer landing home on E): 56 bars, about three minutes.

The Bell of Saltmere: its toll every bar in the first phase, every half bar in the second, and the
peal (a cluster of every bell) every other bar; the kill tolls once more, and right: B, G, E.

    python tools/gen_score_streets.py [--preview]
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

TUNE = "E5/1 G5/1 B5/2 A5/1 G5/1 F5/2 G5/1 F5/1 E5/1 B4/1 D5/3 r/1"
ANSWER = "E5/1 G5/1 C6/2 B5/1 A5/1 E5/2 F5/1 A5/1 G5/1 F5/1 B5/1 G5/1 D#5/2"   # ends on the toll
HOME = "E5/1 G5/1 C6/2 B5/1 A5/1 E5/2 F5/1 A5/1 G5/1 F5/1 B5/1 G5/1 E5/2"
HIGH = "A5/2 C6/2 D6/2 F6/1 E6/1 D6/2 B5/2 C6/3 r/1 A5/1 C6/1 F6/2 E6/1 D6/1 A5/2 B5/2 G5/2 E5/4"
WIND_DOWN = "E5/2 G5/2 B5/4 A5/2 G5/2 F5/4 G5/2 F5/2 E5/2 B4/2 D5/8"
SEA = "E3/4 F3/4 F#3/4 G3/6 F#3/2 F3/4 E3/8"
TOLL = ["B3", "G3", "D#3"]

A16 = "Em F Em Dm C Am F Em Em F Em Dm C Am F Em"
B16 = "Am Dm G C F Dm Em Em Am Dm G C F Dm Em Em"
C8 = "Em Em F F Em Em Dm Dm"
BOSS1 = "Em F Em F Em F Dm Em"
BOSS2 = "Em F Em F C Dm Em Em"

DRUM = "A2/1@.9 A2/.5@.4 A2/.5@.5 A2/1@.8 A2/1@.45"


def n(symbols):
    return len(symbols.split())


def down(text, semis=-12):
    out = []
    for tok in text.split():
        p, r = tok.split("/", 1)
        if p != "r":
            p = score.note(round(12 * np.log2(score.synth.hz(p) / 440.0) + 69) + semis)
        out.append(p + "/" + r)
    return " ".join(out)


def tolls(bars, every=2.0, vel=0.55):
    """The toll on the Bell of Saltmere, B, G, E flat, round again, one stroke every `every` bars."""
    out, k, beats = [], 0, bars * 4
    step = every * 4
    t = 0.0
    while t < beats - 1e-6:
        d = min(step, beats - t)
        out.append(f"{TOLL[k % 3]}/{d:g}@{vel}")
        k += 1
        t += d
    return " ".join(out)


def bed(symbols, every=2.0):
    bars = n(symbols)
    return [("drone", f"E2/{bars * 4}@.7", 0.0, 0.5),
            ("strings", chords(symbols, 2, fifths=True, vel=0.4), 0.1, 0.3),
            ("saltmere", tolls(bars, every), -0.15, 0.45)]


def rhythm(symbols, drum=DRUM, row="2@.85 2@.6"):
    return [("frame_drum", " ".join([drum] * n(symbols)), 0.2, 0.8), ("bass", roots(symbols, row), -0.1, 0.7)]


def tide(symbols, voice="choir_oo"):
    return [(voice, chords(symbols, 3, vel=0.45), -0.25, 0.5)]


def sea(bars):
    return " ".join([SEA] * (bars // 8))


SPEC = {
    "name": "music_streets", "folder": "streets", "bpm": 72, "first": "a",
    "sections": {
        "a": {"bars": 16, "next": "b", "stems": {
            "bed": bed(A16),
            "melody": [("music_box", " ".join([TUNE, ANSWER, "r/32"]), -0.2, 0.9),
                       ("choir_oo", " ".join(["r/32", down(TUNE), down(HOME)]), 0.25, 0.7)],
            "rhythm": rhythm(A16),
            "danger": [("strings", sea(16), 0.35, 0.45)],
            "tide": tide(A16)}},
        "b": {"bars": 16, "next": "c", "stems": {
            "bed": bed(B16),
            "melody": [("music_box", HIGH + " r/32", -0.2, 0.9),
                       ("choir_ah", "r/32 " + down(HIGH), 0.25, 0.6)],
            "rhythm": rhythm(B16),
            "danger": [("strings", sea(16), 0.35, 0.45)],
            "tide": tide(B16)}},
        "c": {"bars": 8, "next": "a2", "level": -3.0, "stems": {
            "bed": bed(C8, 1.0),
            "melody": [("music_box", WIND_DOWN, 0.1, 0.8)],
            "rhythm": rhythm(C8, "A2/2@.6 A2/2@.3", "4@.55"),
            "danger": [("strings", sea(8), 0.35, 0.4)],
            "tide": tide(C8)}},
        "a2": {"bars": 16, "next": "a", "stems": {
            "bed": bed(A16),
            "melody": [("music_box", " ".join([TUNE, HOME, "r/32"]), -0.2, 0.9),
                       ("choir_oo", " ".join(["r/32", down(TUNE), down(HOME)]), 0.25, 0.7)],
            "rhythm": rhythm(A16),
            "danger": [("strings", sea(16), 0.35, 0.45)],
            "tide": tide(A16)}},
        # The Bell of Saltmere: the toll every bar, then every half bar under the peal.
        "boss1": {"bars": 8, "level": 1.0, "stems": {
            "bed": bed(BOSS1, 1.0),
            "melody": [("music_box", " ".join(["E5/.5 F5/.5 B5/.5 F5/.5"] * 16), -0.2, 0.7),
                       ("choir_ah", chords(BOSS1, 4, vel=0.5), 0.25, 0.45)],
            "rhythm": [("frame_drum", " ".join(["A2/.5@.9 A2/.5@.4 A2/.5@.6 A2/.5@.4"] * 16), 0.2, 0.8),
                       ("bass", roots(BOSS1, "1@.85 1@.5 1@.7 1@.5"), -0.1, 0.7)],
            "danger": [("strings", SEA, 0.35, 0.6)],
            "tide": tide(BOSS1, "choir_ah")}},
        "boss2": {"bars": 8, "level": 2.0, "stems": {
            "bed": bed(BOSS2, 0.5),
            "melody": [("music_box", " ".join(["E5/.5 F5/.5 B5/.5 F5/.5 E5/.5 G5/.5 D#5/.5 G5/.5"] * 8), -0.2, 0.7),
                       ("hand_bell", " ".join(["E5+F5+G5+B5/8@.8"] * 4), 0.35, 0.5),      # the peal
                       ("ship_bell", " ".join(["F4/8@.7"] * 4), -0.35, 0.4)],
            "rhythm": [("frame_drum", " ".join(["A2/.5@.95 A2/.5@.5 A2/.5@.7 A2/.5@.5"] * 16), 0.2, 0.85),
                       ("bass", roots(BOSS2, "1@.9 1@.6 1@.8 1@.6"), -0.1, 0.75)],
            "danger": [("strings", SEA, 0.35, 0.7)],
            "tide": tide(BOSS2, "choir_ah")}},
        "kill": {"bars": 2, "next": "a", "level": 1.0, "stems": {
            "bed": [("drone", "E2/8@.6", 0.0, 0.5), ("saltmere", "B3/2@.6 G3/2@.6 E3/4@.6", -0.15, 0.5)],
            "melody": [("music_box", "B5/2 G5/2 E5/4", -0.2, 0.8)]}},
    },
}


def main():
    if "--preview" not in sys.argv:
        score.build(SPEC)
    amb = read(os.path.join(ROOT, "assets", "audio", "amb_streets.ogg"))[1]
    amb = resample_poly(amb, 2, 1, axis=0) if len(amb) < 30 * 44100 else amb
    amb = np.repeat(amb, 2, axis=1) if amb.shape[1] == 1 else amb
    score.preview(SPEC, amb * 10 ** ((-15 + 11) / 20))


if __name__ == "__main__":
    main()
