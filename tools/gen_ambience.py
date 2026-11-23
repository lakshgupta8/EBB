"""Ambience (audio Stage 11; STYLE.md 23, Ambience beds -26 LUFS integrated): each place's bed in
three layers the tide moves between, and spot sounds placed with the set pieces, heard from where
they stand. Stereo Ogg loops, 44.1 kHz, each crossfaded end into start so it has no seam.

The sample (the Flats):
  amb_flats_dry    the tide out: wind over the sand, the sea a long way off, sand hissing in gusts
  amb_flats_wet    the tide in the channels: water running out over sand, lapping at the banks
  amb_flats_flood  the tide over everything: a slow swell through the room, slaps against rock
  amb_spot_fire    a cairn's fire: a low draw and the crackle (warm lights)
  amb_spot_glow    a cold light in the kelp: a faint glass shimmer, a bubble now and then
  amb_spot_wreck   a wreck's timbers working in the wind: creaks, a hollow knock
  amb_spot_pool    a tidepool filling: a trickle and small drops
  amb_spot_boat    a boat beached on stones: the hull rocking, knocking, its rope
  amb_spot_rigging a mast's rigging: a loose line slapping, the ropes creaking

    python tools/gen_ambience.py [names...]
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth  # noqa: E402
from synth import SR, secs, decay, lowpass, highpass, bandpass, resonator, env  # noqa: E402
from gen_sfx_combat import n_of, at, clicks, creak, thump, bubbles, rush, inst  # noqa: E402
from audio_audit import loudness  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
BED_LUFS = -26.0    # each layer alone at the bed's target; two meet at the crossover
SPOT_LUFS = -24.0   # a spot at its source; the room's distance takes it down


def stereo(fn, n, rng, width=0.6):
    """Two takes of the same sound, mixed so the sides share `1 - width` of it: wide, not two."""
    a, b = fn(n, rng), fn(n, rng)
    return np.stack([a * (1 - width / 2) + b * width / 2, b * (1 - width / 2) + a * width / 2], axis=1)


def save_loop(name, x, lufs, fade=2.0):
    """Crossfade the tail into the head (so the loop has no seam), set the loudness, write Ogg."""
    k = n_of(fade)
    head = x[:k].copy()
    x = x[k:]
    w = np.linspace(0, 1, k)[:, None]
    x[-k:] = x[-k:] * (1 - w) + head * w
    x = x - x.mean(axis=0)
    integ, _, _ = loudness(SR, x)
    x = x * 10 ** ((lufs - integ) / 20)
    peak = np.abs(x).max()
    if peak > 0.85:
        x = synth.limit(x, -1.5, look_ms=5.0, release_ms=200.0)
    synth.save_ogg(name, x, OUT, quality=3)
    i2, _, _ = loudness(SR, x)
    print(f"{name}: {len(x) / SR:.1f} s, {i2:.1f} LUFS")


def slow(n, rng, rate=0.05, depth=0.5):
    """A slow wander between 1 - depth and 1."""
    tt = secs(n)
    w = sum(np.sin(2 * np.pi * r * tt + rng.uniform(0, 6.28)) for r in (rate, rate * 1.7, rate * 0.6)) / 3
    return 1 - depth * (0.5 + 0.5 * w)


# ----------------------------------------------------------------------------- the Flats' bed
def flats_dry(n, rng):
    wind = synth.wind(0, n / SR, 0.6, rng)[:n] * slow(n, rng, 0.04, 0.6)
    far_sea = lowpass(rng.normal(0, 1, n), 350, 4) * slow(n, rng, 0.08, 0.5) * 1.2
    hiss = np.zeros(n)
    for t0 in rng.uniform(0, n / SR - 3, 6):
        m = n_of(rng.uniform(1.5, 3.0))
        at(hiss, bandpass(rng.normal(0, 1, m), 3000, 9000) * np.sin(np.pi * np.linspace(0, 1, m)) ** 2 * 0.25, t0)
    return wind + far_sea + hiss


def flats_wet(n, rng):
    run = bandpass(rng.normal(0, 1, n), 600, 3500) * slow(n, rng, 0.1, 0.4) * 0.5
    trickle = bubbles(n, np.sort(rng.uniform(0, n / SR, int(n / SR * 9))), rng, 700, 1800, 0.03) * 0.5
    lap = np.zeros(n)
    t = rng.uniform(0, 2)
    while t < n / SR - 2:
        m = n_of(rng.uniform(1.2, 2.0))
        at(lap, rush(m, rng, 300, 2500, np.sin(np.pi * np.linspace(0, 1, m)) ** 3) * rng.uniform(0.5, 1.0), t)
        t += rng.uniform(2.5, 5.0)
    return run + trickle + lap + lowpass(rng.normal(0, 1, n), 250) * 0.4


def flats_flood(n, rng):
    tt = secs(n)
    swell = rush(n, rng, 80, 1500, 0.55 + 0.45 * np.sin(2 * np.pi * tt / 8.0 + rng.uniform(0, 6.28)))
    deep = lowpass(rng.normal(0, 1, n), 90, 4) * 3.0 * slow(n, rng, 0.06, 0.4)
    slaps = np.zeros(n)
    for t0 in np.sort(rng.uniform(0, n / SR - 1, int(n / SR / 3))):
        m = n_of(0.5)
        at(slaps, bandpass(rng.normal(0, 1, m), 400, 4000) * decay(m, 0.12) * rng.uniform(0.4, 1.0), t0)
    return swell * 1.2 + deep + slaps * 0.8


# ----------------------------------------------------------------------------- spots
def spot_fire(n, rng):
    draw = bandpass(rng.normal(0, 1, n), 120, 900) * slow(n, rng, 0.3, 0.4) * 0.6
    crackle = clicks(np.sort(rng.uniform(0, n / SR, int(n / SR * 14))), n, 3500, rng, ratios=(1.0, 1.7, 2.9), t60=0.004, amp=0.6)
    pops = clicks(np.sort(rng.uniform(0, n / SR, int(n / SR * 1.2))), n, 1600, rng, ratios=(1.0, 2.2), t60=0.015, amp=1.2)
    return draw + crackle + pops


def spot_glow(n, rng):
    tt = secs(n)
    shimmer = sum(np.sin(2 * np.pi * f * tt + rng.uniform(0, 6.28)) * (0.5 + 0.5 * np.sin(2 * np.pi * r * tt + rng.uniform(0, 6.28)))
                  for f, r in ((1318, 0.13), (1975, 0.09), (2637, 0.17))) * 0.05
    return shimmer + bubbles(n, np.sort(rng.uniform(0, n / SR, int(n / SR * 0.8))), rng, 500, 1200, 0.05) * 0.5 + \
        bandpass(rng.normal(0, 1, n), 2000, 6000) * 0.03


def spot_wreck(n, rng):
    out = np.zeros(n)
    t = rng.uniform(0, 1)
    while t < n / SR - 2:
        m = n_of(rng.uniform(0.6, 1.4))
        at(out, creak(m, rng.uniform(25, 60), rng.uniform(20, 80), rng, (110, 260, 600), 30) * np.sin(np.pi * np.linspace(0, 1, m)) * 0.5, t)
        if rng.uniform() < 0.4:
            at(out, synth.hull(rng.uniform(60, 90), 0.5, 0.5, rng)[:n_of(0.8)], t + rng.uniform(0, 0.5))
        t += rng.uniform(1.5, 4.0)
    return out + lowpass(rng.normal(0, 1, n), 300) * 0.15


def spot_pool(n, rng):
    trickle = bandpass(rng.normal(0, 1, n), 1200, 5000) * slow(n, rng, 0.2, 0.5) * 0.25
    drops = bubbles(n, np.sort(rng.uniform(0, n / SR, int(n / SR * 4))), rng, 900, 2200, 0.04)
    return trickle + drops


def spot_boat(n, rng):
    tt = secs(n)
    out = np.zeros(n)
    t = rng.uniform(0, 1)
    while t < n / SR - 1:
        at(out, synth.hull(rng.uniform(140, 190), 0.4, rng.uniform(0.3, 0.7), rng)[:n_of(0.6)] + np.pad(thump(n_of(0.3), 80, 0.05, rng), (0, n_of(0.3))) * 0.3, t)
        t += rng.uniform(1.8, 3.2)
    rope = creak(n, 18, 30, rng, (400, 900, 1800), 60) * (0.5 + 0.5 * np.sin(2 * np.pi * tt / 2.6)) * 0.15
    return out + rope


def spot_rigging(n, rng):
    out = np.zeros(n)
    t = rng.uniform(0, 1)
    while t < n / SR - 1:
        k = int(rng.integers(2, 5))
        for j in range(k):  # a loose line slapping the mast a few times
            m = n_of(0.08)
            at(out, bandpass(rng.normal(0, 1, m), 800, 5000) * decay(m, 0.015) * rng.uniform(0.5, 1.0), t + j * rng.uniform(0.08, 0.14))
        t += rng.uniform(2.0, 5.0)
    return out + creak(n, 15, 25, rng, (500, 1100, 2300), 80) * slow(n, rng, 0.3, 0.6) * 0.1 + synth.wind(0, n / SR, 0.3, rng)[:n] * 0.3


BEDS = [("amb_flats_dry", flats_dry, 44.0), ("amb_flats_wet", flats_wet, 44.0), ("amb_flats_flood", flats_flood, 44.0)]
SPOTS = [("amb_spot_fire", spot_fire, 10.0), ("amb_spot_glow", spot_glow, 14.0), ("amb_spot_wreck", spot_wreck, 22.0),
         ("amb_spot_pool", spot_pool, 10.0), ("amb_spot_boat", spot_boat, 16.0), ("amb_spot_rigging", spot_rigging, 18.0)]


def main():
    only = sys.argv[1:]
    for k, (name, fn, secs_) in enumerate(BEDS + SPOTS):
        if only and not any(name.startswith(o) for o in only):
            continue
        rng = np.random.default_rng(500 + k)
        bed = (name, fn, secs_) in BEDS
        x = stereo(fn, n_of(secs_ + 2.0), rng, 0.7 if bed else 0.3)
        save_loop(name, x, BED_LUFS if bed else SPOT_LUFS)




def bed_gains(level):
    """As Audio.bed_gains: each layer's share at a tide level."""
    def smooth(a, b, x):
        t = np.clip((x - a) / (b - a), 0, 1)
        return t * t * (3 - 2 * t)
    return [1 - 0.8 * smooth(0.3, 1.6, level), smooth(0.1, 1.0, level) * (1 - 0.5 * smooth(1.8, 3.0, level)), smooth(1.2, 2.4, level)]


