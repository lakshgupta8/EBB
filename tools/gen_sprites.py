"""Generates every placeholder-but-real sprite sheet under assets/sprites/.

Sprites are text grids composed from parts so animation frames stay consistent.
Run:  python tools/gen_sprites.py          (writes PNGs)
      python tools/gen_sprites.py --preview (also writes a zoomed contact sheet to .shots/sprites.png)
"""
import math
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites")
CELL = 24

PAL = {
    ".": None,
    "k": (24, 20, 37),      # outline
    "h": (58, 68, 88),      # hood
    "H": (84, 98, 120),     # hood light
    "c": (92, 78, 60),      # coat dark
    "C": (132, 112, 86),    # coat
    "f": (232, 196, 164),   # skin
    "F": (200, 150, 120),   # skin shade
    "e": (40, 32, 40),      # eye
    "b": (60, 48, 40),      # boots / belt
    "y": (250, 210, 90),    # lantern
    "Y": (255, 244, 200),   # lantern core
    "g": (120, 125, 135),   # metal
    "G": (190, 195, 205),   # metal light
    "w": (110, 78, 46),     # wood
    "W": (150, 110, 70),    # wood light
    # shellback
    "s": (86, 110, 84),     # shell
    "S": (122, 150, 110),   # shell light
    "t": (56, 74, 58),      # shell dark
    "m": (170, 140, 100),   # crab flesh
    "M": (210, 180, 130),   # flesh light
    "r": (220, 70, 60),     # angry red
    # gull
    "u": (236, 236, 228),   # feather white
    "U": (255, 255, 250),   # feather bright
    "v": (150, 150, 160),   # feather grey
    "o": (240, 170, 60),    # beak
    # fx
    "1": (255, 255, 255),
    "2": (255, 240, 190),
    "3": (255, 200, 120),
    "4": (255, 120, 90),
    "z": (0, 0, 0),
}


class Canvas:
    def __init__(self, w=CELL, h=CELL):
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    def blit(self, grid, x, y, flip=False):
        rows = [r for r in grid.strip("\n").split("\n")]
        for j, row in enumerate(rows):
            if flip:
                row = row[::-1]
            for i, ch in enumerate(row):
                col = PAL.get(ch)
                if col is None:
                    continue
                px, py = x + i, y + j
                if 0 <= px < self.im.width and 0 <= py < self.im.height:
                    self.im.putpixel((px, py), col + (255,))
        return self

    def px(self, x, y, ch, a=255):
        if 0 <= x < self.im.width and 0 <= y < self.im.height:
            self.im.putpixel((x, y), PAL[ch] + (a,))


def sheet(frames, name):
    im = Image.new("RGBA", (CELL * len(frames), CELL), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.alpha_composite(f.im, (i * CELL, 0))
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name))
    return im


# ----------------------------------------------------------------------------- player
HEAD = """
...kkkkkk...
..khhhhhhk..
.khhHHHHhhk.
.khHffffHhk.
.khfeffefhk.
.khFffffFhk.
..khFFFFhk..
...kkkkkk...
"""
TORSO = """
..kkkkkkkk..
.kCCCCCCCCk.
kCCcCCCCcCCk
kCCcCCCCcCCk
kfkcCCCCckfk
.kkbbbbbbkk.
"""
LEGS_IDLE = """
.kcckkcck.
.kcckkcck.
.kcckkcck.
.kbbkkbbk.
.kbbkkbbk.
.kkkkkkkk.
"""
LEGS_A = """
kcck..kcck
kcck..kcck
kbbk..kcck
kbbk..kbbk
kkkk..kbbk
......kkkk
"""
LEGS_B = """
..kcckcck.
..kcckcck.
..kbbkcck.
..kbbkbbk.
..kkkkbbk.
......kkk.
"""
LANTERN = """
.k.
kyk
kYk
kyk
.k.
"""


def player_frame(legs, bob=0, hurt=False, dash=False):
    c = Canvas()
    if dash:
        # stretched forward lean: body shifted, legs tucked
        c.blit(TORSO, 6, 9 - bob)
        c.blit(HEAD, 7, 1 - bob)
        c.blit(LEGS_IDLE, 7, 15 - bob)
        return c
    c.blit(legs, 7, 15)
    c.blit(TORSO, 6, 9 - bob)
    c.blit(HEAD, 6, 2 - bob)
    c.blit(LANTERN, 4, 13 - bob)
    if hurt:
        # eyes shut, tilt back
        c.blit("kk", 9, 6 - bob)
        c.blit("kk", 13, 6 - bob)
    return c


def build_player():
    frames = [
        player_frame(LEGS_IDLE, 0),          # 0 idle a
        player_frame(LEGS_IDLE, 1),          # 1 idle b (breathe)
        player_frame(LEGS_A, 0),             # 2 walk 1
        player_frame(LEGS_IDLE, 1),          # 3 walk 2
        player_frame(LEGS_B, 0),             # 4 walk 3
        player_frame(LEGS_IDLE, 1),          # 5 walk 4
        player_frame(LEGS_IDLE, 0, hurt=True),  # 6 hurt
        player_frame(LEGS_IDLE, 0, dash=True),  # 7 dash
    ]
    return sheet(frames, "player.png")


