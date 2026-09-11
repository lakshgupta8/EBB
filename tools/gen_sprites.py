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
def slash_frame(t, size=32):
    """Arc sweeping from -70deg to +70deg; t in [0,1] moves the bright head."""
    c = Canvas(size, size)
    cx, cy = 6, size // 2
    a0, a1 = -70, 70
    head = a0 + (a1 - a0) * t
    for r in (12, 13, 14, 15):
        for deg in range(a0, a1 + 1):
            if deg > head:
                break
            age = (head - deg) / (a1 - a0)  # 0 at head, 1 at tail
            if age > 0.55:
                continue
            ch = "1" if age < 0.12 else "2" if age < 0.3 else "3"
            if r in (12, 15) and age > 0.2:
                continue
            x = int(round(cx + r * math.cos(math.radians(deg))))
            y = int(round(cy + r * math.sin(math.radians(deg))))
            c.px(x, y, ch)
    return c


def build_slash():
    frames = [slash_frame(0.45), slash_frame(0.75), slash_frame(1.0)]
    im = Image.new("RGBA", (32 * 3, 32), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.alpha_composite(f.im, (i * 32, 0))
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


def build_tiles():
    import random
    im = Image.new("RGBA", (16 * 4, 16), (0, 0, 0, 0))
    sand = (200, 180, 130); sand_l = (225, 205, 160); sand_d = (150, 128, 90)
    wall = (70, 62, 52); wall_l = (96, 86, 72); wall_d = (44, 38, 32)
    for v in range(2):
        random.seed(v)
        for y in range(16):
            for x in range(16):
                r = random.random()
                c = sand_l if r < 0.12 else sand_d if r < 0.16 else sand
                im.putpixel((v * 16 + x, y), c + (255,))
    for v in range(2):
        random.seed(10 + v)
        for y in range(16):
            for x in range(16):
                c = wall
                if y % 8 == 0 or (x + (4 if (y // 8) % 2 else 0)) % 8 == 0:
                    c = wall_d
                elif random.random() < 0.08:
                    c = wall_l
                im.putpixel((32 + v * 16 + x, y), c + (255,))
    im.save(os.path.join(OUT, "tiles.png"))
    return im


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
    }
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
