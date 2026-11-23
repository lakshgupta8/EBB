"""The menus (audio Stage 12; STYLE.md 23, Interface -20 momentary max): one sound for each thing a
menu does, from the keeper's own kit (wood, brass, glass), never a beep. Mono WAV, played centred
on the Interface bus.

  ui_move     the cursor stepping to another row: a small dry wood tick
  ui_confirm  a choice taken: a brass latch and a glass note above it
  ui_back     a menu closed: the latch let go, a lower, softer note
  ui_open     a menu or a page opening: paper turned over and settled
  ui_buy      something bought: salt counted out, the glass note answering
  ui_refuse   not now (too dear, sold out, locked): two dull knocks on wood

    python tools/gen_sfx_interface.py
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sfx_combat as c  # noqa: E402
from synth import SR, secs, decay, bandpass, env  # noqa: E402
from gen_sfx_combat import n_of, fit, at, clicks, thump, inst  # noqa: E402

c.TARGET["interface"] = -20.0


def ui_move(rng):
    n = n_of(0.08)
    return clicks([0.0], n, rng.uniform(1700, 1900), rng, ratios=(1.0, 2.6, 4.1), t60=0.008, amp=0.8)


def ui_confirm(rng):
    n = n_of(0.5)
    latch = clicks([0.0, 0.025], n, 2600, rng, ratios=(1.0, 2.7, 5.2), t60=0.015, amp=0.7)
    return latch + at(np.zeros(n), fit(inst("glass", "E6", 0.5, 0.35, rng), n_of(0.45)), 0.02)


def ui_back(rng):
    n = n_of(0.45)
    latch = clicks([0.0], n, 1900, rng, ratios=(1.0, 2.7, 5.2), t60=0.012, amp=0.5)
    return latch + at(np.zeros(n), fit(inst("glass", "B5", 0.4, 0.25, rng), n_of(0.4)), 0.015)


def ui_open(rng):
    n = n_of(0.35)
    tt = secs(n)
    turn = bandpass(rng.normal(0, 1, n), 1500, 7000) * np.exp(-((tt - 0.09) / 0.05) ** 2) * 0.6
    settle = bandpass(rng.normal(0, 1, n), 600, 3000) * np.exp(-((tt - 0.2) / 0.03) ** 2) * 0.4
    return turn + settle


def ui_buy(rng):
    n = n_of(0.7)
    salt = clicks(np.sort(rng.uniform(0, 0.12, 6)), n, rng.uniform(3800, 4600), rng, ratios=(1.0, 2.3, 3.9), t60=0.04, amp=0.45)
    return salt + at(np.zeros(n), fit(inst("glass", "A6", 0.55, 0.4, rng), n_of(0.55)), 0.14)


def ui_refuse(rng):
    n = n_of(0.3)
    return clicks([0.0, 0.11], n, rng.uniform(380, 440), rng, ratios=(1.0, 2.4, 3.9), t60=0.03, amp=0.9) + \
        at(np.zeros(n), thump(n_of(0.15), 90, 0.03, rng) * 0.4, 0.0)


SOUNDS = [("ui_move", ui_move, 3), ("ui_confirm", ui_confirm, 2), ("ui_back", ui_back, 2), ("ui_open", ui_open, 2),
          ("ui_buy", ui_buy, 2), ("ui_refuse", ui_refuse, 1)]


def main():
    for name, fn, k in SOUNDS:
        c.variants(name, fn, "interface", k, seed=20)
    print("interface sounds written")


if __name__ == "__main__":
    main()