# ----------------------------------------------------------------------------- gaff hook (weapon, drawn pointing right, pivot at left)
GAFF = """
..........kk........
kkkkkkkkkkkGGk......
kwWwWwWwWwkGkGk.....
kkkkkkkkkkkGk.kk....
..........kGk.......
...........k........
"""


def build_gaff():
    c = Canvas(20, 6)
    c.blit(GAFF, 0, 0)
    os.makedirs(OUT, exist_ok=True)
    c.im.save(os.path.join(OUT, "gaff_hook.png"))
    return c.im


# ----------------------------------------------------------------------------- shellback
SHELL = """
.....kkkkkkkkkk.....
...kkSSSSSSSSSSkk...
..kSSSsssssssssSSk..
.kSSssssssssssssssk.
.ksssstsssssstsssssk
kssssttssssstts sssk
ksstttsssttssstttssk
kstttttsssssstttttsk
.ktttttttttttttttttk
..kkkkkkkkkkkkkkkkk.
"""
SHELL = SHELL.replace(" ", "s")
CRAB_HEAD = """
.kmmk.
kmeMek
kmMMmk
.kkkk.
"""
CRAB_HEAD_ANGRY = """
.kmmk.
kmrMrk
kmMMmk
.kkkk.
"""
LEGS_C1 = """
.kmk...kmk...kmk...kmk.
kmk.....kmk.kmk.....kmk
"""
LEGS_C2 = """
..kmk.kmk.....kmk.kmk..
.kmk...kmk...kmk...kmk.
"""


def shellback_frame(legs, dy=0, angry=False, slam=False):
    c = Canvas()
    c.blit(legs, 0, 19)
    c.blit(SHELL, 2, 7 + dy)
    c.blit(CRAB_HEAD_ANGRY if angry else CRAB_HEAD, 16, 13 + dy)
    if slam:
        for x in (1, 22):
            c.px(x, 20, "M"); c.px(x, 19, "M")
    return c


def build_shellback():
    frames = [
        shellback_frame(LEGS_C1, 0),        # 0 idle a
        shellback_frame(LEGS_C1, 1),        # 1 idle b
        shellback_frame(LEGS_C1, 0),        # 2 walk 1
        shellback_frame(LEGS_C2, 0),        # 3 walk 2
        shellback_frame(LEGS_C1, -3, angry=True),  # 4 windup (rear up)
        shellback_frame(LEGS_C2, 2, angry=True, slam=True),  # 5 slam
        shellback_frame(LEGS_C2, 0),        # 6 hurt
    ]
    return sheet(frames, "shellback.png")


# ----------------------------------------------------------------------------- gull (top-down, facing right)
GULL_BODY = """
....kkkkkk....
..kkuuuuuukk..
.kvvuuuuuuuuko
kvvvuuuuuuuekoo
.kvvuuuuuuuuko
..kkuuuuuukk..
....kkkkkk....
"""


def gull_wing(c, x, y, span, slant, up=True):
    """Draw a wing of `span` rows starting at (x,y) growing upward (up) or downward.
    Each row is narrower and shifted by `slant` px toward the tail as it extends."""
    for i in range(span):
        width = 10 - i * 2
        if width < 3:
            break
        dx = x - i * slant
        yy = y - i if up else y + i
        row = "k" + "u" * (width - 2) + "k"
        if i == span - 1 or width <= 4:
            row = "k" * width
        c.blit(row, dx, yy)
        if i > 0 and width > 4:
            c.px(dx + 1, yy, "v"); c.px(dx + 2, yy, "v")


def gull_frame(pose):
    c = Canvas()
    bx, by = 5, 9
    c.blit(GULL_BODY, bx, by)
    if pose == "spread":
        gull_wing(c, bx + 2, by - 1, 5, 0, up=True)
        gull_wing(c, bx + 2, by + 7, 5, 0, up=False)
    elif pose == "raised":
        gull_wing(c, bx + 2, by - 1, 3, 0, up=True)
        gull_wing(c, bx + 2, by + 7, 3, 0, up=False)
    elif pose == "back":
        gull_wing(c, bx + 2, by - 1, 5, 1, up=True)
        gull_wing(c, bx + 2, by + 7, 5, 1, up=False)
    elif pose == "dive":
        gull_wing(c, bx + 1, by - 1, 4, 2, up=True)
        gull_wing(c, bx + 1, by + 7, 4, 2, up=False)
    return c


def build_gull():
    frames = [
        gull_frame("spread"),  # 0 fly 1
        gull_frame("raised"),  # 1 fly 2
        gull_frame("back"),    # 2 fly 3
        gull_frame("raised"),  # 3 fly 4
        gull_frame("dive"),    # 4 dive
        gull_frame("back"),    # 5 hurt
    ]
    return sheet(frames, "gull.png")


# ----------------------------------------------------------------------------- fx
SLASH_CELL = 48
SLASH_R_IN = 17   # matches the gaff hitbox: circle r16 at 16px out => reach 0..32 from pivot
SLASH_R_OUT = 31


