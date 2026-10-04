"""Map Stage 06: the one-cell obstacles (the 'o' cells of a plan), drawn per look. Until now
every 'o' was the same grey square in every biome, which read as a placeholder block. Now a
rock cell is a boulder on the Flats, a heap of fallen masonry in the Streets, a cut block or a
column drum in the Hall, a crate or a bollard on the Harbour quays. Drawn as the set pieces are
(tools/gen_set_pieces.py): from the south and above, lit from the top, an Ink foot line, the
shadow hugging the foot. Each sprite is 16x24: the cell, and 8 px rising above it that room.gd
draws over anyone standing behind it.

    assets/sprites/obstacles.png    rows by Tiles.Look (flats, streets, hall, harbour, hub),
                                    three variants across, 16x24 each
    assets/reference/maps/obstacles_sheet.png   each over its floor at 4x

Run:  python tools/gen_obstacles.py
"""
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
from gen_set_pieces import Canvas, SPRITES, REF  # noqa: E402

W, H = 16, 24
RISE = 8  # px above the cell
LOOKS = ["flats", "streets", "hall", "harbour", "hub"]  # Tiles.Look order


def _shade(c, x0, x1, y_mid=20):
    c.shadow(x0, y_mid, x1, 23)


def _rock(c, cx, base, rx, ry, top, face, dark, seed):
    """A rounded rock: its outline wanders, lit top, face below, dark at the foot."""
    rnd = random.Random(seed)
    bumps = [rnd.uniform(-0.12, 0.12) for _ in range(8)]
    import math
    for y in range(base - 2 * ry, base + 1):
        for x in range(cx - rx - 1, cx + rx + 2):
            dx, dy = (x - cx) / rx, (y - (base - ry)) / ry
            a = math.atan2(dy, dx)
            r = 1.0 + bumps[int((a + math.pi) / (2 * math.pi) * 8) % 8]
            if dx * dx + dy * dy <= r * r and y <= base:
                rel = (y - (base - 2 * ry)) / (2 * ry)
                key = top if rel < 0.38 else (face if rel < 0.82 else dark)
                c.px(x, y, key)


def boulder(v):
    c = Canvas(W, H)
    if v == 0:
        _shade(c, 1, 15)
        _rock(c, 8, 21, 6, 6, "STONE_LIGHT", "STONE", "STONE_DARK", "b0")
        c.px(5, 11, "SALT_WHITE")
        c.px(10, 12, "SALT_WHITE")
    elif v == 1:
        _shade(c, 0, 15)
        _rock(c, 10, 21, 5, 5, "STONE_LIGHT", "STONE", "STONE_DARK", "b1a")
        _rock(c, 4, 21, 3, 3, "STONE", "STONE_DARK", "STONE_DARK", "b1b")
    else:
        _shade(c, 1, 15)
        _rock(c, 8, 21, 7, 4, "STONE_LIGHT", "STONE", "STONE_DARK", "b2")
        for x, y, k in [(4, 19, "BONE"), (6, 20, "BONE_DARK"), (11, 19, "KELP"), (12, 20, "KELP")]:
            c.px(x, y, k)
    c.foot(0, 15, 22)
    return c


def rubble(v):
    """Fallen masonry: cut blocks in a heap, moss in the joints."""
    c = Canvas(W, H)
    _shade(c, 0, 15)
    blocks = {
        0: [(1, 16, 7, 21), (8, 15, 14, 21), (4, 11, 11, 15)],
        1: [(2, 13, 13, 21), (5, 9, 10, 13)],
        2: [(1, 17, 6, 21), (7, 14, 14, 21), (9, 10, 13, 14)],
    }[v]
    for x0, y0, x1, y1 in blocks:
        c.rect(x0, y0, x1, y1, "STONE")
        c.rect(x0, y0, x1, y0 + 1, "STONE_LIGHT")
        c.rect(x0, y1 - 1, x1, y1, "SLATE")
        c.px(x1, y0 + 2, "SLATE")
    if v == 1:  # a column stump: rounded top, flutes
        for x in (4, 7, 10):
            c.line(x, 15, x, 20, "SLATE")
    for x, y in [(2, 16), (8, 15), (13, 20), (5, 21)][: 2 + v]:
        c.px(x, y, "MOSS")
    c.foot(0, 15, 22)
    return c


