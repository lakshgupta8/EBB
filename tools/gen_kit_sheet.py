"""The instrument sheet (audio Stage 04's gate): every voice of the kit in tools/synth.py played
alone, the same phrase in each place's space, the four motifs, and a short sketch of the kit
together. Each demo is brought to one loudness (-18 LUFS, peaks under -1 dBFS) so they compare.

    python tools/gen_kit_sheet.py          -> assets/reference/audio/kit/ (local only), index.html
"""
import html
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth  # noqa: E402
from audio_audit import loudness  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "reference", "audio", "kit")

LAMP_A = "A3/1 E4/1.5 D4/.5 C4/1 A3/2"  # the Lamp in A dorian: a rising fifth, two steps down, home

# name: (family, what it stands for, notes, bpm, space)
VOICES = {
    "cittern": ("plucked", "Tam, the keepers, the living (the Lamp)", LAMP_A, 66, "flats"),
    "harp": ("plucked", "the Cartographer, the reef's arpeggios", "F#3/.5 A3/.5 C#4/.5 E4/.5 F#4/.5 E4/.5 C#4/.5 A3/.5 F#3/2", 68, "reef"),
    "bass": ("plucked", "the floor of the Flats and the Harbour", "D2/1 D2/.5 A1/.5 C2/1 D2/1 F2/1 E2/.5 C2/.5 D2/2", 66, "flats"),
    "harmonium": ("reed", "the lighthouse's own: home", "A2+E3+C4/2 D3+F#3+A3/2 G2+D3+B3/2 A2+E3+C4/3", 58, "rock"),
    "concertina": ("reed", "the harbour's work song", "C4/.5 D4/.5 Eb4/1 G4/.5 F4/.5 Eb4/1 D4/.5 C4/.5 Bb3/1 C4/2", 62, "harbour"),
    "ship_bell": ("metal", "time, warning; the Wreck's second phase", "D4/2 A3/2 D4/3", 60, "flats"),
    "hand_bell": ("metal", "Wren's bells", "A5/.5 C6/.5 E6/.5 D6/.5 A5/2", 66, "rock"),
    "buoy": ("metal", "the harbour's off-beat", "C4/3 C4/3", 62, "harbour"),
    "glass": ("metal", "Pell's salt-glass, the reef's light", "F#5/1 A5/1 C#6/2", 68, "reef"),
    "saltmere": ("metal", "the Bell of Saltmere (the Bell's toll)", "B3/2 G3/2 Eb3/5", 72, "streets"),
    "frame_drum": ("wood", "the rhythm layer", "A2/1@.9 A2/.5@.45 A2/.5@.6 A2/1@.9 A2/.5@.4 A2/.5@.5 A2/1@.9 A2/1@.55", 66, "flats"),
    "wood_block": ("wood", "the harbour's clock", "G5/.5@.9 G5/.5@.5 D6/.5@.7 G5/.5@.5 G5/.5@.9 G5/.5@.5 D6/1@.7", 62, "harbour"),
    "stone_marimba": ("wood", "Hale, the reef (rising)", "F#4/.5 A4/.5 B4/.5 C#5/.5 E5/1 F#5/2", 68, "reef"),
    "hull": ("wood", "the Wreck's drum", "D2/1@.9 D2/.5@.5 D2/.5@.7 A1/1@.9 D2/1@.6", 66, "flats"),
    "strings": ("bowed", "the sea, the danger layer (the Sea)", "D3/2 Eb3/2 E3/2 F3/3 E3/2 Eb3/2 D3/4", 54, "hall"),
    "bowed_glass": ("bowed", "the drowned's light", "A5/4 E5/4", 60, "reef"),
    "drone": ("bowed", "the floor under every place", "D2/8", 60, "flats"),
    "choir_ah": ("voice", "the Choir, the Hall", "C#4+E4+G#4/4 B3+E4+G#4/4", 54, "hall"),
    "choir_oo": ("voice", "the sea's chorus under a place", "A3+C4+E4/4 G3+C4+E4/4", 54, "streets"),
    "hum": ("voice", "Maren (Maren's hum)", "G#4/1 B4/1 A4/1.5 F#4/.5 E4/2", 54, "rock"),
    "surf": ("noise", "the shore", "C4/6", 60, "flats"),
    "wind": ("noise", "the rock's weather", "C4/6", 60, "rock"),
    "breath": ("noise", "the drowned breathing", "C4/2.4", 60, "streets"),
    "chain": ("noise", "the Chainmother, the Mooring", "C4/1.2@.9", 60, "harbour"),
    "rain": ("noise", "weather", "C4/5", 60, "streets"),
}

MOTIFS = {
    "motif_lamp": ("The Lamp, on the harmonium alone, as the title (F dorian)", "harmonium", "F3/1 C4/1.5 Bb3/.5 Ab3/1 F3/3", 52, "rock"),
    "motif_maren": ("Maren's hum, in the Hall (five notes, never home)", "hum", "G#4/1 B4/1 A4/1.5 F#4/.5 E4/3", 54, "hall"),
    "motif_bell": ("The Bell's toll, in the Streets (the last a semitone flat)", "saltmere", "B3/2 G3/2 Eb3/6", 72, "streets"),
    "motif_sea": ("The Sea, bowed, in the Hall (up a fourth by semitones and back)", "strings", "D3/2 Eb3/2 E3/2 F3/3 E3/2 Eb3/2 D3/4", 54, "hall"),
}


