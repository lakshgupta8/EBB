"""The drop shadows (STYLE.md 4, art Stage 22).

    assets/sprites/shadow.png   a strip of 48x8 cells, one Ink 45 % ellipse each

Every grounded entity carries one of these under its feet: Ink at 45 %, 60 % of the body's
width, 4 rows tall (6 for a boss). Before Stage 22 the one 14x6 blob was black at 27 % and
each scene stretched it by a non-integer scale (3.4 on the Wreck); now each scene picks a
cell by region and never scales. `WIDTHS` is the cell order; `cell_for(body_width, boss)`
picks the cell, and tools/patch_shadows.py (Stage 22) wrote the scenes from the sheets.

Run:  python tools/gen_shadow.py
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402

CELL_W, CELL_H = 48, 8
WIDTHS = [(8, 4), (10, 4), (12, 4), (14, 4), (24, 6), (28, 6), (36, 6), (40, 6)]
INK45 = P.rgb("INK") + (115,)


def cell_for(body_width, boss=False):
    """The cell whose width is nearest 60 % of the body, among the 4-row cells for an
    enemy and the 6-row cells for a boss."""
    want = body_width * 0.6
    choices = [i for i, (w, h) in enumerate(WIDTHS) if (h == 6) == boss]
    return min(choices, key=lambda i: abs(WIDTHS[i][0] - want))


def ellipse(w, h):
    im = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    px = im.load()
    cx, cy = CELL_W / 2.0, CELL_H / 2.0
    for y in range(CELL_H):
        for x in range(CELL_W):
            nx = (x + 0.5 - cx) / (w / 2.0)
            ny = (y + 0.5 - cy) / (h / 2.0)
            if nx * nx + ny * ny <= 1.0:
                px[x, y] = INK45
    return im


def main():
    strip = Image.new("RGBA", (CELL_W * len(WIDTHS), CELL_H), (0, 0, 0, 0))
    for i, (w, h) in enumerate(WIDTHS):
        strip.alpha_composite(ellipse(w, h), (i * CELL_W, 0))
    out = os.path.join(P.ROOT, "assets", "sprites", "shadow.png")
    strip.save(out)
    print("wrote shadow.png: %s" % ", ".join("%dx%d" % wh for wh in WIDTHS))


if __name__ == "__main__":
    main()
