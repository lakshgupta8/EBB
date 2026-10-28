"""Scores for the music director (audio Stage 06 on): a place's music written as sections of
stems, rendered with the kit in tools/synth.py, and listed in data/music.json for the game.

A spec:
    {"name": "music_flats", "folder": "flats", "bpm": 66, "first": "a",
     "sections": {"a": {"bars": 12, "next": "b", "stems": {
         "bed": [("drone", "D2/48", 0.0, 0.5), ...],     # (instrument, notes, pan, gain)
         "melody": [...], "rhythm": [...], "danger": [...], "tide": [...]}}, ...}}

Each stem is cut to exactly its section's bars. What still rings at the end is carried into the
start of the section that follows (its own start, for a section that loops), so nothing is cut
off at a join. Each stem is then brought to its own loudness (STEM_LU, plus the section's
"level"), measured, not guessed from the instruments' gains: exploring (bed and melody) comes
to about -20 LUFS and a full fight to about -18 (STYLE.md 23.4), peaks under -1 dBFS.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth  # noqa: E402
from audio_audit import loudness  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCORES = os.path.join(ROOT, "assets", "audio", "score")
MUSIC_JSON = os.path.join(ROOT, "data", "music.json")
STEMS = ["bed", "melody", "rhythm", "danger", "tide"]
TARGET = -18.0
# Each stem's own integrated loudness, LUFS: the melody leads, the bed under it, the fight's
# layers adding two LU, the tide a colour.
STEM_LU = {"bed": -25.0, "melody": -22.0, "rhythm": -24.0, "danger": -27.0, "tide": -28.0}
# Vorbis quality by stem: the bed and the melody are heard alone, the rest under them. A place's
# score is about 6 MB this way (15 at quality 5); six scores keep the setup under 80 MB.
QUALITY = {"bed": 1, "melody": 1, "rhythm": 0, "danger": 0, "tide": 0}

_STEPS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
_SHARPS = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]


def note(midi):
    return f"{_SHARPS[midi % 12]}{midi // 12 - 1}"


def chord_notes(symbol, octave):
    """'Dm' -> D F A from octave; 'A' major; 'D5' an open fifth; 'Bbm'."""
    root = _STEPS[symbol[0]]
    i = 1
    if i < len(symbol) and symbol[i] in "#b":
        root += 1 if symbol[i] == "#" else -1
        i += 1
    kind = symbol[i:]
    base = 12 * (octave + 1) + root
    if kind == "5":
        return [base, base + 7]
    third = 3 if kind == "m" else 4
    return [base, base + third, base + 7]


def chords(symbols, octave=3, beats=4, vel=0.6, fifths=False, root_only=False):
    """'Dm Dm Bb C' -> one chord a bar as note text."""
    out = []
    for s in symbols.split():
        ns = chord_notes(s, octave)
        if fifths:
            ns = [ns[0], ns[-1]]
        if root_only:
            ns = [ns[0]]
        out.append("+".join(note(n) for n in ns) + f"/{beats}@{vel}")
    return " ".join(out)


def roots(symbols, pattern, octave=2):
    """A bass or drum line on each bar's root: pattern like '2@.9 1.5@.6 .5@.5' (beats@vel)."""
    out = []
    for s in symbols.split():
        r = note(chord_notes(s, octave)[0])
        for p in pattern.split():
            beats, vel = p.split("@")
            out.append(f"{r}/{beats}@{vel}")
    return " ".join(out)


def bars_of(text):
    return sum(float(t.split("@")[0].split("/")[1]) for t in text.split()) / 4.0