def level(x, target=-18.0):
    """To the target loudness (integrated when long enough, else the loudest 400 ms), peaks under -1 dBFS."""
    integ, mom, _ = loudness(synth.SR, x)
    now = integ if integ is not None else mom
    x = x * 10 ** ((target - now) / 20)
    pk = np.abs(x).max()
    if pk > 0.89:
        x *= 0.89 / pk
    return x


def flats_sketch():
    """Twenty seconds of the kit together: the Flats exploring, then the fight layer coming in."""
    bpm = 66
    lamp = "r/4 D4/1 A4/1.5 G4/.5 F4/1 D4/2 r/2 D4/1 A4/1.5 G4/.5 Bb4/1 A4/2 r/2"  # the Lamp in D minor
    parts = [
        synth.render("drone", "D2/24", bpm, 0.0, 3, 0.8),
        synth.render("bass", "D2/2 r/2 C2/2 r/2 Bb1/2 r/2 A1/2 r/2 D2/2 r/2 C2/2 r/2", bpm, -0.1, 4, 0.7),
        synth.render("cittern", lamp, bpm, -0.3, 5),
        synth.render("strings", "r/12 D3/4 Eb3/4 D3/4", bpm, 0.35, 6, 0.6),
        synth.render("frame_drum", "r/12 " + "A2/1@.9 A2/.5@.45 A2/.5@.6 A2/1@.85 A2/1@.5 " * 3, bpm, 0.15, 7, 0.8),
    ]
    return synth.reverb(synth.mix(*parts), "flats", 0.3)


def main():
    rows = []
    for i, (name, (family, stands, notes, bpm, space)) in enumerate(VOICES.items()):
        dry = synth.render(name, notes, bpm, 0.0, seed=100 + i)
        x = level(synth.reverb(dry, space, 0.2))
        synth.save_ogg(name, x, OUT)
        rows.append(("voices", name, family, stands, f"{notes} at {bpm} bpm, in the {space}"))
        print("voice", name)
    phrase = synth.render("cittern", LAMP_A, 66, -0.2, seed=9)
    for space in synth.SPACES:
        synth.save_ogg("space_" + space, level(synth.reverb(phrase, space, 0.35)), OUT)
        t60 = synth.SPACES[space][0]
        rows.append(("spaces", "space_" + space, "space", f"the {space}: t60 {t60} s", "the Lamp on the cittern, wet 0.35"))
    for name, (what, inst, notes, bpm, space) in MOTIFS.items():
        synth.save_ogg(name, level(synth.reverb(synth.render(inst, notes, bpm, 0.0, seed=21), space, 0.3)), OUT)
        rows.append(("motifs", name, inst, what, notes))
    synth.save_ogg("sketch_flats", level(flats_sketch()), OUT)
    rows.append(("together", "sketch_flats", "sketch", "the Flats: drone, bass, the Lamp in D on the cittern; then the Sea and the frame drum come in as a fight would bring them",
                 "66 bpm, in the Flats"))
    write_page(rows)
    print(f"wrote {len(rows)} demos to {os.path.relpath(OUT, ROOT)}")


def write_page(rows):
    css = ("body{font:14px system-ui;background:#10141c;color:#d8dde6;margin:24px;max-width:1100px}"
           "td,th{padding:5px 8px;border-bottom:1px solid #263040;text-align:left;vertical-align:middle}"
           "table{border-collapse:collapse;width:100%}th{color:#8fa3bf}h2{color:#7fd1c7;margin-top:28px}"
           "audio{height:28px;width:240px}td.n{color:#9aa4b2;font-size:12px}")
    out = [f"<!doctype html><meta charset=utf-8><title>EBB instrument sheet</title><style>{css}</style>",
           "<h1>EBB: the instrument kit</h1><p>Audio Stage 04. Every demo at -18 LUFS. Headphones, one volume. "
           "STYLE.md 23.1 and 23.2.</p>"]
    for group in ["voices", "motifs", "spaces", "together"]:
        out.append(f"<h2>{group}</h2><table><tr><th>demo</th><th>listen</th><th>family</th><th>for</th><th>played</th><th>notes</th></tr>")
        for g, name, fam, what, how in rows:
            if g != group:
                continue
            out.append(f"<tr><td>{name}</td><td><audio controls preload=none src='{name}.ogg'></audio></td>"
                       f"<td>{html.escape(fam)}</td><td>{html.escape(what)}</td><td class=n>{html.escape(how)}</td>"
                       "<td contenteditable=true></td></tr>")
        out.append("</table>")
    open(os.path.join(OUT, "index.html"), "w", encoding="utf-8").write("\n".join(out))


if __name__ == "__main__":
    main()
