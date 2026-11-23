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
    for _ in range(3):  # a peaky loop (the well's drops) loses loudness to the limiter: set it again
        if np.abs(x).max() <= 0.85:
            break
        x = synth.limit(x, -1.5, look_ms=5.0, release_ms=60.0)
        integ, _, _ = loudness(SR, x)
        x = x * 10 ** (min(lufs - integ, 3.0) / 20)
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


# ============================================================================= the rest (Stage 11)
def events(n, rng, every, fn, jitter=0.5):
    """fn(rng) -> a short sound, laid every `every` seconds or so through n samples."""
    out = np.zeros(n)
    t = rng.uniform(0, every)
    while t < n / SR - 1.5:
        at(out, fn(rng), t)
        t += every * rng.uniform(1 - jitter, 1 + jitter)
    return out


def knock(f, dur=0.6, vel=0.5):
    return lambda rng: synth.hull(f * rng.uniform(0.85, 1.15), dur, vel * rng.uniform(0.6, 1.0), rng)[:n_of(dur)]


def plink(lo, hi, t60=0.05):
    return lambda rng: bubbles(n_of(0.1), [0.0], rng, lo, hi, t60)


def splash_(m, lo=400, hi=4000, t60=0.12):
    return lambda rng: bandpass(rng.normal(0, 1, n_of(m)), lo, hi) * decay(n_of(m), t60) * rng.uniform(0.4, 1.0)


# --- the Harbour: hulls on their ropes, water among the piles, the harbour risen
def harbour_dry(n, rng):
    ropes = creak(n, 12, 20, rng, (300, 700, 1500), 60) * slow(n, rng, 0.15, 0.7) * 0.12
    hulls = events(n, rng, 3.5, knock(85, 0.8, 0.5))
    buoy = events(n, rng, 11.0, lambda r: inst("buoy", "A4", 3.0, 0.15, r)[:n_of(3.0)], 0.3)
    return ropes + hulls + buoy + synth.wind(0, n / SR, 0.35, rng)[:n] + lowpass(rng.normal(0, 1, n), 300) * 0.3


def harbour_wet(n, rng):
    chop = events(n, rng, 0.7, splash_(0.4, 500, 3500, 0.08), 0.6) * 0.6
    under = rush(n, rng, 150, 1500, slow(n, rng, 0.12, 0.5)) * 0.5
    return chop + under + events(n, rng, 4.0, knock(95, 0.6, 0.4))


def harbour_flood(n, rng):
    tt = secs(n)
    swell = rush(n, rng, 70, 1200, 0.55 + 0.45 * np.sin(2 * np.pi * tt / 9.0)) * 1.2
    groan = events(n, rng, 6.0, lambda r: creak(n_of(1.6), 20, 45, r, (80, 190, 420), 25) * np.sin(np.pi * np.linspace(0, 1, n_of(1.6))) * 0.6)
    return swell + groan + lowpass(rng.normal(0, 1, n), 80, 4) * 2.5


# --- the Reef: outside the wall, the open sea breaking on living coral
def reef_dry(n, rng):
    surf = events(n, rng, 7.0, lambda r: synth.surf(0, 6.0, 0.8, r)[:n_of(6.0)], 0.25)
    coral = events(n, rng, 0.25, lambda r: clicks([0.0], n_of(0.05), r.uniform(2500, 4500), r, ratios=(1.0, 2.3), t60=0.004, amp=0.25), 0.9)
    return surf + coral + synth.wind(0, n / SR, 0.4, rng)[:n]


def reef_wet(n, rng):
    run = rush(n, rng, 300, 3000, slow(n, rng, 0.2, 0.4)) * 0.7
    coral = events(n, rng, 0.12, lambda r: clicks([0.0], n_of(0.05), r.uniform(2500, 5000), r, ratios=(1.0, 2.3), t60=0.004, amp=0.3), 0.9)
    return run + coral + events(n, rng, 5.0, lambda r: synth.surf(0, 5.0, 0.5, r)[:n_of(5.0)], 0.3)


