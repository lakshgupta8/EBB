"""A small score for testing the music director (audio Stage 05): 120 bpm in 4/4, sections a and b
(two bars each, a running into b and back), boss1 and boss2 (two bars, looping) and kill (one bar,
running into a), each with the five stems cut to exactly its bars, so a section change lands on
a bar line by the sample.

    python tools/gen_test_score.py   -> tests/music/test/<section>_<stem>.ogg
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "music", "test")
BPM = 120
SECTIONS = {"a": (2, "D3"), "b": (2, "F3"), "boss1": (2, "E3"), "boss2": (2, "Bb2"), "kill": (1, "D3")}


def exact(x, bars):
    n = int(round(bars * 4 * 60.0 / BPM * synth.SR))
    out = np.zeros((n, 2))
    out[:min(n, len(x))] = x[:n]
    fade = int(0.01 * synth.SR)
    out[-fade:] *= np.linspace(1, 0, fade)[:, None]
    return out


def main():
    for i, (name, (bars, root)) in enumerate(SECTIONS.items()):
        beats = bars * 4
        stems = {
            "bed": synth.render("harmonium", f"{root}/{beats}", BPM, 0.0, 10 + i, 0.8),
            "melody": synth.render("cittern", " ".join([f"{root[0]}4/1"] * beats), BPM, -0.3, 20 + i),
            "rhythm": synth.render("frame_drum", " ".join(["A2/1@.9"] * beats), BPM, 0.2, 30 + i),
            "danger": synth.render("strings", f"{root}/{beats}", BPM, 0.4, 40 + i, 0.8),
            "tide": synth.render("choir_oo", f"{root[0]}4/{beats}", BPM, -0.2, 50 + i),
        }
        for stem, x in stems.items():
            synth.save_ogg(f"{name}_{stem}", exact(x, bars) * 0.6, OUT)
    print(f"wrote {len(SECTIONS) * 5} stems to {os.path.relpath(OUT, ROOT)}")


if __name__ == "__main__":
    main()
