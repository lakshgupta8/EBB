"""Map Stage 04: large ground decals.  Three per look, 32x32 cells, flat on the floor: low tier
(three or four colours, no outline, STYLE.md 8), so they read as ground, not as things.

    assets/sprites/ground_decals.png   rows by look (Tiles.Look order: flats, streets, deep,
                                       harbour, hub), three 32x32 cells each, anchored at centre
        flats / hub: half-buried ribs, a drag mark, a wrack line of kelp
        streets:     a drain grate, a cracked and sunken flag, a well cover
        deep:        the tide sigil inlaid in the floor, a slab broken in a star, a ring of
                     old candle wax
        harbour:     a hatch cover, a hawser coiled flat, a tar spill
        reef:        a sunken anchor, a sea fan fallen flat, a course of the sea wall sunk in the
                     rubble (map Stage 11b)
    assets/reference/maps/ground_decals_sheet.png   at 4x over each look's floor

Run:  python tools/gen_ground_decals.py
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
REF = os.path.join(P.ROOT, "assets", "reference", "maps")
C = 32
LOOKS = ["flats", "streets", "deep", "harbour", "hub", "reef"]


def new():
    return Image.new("RGBA", (C, C), (0, 0, 0, 0))


def px(im, x, y, key, a=255):
    if 0 <= x < C and 0 <= y < C:
        im.putpixel((int(x), int(y)), P.rgba(key, a))


def ribs():
    im = new()
    # A rib cage on its side, half sunk: the spine along the sand, ribs arching over it and
    # curving back down, longest in the middle.
    for x in range(3, 29):
        px(im, x, 23 + int(1.2 * math.sin(x / 4.0)), "BONE_DARK")
    for i, x0 in enumerate(range(5, 27, 5)):
        h = [7, 10, 12, 10, 7][i]
        w = 3
        for k in range(24):
            t = k / 23 * math.pi
            x = x0 + w * (1 - math.cos(t)) / 2
            y = 23 - h * math.sin(t)
            px(im, x, y, "BONE")
            px(im, x, y + 1, "BONE_DARK")
        px(im, x0 + w // 2, 23 - h - 1, "BONE_LIGHT")
        px(im, x0 + w, 24, "SAND_DARK")
    return im


def drag():
    im = new()
    # Two grooves dragged through the sand, a heap pushed up at the end.
    for t in range(60):
        x = 3 + t * 0.42
        y = 25 - 14 * (t / 60) ** 1.4
        for off in (0, 5):
            px(im, x, y + off * 0.6 - off, "SAND_DARK")
            px(im, x, y + off * 0.6 - off + 1, "BONE_DARK")
    for dx, dy in ((0, 0), (1, 0), (2, 0), (1, -1), (0, 1), (2, 1), (3, 0)):
        px(im, 27 + dx, 9 + dy, "SAND_LIGHT")
    return im


def wrack():
    im = new()
    rnd = random.Random("wrack")
    # A tide line of kelp, tangled and long, with shells caught in it.
    for x in range(1, 31):
        y = 16 + int(2 * math.sin(x / 4.0))
        for k in range(rnd.randint(1, 3)):
            px(im, x, y + k - 1, rnd.choice(["KELP", "KELP", "MOSS_DARK", "KELP_LIGHT"]))
        if rnd.random() < 0.15:
            px(im, x, y - 2, "BONE")
    return im


def grate():
    im = new()
    # A square drain in an iron frame, bars across it, the dark beneath.
    for y in range(8, 24):
        for x in range(8, 24):
            edge = x in (8, 23) or y in (8, 23)
            if edge:
                px(im, x, y, "IRON")
            elif x % 3 == 0:
                px(im, x, y, "IRON_DARK")
            else:
                px(im, x, y, "INK")
    for x in range(8, 24):
        px(im, x, 7, "STONE_LIGHT")
    for y in range(9, 23, 4):
        px(im, 22, y, "RUST")
    return im


def cracked():
    im = new()
    rnd = random.Random("cracked")
    # A flag sunk and broken, cracks running out from its corner.
    for y in range(10, 22):
        for x in range(9, 23):
            if (x + y) % 7 and rnd.random() < 0.9:
                px(im, x, y, "STONE_DARK")
    for _ in range(4):
        x, y = 16, 16
        a = rnd.uniform(0, 6.28)
        for k in range(12):
            x += math.cos(a)
            y += math.sin(a)
            a += rnd.uniform(-0.5, 0.5)
            px(im, x, y, "NIGHT_2")
    px(im, 12, 12, "MOSS")
    px(im, 13, 12, "MOSS_DARK")
    return im


def well():
    im = new()
    # A round iron cover set in the street, a ring of bolts.
    for y in range(C):
        for x in range(C):
            d = math.hypot(x - 15.5, y - 15.5)
            if d < 10.5:
                px(im, x, y, "IRON" if d < 9.5 else "IRON_DARK")
            if 6 < d < 7.2:
                px(im, x, y, "IRON_DARK")
    for k in range(8):
        a = k * math.pi / 4
        px(im, 15.5 + 8.2 * math.cos(a), 15.5 + 8.2 * math.sin(a), "IRON_LIGHT")
    px(im, 14, 15, "RUST")
    px(im, 15, 15, "RUST")
    return im


def sigil():
    im = new()
    # The tide sigil inlaid in the floor: a ring, a wave across it, worn.
    for y in range(C):
        for x in range(C):
            d = math.hypot(x - 15.5, y - 15.5)
            if 12.5 < d < 13.6 and (x * 3 + y) % 11:
                px(im, x, y, "IRON")
            if 9.5 < d < 10.4 and (x + y * 3) % 13:
                px(im, x, y, "BASALT_LIGHT")
    for x in range(6, 26):
        y = 15.5 + 3 * math.sin((x - 6) / 20 * 2 * math.pi)
        px(im, x, y, "IRON_LIGHT" if x % 5 else "IRON")
    return im


def star():
    im = new()
    rnd = random.Random("star")
    # A slab broken where something heavy fell, cracks in a star, chips around.
    for k in range(6):
        a = k * math.pi / 3 + rnd.uniform(-0.3, 0.3)
        x, y = 15.5, 15.5
        for s in range(rnd.randint(8, 13)):
            x += math.cos(a)
            y += math.sin(a)
            a += rnd.uniform(-0.3, 0.3)
            px(im, x, y, "BASALT_DARK")
    for _ in range(6):
        px(im, rnd.randint(10, 21), rnd.randint(10, 21), "BASALT_LIGHT")
    px(im, 15, 15, "INK")
    px(im, 16, 16, "INK")
    return im


def wax():
    im = new()
    rnd = random.Random("wax")
    # Where candles burned down for years: a ring of old wax, Bone in drips.
    for k in range(40):
        a = k / 40 * 2 * math.pi
        r = 9 + rnd.uniform(-1.2, 1.2)
        x, y = 15.5 + r * math.cos(a), 15.5 + r * 0.7 * math.sin(a)
        px(im, x, y, "BONE_DARK")
        if rnd.random() < 0.35:
            px(im, x + 1, y, "BONE")
    for _ in range(5):
        px(im, rnd.randint(8, 23), rnd.randint(11, 20), "BONE_DARK")
    return im


def hatch():
    im = new()
    # A cargo hatch: planks run across, an iron frame, a ring to lift it by.
    for y in range(7, 25):
        for x in range(5, 27):
            edge = x in (5, 26) or y in (7, 24)
            if edge:
                px(im, x, y, "IRON_DARK")
            elif (y - 8) % 4 == 3:
                px(im, x, y, "TAR")
            else:
                px(im, x, y, "WOOD_LIGHT" if (x + y * 7) % 13 else "WOOD")
    for dx, dy in ((0, 0), (1, 0), (-1, 1), (2, 1), (0, 2), (1, 2)):
        px(im, 15 + dx, 14 + dy, "IRON")
    return im


def hawser():
    im = new()
    # A heavy rope coiled flat on the deck, its end trailing off.
    for k in range(220):
        t = k / 220 * 3.2 * 2 * math.pi
        r = 2.5 + t * 0.55
        x, y = 15.5 + r * math.cos(t), 15.5 + r * 0.8 * math.sin(t)
        px(im, x, y, "ROPE" if k % 6 else "BRONZE_DARK")
    for x in range(26, 31):
        px(im, x, 17 + (x - 26) // 2, "ROPE")
    return im


def tar():
    im = new()
    rnd = random.Random("tar")
    # Spilled tar gone hard: an irregular pool, a few splashes, a dull edge.
    for y in range(C):
        for x in range(C):
            d = math.hypot((x - 15.5) / 1.3, y - 15.5) + 1.8 * math.sin(x * 0.7) * math.cos(y * 0.6)
            if d < 7.5:
                px(im, x, y, "TAR")
            elif d < 8.3:
                px(im, x, y, "IRON_DARK")
    for _ in range(5):
        px(im, rnd.randint(3, 28), rnd.randint(4, 27), "TAR")
    px(im, 13, 13, "IRON")
    return im


def anchor():
    """A ship's anchor lying on its side, half sunk, rust on iron, coral on the crown."""
    im = new()
    for y in range(6, 25):
        px(im, 16, y, "IRON")
        px(im, 17, y, "IRON_DARK")
    for x in range(12, 22):
        px(im, x, 8, "IRON")
    px(im, 16, 4, "IRON")
    px(im, 15, 5, "IRON")
    px(im, 17, 5, "IRON")
    for k in range(9):
        t = k / 8 * math.pi
        x = 16 + 8 * math.cos(t)
        y = 24 + 3 * math.sin(t)
        px(im, x, y, "IRON")
        px(im, x, y + 1, "RUST")
    for x, y in ((8, 23), (24, 23), (9, 22), (23, 22)):
        px(im, x, y, "IRON")
    for x, y in ((16, 25), (15, 26), (18, 26)):
        px(im, x, y, "DROWNED_SKIN")
    return im