def reef_flood(n, rng):
    tt = secs(n)
    surge = rush(n, rng, 60, 2500, 0.5 + 0.5 * np.sin(2 * np.pi * tt / 6.0) ** 2) * 1.3
    return surge + lowpass(rng.normal(0, 1, n), 70, 4) * 3.0 + events(n, rng, 2.5, splash_(0.6, 300, 5000, 0.2))


# --- the Streets: water falling into water in stone rooms
def streets_dry(n, rng):
    drips = events(n, rng, 0.9, plink(700, 1800), 0.8) * 0.8
    alley = synth.wind(0, n / SR, 0.25, rng)[:n] * slow(n, rng, 0.05, 0.6)
    return drips + alley + lowpass(rng.normal(0, 1, n), 200) * 0.3


def streets_wet(n, rng):
    gutter = bandpass(rng.normal(0, 1, n), 900, 4500) * slow(n, rng, 0.15, 0.4) * 0.35
    steps = events(n, rng, 0.35, plink(500, 1300, 0.04), 0.7) * 0.6
    return gutter + steps + events(n, rng, 1.2, plink(700, 1800), 0.8) * 0.6


def streets_flood(n, rng):
    tt = secs(n)
    slosh = rush(n, rng, 120, 1800, 0.5 + 0.5 * np.sin(2 * np.pi * tt / 5.0 + 1.0)) * 0.9
    hollow = events(n, rng, 3.0, splash_(0.8, 250, 2000, 0.25)) * 0.7
    return slosh + hollow + lowpass(rng.normal(0, 1, n), 120, 4) * 1.5


# --- the Hall: pressure, a room breathing, the deep beneath it
def hall_dry(n, rng):
    tt = secs(n)
    press = (np.sin(2 * np.pi * 41 * tt) * 0.5 + np.sin(2 * np.pi * 61.5 * tt) * 0.3) * slow(n, rng, 0.03, 0.5)
    far = events(n, rng, 8.0, lambda r: np.sin(2 * np.pi * r.uniform(150, 260) * secs(n_of(3.0))) * env(n_of(3.0), 1.2, r=1.4) * 0.15)
    return press * 0.5 + far + lowpass(rng.normal(0, 1, n), 180) * 0.4


def hall_wet(n, rng):
    seep = bandpass(rng.normal(0, 1, n), 500, 3000) * slow(n, rng, 0.07, 0.5) * 0.3
    channel = rush(n, rng, 150, 1200, slow(n, rng, 0.1, 0.4)) * 0.5
    return seep + channel + events(n, rng, 2.0, plink(400, 1000, 0.08), 0.7) * 0.8


def hall_flood(n, rng):
    rise_ = bubbles(n, np.sort(rng.uniform(0, n / SR, int(n / SR * 6))), rng, 150, 450, 0.08) * 0.8
    groan = events(n, rng, 9.0, lambda r: creak(n_of(2.5), 12, 25, r, (60, 140, 320), 20) * np.sin(np.pi * np.linspace(0, 1, n_of(2.5))) * 0.7)
    return lowpass(rng.normal(0, 1, n), 100, 4) * 3.5 * slow(n, rng, 0.05, 0.4) + rise_ + groan


# --- spots for the rest
def spot_crane(n, rng):      # the crane's cable working, a chain link knocking, its lamp
    return creak(n, 10, 18, rng, (250, 600, 1300), 40) * slow(n, rng, 0.2, 0.7) * 0.2 + \
        events(n, rng, 2.5, lambda r: synth.chain(0, 0.6, 0.3, r)[:n_of(0.6)]) + spot_lamp(n, rng) * 0.5


def spot_lamp(n, rng):       # an oil lamp: a soft flame and its glass ticking warm
    return bandpass(rng.normal(0, 1, n), 200, 1200) * slow(n, rng, 0.5, 0.3) * 0.3 + \
        events(n, rng, 1.8, lambda r: clicks([0.0], n_of(0.05), r.uniform(4000, 5500), r, ratios=(1.0, 1.6), t60=0.006, amp=0.2))


