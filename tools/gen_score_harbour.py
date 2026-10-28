"""The Sunken Harbour's score (audio Stage 07; STYLE.md 23.3): C dorian in 6/8, a dotted crotchet at
62 (written in eighths at 186), a work song on the concertina, four bars and its answer, over a
drone, low fifths and a buoy bell on the off beat. A fight brings in the wood block, the frame
drum and the bass rowing in 6/8, and the Sea under it on low strings; a high tide, the closed
choir. A (24 bars: the song, the song again with a second concertina a third under, eight bars of
the harp alone) runs into B (24, the song's other half, in E flat), the breakdown (16, the harp
and the buoy) and A' (24, the song landing home): 88 bars, about three minutes.

The Chainmother: chains as the percussion, low bowed strings like brass, the frame drum driving;
in her second phase the haul is a held swell on the strings and the choir, the buoy clanging every
bar. The kill lets the song finish.

    python tools/gen_score_harbour.py [--preview]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score  # noqa: E402
from score import chords, roots  # noqa: E402
from audio_audit import read  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAR = 6  # eighths

# The work song: four bars and its answer (durations in eighths).
SONG = "G4/2 G4/1 C5/2 Bb4/1 A4/2 G4/1 F4/3 Eb4/2 F4/1 G4/2 Eb4/1 D4/3 C4/3"
ANSWER = "C5/2 C5/1 D5/2 C5/1 Bb4/2 A4/1 G4/3 F4/2 G4/1 A4/2 F4/1 G4/6"
HOME = "C5/2 C5/1 D5/2 C5/1 Bb4/2 A4/1 G4/3 F4/2 G4/1 A4/2 F4/1 Eb4/3 C4/3"
UNDER = "Eb4/2 Eb4/1 G4/2 G4/1 F4/2 Eb4/1 C4/3 C4/2 D4/1 Eb4/2 C4/1 Bb3/3 G3/3"   # a third under the song
OTHER = ("Bb4/2 Bb4/1 Eb5/2 D5/1 D5/2 C5/1 Bb4/3 A4/2 Bb4/1 C5/2 A4/1 G4/3 F4/3 "
         "Eb4/2 F4/1 G4/2 Bb4/1 D5/3 F5/3 Eb5/2 D5/1 C5/2 A4/1 C5/6")
# The Sea, in C, eight bars of 6/8.
SEA = "C3/6 Db3/6 D3/6 Eb3/9 D3/3 Db3/6 C3/12"

A8 = "Cm F Cm Gm Cm Gm F Cm"
B8 = "Eb Bb F Cm Eb Bb F F"
C8 = "Cm Cm F F Cm Cm Gm Gm"
BOSS1 = "Cm Cm Db Cm Cm Ab Bb G"
BOSS2 = "Cm Db Cm Db Ab Bb G G"

DRUM = "A2/2@.9 A2/1@.4 A2/2@.7 A2/1@.5"
BLOCK = "G5/1@.5 G5/1@.3 G5/1@.4 D6/1@.6 G5/1@.3 G5/1@.4"
ROW = "3@.85 2@.6 1@.5"


def n(symbols):
    return len(symbols.split())


def rest(bars):
    return f"r/{bars * BAR}"


def arp(symbols, octave=3, vel=0.45):
    """The harp breaking each bar's chord in 6/8: root, fifth, third, fifth, root up, fifth."""
    out = []
    for s in symbols.split():
        r, t, f = score.chord_notes(s, octave)
        for k, m in enumerate([r, f, t + 12, f, r + 12, f]):
            out.append(f"{score.note(m)}/1@{vel if k in (0, 3) else vel * 0.7:.2f}")
    return " ".join(out)


