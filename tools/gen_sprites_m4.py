"""M4 sprites: biome 2 (Drowned Streets) tiles and decor, the echo NPCs and their cages,
the Net & Knife, and four new enemies. Imported and run by gen_sprites.py.
"""
import os
import random

from PIL import Image

import gen_sprites as G
from gen_sprites import Canvas, PAL, sheet, OUT

# Extra palette.
PAL["n"] = (118, 124, 118)   # statue stone
PAL["N"] = (158, 164, 156)   # statue light
PAL["j"] = (64, 70, 68)      # statue dark / dark robe
PAL["p"] = (88, 68, 112)     # lamplighter robe
PAL["P"] = (128, 100, 150)   # robe light
PAL["i"] = (150, 110, 50)    # bronze
PAL["I"] = (204, 164, 84)    # bronze light
PAL["x"] = (56, 132, 124)    # swimmer skin
PAL["X"] = (100, 190, 170)   # swimmer light
PAL["l"] = (176, 118, 78)    # bram leather apron
PAL["L"] = (214, 160, 110)
PAL["T"] = (200, 200, 190)   # wren's veil
PAL["t2"] = (60, 74, 58)
PAL["7"] = (74, 44, 30)      # bram beard/hair
PAL["8"] = (190, 170, 130)   # parchment
PAL["9"] = (96, 88, 120)     # cartographer coat

# ----------------------------------------------------------------------------- tiles (appended to the strip)
TILE_NAMES_M4 = ["cobble", "cobble2", "ruin", "ruin2", "moss", "flag"]