def build(spec):
    """Render every section's stems, carry tails across joins, level, write Ogg and the spec."""
    bpm = spec["bpm"]
    folder = os.path.join(SCORES, spec["folder"])
    bar_n = lambda bars: int(round(bars * 4 * 60.0 / bpm * synth.SR))  # noqa: E731
    raw = {}  # (section, stem) -> stereo, longer than the section
    seed = 1
    for sec, s in spec["sections"].items():
        for stem in STEMS:
            parts = []
            for inst, notes, pan, gain in s["stems"].get(stem, []):
                assert abs(bars_of(notes) - s["bars"]) < 1e-6 or bars_of(notes) <= s["bars"], (sec, stem, inst, bars_of(notes))
                parts.append(synth.render(inst, notes, bpm, pan, seed, gain))
                seed += 1
            if parts:
                raw[(sec, stem)] = synth.mix(*parts)
            print(f"  {sec:6s} {stem:7s} {len(parts)} parts")
    # Cut each stem to its bars; the ring past the end goes into the head of what follows.
    cut = {}
    for (sec, stem), x in raw.items():
        n = bar_n(spec["sections"][sec]["bars"])
        body = np.zeros((n, 2))
        body[:min(n, len(x))] += x[:n]
        cut[(sec, stem)] = body
    for (sec, stem), x in raw.items():
        n = bar_n(spec["sections"][sec]["bars"])
        tail = x[n:]
        if not len(tail):
            continue
        nxt = spec["sections"][sec].get("next", sec)
        key = (nxt, stem)
        if key not in cut:
            cut[key] = np.zeros((bar_n(spec["sections"][nxt]["bars"]), 2))
        m = min(len(tail), len(cut[key]))
        cut[key][:m] += tail[:m]
    # Each stem to its loudness; then one trim if any section's sum would peak over -1 dBFS.
    for (sec, stem), x in cut.items():
        integ, mom, _ = loudness(synth.SR, x)
        now = integ if integ is not None else mom
        want = STEM_LU[stem] + float(spec["sections"][sec].get("level", 0.0))
        cut[(sec, stem)] = synth.limit(x * 10 ** ((want - now) / 20), -7.0)
    peak = max(np.abs(sum(cut[(sec, st)] for st in STEMS if (sec, st) in cut)).max() for sec in spec["sections"])
    gain = min(1.0, 0.89 / peak)
    os.makedirs(folder, exist_ok=True)
    for f in os.listdir(folder):
        if f.endswith(".ogg") or f.endswith(".ogg.import"):
            os.remove(os.path.join(folder, f))
    for (sec, stem), x in cut.items():
        synth.save_ogg(f"{sec}_{stem}", x * gain, folder, QUALITY[stem])
    # The loudness of each section as heard exploring (bed and melody) and fighting (all).
    report = {}
    for sec in spec["sections"]:
        calm = sum(cut[(sec, st)] for st in ("bed", "melody") if (sec, st) in cut) * gain
        full = sum(cut[(sec, st)] for st in STEMS if (sec, st) in cut) * gain
        report[sec] = (loudness(synth.SR, calm)[0], loudness(synth.SR, full)[0], 20 * np.log10(np.abs(full).max() + 1e-9))
    # List the score for the game.
    music = json.load(open(MUSIC_JSON, encoding="utf-8")) if os.path.exists(MUSIC_JSON) else {}
    music[spec["name"]] = {
        "dir": "res://assets/audio/score/" + spec["folder"], "bpm": bpm, "bar_beats": 4, "first": spec["first"],
        "sections": {sec: ({"bars": s["bars"], "next": s["next"]} if "next" in s else {"bars": s["bars"]})
                     for sec, s in spec["sections"].items()},
    }
    with open(MUSIC_JSON, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(music, fh, indent="\t")
        fh.write("\n")
    total = sum(s["bars"] for k, s in spec["sections"].items() if not k.startswith(("boss", "kill")))
    print(f"{spec['name']}: {len(cut)} stems, gain {20 * np.log10(gain):+.1f} dB; the place runs "
          f"{total} bars ({total * 4 * 60.0 / bpm:.0f} s) before it repeats")
    for sec, (calm, full, pk) in report.items():
        print(f"  {sec:6s} exploring {calm if calm is None else round(calm, 1)} LUFS, fighting {full if full is None else round(full, 1)} LUFS, peak {pk:.1f} dBFS")
    return report


def preview(spec, ambience=None):
    """Listening mixes from the rendered stems, to assets/reference/audio/<folder>/ (local): the
    place exploring (every section in order, bed and melody), the same in a fight (all but the
    tide), the tide high (all), and the boss (phase 1 twice, phase 2 twice, the kill, the place
    again), each with the place's ambience under it if given. And a page to play them."""
    from audio_audit import read
    folder = os.path.join(SCORES, spec["folder"])
    out = os.path.join(ROOT, "assets", "reference", "audio", spec["folder"])
    stems = {}
    for sec in spec["sections"]:
        for st in STEMS:
            p = os.path.join(folder, f"{sec}_{st}.ogg")
            if os.path.exists(p):
                stems[(sec, st)] = read(p)[1]
    def section(sec, which):
        xs = [stems[(sec, st)] for st in which if (sec, st) in stems]
        n = max(len(x) for x in xs)
        return sum(np.pad(x, ((0, n - len(x)), (0, 0))) for x in xs)
    order, sec = [], spec["first"]
    while sec not in order:
        order.append(sec)
        sec = spec["sections"][sec].get("next", sec)
    mixes = {
        "explore": [(s, ("bed", "melody")) for s in order],
        "fight": [(s, ("bed", "melody", "rhythm", "danger")) for s in order[:2]],
        "tide": [(s, STEMS) for s in order[:2]],
    }
    if "boss1" in spec["sections"]:
        mixes["boss"] = [("boss1", STEMS)] * 2 + [("boss2", STEMS)] * 2 + [("kill", STEMS), (order[0], STEMS)]
    rows = []
    for name, seq in mixes.items():
        x = np.concatenate([section(s, w) for s, w in seq])
        if ambience is not None:
            reps = int(np.ceil(len(x) / len(ambience)))
            x = x + np.tile(ambience, (reps, 1))[:len(x)]
        synth.save_ogg(name, np.clip(x, -1, 1), out)
        integ = loudness(synth.SR, x)[0]
        rows.append((name, " > ".join(s for s, _ in seq), len(x) / synth.SR, integ))
    css = ("body{font:14px system-ui;background:#10141c;color:#d8dde6;margin:24px;max-width:900px}"
           "td{padding:6px 10px;border-bottom:1px solid #263040}audio{width:320px}h1{color:#7fd1c7}")
    page = [f"<!doctype html><meta charset=utf-8><title>{spec['name']}</title><style>{css}</style>",
            f"<h1>{spec['name']}</h1><p>{spec['bpm']} bpm. Headphones, one volume.</p><table>"]
    for name, seq, secs, integ in rows:
        page.append(f"<tr><td><b>{name}</b><br><small>{seq}<br>{secs:.0f} s, {integ:.1f} LUFS</small></td>"
                    f"<td><audio controls preload=none src='{name}.ogg'></audio></td></tr>")
    page.append("</table>")
    open(os.path.join(out, "index.html"), "w", encoding="utf-8").write("\n".join(page))
    print(f"previews in {os.path.relpath(out, ROOT)}: " + ", ".join(f"{r[0]} {r[2]:.0f} s" for r in rows))
