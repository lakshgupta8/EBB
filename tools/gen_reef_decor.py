"""Map Stage 11c: the Reef's small decor, eight 16 px cells in a row as the other decor sheets.

    assets/sprites/decor5.png   shell, coral finger, urchin, starfish, sea grass, shards, a pot
                                sherd from the city, a crab's cast shell
                                (DecorRules.REEF gives each its rule, in this order)
    assets/reference/maps/s11c_reef_decor.png   at 6x over the Reef floor

Low tier (STYLE.md 8): three or four colours, no outline. The reef is dead and pale; the living
things (the starfish, the urchin, the sea grass) keep by the water, as the living coral does.

Run:  python tools/gen_reef_decor.py
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
REF = os.path.join(P.ROOT, "assets", "reference", "maps")
C = 16


def cell():
    return Image.new("RGBA", (C, C), (0, 0, 0, 0))


def put(im, pts, key):
    for x, y in pts:
        if 0 <= x < C and 0 <= y < C:
            im.putpixel((x, y), P.rgba(key))


def shell():
    im = cell()
    put(im, [(6, 9), (7, 8), (8, 8), (9, 9), (6, 10), (7, 10), (8, 10), (9, 10), (7, 9), (8, 9)], "DROWNED_SKIN")
    put(im, [(7, 11), (8, 11), (5, 10), (10, 10)], "PALE_SLATE")
    put(im, [(7, 7)], "SALT_WHITE")
    return im


def finger():
    im = cell()
    put(im, [(5, 11), (6, 10), (7, 9), (8, 9), (9, 8), (10, 7)], "DROWNED_SKIN")
    put(im, [(6, 11), (7, 10), (8, 10), (9, 9), (10, 8), (8, 8)], "OILSKIN_LIGHT")
    put(im, [(10, 6)], "SALT_WHITE")
    return im


def urchin():
    im = cell()
    put(im, [(7, 8), (8, 8), (7, 9), (8, 9)], "DEEP_VIOLET")
    put(im, [(6, 7), (9, 7), (6, 10), (9, 10), (5, 8), (10, 9), (7, 6), (8, 11), (4, 9), (11, 8)], "OILSKIN")
    put(im, [(7, 8)], "VIOLET_LIGHT")
    return im


def starfish():
    im = cell()
    put(im, [(7, 8), (8, 8), (7, 9), (8, 9), (7, 6), (7, 7), (10, 8), (9, 8), (5, 9), (6, 9),
             (6, 11), (6, 10), (9, 11), (9, 10)], "AMBER_DEEP")
    put(im, [(7, 5), (11, 8), (4, 9), (5, 12), (10, 12)], "SALT_RED")
    return im


def grass():
    im = cell()
    for x0, h in ((5, 6), (7, 8), (9, 7), (11, 5)):
        for k in range(h):
            put(im, [(x0 + (1 if k > h // 2 else 0), 12 - k)], "KELP" if k % 2 else "KELP_LIGHT")
    return im


def shards():
    im = cell()
    put(im, [(4, 9), (5, 9), (9, 11), (11, 7), (12, 7), (7, 6)], "DROWNED_SKIN")
    put(im, [(5, 10), (10, 11), (12, 8)], "PALE_SLATE")
    return im


def sherd():
    """A piece of a Saltmere pot, glazed once, now crusted."""
    im = cell()
    put(im, [(5, 9), (6, 8), (7, 8), (8, 8), (9, 8), (10, 9), (6, 9), (7, 9), (8, 9), (9, 9)], "RUST")
    put(im, [(6, 10), (7, 10), (8, 10), (9, 10)], "RUST_LIGHT")
    put(im, [(8, 8), (5, 9)], "DROWNED_SKIN")
    return im


def crabshell():
    im = cell()
    put(im, [(6, 8), (7, 8), (8, 8), (9, 8), (6, 9), (7, 9), (8, 9), (9, 9), (7, 10), (8, 10)], "PALE_SLATE")
    put(im, [(5, 7), (10, 7), (4, 9), (11, 9), (5, 11), (10, 11)], "OILSKIN_LIGHT")
    put(im, [(7, 8)], "DROWNED_SKIN")
    return im


CELLS = [shell, finger, urchin, starfish, grass, shards, sherd, crabshell]


def main():
    atlas = Image.new("RGBA", (C * len(CELLS), C), (0, 0, 0, 0))
    for i, fn in enumerate(CELLS):
        atlas.alpha_composite(fn(), (i * C, 0))
    atlas.save(os.path.join(SPRITES, "decor5.png"))
    bg = Image.new("RGBA", atlas.size, P.rgba("DROWNED_SHADE"))
    bg.alpha_composite(atlas)
    os.makedirs(REF, exist_ok=True)
    bg.resize((atlas.width * 6, atlas.height * 6), Image.NEAREST).save(os.path.join(REF, "s11c_reef_decor.png"))
    print("wrote decor5.png", atlas.size)


if __name__ == "__main__":
    main()
