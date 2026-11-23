"""The world underfoot (audio Stage 10; STYLE.md 23, the World role, -18 momentary max): Tam's steps by
surface and depth, the tide rising by eighths, doors, chests, pickups by kind, drips. 44.1 kHz mono
WAV, levelled as the combat sounds are (`gen_sfx_combat.save`), several variants where a sound
comes often so a walk never repeats one step twice running.

The sample (the Flats, the Harbour, the Hall):
  step_sand     a soft crunch, the grains giving             (the Flats, Marrow Rock)
  step_wood     a hollow knock on deck boards, now and then a creak   (the Harbour)
  step_stone    a hard heel on basalt, a little grit          (the Hall)
  step_shallow  a small splash, the foot lifting out          (any shallow water)
  step_deep     a slow wading slosh, water pushed aside       (any deep water)
  tide_rise     the sea coming in a little further: a swell rolling up (each eighth of the tide)
  tide_mark     the same, longer and lower, as the tide goes over a whole level
  door_open     an iron grate drawn up its stone arch: chain, scrape and the latch
  chest_open    a lid's hinge creaking, the hasp knocked back
  pick_salt, pick_pearl, pick_key, pick_page, pick_glass, pick_shell, pick_fish
  drip          one drop falling into water, placed where it falls

    python tools/gen_sfx_world.py [names...]
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth  # noqa: E402
import gen_sfx_combat as c  # noqa: E402
from synth import SR, secs, decay, lowpass, highpass, bandpass, resonator, env  # noqa: E402
from gen_sfx_combat import n_of, fit, at, clicks, creak, thump, bubbles, grind, rush, clang, whoosh, inst  # noqa: E402

c.TARGET["world"] = -18.0


# ----------------------------------------------------------------------------- steps
def grains(n, rng, count, lo, hi, spread):
    """Many tiny grains giving under a weight: short bandpassed ticks bunched at the start."""
    out = np.zeros(n)
    m = n_of(0.006)
    for t in np.sort(rng.gamma(1.5, spread / 1.5, count)):
        i = int(t * SR)
        if i + m < n:
            out[i:i + m] += bandpass(rng.uniform(-1, 1, m), lo, hi) * rng.uniform(0.2, 1.0) * np.hanning(m)
    return out


def step_sand(rng):
    n = n_of(0.22)
    press = lowpass(rng.normal(0, 1, n), 500) * env(n, 0.01, r=0.12) * decay(n, 0.08) * 0.6
    return grains(n, rng, 60, 1200, 6000, 0.04) + press + thump(n, 70, 0.03, rng) * 0.25


def step_wood(rng):
    n = n_of(0.3)
    board = synth._modal(rng.uniform(150, 210), n, [1.0, 2.4, 3.9, 6.1], [0.07, 0.04, 0.025, 0.015], [1.0, 0.5, 0.3, 0.15], rng)
    heel = highpass(rng.uniform(-1, 1, n) * decay(n, 0.004), 1500) * 0.3
    out = board + heel + thump(n, 90, 0.03, rng) * 0.5
    if rng.uniform() < 0.3:  # an old board answers
        out += at(np.zeros(n), creak(n_of(0.15), 120, 60, rng, (350, 800, 1600), 70) * 0.15, 0.04)
    return out


def step_stone(rng):
    n = n_of(0.18)
    tap = clicks([0.0], n, rng.uniform(1900, 2400), rng, ratios=(1.0, 2.6, 4.3), t60=0.012, amp=0.8)
    scuff = bandpass(rng.normal(0, 1, n), 2000, 8000) * env(n, 0.005, r=0.06) * decay(n, 0.04) * 0.3
    return tap + scuff + thump(n, 110, 0.025, rng) * 0.6


def step_shallow(rng):
    n = n_of(0.3)
    slap = bandpass(rng.normal(0, 1, n), 600, 5000) * decay(n, 0.05)
    lift = at(np.zeros(n), bandpass(rng.normal(0, 1, n_of(0.12)), 1500, 6000) * env(n_of(0.12), 0.02, r=0.08) * 0.35, 0.13)
    return slap + lift + bubbles(n, np.sort(rng.uniform(0.01, 0.15, 4)), rng, 700, 1500) * 0.4


def step_deep(rng):
    n = n_of(0.55)
    push = rush(n, rng, 200, 2200, env(n, 0.12, r=0.25)) * 1.2
    return push + bubbles(n, np.sort(rng.uniform(0.1, 0.45, 7)), rng, 300, 800, 0.05) * 0.6 + lowpass(rng.normal(0, 1, n), 200) * env(n, 0.1, r=0.3) * 0.8


# ----------------------------------------------------------------------------- the tide
def tide_rise(rng):
    n = n_of(2.4)
    tt = secs(n)
    swell = rush(n, rng, 150, 2500, np.sin(np.pi * np.clip(tt / 2.2, 0, 1)) ** 2)
    hiss = bandpass(rng.normal(0, 1, n), 2500, 9000) * np.exp(-((tt - 1.3) / 0.35) ** 2) * 0.5
    return swell + hiss + c.rumble(n, rng, 70) * np.sin(np.pi * np.clip(tt / 2.4, 0, 1)) * 0.5


def tide_mark(rng):
    n = n_of(3.6)
    tt = secs(n)
    swell = rush(n, rng, 90, 2000, np.sin(np.pi * np.clip(tt / 3.4, 0, 1)) ** 2) * 1.2
    deep = c.rumble(n, rng, 55) * np.sin(np.pi * np.clip(tt / 3.6, 0, 1)) * 1.1
    buoy = at(np.zeros(n), fit(inst("buoy", "D4", 2.5, 0.35, rng), n_of(2.5)), 0.9)
    return swell + deep + buoy


# ----------------------------------------------------------------------------- doors and chests
def door_open(rng):
    n = n_of(1.1)
    chain = synth.chain(0, 0.7, 0.9, rng)[:n_of(0.7)]
    scrape = grind(n_of(0.6), rng, 400, 2500, 30) * env(n_of(0.6), 0.05, r=0.15) * 0.8
    out = at(np.zeros(n), chain, 0.0)
    at(out, scrape, 0.1)
    return at(out, clang(rng.uniform(520, 600), n_of(0.4), rng, 0.15, 1.2) + thump(n_of(0.4), 80, 0.06, rng), 0.68)


def chest_open(rng):
    n = n_of(0.8)
    hasp = clang(rng.uniform(1100, 1300), n_of(0.2), rng, 0.05, 0.9)
    hinge = creak(n_of(0.5), 90, 30, rng, (500, 1100, 2300), 80) * env(n_of(0.5), 0.05, r=0.1) * 0.5
    out = at(np.zeros(n), hasp, 0.0)
    at(out, hinge, 0.12)
    return at(out, thump(n_of(0.3), 90, 0.06, rng) * 0.7, 0.6)


# ----------------------------------------------------------------------------- pickups
def pick_salt(rng):    # a crystal into the pouch: a small bright tinkle
    n = n_of(0.3)
    return clicks(np.sort(rng.uniform(0, 0.06, 3)), n, rng.uniform(3800, 4600), rng, ratios=(1.0, 2.3, 3.9), t60=0.05, amp=0.5)


def pick_pearl(rng):   # a pearl: a rounder, sweeter note
    n = n_of(0.6)
    return fit(inst("glass", rng.choice(["E6", "F#6", "A6"]), 0.6, 0.6, rng), n) + clicks([0.0], n, 2200, rng, ratios=(1.0, 2.0), t60=0.02, amp=0.2)


def pick_key(rng):     # an iron key on a ring
    n = n_of(0.5)
    return clang(2600, n, rng, 0.08, 0.5) + at(np.zeros(n), clang(3100, n_of(0.3), rng, 0.06, 0.4), 0.07)


def pick_page(rng):    # a wet page folded away
    n = n_of(0.45)
    tt = secs(n)
    rustle = bandpass(rng.normal(0, 1, n), 1500, 7000) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 11 * tt))) * env(n, 0.03, r=0.15)
    return rustle * 0.7


def pick_glass(rng):   # salt-glass: two notes, Pell's
    n = n_of(0.9)
    return fit(inst("glass", "B5", 0.9, 0.6, rng), n) + at(np.zeros(n), fit(inst("glass", "F#6", 0.8, 0.4, rng), n_of(0.8)), 0.09)


def pick_shell(rng):   # a shell: a light hollow clack
    n = n_of(0.25)
    return clicks([0.0, 0.05], n, rng.uniform(900, 1100), rng, ratios=(1.0, 2.7, 5.1), t60=0.04, amp=0.8)


def pick_fish(rng):    # a fish: a wet flop
    n = n_of(0.35)
    return thump(n, 110, 0.05, rng) + bandpass(rng.normal(0, 1, n), 500, 3000) * decay(n, 0.05) * 0.8 + \
        at(np.zeros(n), bandpass(rng.normal(0, 1, n_of(0.1)), 600, 3000) * decay(n_of(0.1), 0.03) * 0.5, 0.15)


# ----------------------------------------------------------------------------- drips
def drip(rng):
    n = n_of(0.35)
    tt = secs(n)
    f = rng.uniform(900, 1500) * (1 + 1.5 * tt / 0.05)
    plink = np.sin(2 * np.pi * np.cumsum(np.minimum(f, 4000)) / SR) * decay(n, 0.04)
    return plink + clicks([0.0], n, 3000, rng, ratios=(1.0, 2.1), t60=0.004, amp=0.2)


# ============================================================================= the rest (Stage 10)
def step_cobble(rng):    # the Streets: a heel on a rounded stone, the next one rocking in its bed
    n = n_of(0.22)
    tap = clicks([0.0], n, rng.uniform(1300, 1700), rng, ratios=(1.0, 2.3, 3.8), t60=0.018, amp=0.8)
    rock = clicks([rng.uniform(0.03, 0.05)], n, rng.uniform(700, 900), rng, ratios=(1.0, 2.6), t60=0.02, amp=0.35)
    grit = bandpass(rng.normal(0, 1, n), 1500, 6000) * env(n, 0.005, r=0.08) * decay(n, 0.05) * 0.35
    return tap + rock + grit + thump(n, 95, 0.03, rng) * 0.5


def step_coral(rng):     # the Reef: dead coral crunching, brittle and many-voiced
    n = n_of(0.24)
    crunch = clicks(np.sort(rng.gamma(1.5, 0.012, 9)), n, rng.uniform(2200, 3000), rng, ratios=(1.0, 3.1, 6.3), t60=0.01, amp=0.35)
    return crunch + grains(n, rng, 25, 2500, 8000, 0.03) * 0.6 + thump(n, 85, 0.03, rng) * 0.4


def current(rng):        # the water running in a channel round Tam's legs: a loop, seamless
    n = n_of(6.0)
    tt = secs(n)
    flow = rush(n, rng, 250, 2600) * (1 + 0.25 * np.sin(2 * np.pi * tt / 3.0))
    burble = bubbles(n, np.sort(rng.uniform(0, 6.0, 40)), rng, 300, 900, 0.05) * 0.35
    low = lowpass(rng.normal(0, 1, n), 180) * 0.6
    return flow + burble + low


def coral_cut(rng):      # living coral opening a leg: a quick rasp and a sting
    n = n_of(0.3)
    rasp = bandpass(rng.normal(0, 1, n), 2500, 9000) * np.abs(np.sin(2 * np.pi * 45 * secs(n))) * decay(n, 0.08)
    return rasp + clicks(np.sort(rng.uniform(0, 0.05, 4)), n, 3200, rng, ratios=(1.0, 3.1), t60=0.008, amp=0.4)


def fountain(rng):       # cupped hands in the fountain: water lifted and drunk, the basin ringing
    n = n_of(1.2)
    scoop = rush(n_of(0.4), rng, 400, 4000, env(n_of(0.4), 0.05, r=0.2))
    out = at(np.zeros(n), scoop, 0.0)
    at(out, bubbles(n_of(0.6), np.sort(rng.uniform(0, 0.4, 8)), rng, 400, 1000, 0.05) * 0.6, 0.25)
    return at(out, fit(inst("glass", "E5", 1.0, 0.35, rng), n_of(0.9)), 0.3)


def vault_open(rng):     # the vault's door swung on old iron, a bolt drawn, the hoard shifting
    n = n_of(1.8)
    bolt = clang(rng.uniform(380, 430), n_of(0.4), rng, 0.2)
    groan = creak(n_of(1.0), 30, 70, rng, (120, 260, 600, 1300), 30) * env(n_of(1.0), 0.1, r=0.2) * 0.8
    out = at(np.zeros(n), bolt, 0.0)
    at(out, groan, 0.25)
    return at(out, clicks(np.sort(rng.uniform(0, 0.5, 16)), n_of(0.6), 3600, rng, ratios=(1.0, 2.3, 3.9), t60=0.04, amp=0.25), 1.15)


def vault_locked(rng):   # the bolt tried and holding: a rattle and a dead knock
    n = n_of(0.5)
    rattle = clicks([0.0, 0.06, 0.11], n, 900, rng, ratios=(1.0, 2.7, 5.2), t60=0.04, amp=0.8)
    return rattle + at(np.zeros(n), thump(n_of(0.3), 90, 0.06, rng), 0.16)


SOUNDS = [  # (name, fn, role, variants)
    ("step_sand", step_sand, "world", 6), ("step_wood", step_wood, "world", 6), ("step_stone", step_stone, "world", 6),
    ("step_shallow", step_shallow, "world", 6), ("step_deep", step_deep, "world", 4),
    ("tide_rise", tide_rise, "world", 2), ("tide_mark", tide_mark, "world", 1),
    ("door_open", door_open, "world", 2), ("chest_open", chest_open, "world", 2),
    ("pick_salt", pick_salt, "world", 4), ("pick_pearl", pick_pearl, "world", 3), ("pick_key", pick_key, "world", 1),
    ("pick_page", pick_page, "world", 2), ("pick_glass", pick_glass, "world", 1), ("pick_shell", pick_shell, "world", 2),
    ("pick_fish", pick_fish, "world", 2), ("drip", drip, "world", 4),
    ("step_cobble", step_cobble, "world", 6), ("step_coral", step_coral, "world", 6),
    ("coral_cut", coral_cut, "world", 3), ("fountain", fountain, "world", 1),
    ("vault_open", vault_open, "world", 1), ("vault_locked", vault_locked, "world", 1),
]


def current_loop():
    """The current as an Ogg loop (played held, its volume ridden by how hard the water carries):
    the tail crossfaded into the head so it has no seam."""
    rng = np.random.default_rng(77)
    x = current(rng)
    k = n_of(1.0)
    head = x[:k].copy()
    w = np.linspace(0, 1, k)
    x = x[k:]
    x[-k:] = x[-k:] * (1 - w) + head * w
    x = x - x.mean()
    x = x / np.abs(x).max() * 0.5
    _, mom, _ = c.loudness(SR, x[:, None])
    x = x * 10 ** ((-18.0 - mom) / 20)  # the World level; the game rides it down
    synth.save_ogg("current", np.stack([x, x], axis=1), c.OUT)


STEP_DB = {"sand": -4.0, "wood": -1.0, "stone": 0.0, "cobble": 0.0, "coral": -4.0, "shallow": -3.0, "deep": -2.0}  # as Player.STEP_DB
REF = os.path.join(c.ROOT, "assets", "reference", "audio", "world")


def sheet():
    """A listening page (local): eight seconds' walk on each surface as the game plays it (a foot
    every 0.3 s, a variant at random, the surface's level), then every other sound here."""
    from scipy.io import wavfile
    os.makedirs(REF, exist_ok=True)
    rng = np.random.default_rng(3)
    rows = []
    for s, db in STEP_DB.items():
        files = sorted(f for f in os.listdir(c.OUT) if f.startswith(f"step_{s}_") and f.endswith(".wav"))
        out = np.zeros(n_of(8.5))
        for k in range(26):
            _, x = wavfile.read(os.path.join(c.OUT, files[rng.integers(len(files))]))
            at(out, x / 32768.0, 0.02 + 0.3 * k + rng.uniform(-0.01, 0.01), 10 ** (db / 20))
        wavfile.write(os.path.join(REF, f"walk_{s}.wav"), SR, (out * 32767).astype(np.int16))
        rows.append((f"walking: {s}", f"walk_{s}.wav"))
    for name, _, _, k in SOUNDS:
        if name.startswith("step_"):
            continue
        f = name + ("_0" if k > 1 else "") + ".wav"
        import shutil
        shutil.copy(os.path.join(c.OUT, f), os.path.join(REF, f))
        rows.append((name, f))
    for f in sorted(os.listdir(REF)):
        if f.startswith("bot_") and f.endswith(".ogg"):
            rows.append((f"a bot night: {f[4:-4]}", f))
    body = "".join(f"<tr><td>{a}</td><td><audio controls preload=none src='{b}'></audio></td></tr>" for a, b in rows)
    page = ("<!doctype html><meta charset=utf-8><title>EBB: the world underfoot</title><style>"
            "body{font:15px system-ui;background:#10141c;color:#d8dde6;margin:24px;max-width:860px}"
            "td{padding:6px 10px;border-bottom:1px solid #263040}h1{color:#7fd1c7}audio{height:28px}</style>"
            "<h1>The world underfoot</h1><p>Audio Stage 10. The walks are at the levels the game plays them, "
            "relative to each other; the rest at their file level.</p><table>" + body + "</table>")
    open(os.path.join(REF, "index.html"), "w", encoding="utf-8").write(page)
    print(f"sheet: {len(rows)} rows -> {os.path.relpath(REF, c.ROOT)}")


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--sheet" not in sys.argv:
        for name, fn, role, k in SOUNDS:
            if not only or any(name.startswith(o) for o in only):
                c.variants(name, fn, role, k, seed=10)
        if not only or "current" in only:
            current_loop()
        print("world sounds written")
    sheet()


if __name__ == "__main__":
    main()
