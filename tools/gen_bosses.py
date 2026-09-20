"""Stage 08: the three bosses at native size (STYLE.md 19).  Node scale is 1 from here on.

    wreck.png   72x48 x 7 frames   a hull on its side walking on broken ribs
    bell.png    48x72 x 7 frames   the town bell in its iron frame, base flooded
    ebb.png     72x72 x 7 frames   a standing figure of still water holding a keeper's lantern

Frame layout matches the shipped bindings (idle 0-1, walk 2-3, windup 4, attack 5, hurt 6).
Big curved forms are rasterised from profiles (clean 1-2-3 stepping) and the details are
hand-placed grids; every colour is a palette key.  Outlines are full 1 px Ink.

Review: assets/reference/anchors/bosses_sheet.png and mock_bosses.png (each boss beside
its biome's enemies at 1x).

Run:  python tools/gen_bosses.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
import gen_anchors as GA  # noqa: E402
from gen_anchors import grid, zoom  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
REF = os.path.join(P.ROOT, "assets", "reference", "anchors")


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(im, x, y, key, a=255):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), P.rgb(key) + (a,))


def fill_profile(im, y0, y1, half_width, cx, colour):
    """Rows y0..y1: fill from cx-hw(y) to cx+hw(y) using colour(x, y, hw) -> key or None."""
    for y in range(y0, y1 + 1):
        hw = half_width(y)
        if hw is None or hw < 0:
            continue
        x0, x1 = int(round(cx - hw)), int(round(cx + hw))
        for x in range(x0, x1 + 1):
            k = colour(x, y, hw)
            if k:
                put(im, x, y, k)


def outline(im, key="INK"):
    """A 1 px Ink line around every opaque pixel that touches transparency (4-neighbour)."""
    src = im.copy()
    px = src.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] and px[nx, ny][:3] != P.rgb("INK"):
                    put(im, x, y, key)
                    break
    return im


def paste(im, part, x, y):
    im.alpha_composite(part, (x, y))
    return im


def shifted(im, dx, dy):
    out = canvas(im.width, im.height)
    out.alpha_composite(im, (dx, dy)) if dx >= 0 and dy >= 0 else out.alpha_composite(
        im.crop((max(0, -dx), max(0, -dy), im.width, im.height)), (max(0, dx), max(0, dy)))
    return out


# =============================================================================
# THE WRECK 72x48.  Bow to the right.  Feet (rib tips) on row 45.
# =============================================================================
W_W, W_H = 72, 48


def wreck_hull():
    im = canvas(W_W, W_H)

    def hw(y):
        return None

    # hull as top/bottom edges per column
    def edges(x):
        if x < 6 or x > 66:
            return None
        top, bot = 13, 36
        if x > 55:                       # bow taper
            t = (x - 55) / 11.0
            top = 13 + int(round(t * 9))
            bot = 36 - int(round(t * 8))
        if x < 12:                       # rounded stern
            t = (12 - x) / 6.0
            top = 13 + int(round(t * 3))
            bot = 36 - int(round(t * 2))
        return top, bot

    for x in range(W_W):
        e = edges(x)
        if not e:
            continue
        top, bot = e
        for y in range(top, bot + 1):
            if y <= top + 1:
                k = "WOOD_LIGHT"
            elif y >= bot - 4:
                k = "TAR"
            elif (y - top) % 5 == 4:
                k = "TAR"                # plank gap
            else:
                k = "WOOD"
            put(im, x, y, k)
    # the deck line is wet: a Salt white run on the lit top edge (max 6 px on bosses)
    for x in (30, 31, 32, 33, 34, 35):
        put(im, x, 13, "SALT_WHITE")
    # the broken side: a hole showing the ribs on a Night 1 interior
    for y in range(16, 29):
        for x in range(13, 30):
            nx, ny = (x - 21.5) / 8.5, (y - 22) / 6.0
            if nx * nx + ny * ny <= 1.0:
                put(im, x, y, "NIGHT_1")
                if x % 4 == 1:
                    put(im, x, y, "BONE")
                elif x % 4 == 2:
                    put(im, x, y, "BONE_DARK")
    for x in range(13, 30):               # a splintered edge in Tar
        for y in (15, 29):
            nx = (x - 21.5) / 8.5
            if abs(nx) < 0.95:
                put(im, x, y if y == 15 else 29, "TAR")
    # barnacle rings on the tarred lower hull
    for (bx, by) in ((36, 31), (44, 33), (52, 30), (24, 33)):
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            put(im, bx + dx, by + dy, "BONE_DARK")
        put(im, bx, by, "BONE")
    # rust on the iron strake
    for x in range(34, 60, 2):
        put(im, x, 25, "IRON_DARK")
        put(im, x + 1, 25, "IRON")
    for (rx, ry) in ((40, 26), (41, 26), (48, 26), (49, 26), (49, 27)):
        put(im, rx, ry, "RUST")
    return im


WRECK_MAST = grid("""
.......kk..
......kBBk.
.....kBBk..
....kBBk...
...kxxk....
...kxxk....
...kxxk....
...kxxk....
""")
WRECK_FIGUREHEAD = grid("""
.....kkkk.
....kwwwwk
...kwwwwwk
...kwwbwwk
...kFwwwFk
..k3FFFF3k
.k333333k.
.k333333k.
kk3333kk..
""")
WRECK_LANTERN = grid("""
..kIk..
.k%%%k.
.kePek.
.kPPPk.
.kePek.
.k%%%k.
..kkk..
""")
WRECK_CHAIN = grid("""
hk......
khk.....
.khk....
..khk...
...khk..
....khk.
.....khk
......kh
""")
WRECK_ROPE = grid("""
.rrr.
rrxrr
rrrrr
.rrr.
""")
LEGS_A = grid("""
kBvk......kBvk.......kBvk.......kBvk...
kBvk......kBvk.......kBvk.......kBvk...
kvvk.....kvvk.......kvvk.......kvvk....
.kvvk...kvvk.........kvvk.....kvvk.....
..kvvk.kvvk...........kvvk...kvvk......
...kvvkvvk.............kvvk.kvvk.......
....kvkkvk..............kvkkvk.........
....kvk.kvk.............kvk.kvk........
....kk...kk.............kk...kk........
""")
LEGS_B = grid("""
..kBvk....kBvk......kBvk.....kBvk......
..kBvk....kBvk......kBvk.....kBvk......
.kvvk......kvvk....kvvk.......kvvk.....
kvvk........kvvk..kvvk.........kvvk....
kvk..........kvk..kvk...........kvk....
kvk..........kvk..kvk...........kvk....
kvk..........kvk..kvk...........kvk....
kvk..........kvk..kvk...........kvk....
kk...........kk...kk............kk.....
""")
LEGS_SPLAY = grid("""
kBvk...........kBvk...kBvk...........kBvk
kvvk...........kvvk...kvvk...........kvvk
.kvvk.........kvvk.....kvvk.........kvvk.
..kvvk.......kvvk.......kvvk.......kvvk..
...kvvk.....kvvk.........kvvk.....kvvk...
....kvvk...kvvk...........kvvk...kvvk....
.....kvk...kvk.............kvk...kvk.....
.....kvk...kvk.............kvk...kvk.....
.....kk....kk...............kk...kk......
""")


def wreck_frame(hull_dy=0, hull_dx=0, legs=LEGS_A, lantern_dy=0, chain_dx=0):
    im = canvas(W_W, W_H)
    paste(im, legs, 14, 37)
    hull = wreck_hull()
    body = canvas(W_W, W_H)
    paste(body, hull, 0, 0)
    paste(body, WRECK_MAST, 26, 6)
    paste(body, WRECK_FIGUREHEAD, 56, 9)
    paste(body, WRECK_ROPE, 8, 17)
    paste(body, WRECK_CHAIN, 0, 30 + chain_dx)
    paste(body, WRECK_CHAIN.transpose(Image.FLIP_LEFT_RIGHT), 2, 22)
    outline(body)
    paste(im, shifted(body, hull_dx, hull_dy), 0, 0)
    paste(im, WRECK_LANTERN, 60 + hull_dx, 30 + hull_dy + lantern_dy)
    return im


def build_wreck():
    return [
        wreck_frame(),
        wreck_frame(hull_dy=1, lantern_dy=1),
        wreck_frame(legs=LEGS_B),
        wreck_frame(hull_dy=1, legs=LEGS_A, lantern_dy=1),
        wreck_frame(hull_dy=-4, hull_dx=-2, legs=LEGS_SPLAY, lantern_dy=-1),
        wreck_frame(hull_dy=3, hull_dx=1, legs=LEGS_SPLAY, lantern_dy=2),
        wreck_frame(hull_dx=-2, chain_dx=1),
    ]


# =============================================================================
# THE BELL OF SALTMERE 48x72.  Iron frame, wood beam, bronze bell, a drowned arm for a
# clapper, a stone base standing in water.  Feet on row 69.
# =============================================================================
B_W, B_H = 48, 72


def bell_body(rim=False):
    im = canvas(B_W, B_H)
    cx = 24

    def hw(y):
        if y < 0 or y > 40:
            return None
        t = y / 40.0
        w = 3 + 12 * (t ** 1.7)
        if y >= 37:
            w += (y - 36) * 0.8
        return w

    def col(x, y, w):
        if y >= 38:
            return "BRONZE_DARK"
        if x > cx + w * 0.45:
            return "BRONZE_DARK"
        if rim and y > 4 and x < cx - w * 0.55:
            return "BRONZE_LIGHT"
        return "BRONZE"

    fill_profile(im, 0, 40, hw, cx, col)
    # verdigris patches on the lower half, 2x2 or larger
    for (vx, vy, w, h) in ((13, 30, 3, 2), (19, 35, 2, 2), (32, 32, 2, 3), (26, 27, 2, 2), (16, 25, 2, 2)):
        for dy in range(h):
            for dx in range(w):
                put(im, vx + dx, vy + dy, "VERDIGRIS")
    # crown loop
    for x in range(22, 27):
        put(im, x, 0, "BRONZE_DARK")
    return im


BELL_CLAPPER = grid("""
.k33k.
.k33k.
.k33k.
.k33k.
.k33k.
.k33k.
.kFFk.
kFFFFk
kFFFFk
.kFFk.
..kk..
""")
BELL_POST = grid("""
khiIk
khiIk
""")


def bell_frame(bell_dx=0, bell_dy=0, rim=False, post_dy=(0, 0), water_shift=0, clapper_dx=0):
    im = canvas(B_W, B_H)
    # water at the base and the stone step
    for y in range(60, 70):
        for x in range(2, 46):
            put(im, x, y, "SEA")
    for x in range(2, 46):
        put(im, x, 60, "SALT_WHITE" if (x + water_shift) % 7 in (0, 1, 2) else "SEA")
    for y in range(62, 70):
        for x in range(12, 36):
            put(im, x, y, "STONE_DARK" if y >= 68 else ("STONE_LIGHT" if y == 62 else "STONE"))
    # frame: two posts and the beam
    for side, px_ in ((0, 4), (1, 39)):
        for y in range(4 + post_dy[side], 66 + post_dy[side]):
            for dx, k in ((0, "IRON_DARK"), (1, "IRON"), (2, "IRON"), (3, "IRON_LIGHT")):
                put(im, px_ + dx, y, k)
        for y in range(66, 70):
            for dx in range(-1, 6):
                put(im, px_ + dx, y, "IRON_DARK" if y > 67 else "IRON")
    for y in range(2, 8):
        for x in range(2, 46):
            put(im, x, y, "WOOD_LIGHT" if y == 2 else ("TAR" if y == 7 else "WOOD"))
    for x in (5, 6, 41, 42):
        put(im, x, 4, "IRON_LIGHT")
        put(im, x, 5, "IRON_LIGHT")
    # rust on the lower posts
    for (rx, ry) in ((5, 50), (6, 50), (5, 51), (40, 44), (41, 44), (41, 45), (40, 57), (41, 57)):
        put(im, rx, ry, "RUST")
    body = outline(im)
    # the bell itself, on its own layer so it swings over the frame
    bell = canvas(B_W, B_H)
    paste(bell, bell_body(rim), 0, 9)
    paste(bell, BELL_CLAPPER, 21 + clapper_dx, 44)
    outline(bell)
    paste(body, shifted(bell, bell_dx, bell_dy), 0, 0)
    return body


def build_bell():
    return [
        bell_frame(),
        bell_frame(bell_dx=1, clapper_dx=-1, water_shift=3),
        bell_frame(post_dy=(-1, 0)),
        bell_frame(post_dy=(0, -1), water_shift=3),
        bell_frame(bell_dx=-4, bell_dy=-2, clapper_dx=2),
        bell_frame(bell_dx=4, bell_dy=1, rim=True, clapper_dx=-3, water_shift=5),
        bell_frame(bell_dx=-1, bell_dy=1, post_dy=(1, 1)),
    ]


# =============================================================================
# THE EBB 72x72.  A standing figure of still water.  Drowned figures inside it.  It holds a
# keeper's lantern out to the right: the only warm thing on it.  Feet (the pool) on row 69.
# =============================================================================
E_W, E_H = 72, 72
DROWNED_SMALL = [grid("""
.FFF.
.FkF.
.FFF.
.333.
33333
.333.
.3.3.
"""), grid("""
.FFF.
FFkFF
.FFF.
.333.
.333.
33333
.3.3.
""")]
EBB_LANTERN = grid("""
...kIIk...
..kh%%hk..
.k%%%%%%k.
.kyaaaayk.
.kyacacyk.
.kyccccyk.
.kyacacyk.
.kyaaaayk.
.k%%%%%%k.
..kkkkkk..
""")


def ebb_frame(fig_dy=(0, 0, 0), arm_y=30, arm_x_end=58, lantern=(56, 26), swell=0, pool_shift=0, body_dx=0, flame=0, arc=False):
    im = canvas(E_W, E_H)
    cx = 34 + body_dx

    def hw(y):
        if y < 3:
            return None
        if y <= 20:                              # head: an oval
            t = (y - 11.5) / 8.5
            return 9.0 * math.sqrt(max(0.0, 1 - t * t)) + swell * 0.3
        if y <= 24:                              # neck
            return 6 + (y - 20) * 1.5 + swell * 0.5
        if y <= 60:                              # the robe widens
            t = (y - 24) / 36.0
            return 12 + 14 * t + swell
        return None

    def col(x, y, w):
        rel = (x - cx) / max(w, 1)
        if y <= 20 and abs(rel) < 0.7 and 7 <= y <= 18:
            return "ABYSS"                       # the face is an absence
        wob = (y // 4) % 2
        if y > 22 and abs(rel) > 0.4 and (x + wob) % 6 == 0 and y % 8 < 5:
            return "SHALLOW"                     # vertical wavering lines, the water's fall
        if abs(rel) < 0.35 and y > 24:
            return "SEA"
        return "DEEP_SEA"

    fill_profile(im, 3, 60, hw, cx, col)
    # eyes: two calm cold points, lowered
    put(im, cx - 3, 14, "SEA_PALE")
    put(im, cx + 3, 14, "SEA_PALE")
    # a wet rim on the crown and the shoulders
    for x in range(cx - 2, cx + 3):
        put(im, x, 3, "SALT_WHITE")
    for x in range(cx - 13, cx - 8):
        put(im, x, 26, "SALT_WHITE")
    # the cold core in the chest
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (-1, 0), (2, 0), (0, -1), (1, -1), (0, 2), (1, 2)):
        put(im, cx + dx, 30 + dy, "SEA_PALE")
    # the drowned inside, suspended
    for i, (fx, fy) in enumerate(((cx - 11, 34), (cx + 5, 40), (cx - 3, 49))):
        paste(im, DROWNED_SMALL[i % 2], fx, fy + fig_dy[i])
    # the arm reaching out with the lantern
    for x in range(cx + 8, arm_x_end):
        yy = arm_y + int(round((x - cx - 8) * (lantern[1] + 4 - arm_y) / max(1, arm_x_end - cx - 8)))
        for dy in range(4):
            put(im, x, yy + dy, "DEEP_SEA" if dy in (0, 3) else "SEA")
    # the pool: still water, a foam line, ripples
    for y in range(58, 70):
        t = (y - 63.5) / 6.5
        pw = 30 * math.sqrt(max(0.0, 1 - t * t))
        for x in range(int(cx - pw), int(cx + pw) + 1):
            put(im, x, y, "DEEP_SEA")
    for y in (61, 65):
        t = (y - 63.5) / 6.5
        pw = 30 * math.sqrt(max(0.0, 1 - t * t)) - 4
        for x in range(int(cx - pw), int(cx + pw) + 1):
            if (x + pool_shift) % 9 in (0, 1, 2, 3):
                put(im, x, y, "SHALLOW")
    for x in range(int(cx - 26), int(cx + 27)):
        if (x + pool_shift) % 5 != 4:
            put(im, x, 68, "SALT_WHITE")
    outline(im)
    lan = EBB_LANTERN
    if flame:
        lan = grid(EBB_LANTERN and """