def sheet(place="flats"):
    """The listening page (local): the bed swept from the tide out to over the floor in a minute,
    as the game mixes it, then each layer and spot alone."""
    import shutil
    from audio_audit import read
    ref = os.path.join(ROOT, "assets", "reference", "audio", "ambience")
    os.makedirs(ref, exist_ok=True)
    n = n_of(60.0)
    level = np.linspace(0, 3.0, n)
    out = np.zeros((n, 2))
    for i, k in enumerate(("dry", "wet", "flood")):
        _, x, _ = read(os.path.join(OUT, f"amb_{place}_{k}.ogg"))
        x = np.tile(x, (n // len(x) + 1, 1))[:n]
        out += x * np.array([bed_gains(v)[i] for v in level[::441]]).repeat(441)[:n, None]
    synth.save_ogg(f"sweep_{place}", out, ref, quality=4)
    rows = [(f"the {place} bed, the tide rising from out to over the floor in a minute", f"sweep_{place}.ogg")]
    for name, _, _ in BEDS + SPOTS:
        shutil.copy(os.path.join(OUT, name + ".ogg"), os.path.join(ref, name + ".ogg"))
        rows.append((name, name + ".ogg"))
    for f in sorted(os.listdir(ref)):
        if f.startswith("bot_"):
            rows.append((f"a bot night: {f[4:-4]}", f))
    body = "".join(f"<tr><td>{a}</td><td><audio controls preload=none src='{b}'></audio></td></tr>" for a, b in rows)
    open(os.path.join(ref, "index.html"), "w", encoding="utf-8").write(
        "<!doctype html><meta charset=utf-8><title>EBB: ambience</title><style>"
        "body{font:15px system-ui;background:#10141c;color:#d8dde6;margin:24px;max-width:860px}"
        "td{padding:6px 10px;border-bottom:1px solid #263040}h1{color:#7fd1c7}audio{height:28px}</style>"
        "<h1>Ambience</h1><p>Audio Stage 11. Beds at their file level (the game plays them 6 dB down); spots at their "
        "source (the room's distance takes them down).</p><table>" + body + "</table>")
    print(f"sheet: {len(rows)} rows -> {os.path.relpath(ref, ROOT)}")


if __name__ == "__main__":
    if "--sheet" in sys.argv:
        sheet()
    else:
        main()
