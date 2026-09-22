"""M6a sprites: the Sunken Harbour (biome 1.5) tiles and decor, the Mooring, the Barnacle
Swarm, the Deckhand, the Chainmother, and the anchor she drops. Imported by gen_sprites.py.
"""
import os
import random

from PIL import Image

import gen_sprites as G
from gen_sprites import Canvas, PAL, sheet, OUT

PAL["a"] = (150, 84, 52)     # rust
PAL["d"] = (196, 128, 80)    # rust light
PAL["q"] = (54, 40, 30)      # tarred wood
PAL["0"] = (214, 216, 208)   # barnacle pale
PAL["!"] = (160, 164, 158)   # barnacle shade
PAL["@"] = (66, 84, 104)     # deckhand coat
PAL["$"] = (96, 118, 140)    # deckhand coat light
PAL["^"] = (120, 104, 84)    # swarm flesh
PAL["&"] = (170, 176, 186)   # chain
PAL["*"] = (70, 56, 44)      # chainmother hull
PAL["("] = (110, 90, 66)     # chainmother hull light
PAL[")"] = (255, 150, 60)    # her lantern eye
PAL["~"] = (110, 170, 150)   # weed on wet wood

# ----------------------------------------------------------------------------- tiles (appended)
TILE_NAMES_M6 = ["deck", "deck2", "hull", "hull2", "silt", "quay"]