def slash_frame(t, size=SLASH_CELL):
    """Arc sweeping from -62deg to +62deg around the pivot (left-centre of the cell).
    t in [0,1] moves the bright head; the tail fades behind it."""
    c = Canvas(size, size)
    cx, cy = 4, size // 2
    a0, a1 = -62, 62
    head = a0 + (a1 - a0) * t
    for r in range(SLASH_R_IN, SLASH_R_OUT + 1):
        band = (r - SLASH_R_IN) / (SLASH_R_OUT - SLASH_R_IN)  # 0 inner .. 1 outer
        for deg in range(a0, a1 + 1):
            if deg > head:
                break
            age = (head - deg) / (a1 - a0)
            if age > 0.6:
                continue
            # thinner tail: inner rings drop out as the arc ages
            if band < age * 1.2:
                continue
            ch = "1" if age < 0.1 else "2" if age < 0.3 else "3"
            x = int(round(cx + r * math.cos(math.radians(deg))))
            y = int(round(cy + r * math.sin(math.radians(deg))))
            c.px(x, y, ch)
    return c


def build_slash():
    frames = [slash_frame(0.4), slash_frame(0.7), slash_frame(1.0), slash_frame(1.0)]
    # last frame: faded tail only
    im = Image.new("RGBA", (SLASH_CELL * len(frames), SLASH_CELL), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        fr = f.im
        if i == 3:
            fr = fr.copy()
            px = fr.load()
            for y in range(fr.height):
                for x in range(fr.width):
                    r_, g_, b_, a_ = px[x, y]
                    px[x, y] = (r_, g_, b_, a_ // 2)
        im.alpha_composite(fr, (i * SLASH_CELL, 0))
    im.save(os.path.join(OUT, "fx_slash.png"))
    return im


def spark_frame(i):
    c = Canvas(12, 12)
    cx = cy = 6
    if i == 0:
        for d in range(-2, 3):
            c.px(cx + d, cy, "1"); c.px(cx, cy + d, "1")
    elif i == 1:
        for d in (-4, -3, 3, 4):
            c.px(cx + d, cy, "2"); c.px(cx, cy + d, "2")
        for dx, dy in ((-2, -2), (2, 2), (-2, 2), (2, -2)):
            c.px(cx + dx, cy + dy, "1")
    else:
        for dx, dy in ((-5, 0), (5, 0), (0, -5), (0, 5), (-3, -3), (3, 3), (-3, 3), (3, -3)):
            c.px(cx + dx, cy + dy, "3")
    return c


def build_spark():
    im = Image.new("RGBA", (12 * 3, 12), (0, 0, 0, 0))
    for i in range(3):
        im.alpha_composite(spark_frame(i).im, (i * 12, 0))
    im.save(os.path.join(OUT, "fx_spark.png"))
    return im


def build_shadow():
    c = Canvas(14, 6)
    for y in range(6):
        for x in range(14):
            nx, ny = (x - 6.5) / 6.5, (y - 2.5) / 2.5
            if nx * nx + ny * ny <= 1.0:
                c.px(x, y, "z", 70)
    c.im.save(os.path.join(OUT, "shadow.png"))
    return c.im


def _noise_tile(im, ox, base, light, dark, seed, p_light=0.12, p_dark=0.04):
    import random
    random.seed(seed)
    for y in range(16):
        for x in range(16):
            r = random.random()
            c = light if r < p_light else dark if r < p_light + p_dark else base
            im.putpixel((ox + x, y), c + (255,))


TILE_NAMES = ["sand", "sand2", "wall", "wall2", "water", "water2", "deep", "low", "raised", "door", "door_open", "rock", "foam", "foam2"]


def build_tiles():
    """16px tile strip. Index order is TILE_NAMES; src/world/tiles.gd mirrors it."""
    import random
    n = len(TILE_NAMES)
    im = Image.new("RGBA", (16 * n, 16), (0, 0, 0, 0))
    # Cool, damp coastal palette: the night tint in-game pushes it bluer still.
    sand = (186, 172, 132); sand_l = (206, 194, 156); sand_d = (142, 128, 96)
    wall = (58, 64, 74); wall_l = (92, 102, 112); wall_d = (34, 38, 46); weed = (46, 78, 66); barn = (150, 158, 160)
    wat = (60, 100, 130); wat_l = (90, 150, 180); deep = (32, 54, 84); deep_l = (52, 84, 116)
    low = (138, 128, 104); low_l = (158, 150, 122); low_d = (104, 92, 72)
    rai = (128, 128, 124); rai_l = (160, 160, 154); rai_d = (86, 86, 82)
    foam = (225, 235, 240)
    # 0,1 sand
    _noise_tile(im, 0, sand, sand_l, sand_d, 0)
    _noise_tile(im, 16, sand, sand_l, sand_d, 1)
    # 2,3 wall: wet rock, cracks, barnacles and weed
    for v in range(2):
        random.seed(10 + v)
        for y in range(16):
            for x in range(16):
                c = wall
                r = random.random()
                if (x * 3 + y * 5 + v * 7) % 11 == 0 or (x + y * 2) % 13 == 0:
                    c = wall_d
                elif r < 0.05:
                    c = barn
                elif r < 0.12:
                    c = wall_l
                elif r < 0.17 and y > 8:
                    c = weed
                im.putpixel((32 + v * 16 + x, y), c + (255,))
    # 4,5 water (two phases of a ripple)
    for v in range(2):
        for y in range(16):
            for x in range(16):
                c = wat_l if ((x + y // 2 + v * 3) % 7 == 0) else wat
                im.putpixel((64 + v * 16 + x, y), c + (255,))
    # 6 deep water
    for y in range(16):
        for x in range(16):
            c = deep_l if ((x + y // 2) % 9 == 0) else deep
            im.putpixel((96 + x, y), c + (255,))
    # 7 low ground (wet, darker)
    _noise_tile(im, 112, low, low_l, low_d, 3, 0.1, 0.1)
    # 8 raised stone (flagstones)
    random.seed(20)
    for y in range(16):
        for x in range(16):
            c = rai
            if y % 8 == 7 or x % 8 == 7:
                c = rai_d
            elif random.random() < 0.1:
                c = rai_l
            im.putpixel((128 + x, y), c + (255,))
    # 9 door closed (dark arch with bars), 10 door open (dark arch, glow)
    for v in range(2):
        ox = 144 + v * 16
        for y in range(16):
            for x in range(16):
                c = wall_d
                inside = 2 <= x <= 13 and y >= 3
                if inside:
                    c = (18, 16, 28) if v == 0 else (34, 48, 70)
                    if v == 0 and x % 4 == 2:
                        c = (90, 80, 70)
                    if v == 1 and y > 10 and (x + y) % 3 == 0:
                        c = (70, 110, 140)
                if y < 3 or x < 2 or x > 13:
                    c = wall if (x + y) % 5 else wall_l
                im.putpixel((ox + x, y), c + (255,))
    # 12,13 foam: water with white specks along the edges (shoreline), two phases
    for v in range(2):
        random.seed(30 + v)
        ox = 192 + v * 16
        for y in range(16):
            for x in range(16):
                c = wat_l if ((x + y // 2 + v * 3) % 7 == 0) else wat
                edge = x == 0 or y == 0 or x == 15 or y == 15
                near = x <= 1 or y <= 1 or x >= 14 or y >= 14
                if (edge and random.random() < 0.55) or (near and random.random() < 0.18):
                    c = foam
                im.putpixel((ox + x, y), c + (255,))
    # 11 rock prop (drawn over sand)
    _noise_tile(im, 176, sand, sand_l, sand_d, 5)
    rock = (110, 105, 100); rock_l = (150, 145, 140); rock_k = (24, 20, 37)
    for y in range(4, 14):
        for x in range(3, 13):
            nx, ny = (x - 7.5) / 5.0, (y - 9) / 4.5
            d = nx * nx + ny * ny
            if d <= 1.0:
                c = rock_k if d > 0.75 else rock_l if (y < 8 and x < 8) else rock
                im.putpixel((176 + x, y), c + (255,))
    im.save(os.path.join(OUT, "tiles.png"))
    return im


ICONS = {
    "combat": """
k.........k.
.k.......k..
..k.....k...
...k...k....
....k.k.....
.....k......
....k.k.....
...k...k....
..kGk.kGk...
.kG.....Gk..
k.........k.
............
""",
    "elite": """
...kkkkkk...
..kuuuuuuk..
.kuuuuuuuuk.
.kukkuuukkuk
.kukkuuukkuk
.kuuuukuuuuk
..kuuuuuuk..
...kkkkkk...
...kukuku...
...kkkkkk...
............
............
""",
    "fountain": """
.....kk.....
....kBBk....
....kBBk....
...kBBBBk...
...kBUBBk...
..kBUBBBBk..
..kBBBBBBk..
..kBBBBBBk..
...kBBBBk...
....kkkk....
............
............
""",
    "treasure": """
............
..kkkkkkkk..
.kWWWWWWWWk.
.kwwwwwwwwk.
.kkkkkkkkkk.
.kwwwkykwwk.
.kwwwkkkwwk.
.kwwwwwwwwk.
.kwwwwwwwwk.
..kkkkkkkk..
............
............
""",
    "boss": """
.....kk.....
....kGGk....
....kGGk....
.....kk.....
..kkkkkkkk..
.....kk.....
.....kk.....
.k...kk...k.
.kk..kk..kk.
..kkkkkkkk..
....kkkk....
............
""",
}
ICON_ORDER = ["combat", "elite", "fountain", "treasure", "boss", "shop", "altar"]
PAL["B"] = (90, 150, 180)

# 24x24 hanging signboards: same outline/palette rules as every other sprite.
SIGN_BOARD = """
........................
..........k..k..........
..........k..k..........
.kkkkkkkkkkkkkkkkkkkkkk.
kWwwwwwwwwwwwwwwwwwwwwWk
kwwwwwwwwwwwwwwwwwwwwwwk
kwwwwwwwwwwwwwwwwwwwwwwk
kwwwwwwwwwwwwwwwwwwwwwwk
kwwwwwwwwwwwwwwwwwwwwwwk
kwwwwwwwwwwwwwwwwwwwwwwk
kwwwwwwwwwwwwwwwwwwwwwwk
kwwwwwwwwwwwwwwwwwwwwwwk
kwwwwwwwwwwwwwwwwwwwwwwk
kwwwwwwwwwwwwwwwwwwwwwwk
kwwwwwwwwwwwwwwwwwwwwwwk
kwwwwwwwwwwwwwwwwwwwwwwk
kwwwwwwwwwwwwwwwwwwwwwwk
kwwwwwwwwwwwwwwwwwwwwwwk
kwwwwwwwwwwwwwwwwwwwwwwk
kWwwwwwwwwwwwwwwwwwwwwWk
.kkkkkkkkkkkkkkkkkkkkkk.
........................
........................
........................
"""
SIGN_SYMBOLS = {
    # crossed gaff hooks
    "combat": """
................
.kk..........kk.
kGGk........kGGk
kGkGk......kGkGk
.kkkwk....kwkkk.
....kwk..kwk....
.....kwkkwk.....
......kwwk......
......kwwk......
.....kwkkwk.....
....kwk..kwk....
...kwk....kwk...
..kwk......kwk..
..kk........kk..
................
................
""",
    # skull, red eyes
    "elite": """
................
.....kkkkkk.....
....kuuuuuuk....
...kuuuuuuuuk...
...kukkuukkuk...
...kkrkkuukrkk..
...kukkuukkuk...
...kuuuukuuuuk..
....kuuuuuuk....
.....kkkkkk.....
.....kukuku.....
.....kkkkkk.....
................
................
................
................
""",
    # stone basin with a drop
    "fountain": """
................
.......kk.......
......kBBk......
......kBUk......
.....kBBBBk.....
.....kBBUBk.....
......kBBk......
.......kk.......
..kkkkkkkkkkkk..
.kGqqqqqqqqqqGk.
.kGBBBBBBBBBBGk.
..kGGGGGGGGGGk..
...kkkkkkkkkk...
....kgggggg.....
....kkkkkkkk....
................
""",
    # chest with a pearl
    "treasure": """
................
................
...kkkkkkkkkk...
..kWWWWWWWWWWk..
..kwwwwwwwwwwk..
..kkkkkkkkkkkk..
..kwwwwkUukwwk..
..kwwwwkuvkwwk..
..kwwwwkkkkwwk..
..kwwwwwwwwwwk..
..kwwwwwwwwwwk..
..kkkkkkkkkkkk..
................
................
................
................
""",
    # pearl on a pedestal, rays
    "altar": """
................
.......k........
......kUk.......
...k.kUuvk.k....
....kkuvvkk.....
......kkk.......
...k.......k....
....kkkkkkk.....
....kAAAAAk.....
.....kaaak......
.....kaaak......
....kAAAAAk.....
....kaaaaak.....
....kkkkkkk.....
................
................
""",
    # salt crystals on a scale pan
    "shop": """
................
.......k........
......kYk.......
.....kYyyk......
....kYyyyyk.....
....kyyyyyk.....
.....kyyyk......
......kkk.......
..k..........k..
..kk........kk..
...kkkkkkkkkk...
..kGggggggggGk..
...kkkkkkkkkk...
......kggk......
......kkkk......
................
""",
    # broken ship: hull + snapped mast
    "boss": """
........k.......
........kk......
........kuk.....
........kuuk....
........kuuuk...
........kkkkk...
........k.......
....k...k...k...
....kk..k..kk...
.kkkkkkkkkkkkkkk
.kwwwwwwwwwwwwwk
..kwwwwwwwwwwwk.
...kwwwwwwwwwk..
....kkkkkkkkk...
................
................
""",
}


def build_icons():
    im = Image.new("RGBA", (24 * len(ICON_ORDER), 24), (0, 0, 0, 0))
    for i, name in enumerate(ICON_ORDER):
        c = Canvas(24, 24)
        c.blit(SIGN_BOARD, 0, 0)
        c.blit(SIGN_SYMBOLS[name], 4, 4)
        im.alpha_composite(c.im, (i * 24, 0))
    im.save(os.path.join(OUT, "icons.png"))
    return im


PICKUPS = {
    "salt": """
...k....
..kYk...
.kYyyk..
kYyyyyk.
kyyyyyk.
.kyyyk..
..kkk...
........
""",
    "pearl": """
........
..kkkk..
.kUuuvk.
kUuuuvvk
kuuuvvvk
.kuvvvk.
..kkkk..
........
""",
}


def build_pickups():
    names = ["salt", "pearl"]
    im = Image.new("RGBA", (8 * len(names), 8), (0, 0, 0, 0))
    for i, n in enumerate(names):
        c = Canvas(8, 8)
        c.blit(PICKUPS[n], 0, 0)
        im.alpha_composite(c.im, (i * 8, 0))
    im.save(os.path.join(OUT, "pickups.png"))
    return im


PROPS = {
    "fountain": """
....kkkkkkkk....
...kGGGGGGGGk...
..kGBBBBBBBBGk..
..kGBBUBBBBBGk..
..kGBBBBBBBBGk..
...kGGGGGGGGk...
....kkkkkkkk....
......kggk......
......kggk......
....kkkggkkk....
...kgggggggg k..
...kggggggggk...
..kkkkkkkkkkkk..
................
................
................
""".replace(" k", "kk"),
    "chest": """
................
................
...kkkkkkkkkk...
..kWWWWWWWWWWk..
..kwwwwwwwwwwk..
..kkkkkkkkkkkk..
..kwwwwkyywwwk..
..kwwwwkkkwwwk..
..kwwwwwwwwwwk..
..kwwwwwwwwwwk..
..kkkkkkkkkkkk..
................
................
................
................
................
""",
    "chest_open": """
..kkkkkkkkkkkk..
..kWWWWWWWWWWk..
..kwwwwwwwwwwk..
..kkkkkkkkkkkk..
..kUUuUuUUuUUk..
..kkkkkkkkkkkk..
..kwwwwwwwwwwk..
..kwwwwwwwwwwk..
..kwwwwwwwwwwk..
..kwwwwwwwwwwk..
..kkkkkkkkkkkk..
................
................
................
................
................
""",
    "lighthouse": """
......kkkk......
.....kyYYyk.....
.....kYYYYk.....
.....kkkkkk.....
....kuuuuuuk....
....kuuuuuuk....
....krrrrrrk....
....krrrrrrk....
....kuuuuuuk....
....kuuuuuuk....
...krrrrrrrrk...
...krrrrrrrrk...
...kuuuuuuuuk...
...kuuukkuuuk...
..kkkkkkkkkkkk..
................
""",
}
PROPS["merchant"] = """
......kkkk......
.....kBBBBk.....
....kBBqqBBk....
....kBqeeqBk....
....kBqqqqBk....
.....kBBBBk.....
....kBBBBBBk....
...kBBqBBqBBk...
..kBBBqBBqBBBk..
..kyBBBBBBBBBk..
..kYkBBBBBBBBk..
..kykBBBBBBBBk..
...kkBBBBBBBk...
....kBBBBBBk....
....kkkkkkkk....
................
"""
PAL["a"] = (150, 145, 135)  # altar stone
PAL["A"] = (185, 180, 170)
PROPS["altar"] = """
................
.......kk.......
......kUuk......
......kuvk......
.......kk.......
....kkkkkkkk....
...kAAAAAAAAk...
...kaaaaaaaak...
....kkaaaakk....
.....kaaaak.....
.....kaaaak.....
....kkaaaakk....
...kAAAAAAAAk...
...kaaaaaaaak...
...kkkkkkkkkk...
................
"""
PAL["s"] = (120, 90, 110)   # Orla's shawl
PAL["S"] = (150, 120, 140)
PROPS["orla"] = """
.....kkkkk......
....kSSSSSk.....
...kSSuuuSSk....
...kSuffffSk....
...kSfeffeSk....
...kSFffffSk....
....kSFFFSk.....
...kSSSSSSSk....
..kSSsSSSsSSk...
..kSssSSSssSk...
..kSsssssssSk...
..kkssssssskk...
...kssssssk.....
...kbbkkbbk.....
...kkk..kkk.....
................
"""
PROP_ORDER = ["fountain", "chest", "chest_open", "lighthouse", "merchant", "altar", "orla"]


def build_props():
    im = Image.new("RGBA", (16 * len(PROP_ORDER), 16), (0, 0, 0, 0))
    for i, n in enumerate(PROP_ORDER):
        c = Canvas(16, 16)
        c.blit(PROPS[n], 0, 0)
        im.alpha_composite(c.im, (i * 16, 0))
    im.save(os.path.join(OUT, "props.png"))
    return im


# ----------------------------------------------------------------------------- doors (32x32, opening faces DOWN)
DOOR_CLOSED = """
.....kkkkkkkkkkkkkkkkkkkkkk.....
...kkGGGGGGGGGGGGGGGGGGGGGGkk...
..kGGggggggggggggggggggggggGGk..
.kGggkkkkkkkkkkkkkkkkkkkkkkggGk.
.kGgkzzzzzzzzzzzzzzzzzzzzzzkgGk.
.kGgkzzgzzzgzzzgzzzgzzzgzzzkgGk.
.kGgkzzgzzzgzzzgzzzgzzzgzzzkgGk.
.kGgkzzgzzzgzzzgzzzgzzzgzzzkgGk.
.kGgkzzgzzzgzzzgzzzgzzzgzzzkgGk.
.kGgkzzgzzzgzzzgzzzgzzzgzzzkgGk.
.kGgkzzgzzzgzzzgzzzgzzzgzzzkgGk.
.kGgkzzgzzzgzzzgzzzgzzzgzzzkgGk.
.kGgkzzgzzzgzzzgzzzgzzzgzzzkgGk.
.kGgkzzgzzzgzzzgzzzgzzzgzzzkgGk.
.kGgkzzgzzzgzzzgzzzgzzzgzzzkgGk.
.kGgkzzgzzzgzzzgzzzgzzzgzzzkgGk.
.kGgkzzgzzzgzzzgzzzgzzzgzzzkgGk.
.kGgkzzgzzzgzzzgzzzgzzzgzzzkgGk.
.kGgkzzzzzzzzzzzzzzzzzzzzzzkgGk.
.kGgkkkkkkkkkkkkkkkkkkkkkkkkgGk.
.kGggggggggggggggggggggggggggGk.
.kGGGGGGGGGGGGGGGGGGGGGGGGGGGGk.
.kkkkkkkkkkkkkkkkkkkkkkkkkkkkkk.
................................
................................
................................
................................
................................
................................
................................
................................
................................
"""
# Open: same frame, the opening is water-blue with a bright floor; no bars.
DOOR_OPEN = DOOR_CLOSED.replace("g", "b", 0)
DOOR_OPEN = "\n".join(
    (row.replace("z", "B").replace("g", "B") if 4 <= i <= 18 and "kzz" in row else row)
    for i, row in enumerate(DOOR_CLOSED.split("\n"))
)
DOOR_OPEN = "\n".join(
    (row[:4] + row[4:28].replace("B", "q") + row[28:]) if 15 <= i <= 18 else row
    for i, row in enumerate(DOOR_OPEN.split("\n"))
)
PAL["q"] = (140, 190, 215)   # bright water at the threshold
PAL["B"] = (60, 100, 130)    # doorway water


def build_door():
    im = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    for i, g in enumerate((DOOR_CLOSED, DOOR_OPEN)):
        c = Canvas(32, 32)
        c.blit(g, 0, 0)
        im.alpha_composite(c.im, (i * 32, 0))
    im.save(os.path.join(OUT, "door.png"))
    return im


def build_glow():
    """Soft radial glow, 48x48, white with alpha falloff. Tint with modulate."""
    size = 48
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx = cy = size / 2 - 0.5
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy) / (size / 2)
            if d < 1.0:
                a = int(255 * (1.0 - d) ** 2 * 0.9)
                im.putpixel((x, y), (255, 255, 255, a))
    im.save(os.path.join(OUT, "glow.png"))
    return im


# ----------------------------------------------------------------------------- decor (16x16 each, drawn over sand)
PAL["n"] = (90, 120, 80)     # kelp
PAL["N"] = (120, 160, 100)   # kelp light
PAL["p"] = (230, 220, 200)   # shell / bone
PAL["P"] = (255, 250, 240)
DECOR = {
    "shell": """
................
................
................
......kkk.......
.....kPpPk......
....kPpPpPk.....
....kpPpPpk.....
.....kkkkk......
................
................
................
................
................
................
................
................
""",
    "kelp": """
................
.......k........
......kNk.......
.....kNnk.k.....
.....knNk.kk....
......knk.kNk...
.......kk.knk...
....k..kNkknk...
...kNk.knkkNk...
...knkkkNkknk...
....kNknNkknk...
.....knnnnnk....
......kkkkk.....
................
................
................
""",
    "driftwood": """
................
................
................
................
..kk............
.kWwkkkkkkkkk...
kwWwWwWwWwWwwk..
kkwwwWwwwwWwwWk.
..kkkkkkkkkkkkk.
................
................
................
................
................
................
................
""",
    "pebbles": """
................
................
................
....kk..........
...kGgk.........
....kk....kk....
.........kGgk...
..kkk.....kk....
.kGggk..........
..kkk...........
................
................
................
................
................
................
""",
    "puddle": """
................
................
................
................
......BBBB......
....BBqqqqBB....
...BqqqqqqqqB...
...BqqqqqqqqB...
....BBqqqqBB....
......BBBB......
................
................
................
................
................
................
""",
    "bones": """
................
................
.....k..........
....kPk.........
....kpk.....kk..
....kPkkkkkkPpk.
.....kPpPpPpPk..
......kkkkkkk...
................
....k.....k.....
...kPk...kpk....
....kkkkkkk.....
................
................
................
................
""",
    "hole": """
................
................
................
................
................
......kkkk......
....kkzzzzkk....
...kzzzzzzzzk...
...kzzzzzzzzk...
....kkzzzzkk....
......kkkk......
................
................
................
................
................
""",
    "grass": """
................
................
................
................
......n.........
.....nNn..n.....
....nNnNn.Nn....
....nnNnnnNnn...
................
................
................
................
................
................
................
................
................
""",
}
DECOR_ORDER = ["shell", "kelp", "driftwood", "pebbles", "puddle", "bones", "hole", "grass"]


def build_decor():
    im = Image.new("RGBA", (16 * len(DECOR_ORDER), 16), (0, 0, 0, 0))
    for i, n in enumerate(DECOR_ORDER):
        c = Canvas(16, 16)
        c.blit(DECOR[n], 0, 0)
        im.alpha_composite(c.im, (i * 16, 0))
    im.save(os.path.join(OUT, "decor.png"))
    return im


# ----------------------------------------------------------------------------- wrack crab (24x24, faces right)
PAL["r"] = (196, 76, 60)
PAL["R"] = (232, 120, 90)
PAL["d"] = (120, 40, 40)
CRAB_BODY = """
..kkkkkkkkkk..
.kdRRRRRRRRdk.
kRrrrrrrrrrrRk
kkrrrRrrrRrrkk
kdrrrrrrrrrrdk
.kdrrrrrrrrdk.
.kkdddddddkk..
"""
CRAB_EYES = """
kwk..kwk
kdk..kdk
"""
CRAB_CLAW = """
.kk.
kRrk
kdrk
.kk.
"""
CRAB_CLAW_UP = """
kk..
kRk.
kdrk
.kkk
"""
CRAB_LEGS_A = """
k.kk.kk.kk.k
kk.k..k..k.kk
"""
CRAB_LEGS_B = """
.kk.kk.kk.kk.
kk.k.k..k.k.kk
"""


def crab_frame(legs, dy=0, claws_up=False, flat=False):
    c = Canvas()
    c.blit(legs, 6, 18)
    c.blit(CRAB_BODY, 5, 10 + dy)
    c.blit(CRAB_EYES, 8, 8 + dy)
    claw = CRAB_CLAW_UP if claws_up else CRAB_CLAW
    c.blit(claw, 18, 12 + dy - (3 if claws_up else 0))
    c.blit(claw, 2, 12 + dy - (3 if claws_up else 0), flip=True)
    if flat:
        # charging: body squashed, legs streaked
        c.blit("kk..kk..kk", 7, 20)
    return c


def build_wrack_crab():
    frames = [
        crab_frame(CRAB_LEGS_A, 0),                 # 0 idle a
        crab_frame(CRAB_LEGS_B, 1),                 # 1 idle b
        crab_frame(CRAB_LEGS_A, 0),                 # 2 walk 1
        crab_frame(CRAB_LEGS_B, 0),                 # 3 walk 2
        crab_frame(CRAB_LEGS_A, -2, claws_up=True), # 4 windup
        crab_frame(CRAB_LEGS_B, 2, flat=True),      # 5 charge
        crab_frame(CRAB_LEGS_B, 1),                 # 6 hurt
    ]
    return sheet(frames, "wrack_crab.png")


def build_ring():
    """Expanding-ring FX for riptide / flare: 3 frames of 48x48 circles."""
    size = 48
    im = Image.new("RGBA", (size * 3, size), (0, 0, 0, 0))
    for f, (r0, r1, a) in enumerate(((6, 9, 255), (13, 17, 220), (19, 23, 140))):
        c = Canvas(size, size)
        cx = cy = size / 2 - 0.5
        for y in range(size):
            for x in range(size):
                d = math.hypot(x - cx, y - cy)
                if r0 <= d <= r1:
                    c.px(x, y, "1" if d < (r0 + r1) / 2 else "2", a)
        im.alpha_composite(c.im, (f * size, 0))
    im.save(os.path.join(OUT, "fx_ring.png"))
    return im


def build_debris():
    """8x8 rock chunk for boss slam projectiles."""
    c = Canvas(8, 8)
    c.blit("""
..kkkk..
.kGggGk.
kGgggggk
kgggGggk
.kggggk.
..kkkk..
""", 0, 0)
    c.im.save(os.path.join(OUT, "debris.png"))
    return c.im


LIGHTHOUSE_BIG = """
..............kkkk..............
.............kyYYyk.............
............kyYYYYyk............
............kYYYYYYk............
............kkkkkkkk............
...........kggGGGGggk...........
...........kkkkkkkkkk...........
............kuuuuuuk............
............kuuuuuuk............
............kuuuuuuk............
............krrrrrrk............
............krrrrrrk............
............krrrrrrk............
............kuuuuuuk............
...........kuuuuuuuuk...........
...........kuuuuuuuuk...........
...........krrrrrrrrk...........
...........krrrrrrrrk...........
...........krrrrrrrrk...........
...........kuuuuuuuuk...........
...........kuuuuuuuuk...........
..........kuuuuuuuuuuk..........
..........kuuuuuuuuuuk..........
..........krrrrrrrrrrk..........
..........krrrrrrrrrrk..........
..........krrrrrrrrrrk..........
..........kuuuuuuuuuuk..........
..........kuuuuuuuuuuk..........
.........kuuuuuuuuuuuuk.........
.........kuuuuuuuuuuuuk.........
.........kuuuuukkuuuuuk.........
.........kuuuukzzkuuuuk.........
.........kuuuukzzkuuuuk.........
.........kuuuukzzkuuuuk.........
........kkkkkkkkkkkkkkkk........
.......kGggggggggggggggGk.......
......kGgggggggggggggggggk......
.....kkkkkkkkkkkkkkkkkkkkkk.....
....kwwwkGggggggggggggggGkwwk...
...kwwwwwkkkkkkkkkkkkkkkkwwwwk..
..kwwwwwwwwwwwwwwwwwwwwwwwwwwwk.
..kwwwwwwwwwwwwwwwwwwwwwwwwwwwk.
...kwwwwwwwwwwwwwwwwwwwwwwwwwk..
....kkkkkkkkkkkkkkkkkkkkkkkkk...
................................
................................
................................
................................
"""


def build_lighthouse():
    c = Canvas(32, 48)
    c.blit(LIGHTHOUSE_BIG, 0, 0)
    c.im.save(os.path.join(OUT, "lighthouse.png"))
    return c.im


def main():
    os.makedirs(OUT, exist_ok=True)
    built = {
        "player": build_player(),
        "gaff": build_gaff(),
        "shellback": build_shellback(),
        "gull": build_gull(),
        "slash": build_slash(),
        "spark": build_spark(),
        "shadow": build_shadow(),
        "tiles": build_tiles(),
        "icons": build_icons(),
        "pickups": build_pickups(),
        "props": build_props(),
        "door": build_door(),
        "glow": build_glow(),
        "decor": build_decor(),
        "wrack_crab": build_wrack_crab(),
        "debris": build_debris(),
        "ring": build_ring(),
        "lighthouse": build_lighthouse(),
    }
    import gen_sprites_m4
    gen_sprites_m4.build_all(built)
    print("wrote", ", ".join(f"{k}.png" for k in built))
    if "--preview" in sys.argv:
        zoom = 4
        pad = 8
        w = max(im.width for im in built.values()) * zoom + pad * 2
        h = sum(im.height * zoom + pad for im in built.values()) + pad
        contact = Image.new("RGBA", (w, h), (40, 36, 48, 255))
        y = pad
        for im in built.values():
            big = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
            contact.alpha_composite(big, (pad, y))
            y += big.height + pad
        shots = os.path.join(ROOT, ".shots")
        os.makedirs(shots, exist_ok=True)
        contact.save(os.path.join(shots, "sprites.png"))
        print("preview -> .shots/sprites.png")


if __name__ == "__main__":
    main()