def fan():
    """A sea fan broken off and lying flat: a stem, its lattice fanned out, bleached."""
    im = new()
    for y in range(16, 28):
        px(im, 16, y, "DROWNED_SKIN")
    rnd = random.Random("fan")
    for k in range(7):
        a = math.pi * (0.15 + 0.7 * k / 6)
        for r in range(3, 13):
            x = 16 - r * math.cos(a)
            y = 17 - r * math.sin(a)
            if rnd.random() < 0.85:
                px(im, x, y, "DROWNED_SKIN" if r % 3 else "PALE_SLATE")
    for r in (6, 10):
        for k in range(24):
            a = math.pi * (0.15 + 0.7 * k / 23)
            if k % 3:
                px(im, 16 - r * math.cos(a), 17 - r * math.sin(a), "PALE_SLATE")
    return im


def course():
    """Three blocks of the sea wall sunk level with the rubble, their joints grown over."""
    im = new()
    for i, (x0, w) in enumerate(((3, 8), (12, 8), (21, 8))):
        y0 = 13 + (1 if i == 1 else 0)
        for y in range(y0, y0 + 6):
            for x in range(x0, x0 + w):
                px(im, x, y, "STONE" if y > y0 else "STONE_DARK")
        for y in range(y0, y0 + 6):
            px(im, x0 + w, y, "BASALT")
        px(im, x0 + 2, y0 + 3, "DROWNED_SHADE")
    for x in (11, 20):
        px(im, x, 15, "DROWNED_SKIN")
        px(im, x, 16, "DROWNED_SKIN")
    return im


