"""Wordless voices (audio Stage 12, decision E2; STYLE.md 23): as a person's line types out they
babble, a syllable every few letters, in a voice of their own: never words, the tune of speech.
Formant synthesis from the kit (a glottal source through the vowel's resonances), each person
with a pitch, a set of vowels, a pace and a grain. Maren hums. Mono WAV, played on the Voice bus.

  voice_<who>_0..7   eight syllables for each of the thirteen people who talk

    python tools/gen_voices.py [who...]
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sfx_combat as c  # noqa: E402
import synth  # noqa: E402
from synth import SR, secs, lowpass, bandpass, resonator, env  # noqa: E402
from gen_sfx_combat import n_of  # noqa: E402

c.TARGET["voice"] = -20.0

VOWELS = dict(synth.VOWELS)
VOWELS.update({
    "eh": [(530, 70, 1.0), (1850, 100, 0.45), (2500, 120, 0.15), (3500, 140, 0.06)],
    "ih": [(400, 60, 1.0), (2100, 110, 0.4), (2800, 120, 0.15), (3600, 140, 0.05)],
    "aw": [(570, 70, 1.0), (840, 80, 0.6), (2400, 120, 0.08), (3300, 140, 0.04)],
    "uh": [(640, 70, 1.0), (1190, 90, 0.4), (2400, 120, 0.1), (3300, 140, 0.05)],
})

# who: (pitch Hz, vowels, syllable seconds, breath 0..1, rasp 0..1, formant shift)
PEOPLE = {
    "orla": (205, ["ah", "eh", "uh", "ih"], 0.11, 0.25, 0.05, 1.08),          # brisk, the rescuer
    "fen": (150, ["eh", "uh", "aw", "ah"], 0.12, 0.15, 0.1, 1.0),            # the fisherman, even
    "nessa": (235, ["ih", "eh", "ah"], 0.09, 0.2, 0.0, 1.12),                 # quick and bright
    "idris": (128, ["aw", "uh", "oo", "ah"], 0.14, 0.2, 0.15, 0.95),          # measured, low
    "bram": (108, ["ah", "aw", "uh"], 0.12, 0.1, 0.45, 0.92),                 # the smith: gruff
    "maren": (196, ["mm"], 0.16, 0.1, 0.0, 1.0),                               # she hums
    "wren": (290, ["ih", "eh", "ah", "oo"], 0.08, 0.3, 0.0, 1.2),             # small and quick
    "cartographer": (170, ["eh", "ih", "uh"], 0.1, 0.35, 0.05, 1.03),        # dry, precise
    "pell": (220, ["oo", "eh", "ih"], 0.12, 0.4, 0.0, 1.1),                   # soft, airy
    "aldous": (98, ["aw", "oo", "uh"], 0.18, 0.35, 0.3, 0.9),                 # the old keeper, slow
    "choir": (175, ["oo", "ah"], 0.2, 0.15, 0.0, 1.0),                         # several at once
    "merchant": (140, ["ah", "eh", "aw", "ih"], 0.1, 0.1, 0.2, 0.98),         # a seller's patter
    "mason": (95, ["oo", "aw", "uh"], 0.17, 0.2, 0.2, 0.9),                    # Hale: slow, stone
}


def syllable(who, rng):
    f0, vowels, dur, breath, rasp, shift = PEOPLE[who]
    dur *= rng.uniform(0.8, 1.25)
    n = n_of(dur + 0.04)
    tt = secs(n)
    # the tune of speech: each syllable bends a little up or down from somewhere near the voice
    start = f0 * 2 ** (rng.uniform(-3, 4) / 12)
    end = start * 2 ** (rng.choice([-1, 1]) * rng.uniform(0.5, 3.0) / 12)
    f = start + (end - start) * np.clip(tt / dur, 0, 1)
    f *= 1 + 0.01 * lowpass(rng.normal(0, 1, n), 12)
    ph = 2 * np.pi * np.cumsum(f) / SR
    src = sum((1.0 / k ** 1.2) * np.sin(k * ph) for k in range(1, 40))
    if rasp > 0:
        src *= 1 + rasp * lowpass(rng.normal(0, 1, n), 120) * 3
    src += lowpass(rng.normal(0, 1, n), 6000) * breath * 0.25
    a, b = rng.choice(vowels), rng.choice(vowels)
    va = sum(g * resonator(src, fc * shift, bw) for fc, bw, g in VOWELS[a])
    vb = sum(g * resonator(src, fc * shift, bw) for fc, bw, g in VOWELS[b])
    glide = np.clip(tt / dur, 0, 1)
    out = va * (1 - glide) + vb * glide
    if who == "choir":   # three of them, a little apart
        out = sum(np.roll(out, n_of(d)) * 2 ** (cents / 1200) for d, cents in ((0, 0), (0.012, 7), (0.02, -5)))
    if who == "maren":   # a hum: the mouth closed, the nose ringing
        out = lowpass(out, 1800)
    consonant = bandpass(rng.normal(0, 1, n), 2500, 8000) * np.exp(-tt / 0.012) * (0.3 if who != "maren" else 0.0)
    return (out + consonant * np.abs(out).max()) * env(n, 0.012, r=0.04, hold=dur)


def main():
    only = sys.argv[1:]
    for k, who in enumerate(PEOPLE):
        if only and who not in only:
            continue
        c.variants(f"voice_{who}", lambda rng, w=who: syllable(w, rng), "voice", 8, seed=30 + k)
    print("voices written")




EVERY = {"bram": 4, "wren": 3, "nessa": 3, "aldous": 6, "mason": 6, "maren": 5, "choir": 7, "pell": 4}  # as TalkUI.VOICE_EVERY
LINE = "The sea came back in last night. All the way in, gentle as anything."


def sheet():
    """The listening page (local): each person saying the same line at the normal speed (40
    letters a second), as the dialog box babbles it; then the menu sounds."""
    import shutil
    from scipy.io import wavfile
    ref = os.path.join(c.ROOT, "assets", "reference", "audio", "voices")
    os.makedirs(ref, exist_ok=True)
    rng = np.random.default_rng(5)
    rows = []
    for who in PEOPLE:
        files = sorted(f for f in os.listdir(c.OUT) if f.startswith(f"voice_{who}_") and f.endswith(".wav"))
        out = np.zeros(n_of(len(LINE) / 40.0 + 1.0))
        since = 99
        for i, ch in enumerate(LINE):
            if ch == " ":
                continue
            since += 1
            if since >= EVERY.get(who, 4):
                since = 0
                _, x = wavfile.read(os.path.join(c.OUT, files[rng.integers(len(files))]))
                c.at(out, x / 32768.0, (i + 1) / 40.0)
        wavfile.write(os.path.join(ref, f"line_{who}.wav"), SR, (out * 0.6 * 32767).astype(np.int16))
        rows.append((f"{who} says a line", f"line_{who}.wav"))
    for f in sorted(os.listdir(c.OUT)):
        if f.startswith("ui_") and f.endswith((".wav")) and (f.endswith("_0.wav") or f == "ui_refuse.wav"):
            shutil.copy(os.path.join(c.OUT, f), os.path.join(ref, f))
            rows.append((f[:-4], f))
    body = "".join(f"<tr><td>{a}</td><td><audio controls preload=none src='{b}'></audio></td></tr>" for a, b in rows)
    open(os.path.join(ref, "index.html"), "w", encoding="utf-8").write(
        "<!doctype html><meta charset=utf-8><title>EBB: voices and menus</title><style>"
        "body{font:15px system-ui;background:#10141c;color:#d8dde6;margin:24px;max-width:860px}"
        "td{padding:6px 10px;border-bottom:1px solid #263040}h1{color:#7fd1c7}audio{height:28px}</style>"
        f"<h1>Voices and menus</h1><p>Audio Stage 12. Every person says: &ldquo;{LINE}&rdquo;</p><table>" + body + "</table>")
    print(f"sheet: {len(rows)} rows -> {os.path.relpath(ref, c.ROOT)}")


if __name__ == "__main__":
    if "--sheet" in sys.argv:
        sheet()
    else:
        main()
