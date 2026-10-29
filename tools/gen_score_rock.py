"""Marrow Rock, the title, the endings and the night's last word (audio Stage 08; STYLE.md 23.3).

- music_hub, the rock: A dorian at 58, no rhythm; the Lamp on the cittern over a drone, the
  harmonium's chords and the surf. A (16 bars) runs into B (16, the Lamp twice as slow on the
  harmonium) and C (8, the bed and whoever is home), then A: 40 bars, about 2:45. Each echo
  brought home adds a stem of its own, a quiet line through every section, switched on by the
  hub (`Audio.music_layers`): Bram an anvil's ring, Pell glass, Hale the stone marimba, Wren hand
  bells, the Cartographer the harp, the Choir its voices, Maren her hum, Aldous the low strings.
- music_title: F dorian at 52, the Lamp on the harmonium alone over the surf.
- music_keep (the lamp kept): the Lamp in A major, every instrument of the rock with it.
- music_break (the water let in): the Lamp slowed and drowned under the Sea, in the Reef's
  damped water.
- music_still (the walk out): a drone, and one note now and then.
- stinger_won, stinger_taken, stinger_lost: how a night ends (the Lamp resolved; the Sea rising
  over it; the Bell of Saltmere, once, in the dark).

    python tools/gen_score_rock.py [--preview]
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score  # noqa: E402
import synth  # noqa: E402
from score import chords  # noqa: E402
from audio_audit import loudness, read  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ECHOES = ["bram", "pell", "mason", "wren", "cartographer", "choir", "maren", "aldous"]
STEMS = ["bed", "melody"] + ECHOES

LAMP = "A4/2 E5/3 D5/1 C5/2 A4/4 r/4"
LAMP_C = "C5/2 G5/3 F#5/1 E5/2 C5/4 r/4"
FALL = "E5/1 D5/1 C5/1 B4/1 A4/2 G4/2 F#4/2 E4/2 A4/4"
SLOW = "A3/4 E4/6 D4/2 C4/4 A3/8 r/8 C4/4 G4/6 F#4/2 E4/4 C4/8 r/8"
A16 = "Am Am D Am C C D Am Am G D Am Am Em D Am"
B16 = "Am Am D Am Am Am Am Am C C D C Am Am Am Am"
C8 = "Am Am D D Am Am Em Am"


def tones(symbol, octave):
    return [score.note(m) for m in score.chord_notes(symbol, octave)]


def per(symbols, k, fn):
    """fn(chord of each k-bar group) -> notes for those k bars."""
    syms = symbols.split()
    return " ".join(fn(syms[i]) for i in range(0, len(syms), k))


def echo(name, symbols):
    """A quiet line for one echo through the given bars."""
    if name == "bram":   # the anvil's ring, once in four bars
        return per(symbols, 4, lambda c: f"{tones(c, 5)[0]}/16@.45")
    if name == "pell":   # glass on the fifth, on the third beat of every other bar
        return per(symbols, 2, lambda c: f"r/2 {tones(c, 5)[2]}/6@.5")
    if name == "mason":  # Hale's rise in small
        return per(symbols, 4, lambda c: "r/8 {0}/1@.5 {1}/1@.45 {2}/1@.5 {3}/5@.55".format(*tones(c, 4), tones(c, 5)[0]))
    if name == "wren":   # two hand bells
        return per(symbols, 4, lambda c: f"r/4 {tones(c, 5)[2]}/2@.5 {tones(c, 6)[0]}/2@.45 r/8")
    if name == "cartographer":  # the harp walking the chord
        return per(symbols, 1, lambda c: "{0}/1@.4 {2}/1@.3 {1}/1@.3 {2}/1@.3".format(*tones(c, 3)[:1], tones(c, 3)[1], tones(c, 3)[2]))
    if name == "choir":
        return chords(symbols, 3, vel=0.4)
    if name == "maren":  # her hum, here in A: never the root
        bars = len(symbols.split())
        return " ".join(["E4/4 G4/4 F#4/6 D4/2 C4/8 r/8"] * (bars // 8))
    if name == "aldous":
        return per(symbols, 4, lambda c: f"{tones(c, 2)[0]}/16@.5")
    raise KeyError(name)


ECHO_INST = {"bram": "buoy", "pell": "glass", "mason": "stone_marimba", "wren": "hand_bell",
             "cartographer": "harp", "choir": "choir_oo", "maren": "hum", "aldous": "strings"}
ECHO_PAN = {"bram": -0.5, "pell": 0.5, "mason": -0.35, "wren": 0.4, "cartographer": 0.25,
            "choir": -0.15, "maren": 0.1, "aldous": -0.25}


def bed(symbols, root="A2"):
    bars = len(symbols.split())
    return [("drone", f"{root}/{bars * 4}@.7", 0.0, 0.5),
            ("harmonium", chords(symbols, 3, vel=0.35), -0.1, 0.4, ("rock", 0.25)),
            ("surf", " ".join(["C4/8@.5"] * (bars // 2)), 0.3, 0.35)]


def section(bars, nxt, symbols, melody, level=0.0):
    stems = {"bed": bed(symbols), "melody": melody}
    for e in ECHOES:
        stems[e] = [(ECHO_INST[e], echo(e, symbols), ECHO_PAN[e], 0.7, ("rock", 0.25))]
    out = {"bars": bars, "next": nxt, "stems": stems}
    if level:
        out["level"] = level
    return out


HUB = {
    "name": "music_hub", "folder": "rock", "bpm": 58, "first": "a", "stems": STEMS,
    "sections": {
        "a": section(16, "b", A16, [("cittern", " ".join([LAMP, LAMP_C, FALL, "r/16"]), -0.2, 0.9, ("rock", 0.2))]),
        "b": section(16, "c", B16, [("harmonium", SLOW, 0.15, 0.8, ("rock", 0.25))]),
        "c": section(8, "a", C8, [], -2.0),
    },
}

TITLE = {
    "name": "music_title", "folder": "title", "bpm": 52, "first": "a",
    "sections": {"a": {"bars": 12, "stems": {
        "bed": [("drone", "F2/48@.6", 0.0, 0.5), ("surf", " ".join(["C4/8@.5"] * 6), 0.25, 0.45)],
        "melody": [("harmonium", "F3/2 C4/3 Bb3/1 Ab3/2 F3/4 r/4 Ab3/2 Eb4/3 D4/1 C4/2 Ab3/4 r/4 C4/4 Bb3/4 Ab3/4 F3/4", 0.0, 0.9, ("rock", 0.3)),
                   ("harmonium", chords("Fm Fm Bb Fm Ab Ab Bb Fm Cm Bb Bb Fm", 2, vel=0.3), 0.0, 0.5, ("rock", 0.3))]}}},
}

KEEP16 = "A A D A F#m F#m D E A A D A D E A A"
KEEP = {
    "name": "music_keep", "folder": "keep", "bpm": 58, "first": "a",
    "sections": {"a": {"bars": 16, "stems": {
        "bed": [("drone", "A2/64@.6", 0.0, 0.5), ("harmonium", chords(KEEP16, 3, vel=0.4), -0.1, 0.45, ("rock", 0.25)),
                ("choir_oo", chords(KEEP16, 3, vel=0.35), 0.2, 0.35, ("rock", 0.25)),
                ("strings", per(KEEP16, 4, lambda c: f"{tones(c, 2)[0]}/16@.45"), -0.25, 0.35)],
        "melody": [("cittern", "A4/2 E5/3 D5/1 C#5/2 A4/4 r/4 C#5/2 G#5/3 F#5/1 E5/2 C#5/4 r/4 "
                               "E5/1 D5/1 C#5/1 B4/1 A4/2 G#4/2 F#4/2 E4/2 A4/8 r/12", -0.2, 0.9, ("rock", 0.2)),
                   ("hand_bell", per(KEEP16, 4, lambda c: f"r/4 {tones(c, 5)[2]}/2@.45 {tones(c, 6)[0]}/2@.4 r/8"), 0.4, 0.5),
                   ("glass", per(KEEP16, 2, lambda c: f"r/2 {tones(c, 5)[2]}/6@.45"), 0.5, 0.45),
                   ("harp", per(KEEP16, 1, lambda c: "{0}/1@.35 {2}/1@.25 {1}/1@.25 {2}/1@.25".format(*tones(c, 3))), 0.25, 0.5)]}}},
}

BREAK = {
    "name": "music_break", "folder": "break", "bpm": 44, "first": "a",
    "sections": {"a": {"bars": 12, "stems": {
        "bed": [("drone", "Eb2/48@.6", 0.0, 0.5),
                ("strings", "Eb3/4 E3/4 F3/4 Gb3/6 F3/2 E3/4 Eb3/8 Eb3/4 E3/4 F3/8", 0.25, 0.6, ("reef", 0.5))],
        "melody": [("harmonium", "Eb3/4 Bb3/6 Ab3/2 Gb3/4 Eb3/8 Gb3/4 Db4/6 B3/2 Bb3/4 Gb3/8", -0.15, 0.85, ("reef", 0.6)),
                   ("choir_oo", "Eb3+Gb3+Bb3/16 Eb3+Gb3+B3/16 Eb3+Gb3+Bb3/16", 0.2, 0.4, ("reef", 0.6))]}}},
}

STILL = {
    "name": "music_still", "folder": "still", "bpm": 40, "first": "a",
    "sections": {"a": {"bars": 12, "stems": {
        "bed": [("drone", "D2/48@.5", 0.0, 0.5)],
        "melody": [("glass", "r/6 A5/10 r/8 F#5/8 r/4 D6/12", 0.2, 0.7, ("flats", 0.6))]}}},
}


def stinger(name, parts, bpm, space, wet, seconds):
    x = synth.mix(*[synth.render(i, n, bpm, p, 7 + k, g) for k, (i, n, p, g) in enumerate(parts)])
    x = synth.reverb(x, space, wet)[:int(seconds * synth.SR)]
    fade = int(0.8 * synth.SR)
    x[-fade:] *= np.linspace(1, 0, fade)[:, None]
    _, mom, _ = loudness(synth.SR, x)
    x = synth.limit(x * 10 ** ((-14.0 - mom) / 20), -1.5)
    synth.save_ogg(name, x, os.path.join(ROOT, "assets", "audio"))
    print(f"{name}: {len(x) / synth.SR:.1f} s, {loudness(synth.SR, x)[1]:.1f} LUFS momentary max")


def stingers():
    stinger("stinger_won", [
        ("cittern", "A4/.5 E5/.5 D5/.5 C#5/.5 A5/6", -0.2, 0.9),
        ("harmonium", "A3+C#4+E4/8", 0.0, 0.6),
        ("hand_bell", "r/2 A5/6", 0.4, 0.5)], 66, "rock", 0.3, 7.0)
    stinger("stinger_taken", [
        ("strings", "D3/1.5 Eb3/1.5 E3/1.5 F3/4", 0.2, 0.8),
        ("choir_oo", "r/1.5 D4+F4+A4/7", -0.2, 0.6),
        ("cittern", "A4/.5 E5/.5 D5/.5 C5/2", -0.3, 0.5)], 60, "reef", 0.6, 8.0)
    stinger("stinger_lost", [
        ("saltmere", "D3/6", 0.0, 0.9),
        ("drone", "D2/6@.6", 0.0, 0.5)], 60, "hall", 0.4, 8.0)


def main():
    pre = "--preview" in sys.argv
    for spec in (HUB, TITLE, KEEP, BREAK, STILL):
        if not pre:
            score.build(spec)
        score.preview(spec)
    if not pre:
        stingers()


if __name__ == "__main__":
    main()