DECALS = {
    "flats": [ribs, drag, wrack],
    "hub": [ribs, drag, wrack],
    "streets": [grate, cracked, well],
    "deep": [sigil, star, wax],
    "harbour": [hatch, hawser, tar],
    "reef": [anchor, fan, course],
}
FLOOR = {"flats": "SAND", "hub": "SAND_LIGHT", "streets": "STONE", "deep": "BASALT", "harbour": "WOOD",
         "reef": "DROWNED_SHADE"}


def main():
    atlas = Image.new("RGBA", (C * 3, C * len(LOOKS)), (0, 0, 0, 0))
    sheet = Image.new("RGBA", (C * 3 * 4, C * len(LOOKS) * 4), P.rgba("INK"))
    for li, look in enumerate(LOOKS):
        for k, fn in enumerate(DECALS[look]):
            im = fn()
            atlas.alpha_composite(im, (k * C, li * C))
            bg = Image.new("RGBA", (C, C), P.rgba(FLOOR[look]))
            bg.alpha_composite(im)
            sheet.alpha_composite(bg.resize((C * 4, C * 4), Image.NEAREST), (k * C * 4, li * C * 4))
    atlas.save(os.path.join(SPRITES, "ground_decals.png"))
    os.makedirs(REF, exist_ok=True)
    sheet.save(os.path.join(REF, "ground_decals_sheet.png"))
    print("wrote ground_decals.png", atlas.size)


if __name__ == "__main__":
    main()