def bed(symbols):
    bars = n(symbols)
    buoy = " ".join(["r/3 C5/9@.5"] * (bars // 2))
    return [("drone", f"C2/{bars * BAR}@.7", 0.0, 0.5),
            ("strings", chords(symbols, 2, beats=BAR, fifths=True, vel=0.45), 0.1, 0.35),
            ("buoy", buoy, 0.45, 0.3)]


def rhythm(symbols, drum=DRUM, block=BLOCK, row=ROW):
    k = n(symbols)
    parts = [("frame_drum", " ".join([drum] * k), 0.2, 0.8), ("bass", roots(symbols, row), -0.1, 0.7)]
    if block:
        parts.append(("wood_block", " ".join([block] * k), -0.35, 0.5))
    return parts


def tide(symbols, voice="choir_oo"):
    return [(voice, chords(symbols, 3, beats=BAR, vel=0.45), -0.25, 0.5)]


def sea(bars):
    return " ".join([SEA] * (bars // 8))


SPEC = {
    "name": "music_harbour", "folder": "harbour", "bpm": 186, "bar_beats": BAR, "first": "a",
    "sections": {
        "a": {"bars": 24, "next": "b", "stems": {
            "bed": bed(A8 * 1 + " " + A8 + " " + A8),
            "melody": [("concertina", " ".join([SONG, ANSWER, SONG, ANSWER, rest(8)]), -0.25, 0.9),
                       ("concertina", " ".join([rest(8), UNDER, rest(4), rest(8)]), 0.3, 0.55),
                       ("harp", rest(16) + " " + arp(A8), 0.25, 0.7)],
            "rhythm": rhythm(" ".join([A8] * 3)),
            "danger": [("strings", sea(24), 0.35, 0.45)],
            "tide": tide(" ".join([A8] * 3))}},
        "b": {"bars": 24, "next": "c", "stems": {
            "bed": bed(" ".join([B8] * 3)),
            "melody": [("concertina", " ".join([OTHER, OTHER, rest(8)]), -0.25, 0.9),
                       ("harp", rest(16) + " " + arp(B8), 0.25, 0.7)],
            "rhythm": rhythm(" ".join([B8] * 3)),
            "danger": [("strings", sea(24), 0.35, 0.45)],
            "tide": tide(" ".join([B8] * 3))}},
        "c": {"bars": 16, "next": "a2", "level": -3.0, "stems": {
            "bed": bed(C8 + " " + C8),
            "melody": [("harp", "G4/6 C5/6 Bb4/6 A4/6 G4/6 Eb4/6 D4/12 " * 2, 0.15, 0.8)],
            "rhythm": rhythm(C8 + " " + C8, "A2/3@.7 A2/3@.35", "", "6@.6"),
            "danger": [("strings", sea(16), 0.35, 0.4)],
            "tide": tide(C8 + " " + C8)}},
        "a2": {"bars": 24, "next": "a", "stems": {
            "bed": bed(" ".join([A8] * 3)),
            "melody": [("concertina", " ".join([SONG, ANSWER, SONG, HOME, rest(8)]), -0.25, 0.9),
                       ("concertina", " ".join([rest(8), UNDER, rest(4), rest(8)]), 0.3, 0.55),
                       ("harp", rest(16) + " " + arp(A8), 0.25, 0.7)],
            "rhythm": rhythm(" ".join([A8] * 3)),
            "danger": [("strings", sea(24), 0.35, 0.45)],
            "tide": tide(" ".join([A8] * 3))}},
        # The Chainmother: chains for the drum, low bowed strings for brass.
        "boss1": {"bars": 8, "level": 1.0, "stems": {
            "bed": bed(BOSS1),
            "melody": [("strings", "C3/12 Eb3/6 D3/6 C3/12 Ab2/6 G2/6", -0.2, 0.8),
                       ("concertina", " ".join(["r/3 C5/1@.6 Eb5/1@.5 G5/1@.6"] * 8), 0.3, 0.45)],
            "rhythm": [("chain", " ".join(["C4/6@.9"] * 8), 0.0, 0.7),
                       ("frame_drum", " ".join(["A2/1@.9 A2/1@.4 A2/1@.6 A2/1@.9 A2/1@.4 A2/1@.6"] * 8), 0.2, 0.75),
                       ("bass", roots(BOSS1, "2@.85 1@.6 2@.8 1@.6"), -0.1, 0.7)],
            "danger": [("strings", SEA, 0.35, 0.6)],
            "tide": tide(BOSS1, "choir_ah")}},
        "boss2": {"bars": 8, "level": 2.0, "stems": {
            "bed": bed(BOSS2),
            "melody": [("strings", "C3/24 Db3/24", -0.2, 0.9),   # the haul: a held swell
                       ("choir_ah", "C4+Eb4+G4/24 Db4+F4+Ab4/24", 0.25, 0.5)],
            "rhythm": [("chain", " ".join(["C4/3@.9 C4/3@.6"] * 8), 0.0, 0.75),
                       ("frame_drum", " ".join(["A2/1@.95 A2/1@.5 A2/1@.7 A2/1@.95 A2/1@.5 A2/1@.7"] * 8), 0.2, 0.8),
                       ("buoy", " ".join(["C5/6@.7"] * 8), 0.45, 0.4),
                       ("bass", roots(BOSS2, "1@.85 1@.5 1@.6 1@.85 1@.5 1@.6"), -0.1, 0.75)],
            "danger": [("strings", SEA, 0.35, 0.7)],
            "tide": tide(BOSS2, "choir_ah")}},
        "kill": {"bars": 2, "next": "a", "level": 1.0, "stems": {
            "bed": [("drone", "C2/12@.6", 0.0, 0.5), ("strings", "C3+G3/12@.5", 0.1, 0.35)],
            "melody": [("concertina", "Eb4/3 D4/3 C4/6", -0.25, 0.9)]}},
    },
}


def main():
    if "--preview" not in sys.argv:
        score.build(SPEC)
    amb = read(os.path.join(ROOT, "assets", "audio", "amb_harbour.ogg"))[1]
    # The old bed is 22 kHz mono; as stereo at the kit's rate for the preview.
    import numpy as np
    from scipy.signal import resample_poly
    amb = resample_poly(amb, 2, 1, axis=0) if len(amb) < 30 * 44100 else amb
    amb = np.repeat(amb, 2, axis=1) if amb.shape[1] == 1 else amb
    score.preview(SPEC, amb * 10 ** ((-15 + 11) / 20))


if __name__ == "__main__":
    main()
