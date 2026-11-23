"""The drowned breathing (audio Stage 12, decision E2; STYLE.md 23): the townsfolk who went under
with Saltmere still draw breath through water as they wander and wait, now and then a groan; the
Choir holds its note under everything it does. Mono WAV; the hum an Ogg loop.

  breath_drowned_0..5   a wet breath drawn and let go, water rattling in the throat
  groan_drowned_0..3    a low voice that falls and drowns in its own bubbles
  choir_hum             the Choir's held note: three voices on "oo", never quite together (loop)
  choir_sing            the ring opening: the note thrown wide, "ah", bright
  choir_falter          the note slipping, breaking, and the breath going out of it

    python tools/gen_sfx_drowned.py
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sfx_combat as c  # noqa: E402
import gen_ambience as amb  # noqa: E402
import synth  # noqa: E402
from synth import SR, secs, lowpass, bandpass, resonator, env  # noqa: E402
from gen_sfx_combat import n_of, fit, at, bubbles, rise, inst  # noqa: E402
from gen_voices import VOWELS  # noqa: E402

c.TARGET["world"] = -18.0


def _throat(n, rng, f0, f1, vowel, rasp):
    """A voice from a closed, flooded throat: a glottal source bent from f0 to f1, rasped."""
    tt = secs(n)
    f = f0 * (f1 / f0) ** (tt / tt[-1]) * (1 + 0.02 * lowpass(rng.normal(0, 1, n), 8))
    ph = 2 * np.pi * np.cumsum(f) / SR
    src = sum((1.0 / k ** 1.3) * np.sin(k * ph) for k in range(1, 30))
    src *= 1 + rasp * lowpass(rng.normal(0, 1, n), 90) * 3
    return sum(g * resonator(src, fc * 0.92, bw) for fc, bw, g in VOWELS[vowel])


def breath_drowned(rng):
    dur = rng.uniform(0.7, 1.0)
    n = n_of(dur + 0.1)
    tt = secs(n)
    split = dur * rng.uniform(0.4, 0.55)
    inhale = np.sin(np.pi * np.clip(tt / split, 0, 1)) ** 1.5
    exhale = np.sin(np.pi * np.clip((tt - split) / (dur - split), 0, 1)) ** 2
    air = rng.normal(0, 1, n)
    out = resonator(bandpass(air, 400, 3000), rng.uniform(700, 950), 260) * inhale * 1.2
    out += resonator(bandpass(air, 250, 1800), rng.uniform(500, 650), 220) * exhale
    # water in the throat: a rattle through the draw, bubbles on the way out
    rattle = lowpass(rng.normal(0, 1, n), 60) * 4
    out *= 1 + 0.6 * np.clip(rattle, -1, 1) * inhale
    pops = np.sort(rng.uniform(split, dur, rng.integers(4, 8)))
    out += bubbles(n, pops, rng, 300, 900, 0.03) * 0.08
    return out * env(n, 0.03, r=0.08, hold=dur)


def groan_drowned(rng):
    dur = rng.uniform(1.1, 1.6)
    n = n_of(dur + 0.2)
    f0 = rng.uniform(78, 98)
    voice = _throat(n, rng, f0, f0 * 2 ** (-rng.uniform(2, 5) / 12), rng.choice(["aw", "oo", "uh"]), 0.5)
    voice = lowpass(voice, 2200) * env(n, 0.18, r=0.3, hold=dur * 0.8)
    breath = lowpass(synth.breath(0, dur, 0.5, rng), 1500)[:n]
    out = voice + fit(breath, n) * 0.15
    pops = np.sort(rng.uniform(dur * 0.5, dur, rng.integers(5, 10)))
    out += bubbles(n, pops, rng, 250, 700, 0.04) * 0.06 * np.abs(voice).max()
    return out


def choir_note(rng, dur, vowel, note, spread=(0, 7, -6)):
    """Three of them on one note, each a breath out of time and a few cents apart."""
    n = n_of(dur)
    out = np.zeros(n)
    for k, cents in enumerate(spread):
        f = synth.hz(note) * 2 ** (cents / 1200)
        v = synth._voice(f, n, vowel, rng, vib=0.004 + 0.002 * k)
        out += np.roll(v, n_of(0.015 * k))
    return out


def choir_hum():
    """The held note, a loop: swells and thins slowly as their breaths run out at different times."""
    rng = np.random.default_rng(71)
    dur = 12.0
    n = n_of(dur + 2.0)
    sides = []
    for side in range(2):
        x = choir_note(rng, dur + 2.0, "oo", "F3", spread=(0, 6, -5) if side == 0 else (2, -7, 5))
        x = lowpass(x, 2400) * amb.slow(n, rng, 0.07, 0.35)
        x += lowpass(rng.normal(0, 1, n), 3000) * 0.003 * amb.slow(n, rng, 0.11, 0.6)
        sides.append(x)
    x = np.stack([sides[0] * 0.75 + sides[1] * 0.25, sides[1] * 0.75 + sides[0] * 0.25], axis=1)
    amb.save_loop("choir_hum", x, amb.SPOT_LUFS, fade=2.0)


def choir_sing(rng):
    n = n_of(1.0)
    note = choir_note(rng, 1.0, "ah", "A4", spread=(0, 9, -8))
    under = choir_note(rng, 1.0, "oo", "A3", spread=(0, -5))
    shape = np.minimum(rise(n, 0.6, 0.06), np.exp(-np.maximum(secs(n) - 0.35, 0) / 0.3))
    return (note + under * 0.6) * shape


def choir_falter(rng):
    dur = 1.5
    n = n_of(dur)
    tt = secs(n)
    # the held note slides down a tone and loses its voices one by one
    out = np.zeros(n)
    for k, (cents, gone) in enumerate(((0, 1.2), (8, 0.7), (-7, 0.45))):
        f = synth.hz("F3") * 2 ** (cents / 1200)
        bend = 2 ** (-2.0 * np.clip(tt / 1.1, 0, 1) ** 1.5 / 12)
        f_t = f * bend * (1 + 0.012 * np.sin(2 * np.pi * 7.5 * tt) * rise(n, 1.0))
        ph = 2 * np.pi * np.cumsum(f_t) / SR
        src = sum((1.0 / j ** 1.1) * np.sin(j * ph) for j in range(1, 40))
        v = sum(g * resonator(src, fc, bw) for fc, bw, g in synth.VOWELS["oo"])
        out += v * np.clip((gone - tt) / 0.15, 0, 1)
    breath = fit(lowpass(synth.breath(0, 1.0, 0.8, rng), 1800), n_of(1.0))
    out = at(out * 0.8, breath * np.abs(out).max() * 0.6, 0.9)
    return out * env(n, 0.01, r=0.1, hold=dur - 0.1)


def main():
    c.variants("breath_drowned", breath_drowned, "world", 6, seed=40)
    c.variants("groan_drowned", groan_drowned, "world", 4, seed=41)
    c.variants("choir_sing", choir_sing, "combat", 2, seed=42)
    c.variants("choir_falter", choir_falter, "world", 1, seed=43)
    choir_hum()
    print("the drowned written")


if __name__ == "__main__" and "--sheet" not in sys.argv:
    main()


def sheet():
    """The listening page (local): each clip alone, then half a minute of a street with three of
    the drowned breathing at their own pace and the Choir singing among them, as the game plays it
    (breath every 3.5 to 7.5 s at -9 dB, a groan one time in four; the hum at -6, swelling to +2
    over the 0.8 s windup, the ring's note, the hum back over 1.1 s; the note faltering at the end)."""
    import shutil
    from scipy.io import wavfile
    ref = os.path.join(c.ROOT, "assets", "reference", "audio", "drowned")
    os.makedirs(ref, exist_ok=True)
    rows = []
    for f in sorted(os.listdir(c.OUT)):
        if f.startswith(("breath_drowned", "groan_drowned", "choir_")) and f.endswith((".wav", ".ogg")):
            shutil.copy(os.path.join(c.OUT, f), os.path.join(ref, f))
            rows.append((f.rsplit(".", 1)[0], f))

    def load(name):
        p = os.path.join(c.OUT, name)
        if p.endswith(".ogg"):
            _, x, _ = __import__("audio_audit").read(p)
        else:
            _, x = wavfile.read(p)
            x = x / 32768.0
        return x if x.ndim == 1 else x.mean(axis=1)

    rng = np.random.default_rng(9)
    dur = 30.0
    out = np.zeros(n_of(dur + 2))
    bed = load("amb_streets_wet.ogg")
    out[:min(len(bed), len(out))] += bed[:len(out)] * 10 ** (-6 / 20)
    for who, gain in ((0, -3.0), (1, -8.0), (2, -12.0)):   # near, across the street, far
        t = rng.uniform(0.5, 4)
        while t < dur - 2:
            groan = rng.random() < 0.25
            name = f"groan_drowned_{rng.integers(4)}.wav" if groan else f"breath_drowned_{rng.integers(6)}.wav"
            at(out, load(name), t, 10 ** ((gain - 9 + (1 if groan else 0)) / 20))
            t += rng.uniform(3.5, 7.5)
    hum = load("choir_hum.ogg")
    hum = np.tile(hum, 4)[:len(out)]
    level = np.full(len(out), -6.0)
    sing_at = [4.0, 9.3, 14.6, 19.9]
    for s in sing_at:
        a, b, e = n_of(s - 0.8), n_of(s), n_of(s + 0.55)
        level[a:b] = np.linspace(-6, 2, b - a)
        level[b:e] = -30
        level[e:e + n_of(1.1)] = np.linspace(-30, -6, n_of(1.1))
        at(out, load(f"choir_sing_{rng.integers(2)}.wav"), s, 1.0)
    fal = n_of(25.0)
    level[fal:] = np.maximum(-80, np.linspace(-6, -80 * (len(out) - fal) / n_of(0.3), len(out) - fal))
    out += hum * 10 ** (level / 20) * 10 ** (-4 / 20)
    at(out, load("choir_falter.wav"), 25.0, 1.0)
    out = out / max(1.0, np.abs(out).max() / 0.9)
    wavfile.write(os.path.join(ref, "street.wav"), SR, (out * 32767).astype(np.int16))
    rows.insert(0, ("a street: three of the drowned, the Choir singing four times, then faltering", "street.wav"))
    body = "".join(f"<tr><td>{a}</td><td><audio controls preload=none src='{b}'></audio></td></tr>" for a, b in rows)
    open(os.path.join(ref, "index.html"), "w", encoding="utf-8").write(
        "<!doctype html><meta charset=utf-8><title>EBB: the drowned</title><style>"
        "body{font:15px system-ui;background:#10141c;color:#d8dde6;margin:24px;max-width:860px}"
        "td{padding:6px 10px;border-bottom:1px solid #263040}h1{color:#7fd1c7}audio{height:28px}</style>"
        "<h1>The drowned breathing, the Choir's note</h1><p>Audio Stage 12.</p><table>" + body + "</table>")
    print(f"sheet: {len(rows)} rows -> {os.path.relpath(ref, c.ROOT)}")


if __name__ == "__main__" and "--sheet" in sys.argv:
    sheet()