def build_tiles_m4(base):
    """Append the street tiles to tiles.png. `base` is the image gen_sprites built."""
    n0 = base.width // 16
    im = Image.new("RGBA", (16 * (n0 + len(TILE_NAMES_M4)), 16), (0, 0, 0, 0))
    im.alpha_composite(base, (0, 0))
    cob = (96, 100, 112); cob_l = (128, 132, 146); cob_d = (62, 66, 78); cob_w = (72, 92, 104)
    ruin = (70, 58, 62); ruin_l = (104, 90, 92); ruin_d = (40, 32, 38); ruin_m = (56, 78, 66)
    moss = (76, 92, 80); moss_l = (98, 116, 100); moss_d = (54, 66, 58)
    flag = (140, 138, 132); flag_l = (172, 170, 162); flag_d = (96, 94, 90)
    for v in range(2):
        ox = 16 * (n0 + v)
        random.seed(40 + v)
        for y in range(16):
            for x in range(16):
                # rounded cobbles on a 4x4 grid with mortar lines
                gx, gy = x % 5, (y + (2 if (x // 5) % 2 else 0)) % 5
                c = cob
                if gx == 4 or gy == 4:
                    c = cob_d
                elif gx == 0 and gy == 0:
                    c = cob_l
                elif random.random() < 0.06:
                    c = cob_w
                im.putpixel((ox + x, y), c + (255,))
    for v in range(2):
        ox = 16 * (n0 + 2 + v)
        random.seed(50 + v)
        for y in range(16):
            for x in range(16):
                bx = (x + (4 if (y // 4) % 2 else 0)) % 8
                c = ruin
                if y % 4 == 3 or bx == 7:
                    c = ruin_d
                elif random.random() < 0.08:
                    c = ruin_l
                elif y > 10 and random.random() < 0.18:
                    c = ruin_m
                im.putpixel((ox + x, y), c + (255,))
    G._noise_tile(im, 16 * (n0 + 4), moss, moss_l, moss_d, 60, 0.14, 0.1)
    random.seed(70)
    ox = 16 * (n0 + 5)
    for y in range(16):
        for x in range(16):
            c = flag
            if y % 8 == 7 or x % 8 == 7:
                c = flag_d
            elif random.random() < 0.08:
                c = flag_l
            im.putpixel((ox + x, y), c + (255,))
    im.save(os.path.join(OUT, "tiles.png"))
    return im


# ----------------------------------------------------------------------------- street decor
DECOR2 = {
    "lamppost": """
.......kk.......
......kyYk......
......kYYk......
......kkkk......
.......kk.......
.......kk.......
.......kk.......
.......kk.......
.......kk.......
.......kk.......
.......kk.......
.......kk.......
......kkkk......
.....kggggk.....
.....kkkkkk.....
................
""",
    "bench": """
................
................
................
................
................
..kkkkkkkkkkkk..
..kWWWWWWWWWWk..
..kwwwwwwwwwwk..
..kkkkkkkkkkkk..
...kwk....kwk...
...kwk....kwk...
...kkk....kkk...
................
................
................
................
""",
    "barrel": """
................
................
.....kkkkkk.....
....kWwwwwWk....
...kGGGGGGGGk...
...kwwwwwwwwk...
...kwwwwwwwwk...
...kGGGGGGGGk...
...kwwwwwwwwk...
...kwwwwwwwwk...
....kGGGGGGk....
.....kkkkkk.....
................
................
................
................
""",
    "skull": """
................
................
................
................
......kkkk......
.....kuuuuk.....
....kuukkuuk....
....kukkkkuk....
....kuuuuuuk....
.....kukuk......
.....kkkkk......
................
................
................
................
................
""",
    "crack": """
................
................
.....k..........
......k.........
......k.........
.......kk.......
.........k......
.........k......
........k.......
........k.k.....
.......k...k....
.......k........
................
................
................
................
""",
    "weed": """
................
................
................
................
.......k........
......ktk.......
.....kt2tk......
....kt2ttk......
.....ktt2tk.....
......kt2k......
.......kk.......
................
................
................
................
................
""".replace("2", "t"),
    "pot": """
................
................
................
....kkkkkk......
...kGggggGk.....
....kkkkkk......
....kgggg.k.....
...kgggg..k.....
...kgggggkk.....
...kggggggk.....
....kggggk......
.....kkkk.......
................
................
................
................
""",
    "sign": """
................
................
...kkkkkkkkk....
..kWWWWWWWWWk...
..kwkwkwkwkwk...
..kWWWWWWWWWk...
...kkkkkkkkk....
.......kwk......
.......kwk......
.......kwk......
.......kwk......
.......kwk......
......kkkkk.....
................
................
................
""",
}
DECOR2_ORDER = ["lamppost", "bench", "barrel", "skull", "crack", "weed", "pot", "sign"]


def build_decor2():
    im = Image.new("RGBA", (16 * len(DECOR2_ORDER), 16), (0, 0, 0, 0))
    for i, n in enumerate(DECOR2_ORDER):
        c = Canvas(16, 16)
        c.blit(DECOR2[n], 0, 0)
        im.alpha_composite(c.im, (i * 16, 0))
    im.save(os.path.join(OUT, "decor2.png"))
    return im


# ----------------------------------------------------------------------------- props: cages and echoes
PROPS_M4 = {
    # a barnacled iron cage with a figure inside
    "cage": """
.....kkkkkk.....
....kGggggGk....
...kGkkkkkkGk...
...kgkuuuukgk...
...kgkufffkgk...
...kgkuuuukgk...
...kgkkuukkgk...
...kgkuuuukgk...
...kgkuuuukgk...
...kgkkuukkgk...
...kgkkkkkkgk...
...kGggggggGk...
....kkkkkkkk....
................
................
................
""",
    "cage_open": """
.....kkkkkk.....
....kGggggGk....
...kGk....kGk...
...kg......gk...
...kg.......k...
...kg.......k...
...k........k...
...kg.......gk..
...kg.......gk..
...kg......kgk..
...kgkkkkkkkgk..
...kGggggggGk...
....kkkkkkkk....
................
................
................
""",
    # Bram: broad, bearded, leather apron, hammer
    "bram": """
.....kkkkkk.....
....k777777k....
...k7ffffff7k...
...k7feffef7k...
...k77ffff77k...
...k7777777k....
..kkllllllllkk..
.kGgkllllllkGgk.
.kGgkllllllkGgk.
..kkkLLLLLLkkk..
...kllllllllk...
...kllkkkkllk...
...kbbk..kbbk...
...kkkk..kkkk...
................
................
""",
    # Sister Wren: white veil, pale robe, hands folded
    "wren": """
.....kkkkkk.....
....kTTTTTTk....
...kTTffffTTk...
...kTTfeffeTk...
...kTTFffFTTk...
...kTTTTTTTTk...
..kTTTTTTTTTTk..
..kTTTffffTTTk..
..kTTTTTTTTTTk..
..kTTTTTTTTTTk..
..kTTTTTTTTTTk..
...kTTTTTTTTk...
...kTTTTTTTTk...
...kkkkkkkkkk...
................
................
""",
    # The Cartographer: long coat, scroll under arm, no face to speak of
    "cartographer": """
.....kkkkkk.....
....k999999k....
...k99jjjj99k...
...k9jjejjejk...
...k99jjjj99k...
....k999999k....
...k99999999k...
..k9999999998k..
..k9999999888k..
..k9999999888k..
..k99999999kk...
...k999999k.....
...kbbkkbbk.....
...kkk..kkk.....
................
................
""",
}
PROP_ORDER_M4 = ["cage", "cage_open", "bram", "wren", "cartographer"]


def build_props_m4(base):
    n0 = base.width // 16
    im = Image.new("RGBA", (16 * (n0 + len(PROP_ORDER_M4)), 16), (0, 0, 0, 0))
    im.alpha_composite(base, (0, 0))
    for i, n in enumerate(PROP_ORDER_M4):
        c = Canvas(16, 16)
        c.blit(PROPS_M4[n], 0, 0)
        im.alpha_composite(c.im, (16 * (n0 + i), 0))
    im.save(os.path.join(OUT, "props.png"))
    return im


# ----------------------------------------------------------------------------- echo signboard
ECHO_SYMBOL = """
................
....kkkkkkkk....
...kGkkkkkkGk...
...kgkuuuukgk...
...kgkufffkgk...
...kgkuuuukgk...
...kgkkuukkgk...
...kgkuuuukgk...
...kgkuuuukgk...
...kgkkkkkkgk...
...kGggggggGk...
....kkkkkkkk....
......kUuk......
.....kUuuvk.....
......kuvk......
.......kk.......
"""


def build_icons_m4(base):
    n0 = base.width // 24
    im = Image.new("RGBA", (24 * (n0 + 1), 24), (0, 0, 0, 0))
    im.alpha_composite(base, (0, 0))
    c = Canvas(24, 24)
    c.blit(G.SIGN_BOARD, 0, 0)
    c.blit(ECHO_SYMBOL, 4, 4)
    im.alpha_composite(c.im, (24 * n0, 0))
    im.save(os.path.join(OUT, "icons.png"))
    return im


# ----------------------------------------------------------------------------- net & knife
KNIFE = """
kkkkkkkkkk....
kwwGGGGGGGGk..
kwwGGGGGGGGGGk
kkkkkkkkkkkk..
"""


def build_knife():
    c = Canvas(14, 4)
    c.blit(KNIFE, 0, 0)
    c.im.save(os.path.join(OUT, "knife.png"))
    return c.im


def build_net():
    """24x24 thrown net: a loose rope mesh with weights at the rim."""
    size = 24
    c = Canvas(size, size)
    cx = cy = size / 2 - 0.5
    import math
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy)
            if d > 11.0:
                continue
            on_mesh = (x % 4 == 0) or (y % 4 == 0)
            if d > 9.6:
                c.px(x, y, "w" if (x + y) % 3 else "k")
            elif on_mesh:
                c.px(x, y, "W" if (x + y) % 2 else "w", 220)
    for ang in range(0, 360, 60):
        x = int(round(cx + math.cos(math.radians(ang)) * 10.5))
        y = int(round(cy + math.sin(math.radians(ang)) * 10.5))
        c.px(x, y, "g"); c.px(x + 1, y, "k")
    c.im.save(os.path.join(OUT, "net.png"))
    return c.im


# ----------------------------------------------------------------------------- still citizen (24x24, faces right)
CIT_HEAD = """
..kkkkk..
.kNNNNNk.
kNnnnnnNk
kNnenenNk
kNnnnnnNk
.knnnnnk.
..kkkkk..
"""
CIT_BODY = """
..kkkkkkk..
.kNNNNNNNk.
kNnnnnnnnNk
kNnnnnnnnNk
knnnnnnnnnk
.kjjjjjjjk.
"""
CIT_ARM_DOWN = """
kNk
knk
knk
kjk
"""
CIT_ARM_OUT = """
kNNNnk
kkkkkk
"""
CIT_ARM_STAB = """
kNNNnnGGk
kkkkkkkkk
"""
CIT_LEGS_A = """
.kjjk.kjjk.
.kjjk.kjjk.
.kkkk.kkkk.
"""
CIT_LEGS_B = """
kjjk...kjjk
.kjjk.kjjk.
..kkk.kkk..
"""


def citizen_frame(legs, dy=0, arms="down", moss=False):
    c = Canvas()
    c.blit(legs, 6, 19)
    c.blit(CIT_BODY, 6, 13 + dy)
    c.blit(CIT_HEAD, 7, 6 + dy)
    if arms == "down":
        c.blit(CIT_ARM_DOWN, 4, 14 + dy)
        c.blit(CIT_ARM_DOWN, 16, 14 + dy)
    elif arms == "out":
        c.blit(CIT_ARM_OUT, 15, 14 + dy)
        c.blit(CIT_ARM_DOWN, 4, 14 + dy)
    elif arms == "up":
        c.blit("kNk\nknk\nknk", 17, 9 + dy)
        c.blit(CIT_ARM_DOWN, 4, 14 + dy)
    elif arms == "stab":
        c.blit(CIT_ARM_STAB, 15, 15 + dy)
        c.blit(CIT_ARM_DOWN, 4, 14 + dy)
    if moss:
        for (x, y) in ((8, 7), (12, 6), (7, 14), (14, 17), (9, 21)):
            c.px(x, y, "s")
    return c


def build_still_citizen():
    frames = [
        citizen_frame(CIT_LEGS_A, 0, "down", moss=True),   # 0 statue
        citizen_frame(CIT_LEGS_A, 0, "down", moss=True),   # 1 statue (same, no breathing)
        citizen_frame(CIT_LEGS_A, 0, "out"),               # 2 run 1
        citizen_frame(CIT_LEGS_B, -1, "out"),              # 3 run 2
        citizen_frame(CIT_LEGS_A, -1, "up"),               # 4 windup
        citizen_frame(CIT_LEGS_B, 1, "stab"),              # 5 stab
        citizen_frame(CIT_LEGS_B, 1, "down"),              # 6 hurt
    ]
    return sheet(frames, "still_citizen.png")


# ----------------------------------------------------------------------------- lamplighter (hooded, pole lantern)
LL_HOOD = """
..kkkkk..
.kPPPPPk.
kPpppppPk
kPpjejpPk
kPpjjjpPk
.kppppPk.
..kkkkk..
"""
LL_ROBE = """
..kkkkkk..
.kPppppPk.
.kpppppPk.
kpppppppPk
kpppppppPk
kppppppppk
.kkkkkkkk.
"""
LL_POLE = """
kyk
kYk
kyk
.k.
.k.
.k.
.k.
.k.
.k.
.k.
"""


def lamplighter_frame(dy=0, pole_up=False, throw=False, lean=0):
    c = Canvas()
    c.blit(LL_ROBE, 6 + lean, 12 + dy)
    c.blit(LL_HOOD, 7 + lean, 5 + dy)
    if throw:
        c.blit("kyk\nkYk\nkyk", 19, 8 + dy)
        c.blit(".k.\n.k.\n.k.", 16, 12 + dy)
    elif pole_up:
        c.blit(LL_POLE, 16, 2 + dy)
    else:
        c.blit(LL_POLE, 17, 9 + dy)
    c.blit("kjjk...kjjk", 6, 21)
    return c


def build_lamplighter():
    frames = [
        lamplighter_frame(0),            # 0 idle a
        lamplighter_frame(1),            # 1 idle b
        lamplighter_frame(0, lean=1),    # 2 walk 1
        lamplighter_frame(-1, lean=-1),  # 3 walk 2
        lamplighter_frame(-2, pole_up=True),  # 4 kindle
        lamplighter_frame(0, throw=True),     # 5 throw
        lamplighter_frame(1),            # 6 hurt
    ]
    return sheet(frames, "lamplighter.png")


# ----------------------------------------------------------------------------- bell ringer (broad, bell on a yoke)
BR_BODY = """
...kkkkkkkk...
..kjjjjjjjjk..
.kjjjjjjjjjjk.
kjjjjjjjjjjjjk
kjjjjjjjjjjjjk
kjjjjjjjjjjjjk
.kjjjjjjjjjjk.
..kkkkkkkkkk..
"""
BR_HEAD = """
..kkkk..
.knnnnk.
knnenenk
knnnnnnk
.kkkkkk.
"""
BELL = """
...kk...
..kIIk..
.kIiiIk.
.kIiiIk.
.kiiiik.
kIiiiiIk
kkkkkkkk
..k..k..
"""


def ringer_frame(dy=0, bell="back", legs=0, wave=False):
    c = Canvas()
    c.blit("kjjk..kjjk" if legs == 0 else ".kjjkkjjk.", 7, 21)
    if bell == "back":
        c.blit(BELL, 1, 6 + dy)
    c.blit(BR_BODY, 5, 12 + dy)
    c.blit(BR_HEAD, 8, 7 + dy)
    if bell == "up":
        c.blit(BELL, 14, 1 + dy)
    elif bell == "out":
        c.blit(BELL, 15, 9 + dy)
        if wave:
            for (x, y) in ((23, 8), (23, 12), (23, 16), (22, 6), (22, 18)):
                c.px(x, y, "1")
    return c


def build_bell_ringer():
    frames = [
        ringer_frame(0),                 # 0 idle a
        ringer_frame(1),                 # 1 idle b
        ringer_frame(0, legs=0),         # 2 walk 1
        ringer_frame(0, legs=1),         # 3 walk 2
        ringer_frame(-2, bell="up"),     # 4 windup
        ringer_frame(1, bell="out", wave=True),  # 5 ring
        ringer_frame(1),                 # 6 hurt
    ]
    return sheet(frames, "bell_ringer.png")


# ----------------------------------------------------------------------------- swimmer (long, low, mostly submerged)
SW_BODY_A = """
......kkkkkkkk....
...kkkXXXXXXXXkk..
.kkxxxxxxxxxxxxXk.
kxxxxxxxxxxxxxxexk
.kkxxxxxxxxxxxxxk.
...kkkxxxxxxxxkk..
......kkkkkkkk....
"""
SW_BODY_B = """
....kkkkkkkk......
..kkXXXXXXXXkkk...
.kxXxxxxxxxxxxxk..
kxxxxxxxxxxxxxxexk
.kxxxxxxxxxxxxxkk.
..kkxxxxxxxxkkk...
....kkkkkkkk......
"""
SW_JAW = """
kkk
kXk
kkk
"""


def swimmer_frame(body, dy=0, jaw=False, ripple=False):
    c = Canvas()
    c.blit(body, 3, 10 + dy)
    if jaw:
        c.blit("kk\nk1", 20, 12 + dy)
        c.blit("k1\nkk", 20, 15 + dy)
    if ripple:
        for x in (2, 6, 10, 14, 18):
            c.px(x, 18 + dy, "q")
    return c


def build_swimmer():
    frames = [
        swimmer_frame(SW_BODY_A, 0, ripple=True),   # 0 swim a
        swimmer_frame(SW_BODY_B, 1, ripple=True),   # 1 swim b
        swimmer_frame(SW_BODY_A, 0),                # 2 crawl 1
        swimmer_frame(SW_BODY_B, 0),                # 3 crawl 2
        swimmer_frame(SW_BODY_A, -3, jaw=True),     # 4 windup
        swimmer_frame(SW_BODY_B, 1, jaw=True),      # 5 bite
        swimmer_frame(SW_BODY_B, 1),                # 6 hurt
    ]
    return sheet(frames, "swimmer.png")


# ----------------------------------------------------------------------------- small projectiles
def build_lantern_shot():
    c = Canvas(8, 8)
    c.blit("""
..kkkk..
.kyYYyk.
kyYYYYyk
kyYYYYyk
.kyyyyk.
..kkkk..
""", 0, 1)
    c.im.save(os.path.join(OUT, "lantern_shot.png"))
    return c.im


def build_toll():
    """8x8 arc of sound for the bell's toll."""
    c = Canvas(8, 8)
    c.blit("""
....k1..
...k1...
..k1....
..k1....
..k1....
...k1...
....k1..
""", 0, 0)
    c.im.save(os.path.join(OUT, "toll.png"))
    return c.im


def build_all(built):
    """Called by gen_sprites.main with its dict of built images; extends the shared sheets."""
    built["tiles"] = Image.open(os.path.join(OUT, "tiles.png")).convert("RGBA")  # art Stage 09 sheet
    built["props"] = Image.open(os.path.join(OUT, "props.png")).convert("RGBA")  # art Stage 09 sheet
    built["icons"] = Image.open(os.path.join(OUT, "icons.png")).convert("RGBA")  # art Stage 09 sheet
    built["decor2"] = Image.open(os.path.join(OUT, "decor2.png")).convert("RGBA")  # art Stage 09 sheet
    built["knife"] = build_knife()
    built["net"] = build_net()
    built["still_citizen"] = Image.open(os.path.join(OUT, "still_citizen.png")).convert("RGBA")  # art Stage 07 sheet
    built["lamplighter"] = Image.open(os.path.join(OUT, "lamplighter.png")).convert("RGBA")  # art Stage 07 sheet
    built["bell_ringer"] = Image.open(os.path.join(OUT, "bell_ringer.png")).convert("RGBA")  # art Stage 07 sheet
    built["swimmer"] = Image.open(os.path.join(OUT, "swimmer.png")).convert("RGBA")  # art Stage 07 sheet
    built["lantern_shot"] = build_lantern_shot()
    built["toll"] = build_toll()
    return built