def build_tiles_m6(base):
    n0 = base.width // 16
    im = Image.new("RGBA", (16 * (n0 + len(TILE_NAMES_M6)), 16), (0, 0, 0, 0))
    im.alpha_composite(base, (0, 0))
    deck = (112, 88, 62); deck_l = (140, 112, 80); deck_d = (72, 54, 38); deck_w = (86, 112, 100)
    hull = (48, 38, 30); hull_l = (78, 62, 48); hull_d = (26, 20, 16); band = (96, 100, 108); rust = (140, 80, 50)
    silt = (74, 70, 60); silt_l = (96, 92, 80); silt_d = (52, 48, 42)
    quay = (120, 122, 118); quay_l = (152, 154, 148); quay_d = (80, 82, 78)
    # 0,1 deck: planks running across, nail heads, a little green where the water sits
    for v in range(2):
        ox = 16 * (n0 + v)
        random.seed(120 + v)
        for y in range(16):
            for x in range(16):
                px_ = (x + (5 if (y // 4) % 2 else 0)) % 10
                c = deck
                if y % 4 == 3:
                    c = deck_d
                elif px_ == 9:
                    c = deck_d
                elif px_ == 1 and y % 4 == 1:
                    c = deck_l if random.random() < 0.6 else deck
                elif random.random() < 0.05:
                    c = deck_w
                elif random.random() < 0.06:
                    c = deck_l
                im.putpixel((ox + x, y), c + (255,))
    # 2,3 hull: tarred strakes with an iron band and rust weeping down from the rivets
    for v in range(2):
        ox = 16 * (n0 + 2 + v)
        random.seed(130 + v)
        for y in range(16):
            for x in range(16):
                c = hull
                if y % 5 == 4:
                    c = hull_d
                elif y == 7 + v * 3:
                    c = band
                elif y == 8 + v * 3 and x % 5 == 2:
                    c = rust
                elif random.random() < 0.07:
                    c = hull_l
                im.putpixel((ox + x, y), c + (255,))
    # 4 silt: the drydock floor, dark wet mud that floods first
    G._noise_tile(im, 16 * (n0 + 4), silt, silt_l, silt_d, 140, 0.1, 0.14)
    # 5 quay: big dressed blocks
    random.seed(150)
    ox = 16 * (n0 + 5)
    for y in range(16):
        for x in range(16):
            bx = (x + (8 if (y // 8) % 2 else 0)) % 16
            c = quay
            if y % 8 == 7 or bx == 15:
                c = quay_d
            elif random.random() < 0.08:
                c = quay_l
            im.putpixel((ox + x, y), c + (255,))
    im.save(os.path.join(OUT, "tiles.png"))
    return im


# ----------------------------------------------------------------------------- harbour decor
DECOR4 = {
    "rope": """
................
................
................
.....kkkkkk.....
....kWWWWWWk....
...kWwkkkkwWk...
...kWk....kWk...
...kWwkkkkwWk...
....kWWWWWWk....
.....kkkkkk.....
................
................
................
................
................
................
""",
    "crate": """
................
................
....kkkkkkkk....
...kWWWWWWWWk...
...kWwwwwwwWk...
...kWwWWWWwWk...
...kWwWkkWwWk...
...kWwWkkWwWk...
...kWwWWWWwWk...
...kWwwwwwwWk...
...kWWWWWWWWk...
....kkkkkkkk....
................
................
................
................
""",
    "chain": """
................
..kk............
.k&&k...........
.k&&k...........
..kk.kk.........
....k&&k........
....k&&k........
.....kk.kk......
.......k&&k.....
.......k&&k.....
........kk.kk...
..........k&&k..
..........k&&k..
...........kk...
................
................
""",
    "anchor": """
................
.......kk.......
......k&&k......
......k&&k......
.......kk.......
.......k........
.....kkakkk.....
.......a........
.......a........
..k....a....k...
.ka....a....ak..
.ka...aaa...ak..
..ka.aaaaa.ak...
...kaaaakaaak...
....kkkk.kkk....
................
""",
    "hook": """
................
.......k........
......kkk.......
......k&k.......
......k&k.......
......k&k.......
......k&k.......
.....kk&kk......
....k&&&&&k.....
...k&kkkkk&k....
...k&k...k&k....
...k&k...kk.....
....k&k.........
.....k&k........
......kk........
................
""",
    "bollard": """
................
................
................
.....kkkkk......
....kggGGgk.....
....kgGGGgk.....
....kgggggk.....
....kgggggk.....
....kgggggk.....
....kgggggk.....
...kkgggggkk....
...kgggggggk....
...kkkkkkkkk....
................
................
................
""",
    "netting": """
................
.k...k...k...k..
..k.k.k.k.k.k...
...k...k...k....
..k.k.k.k.k.k...
.k...k...k...k..
..k.k.k.k.k.k...
...k...k...k....
..k.k.k.k.k.k...
.k...k...k...k..
..k.k.k.k.k.k...
...k...k...k....
................
................
................
................
""",
    "plank": """
................
................
................
................
................
..kkkkkkkkkkkk..
.kWWWWWWWWWWWWk.
.kwwwwwwwwwwwwk.
.kkkkkkkkkkkkkk.
...kqqqk..kqqqk.
....kkk....kkk..
................
................
................
................
................
""",
}
DECOR4_ORDER = ["rope", "crate", "chain", "anchor", "hook", "bollard", "netting", "plank"]


def build_decor4():
    im = Image.new("RGBA", (16 * len(DECOR4_ORDER), 16), (0, 0, 0, 0))
    for i, name in enumerate(DECOR4_ORDER):
        c = Canvas(16, 16)
        c.blit(DECOR4[name], 0, 0)
        im.alpha_composite(c.im, (i * 16, 0))
    im.save(os.path.join(OUT, "decor4.png"))
    return im


# ----------------------------------------------------------------------------- the mooring (hunched harbour hand, chain on the arm)
MO_HEAD = """
..kkkkk..
.kNNNNNk.
kNnnnnnNk
kNnenenNk
kNnnnnnNk
.knnnnnk.
..kkkkk..
"""
MO_BODY = """
..kkkkkkkk..
.kqqqqqqqqk.
kqqqqqqqqqqk
kqqqqqqqqqqk
kqqqqqqqqqqk
.kjjjjjjjjk.
"""
MO_ARM_CHAIN_DOWN = """
k&k
k&k
k&k
kak
"""
MO_ARM_CHAIN_UP = """
kak
k&k
k&k
k&k
"""
MO_LEGS_A = """
.kjjk.kjjk.
.kjjk.kjjk.
.kkkk.kkkk.
"""
MO_LEGS_B = """
kjjk...kjjk
.kjjk.kjjk.
..kkk.kkk..
"""


def mooring_frame(legs, dy=0, chain="down", lash=False, hurt=False):
    c = Canvas()
    c.blit(legs, 6, 19)
    c.blit(MO_BODY, 6, 13 + dy)
    c.blit(MO_HEAD, 7, 7 + dy)
    c.blit("kNk\nknk\nkjk", 5, 14 + dy)  # left arm
    if lash:
        # chain flung to the right edge of the cell
        c.blit("kaaak&&&&&&", 13, 14 + dy)
        c.blit("kkkkkkkkkkk", 13, 15 + dy)
    elif chain == "up":
        c.blit(MO_ARM_CHAIN_UP, 17, 8 + dy)
        c.blit("k&&k", 18, 6 + dy)
    else:
        c.blit(MO_ARM_CHAIN_DOWN, 17, 14 + dy)
        c.blit("k&k", 17, 18 + dy)
    if hurt:
        c.px(9, 10 + dy, "r")
        c.px(11, 10 + dy, "r")
    for (x, y) in ((8, 8), (13, 15), (10, 17)):
        c.px(x, y + dy, "~")
    return c


def build_mooring():
    frames = [
        mooring_frame(MO_LEGS_A, 0),
        mooring_frame(MO_LEGS_A, -1),
        mooring_frame(MO_LEGS_A, 0),
        mooring_frame(MO_LEGS_B, -1),
        mooring_frame(MO_LEGS_A, -1, chain="up"),
        mooring_frame(MO_LEGS_B, 1, lash=True),
        mooring_frame(MO_LEGS_B, 1, hurt=True),
    ]
    return sheet(frames, "mooring.png")


# ----------------------------------------------------------------------------- the barnacle swarm
BARN_MASS = """
......kkkkkk......
....kk^^^^^^kk....
...k^^^^^^^^^^k...
..k^^^^^^^^^^^^k..
..k^^^^^^^^^^^^k..
...k^^^^^^^^^^k...
....kkkkkkkkkk....
"""
BARN_CONE = """
.k0k.
k0!0k
"""


def barnacle_frame(dy=0, wobble=0, bite=False, hurt=False):
    c = Canvas()
    shift = 2 if bite else 0
    c.blit(BARN_MASS, 3 + shift, 13 + dy)
    cones = [(5, 12), (9, 11), (13, 12), (11, 14), (7, 15), (15, 15)]
    for i, (x, y) in enumerate(cones):
        ox = x + shift + (wobble if i % 2 else -wobble)
        c.blit(BARN_CONE, ox, y + dy)
        if hurt and i % 2 == 0:
            c.px(ox + 2, y + 1 + dy, "r")
    c.px(16 + shift, 17 + dy, "e")
    c.px(18 + shift, 17 + dy, "e")
    if bite:
        c.blit("kKKk\nkkkk", 19, 18 + dy)
    for (x, y) in ((4, 10), (18, 9)):
        c.px(x, y + dy, "O")
    return c


def build_barnacle():
    frames = [
        barnacle_frame(0, 0),
        barnacle_frame(-1, 1),
        barnacle_frame(0, 1),
        barnacle_frame(-1, -1),
        barnacle_frame(-2, 1),
        barnacle_frame(1, 0, bite=True),
        barnacle_frame(1, 1, hurt=True),
    ]
    return sheet(frames, "barnacle.png")


# ----------------------------------------------------------------------------- the deckhand (shield up, cutlass)
DH_HEAD = """
..kkkkk..
.k@@@@@k.
k@nnnnn@k
k@nenen@k
k@nnnnn@k
.knnnnnk.
..kkkkk..
"""
DH_BODY = """
..kkkkkkk..
.k@@@@@@@k.
k@$$$$$$$@k
k@@@@@@@@@k
k@@@@@@@@@k
.kjjjjjjjk.
"""
DH_SHIELD = """
.kkkk.
kWWWWk
kWggWk
kWggWk
kWWWWk
.kkkk.
"""
DH_BLADE_UP = """
.kGk
.kGk
.kGk
kkGk
.kgk
"""
DH_BLADE_OUT = """
kgGGGGGk
kkkkkkkk
"""


def deckhand_frame(legs, dy=0, blade="rest", shield=True, hurt=False):
    c = Canvas()
    c.blit(legs, 6, 19)
    c.blit(DH_BODY, 6, 13 + dy)
    c.blit(DH_HEAD, 7, 7 + dy)
    c.blit("kNk\nknk\nkjk", 5, 14 + dy)
    if shield:
        c.blit(DH_SHIELD, 15, 12 + dy)
    if blade == "up":
        c.blit(DH_BLADE_UP, 18, 5 + dy)
    elif blade == "out":
        c.blit(DH_BLADE_OUT, 15, 15 + dy)
    if hurt:
        c.px(9, 10 + dy, "r")
        c.px(11, 10 + dy, "r")
    return c


def build_deckhand():
    frames = [
        deckhand_frame(MO_LEGS_A, 0),
        deckhand_frame(MO_LEGS_A, -1),
        deckhand_frame(MO_LEGS_A, 0),
        deckhand_frame(MO_LEGS_B, -1),
        deckhand_frame(MO_LEGS_A, -1, blade="up"),
        deckhand_frame(MO_LEGS_B, 1, blade="out", shield=False),
        deckhand_frame(MO_LEGS_B, 1, shield=False, hurt=True),
    ]
    return sheet(frames, "deckhand.png")


# ----------------------------------------------------------------------------- the chainmother (a crane that learned to walk)
CM_HULL = """
....kkkkkkkkkkkkkk....
...k**************k...
..k*((((((((((((((*k..
..k*(************(*k..
..k*(**)))**)))**(*k..
..k*(**)))**)))**(*k..
..k*(************(*k..
..k*((((((((((((((*k..
..k****************k..
..kaaaaaaaaaaaaaaaak..
...kkkkkkkkkkkkkkkk...
"""
CM_LEGS = """
.kk......kk.
k&&k....k&&k
k&&k....k&&k
.kk......kk.
"""


def chainmother_frame(dy=0, arms="down", eyes=True, hurt=False):
    c = Canvas()
    # beam across the top with a hook either side
    c.blit("kkkkkkkkkkkkkkkkkkkkkkkk", 0, 2 + dy)
    c.blit("k999999999999999999999k", 0, 3 + dy)
    c.blit(CM_HULL, 1, 4 + dy)
    c.blit(CM_LEGS, 6, 15 + dy)
    if arms == "down":
        c.blit("k&k\nk&k\nk&k\nkak", 1, 5 + dy)
        c.blit("k&k\nk&k\nk&k\nkak", 20, 5 + dy)
    elif arms == "up":
        c.blit("kak\nk&k", 1, 0 + dy)
        c.blit("kak\nk&k", 20, 0 + dy)
    elif arms == "out":
        c.blit("&&&&&&&", 17, 9 + dy)
        c.blit("kkkkkkk", 17, 10 + dy)
        c.blit("&&&&&&&", 0, 9 + dy)
        c.blit("kkkkkkk", 0, 10 + dy)
    if not eyes:
        for (x, y) in ((8, 8), (9, 8), (10, 8), (13, 8), (14, 8), (15, 8), (8, 9), (9, 9), (10, 9), (13, 9), (14, 9), (15, 9)):
            c.px(x, y + dy, "*")
    if hurt:
        for (x, y) in ((5, 12), (12, 13), (17, 12)):
            c.px(x, y + dy, "r")
    for (x, y) in ((4, 12), (18, 13), (11, 14)):
        c.px(x, y + dy, "~")
    return c


def build_chainmother():
    frames = [
        chainmother_frame(0),
        chainmother_frame(0, eyes=False),
        chainmother_frame(0),
        chainmother_frame(-1),
        chainmother_frame(-1, arms="up"),
        chainmother_frame(1, arms="out"),
        chainmother_frame(1, hurt=True),
    ]
    return sheet(frames, "chainmother.png")


ANCHOR_DROP = """
.......kk.......
......k&&k......
......k&&k......
.......kk.......
.......ka.......
.....kkakkk.....
.......a........
.......a........
..k....a....k...
.ka....a....ak..
.ka...aaa...ak..
..ka.aaaaa.ak...
...kaaaakaaak...
....kkkk.kkk....
................
................
"""


def build_anchor_drop():
    c = Canvas(16, 16)
    c.blit(ANCHOR_DROP, 0, 0)
    c.im.save(os.path.join(OUT, "anchor_drop.png"))
    return c.im


# ----------------------------------------------------------------------------- M6b: door signs, the vault, the key
SIGN_M6 = {
    # hourglass with a wave through it: hold until the tide turns
    "challenge": """
................
...kkkkkkkkkk...
...kGGGGGGGGk...
....kBBBBBBk....
.....kBBBBk.....
......kBBk......
.......kk.......
......kuuk......
.....kuBBuk.....
....kuBBBBuk....
...kBBBBBBBBk...
...kGGGGGGGGk...
...kkkkkkkkkk...
................
................
................
""",
    # padlock
    "vault": """
................
.....kkkkkk.....
....kGGGGGGk....
...kGk....kGk...
...kGk....kGk...
...kGk....kGk...
..kkkkkkkkkkkk..
..kIIIIIIIIIIk..
..kIIIIkkIIIIk..
..kIIIIkkIIIIk..
..kIIIIIkIIIIk..
..kIIIIIIIIIIk..
..kIIIIIIIIIIk..
..kkkkkkkkkkkk..
................
................
""",
    # bubbles rising from a lantern under the water line
    "dive": """
................
......kk........
.....kUuk.......
......kk...kk...
..........kUuk..
....kk.....kk...
...kUuk.........
....kk..........
.BBBBBBBBBBBBBB.
.BkkkkkkkkkkkkB.
.BkyyyyYyyyyykB.
.BkyyyYYYyyyykB.
.BkyyyyYyyyyykB.
.BkkkkkkkkkkkkB.
.BBBBBBBBBBBBBB.
................
""",
}
SIGN_M6_ORDER = ["challenge", "vault", "dive"]


def build_icons_m6(base):
    n0 = base.width // 24
    im = Image.new("RGBA", (24 * (n0 + len(SIGN_M6_ORDER)), 24), (0, 0, 0, 0))
    im.alpha_composite(base, (0, 0))
    for i, name in enumerate(SIGN_M6_ORDER):
        c = Canvas(24, 24)
        c.blit(G.SIGN_BOARD, 0, 0)
        c.blit(SIGN_M6[name], 4, 4)
        im.alpha_composite(c.im, (24 * (n0 + i), 0))
    im.save(os.path.join(OUT, "icons.png"))
    return im


VAULT = """
................
................
....kkkkkkkk....
...k99999999k...
..k9&&&&&&&&9k..
..k9&kkkkkk&9k..
..k9&k9II9k&9k..
..k9&k9IIk&&9k..
..k9&k9II9k&9k..
..k9&kkkkkk&9k..
..k9&&&&&&&&9k..
..k9999999999k..
..kkkkkkkkkkkk..
................
................
................
"""


def build_props_m6(base):
    n0 = base.width // 16
    im = Image.new("RGBA", (16 * (n0 + 1), 16), (0, 0, 0, 0))
    im.alpha_composite(base, (0, 0))
    c = Canvas(16, 16)
    c.blit(VAULT, 0, 0)
    im.alpha_composite(c.im, (16 * n0, 0))
    im.save(os.path.join(OUT, "props.png"))
    return im


KEY = """
.kkk....
kIIIk...
kIkIkkkk
kIIIkIIk
.kkk.kIk
.....kkk
........
........
"""


def build_pickups_m6(base):
    n0 = base.width // 8
    im = Image.new("RGBA", (8 * (n0 + 1), 8), (0, 0, 0, 0))
    im.alpha_composite(base, (0, 0))
    c = Canvas(8, 8)
    c.blit(KEY, 0, 0)
    im.alpha_composite(c.im, (8 * n0, 0))
    im.save(os.path.join(OUT, "pickups.png"))
    return im


# ----------------------------------------------------------------------------- M6c weapons (drawn pointing right, pivot at the left)
KEEPERS_BELL = """
......kkkkkkkk..
.....kGGGGGGGGk.
kkkkkkGggggggggk
kwwwwkGggggggggk
kkkkkkGggggggggk
.....kGGggggggGk
......kkkkkkkkk.
........kggk....
........kkkk....
"""
LINE_HANDLE = """
kkkkkkkkkk
kwwwwwwWWk
kwwwwwwWWk
kkkkkkkkkk
"""
SINKER = """
...kk...
..kGGk..
.kGggGk.
.kgggGk.
.kggggk.
..kggk..
...kk...
........
"""


def build_weapons_m6():
    out = {}
    c = Canvas(16, 9); c.blit(KEEPERS_BELL, 0, 0); c.im.save(os.path.join(OUT, "keepers_bell.png")); out["keepers_bell"] = c.im
    c = Canvas(10, 4); c.blit(LINE_HANDLE, 0, 0); c.im.save(os.path.join(OUT, "line_handle.png")); out["line_handle"] = c.im
    c = Canvas(8, 8); c.blit(SINKER, 0, 0); c.im.save(os.path.join(OUT, "sinker.png")); out["sinker"] = c.im
    return out


def build_all(built):
    built.update(build_weapons_m6())
    built["tiles"] = Image.open(os.path.join(OUT, "tiles.png")).convert("RGBA")  # art Stage 09 sheet
    # Art Stage 19: these are drawn by tools/gen_tiles.py (decor4) and tools/gen_enemies_b.py.
    for name in ("decor4", "mooring", "barnacle", "deckhand", "chainmother", "anchor_drop"):
        built[name] = Image.open(os.path.join(OUT, name + ".png")).convert("RGBA")
    built["icons"] = Image.open(os.path.join(OUT, "icons.png")).convert("RGBA")  # art Stage 09 sheet
    built["props"] = Image.open(os.path.join(OUT, "props.png")).convert("RGBA")  # art Stage 09 sheet
    built["pickups"] = build_pickups_m6(built["pickups"])
    return built