...kIIk...
..kh%%hk..
.k%%%%%%k.
.kyaaaayk.
.kyaccayk.
.kyccccyk.
.kyaccayk.
.kyaaaayk.
.k%%%%%%k.
..kkkkkk..
""")
    paste(im, lan, lantern[0], lantern[1])
    if arc:
        for i, (ax, ay) in enumerate(((66, 22), (68, 26), (69, 31), (68, 36), (66, 40))):
            put(im, ax, ay, "SHALLOW")
            put(im, ax + 1, ay, "SEA_PALE")
            put(im, ax, ay + 1, "SHALLOW")
    return im


def build_ebb():
    return [
        ebb_frame(),
        ebb_frame(fig_dy=(1, -1, 1), pool_shift=3, flame=1),
        ebb_frame(fig_dy=(0, 1, -1), pool_shift=5, body_dx=1),
        ebb_frame(fig_dy=(-1, 0, 1), pool_shift=7, body_dx=-1, flame=1),
        ebb_frame(arm_y=26, arm_x_end=56, lantern=(52, 8), swell=2, fig_dy=(-2, -2, -2), pool_shift=2),
        ebb_frame(arm_y=30, arm_x_end=62, lantern=(60, 26), swell=1, arc=True, pool_shift=4, flame=1),
        ebb_frame(body_dx=-2, fig_dy=(2, 2, 2), pool_shift=6),
    ]


def strip(frames, w, h):
    im = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.alpha_composite(f, (i * w, 0))
    return im


def main():
    os.makedirs(REF, exist_ok=True)
    bosses = {"wreck": (build_wreck(), W_W, W_H), "bell": (build_bell(), B_W, B_H), "ebb": (build_ebb(), E_W, E_H)}
    for name, (frames, w, h) in bosses.items():
        strip(frames, w, h).save(os.path.join(SPRITES, name + ".png"))

    try:
        font = ImageFont.load_default(size=11)
        small = ImageFont.load_default(size=9)
    except TypeError:
        font = small = ImageFont.load_default()
    labels = ["idle", "idle", "walk", "walk", "windup", "attack", "hurt"]
    floors = {"wreck": "SAND", "bell": "STONE", "ebb": "BASALT"}
    Z = 3
    W = 12 + 7 * (72 * Z + 6) + 12
    sheet = Image.new("RGBA", (W, 12 + (48 + 72 + 72) * Z + 3 * 40), (30, 33, 42, 255))
    d = ImageDraw.Draw(sheet)
    y = 8
    for name, (frames, w, h) in bosses.items():
        d.text((12, y), "%s  %dx%d" % (name, w, h), fill=P.rgb("SALT_WHITE"), font=font)
        y += 14
        for i, f in enumerate(frames):
            bg = Image.new("RGBA", (w, h), P.rgba(floors[name]))
            bg.alpha_composite(f)
            sheet.alpha_composite(zoom(bg, Z), (12 + i * (72 * Z + 6), y))
            d.text((12 + i * (72 * Z + 6), y + h * Z + 2), "%d %s" % (i, labels[i]), fill=P.rgb("PALE_SLATE"), font=small)
        y += h * Z + 24
    sheet = sheet.crop((0, 0, W, y))
    sheet.convert("RGB").save(os.path.join(REF, "bosses_sheet.png"))

    # each boss beside its biome's enemies at 1x, in the Flats mock room (mass check)
    A = GA.build_assets()
    for name in ("shellback", "still_citizen", "keeper_shade", "anchor", "bell_ringer", "wrack_crab"):
        A[name] = Image.open(os.path.join(SPRITES, name + ".png")).crop((0, 0, 24, 24))
    A["wreck"], A["bell"], A["ebb"] = (bosses[k][0][0] for k in ("wreck", "bell", "ebb"))
    ents = [("tam", 296, 200, 14), ("wreck", 380, 60, 44), ("shellback", 350, 120, 20), ("wrack_crab", 470, 130, 18),
            ("bell", 120, 60, 30), ("still_citizen", 90, 150, 12), ("bell_ringer", 180, 150, 14),
            ("ebb", 200, 230, 44), ("keeper_shade", 300, 290, 14), ("anchor", 130, 300, 12)]
    mock = GA.compose_mock(A, ents=ents)
    mock.save(os.path.join(REF, "mock_bosses.png"))
    zoom(mock, 2).save(os.path.join(REF, "mock_bosses_2x.png"))
    print("wrote wreck.png, bell.png, ebb.png, bosses_sheet.png, mock_bosses.png")


if __name__ == "__main__":
    main()
