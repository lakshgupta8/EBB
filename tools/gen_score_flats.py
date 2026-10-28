"""The Flats' score (audio Stage 06, the sample; STYLE.md 23.3): D aeolian at 66, the Lamp in minor
on the cittern over open fifths and a drone; a frame drum and a bass string when a fight starts,
the Sea on low strings under it, a closed choir when the tide is high. A (12 bars) runs into B
(16), the breakdown (12, the harp alone) and A' (12), then A again: 52 bars, three minutes.
The Wreck is two phases on the same ground: hull timbers as the drum, the ship's bell added in
the second; the kill resolves the Lamp and runs back into A.

Also the Flats' ambience: wind over the open sand, waves breaking at no fixed interval, left and
right, and drips in the pools; a 64 s loop, -26 LUFS.

    python tools/gen_score_flats.py            the score, the ambience, the previews
    python tools/gen_score_flats.py --preview  the previews only, from the stems on disk
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score  # noqa: E402
import synth  # noqa: E402
from score import chords, roots  # noqa: E402
from audio_audit import loudness  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The Lamp (STYLE.md 23.2) in D minor: a rising fifth, a step down, a step down, home.
LAMP = "D4/2 A4/3 G4/1 F4/2 D4/4 r/4"
LAMP_F = "F4/2 C5/3 Bb4/1 A4/2 F4/4 r/4"
FALL = "D5/1 C5/1 Bb4/1 A4/1 G4/2 F4/2 E4/2 A4/2 r/4"
# The Sea: up a fourth by semitones and back, bowed.
SEA8 = "D3/4 Eb3/4 E3/4 F3/6 E3/2 Eb3/4 D3/8"
SEA4 = "D3/4 Eb3/4 E3/8"
DRUM = "A2/1@.9 A2/.5@.4 A2/.5@.55 A2/1@.8 A2/.5@.4 A2/.5@.6"
HULL = "D2/.5@1 D2/.5@.4 A1/.5@.7 D2/.5@.4 D2/.5@.9 D2/.5@.5 A1/.5@.7 D2/.5@.6"

A = "Dm Dm Bb C Dm Dm F C Bb Gm Am Dm"
B = "F C Dm Am Bb F Gm A F C Dm Bb Gm C Dm Dm"
C = "Dm Dm Dm Dm Bb Bb C C Dm Dm Dm Dm"
BOSS1 = "Dm Dm Eb Dm Dm Bb C A"
BOSS2 = "Dm Eb Dm Eb Bb C A A"


def n(symbols):
    return len(symbols.split())


def arp(symbols, octave, order=(0, 2, 1, 2), beat=0.5, vel=0.6):
    """Each bar's chord broken: root, fifth, third, fifth... in eighths."""
    out = []
    for s in symbols.split():
        ns = score.chord_notes(s, octave)
        per = int(4 / beat)
        for k in range(per):
            out.append(f"{score.note(ns[order[k % len(order)]])}/{beat}@{vel if k % 2 == 0 else vel * 0.75:.2f}")
    return " ".join(out)


def bed(symbols):
    beats = n(symbols) * 4
    return [("drone", f"D2/{beats}@.7", 0.0, 0.5), ("strings", chords(symbols, 2, fifths=True, vel=0.45), 0.1, 0.35)]


def rhythm(symbols, drum=DRUM, bass="2@.85 1.5@.6 .5@.5"):
    return [("frame_drum", " ".join([drum] * n(symbols)), 0.2, 0.8), ("bass", roots(symbols, bass), -0.1, 0.7)]


def tide(symbols, voice="choir_oo"):
    return [(voice, chords(symbols, 3, vel=0.45), -0.25, 0.5)]


