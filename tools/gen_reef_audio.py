"""Map Stage 11l: the Reef's music and ambience, rendered on their own so no other sound in
assets/audio is remade (tools/gen_audio.py rebuilds everything).

- music_reef.wav: the track tools/gen_music.py lists as "music_reef", with the seed its place in
  that table gives it (100 + index), exactly as gen_music.build_music would render it.
- amb_reef.wav: 24 s laid under ambient_sea, like the other places': water running in the
  channels (a band of noise that swells and drains, never still), the dry clicking of living
  coral (snapping shrimp: tiny bright clicks, in bursts), and the sea against the outside of the
  wall (a low surge every few seconds, from the left, then the right).

Run:  python tools/gen_reef_audio.py
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_audio import SR, save, t, env, noise, lowpass, bandpass, highpass, loopable  # noqa: E402
import gen_music  # noqa: E402


def music():
    names = list(gen_music.TRACKS)
    i = names.index("music_reef")
    gen_music.make_track("music_reef", *gen_music.TRACKS["music_reef"], seed=100 + i)


def ambience():
    dur = 24.0
    n = int(SR * dur)
    tt = t(dur)
    rng = np.random.default_rng(83)
    # water running in the channels: it swells and drains, it never stops
    run = bandpass(noise(n), 400, 2200, 2)
    x = 0.32 * run * (0.55 + 0.25 * np.sin(2 * np.pi * 0.083 * tt) + 0.15 * np.sin(2 * np.pi * 0.031 * tt + 1.0))
    x += 0.12 * lowpass(noise(n), 160, 2) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.05 * tt))
    # the coral clicking: bursts of tiny bright clicks
    for b in range(9):
        b0 = rng.uniform(0.3, dur - 2.0)
        for k in range(int(rng.integers(6, 16))):
            s0 = int(SR * (b0 + rng.uniform(0.0, 1.4)))
            ln = int(SR * 0.012)
            if s0 + ln >= n:
                continue
            click = highpass(noise(ln), 3500, 2) * env(ln, 0.0005, 0.008)
            x[s0:s0 + ln] += click * rng.uniform(0.15, 0.4)
    # the sea against the outside of the wall: a low surge, now left of you, now right
    for i in range(5):
        s0 = int(SR * (1.0 + i * 4.6 + rng.uniform(-0.4, 0.4)))
        ln = int(SR * 3.0)
        if s0 + ln >= n:
            continue
        seg = lowpass(noise(ln), 500, 2) * env(ln, 0.9, 1.6, 0.2, 0.5)
        seg += 0.4 * np.sin(2 * np.pi * 52 * (np.arange(ln) / SR)) * env(ln, 0.6, 1.8, 0.1, 0.4)
        x[s0:s0 + ln] += seg * 0.45
    save("amb_reef", loopable(x, 1.5), 0.3)


def main():
    music()
    ambience()
    print("wrote music_reef.wav, amb_reef.wav")


if __name__ == "__main__":
    main()
