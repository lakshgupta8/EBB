"""The drowned crown rim (STYLE.md 18, art Stage 20).

Tam carries a Salt white wet rim on the hood crown; the drowned humans drawn in Stages 07
and 19 did not, and in the Deep Hall a still citizen outside the lantern measured 1.4:1
against the basalt. The one pixel of Salt white under the outline along the crown is what
a wet head does under a cold sky, and it is the cheapest thing that reads at 1x.

`crown(frames)` paints it on frames 0-12 of a 16-frame strip (never on the death frames,
where the body lies down). The crown is the first row from the top whose widest run of
topmost pixels is at least 4 wide, so a raised arm or a pole above the head (1-3 px) is
skipped and the hood under it is found. Both enemy generators call this before they cut
the elite costumes, so the elites inherit it.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402

INK = P.rgb("INK")
SALT = P.rgb("SALT_WHITE") + (255,)

# Everyone who was a person. The Shade is a shade, the sinker is a helmet, the rest are
# animals or lights.
DROWNED = ("still_citizen", "lamplighter", "bell_ringer", "swimmer", "mooring", "deckhand", "netted", "choir")


def _crown_row(px, w, h):
    """The row of the crown and its columns, or (None, [])."""
    tops = {}
    for x in range(w):
        for y in range(h):
            if px[x, y][3] > 0:
                tops[x] = y
                break
    if not tops:
        return None, []
    top = min(tops.values())
    for r in range(top, top + 9):
        cols = sorted(x for x, y in tops.items() if y == r)
        best = []
        run = []
        for x in cols:
            if run and x != run[-1] + 1:
                if len(run) > len(best):
                    best = run
                run = []
            run.append(x)
        if len(run) > len(best):
            best = run
        if len(best) >= 4:
            return r, best
    return None, []


def crown(frames, upto=13):
    for i, im in enumerate(frames[:upto]):
        px = im.load()
        r, cols = _crown_row(px, im.width, im.height)
        if r is None:
            continue
        for x in cols[1:-1]:
            if px[x, r][:3] == INK and r + 1 < im.height and px[x, r + 1][3] > 0 and px[x, r + 1][:3] != INK:
                px[x, r + 1] = SALT
    return frames