def masonry(v):
    """The Hall's: a cut basalt block, a column drum, a slab on end, a carved line on each."""
    c = Canvas(W, H)
    _shade(c, 0, 15)
    if v == 0:
        c.rect(1, 12, 14, 21, "BASALT")
        c.rect(1, 12, 14, 14, "BASALT_LIGHT")
        c.rect(1, 20, 14, 21, "BASALT_DARK")
        c.line(3, 17, 12, 17, "BASALT_DARK")
    elif v == 1:
        c.ellipse(1, 10, 14, 15, "BASALT_LIGHT")
        c.rect(1, 13, 14, 20, "BASALT")
        c.ellipse(1, 17, 14, 22, "BASALT")
        for x in (4, 8, 11):
            c.line(x, 15, x, 21, "BASALT_DARK")
        c.ellipse(5, 11, 10, 14, "BASALT")
    else:
        c.poly([(4, 4), (11, 6), (12, 21), (3, 21)], "BASALT")
        c.poly([(4, 4), (11, 6), (11, 8), (4, 6)], "BASALT_LIGHT")
        c.line(6, 10, 9, 16, "BASALT_DARK")
        c.px(7, 12, "IRON_LIGHT")
    c.foot(0, 15, 22)
    return c


def crate(v):
    """The quay's: a crate, two stacked, a bollard with a rope."""
    c = Canvas(W, H)
    _shade(c, 0, 15)
    if v in (0, 1):
        boxes = [(1, 11, 14, 21)] if v == 0 else [(1, 14, 14, 21), (3, 6, 12, 13)]
        for x0, y0, x1, y1 in boxes:
            c.rect(x0, y0, x1, y1, "WOOD")
            c.rect(x0, y0, x1, y0 + 2, "WOOD_LIGHT")
            for y in range(y0 + 4, y1, 3):
                c.line(x0, y, x1, y, "WEATHERED_BROWN")
            c.line(x0, y0 + 3, x1, y1, "TAR")
            c.rect(x0, y0, x0, y1, "TAR")
            c.rect(x1, y0, x1, y1, "TAR")
    else:
        c.rect(5, 10, 10, 21, "IRON")
        c.rect(4, 8, 11, 10, "IRON_LIGHT")
        c.rect(5, 19, 10, 21, "IRON_DARK")
        c.line(6, 11, 6, 18, "IRON_LIGHT")
        for x in range(4, 12):
            c.px(x, 14 + (x % 2), "ROPE")
        c.px(3, 15, "ROPE")
        c.px(12, 16, "RUST")
    c.foot(0, 15, 22)
    return c


def hub_rock(v):
    c = boulder(v)
    # Marrow Rock's own stone: warmer and lighter than the Flats'.
    swap = {P.rgba("STONE_LIGHT"): P.rgba("BONE"), P.rgba("STONE"): P.rgba("STONE_LIGHT"),
            P.rgba("STONE_DARK"): P.rgba("STONE")}
    for y in range(H):
        for x in range(W):
            p = c.im.getpixel((x, y))
            if p in swap:
                c.im.putpixel((x, y), swap[p])
    return c


DRAW = {"flats": boulder, "streets": rubble, "hall": masonry, "harbour": crate, "hub": hub_rock}
FLOOR = {"flats": "SAND", "streets": "STONE_DARK", "hall": "BASALT_DARK", "harbour": "WOOD", "hub": "SAND_LIGHT"}


def main():
    sheet = Image.new("RGBA", (W * 3, H * len(LOOKS)), (0, 0, 0, 0))
    for j, look in enumerate(LOOKS):
        for v in range(3):
            sheet.alpha_composite(DRAW[look](v).im, (v * W, j * H))
    sheet.save(os.path.join(SPRITES, "obstacles.png"))
    # Review: each over its look's floor, 4x.
    ref = Image.new("RGBA", (W * 3 + 8, H * len(LOOKS) + 2 * len(LOOKS)), P.rgba("NIGHT_1"))
    for j, look in enumerate(LOOKS):
        y = j * (H + 2)
        bg = Image.new("RGBA", (W * 3 + 8, H), P.rgba(FLOOR[look]))
        ref.alpha_composite(bg, (0, y))
        for v in range(3):
            ref.alpha_composite(sheet.crop((v * W, j * H, v * W + W, j * H + H)), (v * (W + 4), y))
    ref = ref.resize((ref.width * 4, ref.height * 4), Image.NEAREST)
    os.makedirs(REF, exist_ok=True)
    ref.save(os.path.join(REF, "obstacles_sheet.png"))
    print("obstacles.png: %d looks x 3" % len(LOOKS))


if __name__ == "__main__":
    main()