def spot_piles(n, rng):      # water slapping round the piles under a pier
    return events(n, rng, 1.1, splash_(0.35, 400, 3000, 0.07), 0.6) + rush(n, rng, 200, 1500, slow(n, rng, 0.2, 0.6)) * 0.3


def spot_buoy(n, rng):       # a bell buoy rocking: its bell now and then, the water round it
    return events(n, rng, 5.5, lambda r: inst("buoy", "D5", 3.0, 0.5, r)[:n_of(3.0)], 0.35) + spot_piles(n, rng) * 0.3


def spot_well(n, rng):       # a well: drops falling a long way into water
    return events(n, rng, 1.3, lambda r: resonator(bubbles(n_of(0.5), [0.0], r, 600, 1200, 0.06), 420, 60), 0.6) + \
        resonator(lowpass(rng.normal(0, 1, n), 600), 420, 80) * 0.08 + lowpass(rng.normal(0, 1, n), 400) * 0.15


def spot_tower(n, rng):      # the bell tower: wind in the belfry, the great bell humming in it
    hum = inst("saltmere", "D3", n / SR, 0.08, rng)[:n]
    hum = np.pad(hum, (0, max(0, n - len(hum))))[:n] * slow(n, rng, 0.1, 0.6)
    return synth.wind(0, n / SR, 0.5, rng)[:n] + lowpass(hum, 900) * 0.8 + \
        creak(n, 8, 14, rng, (200, 480, 1000), 40) * slow(n, rng, 0.15, 0.8) * 0.1


def spot_candles(n, rng):    # candles: many small flames fluttering, wax ticking
    flutter = bandpass(rng.normal(0, 1, n), 300, 2000) * (0.6 + 0.4 * lowpass(rng.normal(0, 1, n), 6) * 8) * 0.15
    return flutter + events(n, rng, 0.6, lambda r: clicks([0.0], n_of(0.04), r.uniform(2500, 4000), r, ratios=(1.0, 1.9), t60=0.004, amp=0.25), 0.9)


def spot_organ(n, rng):      # the drowned organ: the sea breathing through its pipes
    tt = secs(n)
    breath = slow(n, rng, 0.07, 0.9)
    pipes = sum(np.sin(2 * np.pi * f * tt) * (1 / (i + 1)) for i, f in enumerate((55, 110, 164.8, 220)))
    return (pipes * 0.3 + bandpass(rng.normal(0, 1, n), 200, 1500) * 0.4) * breath


def spot_coral(n, rng):      # living coral: dense small clicks and pops
    return events(n, rng, 0.05, lambda r: clicks([0.0], n_of(0.05), r.uniform(2500, 6000), r, ratios=(1.0, 2.3), t60=0.004, amp=0.3), 0.95) + \
        bubbles(n, np.sort(rng.uniform(0, n / SR, int(n / SR * 2))), rng, 800, 2000, 0.03) * 0.3


def spot_breach(n, rng):     # the sea coming through a breach in the wall
    return rush(n, rng, 150, 4000, 0.7 + 0.3 * slow(n, rng, 0.25, 1.0)) * 1.2 + lowpass(rng.normal(0, 1, n), 120, 4) * 2.0


def spot_clam(n, rng):       # a great clam breathing: a slow creak open and shut, bubbles
    tt = secs(n)
    return creak(n, 6, 10, rng, (150, 340, 760), 30) * (0.5 + 0.5 * np.sin(2 * np.pi * tt / 6.0)) * 0.25 + \
        events(n, rng, 6.0, lambda r: bubbles(n_of(1.0), np.sort(r.uniform(0, 0.8, 6)), r, 300, 700, 0.06), 0.2)


def spot_jelly(n, rng):      # a jelly's light: a soft pulse of glass and a bubble
    tt = secs(n)
    pulse = (0.5 + 0.5 * np.sin(2 * np.pi * tt / 2.4)) ** 2
    return sum(np.sin(2 * np.pi * f * tt) for f in (880, 1320, 1760)) * 0.03 * pulse + spot_glow(n, rng) * 0.4