SPEC = {
    "name": "music_flats", "folder": "flats", "bpm": 66, "first": "a",
    "sections": {
        "a": {"bars": 12, "next": "b", "stems": {
            "bed": bed(A),
            "melody": [("cittern", " ".join([LAMP, LAMP_F, FALL]), -0.25, 0.9)],
            "rhythm": rhythm(A),
            "danger": [("strings", SEA8 + " " + SEA4, 0.35, 0.45)],
            "tide": tide(A)}},
        "b": {"bars": 16, "next": "c", "stems": {
            "bed": bed(B),
            "melody": [
                ("cittern", "F4/1 A4/1 C5/2 E5/2 G5/2 F5/2 D5/2 C5/2 A4/2 "
                            "D5/3 C5/1 Bb4/2 A4/2 G4/2 Bb4/2 C#5/2 E5/2 "
                            "F4/2 C5/3 Bb4/1 A4/2 F4/2 D5/2 r/2 Bb4/2 "
                            "G4/2 Bb4/2 C5/2 E4/2 F4/2 E4/1 D4/1 D4/4", -0.25, 0.9),
                ("harp", arp(B, 3, (0, 2, 1, 2), 1.0, 0.45), 0.3, 0.6)],
            "rhythm": rhythm(B),
            "danger": [("strings", SEA8 + " " + SEA8, 0.35, 0.45)],
            "tide": tide(B)}},
        "c": {"bars": 12, "next": "a2", "level": -3.0, "stems": {
            "bed": bed(C),
            "melody": [("harp", "r/4 A4/1 D5/1 F5/2 r/4 r/4 E5/1 D5/1 A4/2 r/4 "
                                "r/4 G4/1 C5/1 E5/2 r/4 r/4 F4/1 A4/1 D5/6", 0.15, 0.8)],
            "rhythm": rhythm(C, "A2/2@.7 A2/2@.35", "4@.6"),
            "danger": [("strings", SEA8 + " " + SEA4, 0.35, 0.4)],
            "tide": tide(C)}},
        "a2": {"bars": 12, "next": "a", "stems": {
            "bed": bed(A),
            "melody": [("cittern", " ".join([LAMP, "F4/2 C5/3 Bb4/1 A4/2 C5/2 A4/2 F4/4",
                                             "D5/1 C5/1 Bb4/1 A4/1 G4/2 F4/2 E4/2 D4/6"]), -0.25, 0.9)],
            "rhythm": rhythm(A),
            "danger": [("strings", SEA8 + " " + SEA4, 0.35, 0.45)],
            "tide": tide(A)}},
        # The Wreck: the hull is the drum; in the second phase the ship's bell tolls every other bar.
        "boss1": {"bars": 8, "level": 1.0, "stems": {
            "bed": bed(BOSS1),
            "melody": [("cittern", arp(BOSS1, 4, (0, 2, 1, 2), 0.5, 0.65), -0.3, 0.75)],
            "rhythm": [("hull", " ".join([HULL] * 8), 0.0, 0.85),
                       ("frame_drum", " ".join(["A2/1@.3 A2/1@.9 A2/1@.3 A2/1@.9"] * 8), 0.25, 0.6),
                       ("bass", roots(BOSS1, "1@.8 1@.5 1@.7 1@.5"), -0.1, 0.7)],
            "danger": [("strings", SEA8, 0.35, 0.6)],
            "tide": tide(BOSS1, "choir_ah")}},
        "boss2": {"bars": 8, "level": 2.0, "stems": {
            "bed": bed(BOSS2),
            "melody": [("cittern", arp(BOSS2, 4, (0, 2, 1, 2), 0.5, 0.7), -0.3, 0.7),
                       ("strings", "D4/4 A4/6 G4/2 F4/4 D4/8 r/8", 0.2, 0.45)],
            "rhythm": [("hull", " ".join([HULL] * 8), 0.0, 0.95),
                       ("frame_drum", " ".join(["A2/1@.5 A2/1@.95 A2/.5@.4 A2/.5@.6 A2/1@.95"] * 8), 0.25, 0.65),
                       ("bass", roots(BOSS2, "1@.85 1@.6 1@.75 1@.6"), -0.1, 0.75),
                       ("ship_bell", "D4/8@.8 D4/8@.7 D4/8@.8 D4/8@.7", 0.4, 0.5)],
            "danger": [("strings", SEA8, 0.35, 0.7)],
            "tide": tide(BOSS2, "choir_ah")}},
        "kill": {"bars": 2, "next": "a", "level": 1.0, "stems": {
            "bed": [("drone", "D2/8@.6", 0.0, 0.5), ("strings", "D3+A3/8@.5", 0.1, 0.35)],
            "melody": [("cittern", "D4/1 A4/1 D5/6@.7", -0.25, 0.9)]}},
    },
}


def ambience():
    """The Flats under the sea bed: wind, waves at no fixed interval, drips in the pools. Rendered
    3 s long and the tail crossfaded into the head, so the 64 s loop has no seam."""
    rng = np.random.default_rng(66)
    secs, fade = 64.0, 3.0
    n = int((secs + fade) * synth.SR)
    out = synth.pan(synth.wind(0, secs + fade, 0.6, rng)[:n], -0.1) + synth.pan(synth.wind(0, secs + fade, 0.5, rng)[:n], 0.3)
    t = rng.uniform(0, 4)
    while t < secs + fade - 1:
        x = synth.pan(synth.surf(0, rng.uniform(5, 8), rng.uniform(0.5, 1.0), rng), rng.uniform(-0.7, 0.7))
        i = int(t * synth.SR)
        m = min(len(x), n - i)
        out[i:i + m] += x[:m]
        t += rng.uniform(6, 12)
    out += synth.pan(synth.highpass(synth.rain(0, secs + fade, 0.15, rng)[:n], 1200), 0.2) * 0.6
    k = int(fade * synth.SR)
    ramp = np.linspace(0, 1, k)[:, None]
    loop = out[:n - k].copy()
    loop[:k] = out[n - k:] * (1 - ramp) + out[:k] * ramp
    integ, _, _ = loudness(synth.SR, loop)
    return loop * 10 ** ((-26.0 - integ) / 20)


def main():
    if "--preview" not in sys.argv:
        score.build(SPEC)
    amb = ambience()
    synth.save_ogg("amb_flats", amb, os.path.join(ROOT, "assets", "audio"))
    print("amb_flats: %.1f LUFS, %.0f s" % (loudness(synth.SR, amb)[0], len(amb) / synth.SR))
    # As heard in the game: the music at -11 dB and the ambience at -15 dB (run.gd).
    score.preview(SPEC, amb * 10 ** ((-15 + 11) / 20))


if __name__ == "__main__":
    main()