BEDS = [("amb_flats_dry", flats_dry, 44.0), ("amb_flats_wet", flats_wet, 44.0), ("amb_flats_flood", flats_flood, 44.0)]
SPOTS = [("amb_spot_fire", spot_fire, 10.0), ("amb_spot_glow", spot_glow, 14.0), ("amb_spot_wreck", spot_wreck, 22.0),
         ("amb_spot_pool", spot_pool, 10.0), ("amb_spot_boat", spot_boat, 16.0), ("amb_spot_rigging", spot_rigging, 18.0)]
REST = [  # appended so the sample's seeds stay as they were
    ("amb_harbour_dry", harbour_dry, 44.0), ("amb_harbour_wet", harbour_wet, 44.0), ("amb_harbour_flood", harbour_flood, 44.0),
    ("amb_reef_dry", reef_dry, 44.0), ("amb_reef_wet", reef_wet, 44.0), ("amb_reef_flood", reef_flood, 44.0),
    ("amb_streets_dry", streets_dry, 44.0), ("amb_streets_wet", streets_wet, 44.0), ("amb_streets_flood", streets_flood, 44.0),
    ("amb_hall_dry", hall_dry, 44.0), ("amb_hall_wet", hall_wet, 44.0), ("amb_hall_flood", hall_flood, 44.0),
    ("amb_spot_crane", spot_crane, 16.0), ("amb_spot_lamp", spot_lamp, 10.0), ("amb_spot_piles", spot_piles, 12.0),
    ("amb_spot_buoy", spot_buoy, 20.0), ("amb_spot_well", spot_well, 14.0), ("amb_spot_tower", spot_tower, 20.0),
    ("amb_spot_candles", spot_candles, 10.0), ("amb_spot_organ", spot_organ, 20.0), ("amb_spot_coral", spot_coral, 10.0),
    ("amb_spot_breach", spot_breach, 12.0), ("amb_spot_clam", spot_clam, 18.0), ("amb_spot_jelly", spot_jelly, 12.0),
]


def main():
    only = sys.argv[1:]
    for k, (name, fn, secs_) in enumerate(BEDS + SPOTS + REST):
        if only and not any(name.startswith(o) for o in only):
            continue
        rng = np.random.default_rng(500 + k)
        bed = "_spot_" not in name
        x = stereo(fn, n_of(secs_ + 2.0), rng, 0.7 if bed else 0.3)
        save_loop(name, x, BED_LUFS if bed else SPOT_LUFS)




def bed_gains(level):
    """As Audio.bed_gains: each layer's share at a tide level."""
    def smooth(a, b, x):
        t = np.clip((x - a) / (b - a), 0, 1)
        return t * t * (3 - 2 * t)
    return [1 - 0.8 * smooth(0.3, 1.6, level), smooth(0.1, 1.0, level) * (1 - 0.5 * smooth(1.8, 3.0, level)), smooth(1.2, 2.4, level)]


def sheet(places=("flats", "harbour", "reef", "streets", "hall")):
    """The listening page (local): the bed swept from the tide out to over the floor in a minute,
    as the game mixes it, then each layer and spot alone."""
    import shutil
    from audio_audit import read
    ref = os.path.join(ROOT, "assets", "reference", "audio", "ambience")
    os.makedirs(ref, exist_ok=True)
    n = n_of(60.0)
    level = np.linspace(0, 3.0, n)
    rows = []
    for place in places:
        out = np.zeros((n, 2))
        for i, k in enumerate(("dry", "wet", "flood")):
            _, x, _ = read(os.path.join(OUT, f"amb_{place}_{k}.ogg"))
            x = np.tile(x, (n // len(x) + 1, 1))[:n]
            out += x * np.array([bed_gains(v)[i] for v in level[::441]]).repeat(441)[:n, None]
        synth.save_ogg(f"sweep_{place}", out, ref, quality=4)
        rows.append((f"the {place} bed, the tide rising from out to over the floor in a minute", f"sweep_{place}.ogg"))
    for name, _, _ in BEDS + SPOTS + REST:
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
