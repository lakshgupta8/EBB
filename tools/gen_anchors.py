"""Stage 05 visual anchors: the twelve samples every later asset is measured against.

Everything is drawn from text grids with tools/palette.py colours and the rules in
assets/reference/pixel_rules.png.  Outputs (all under assets/reference/anchors/):

    tam_a.png tam_b.png tam_c.png   Tam idle candidates (24x24)
    tam_walk.png                    Tam walk frame (24x24)
    shellback.png                   Shellback idle (24x24)
    citizen.png                     Still Citizen idle (24x24)
    flats_floor.png                 Sand base, two variants, low ground (4 x 16x16)
    flats_wall.png                  wall with face (north) and wall top (16x16 each) + cast band
    water.png                       shallow overlay, foam edge 3 frames, deep (16x16 each)
    fountain.png                    32x32 major prop
    gaff.png                        20x6 weapon, pivot at the left edge
    icon_salt.png                   7x7 and 15x15 Salt family icon
    panel.png                       nine-slice source 24x24, a 64x40 panel, a 48x12 row
    anchor_sheet.png                everything at 1x and 4x with captions
    mock_flats.png                  640x360 composition, lit
    mock_flats_2x.png               the same at 2x for review

Run:  python tools/gen_anchors.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402

OUT = os.path.join(P.ROOT, "assets", "reference", "anchors")

# One legend for every grid in this file.
LEG = {
    ".": None,
    "k": ("INK", 255), "K": ("INK", 115), "j": ("INK", 90),
    "0": ("ABYSS", 255), "1": ("NIGHT_1", 255), "2": ("NIGHT_2", 255), "3": ("SLATE", 255),
    "5": ("WET_GREY", 255), "6": ("PALE_SLATE", 255),
    "W": ("SALT_WHITE", 255), "Z": ("FOAM_WHITE", 255),
    "E": ("DEEP_SEA", 255), "e": ("SEA", 255), "S": ("SHALLOW", 255), "P": ("SEA_PALE", 255), "z": ("VERDIGRIS", 255),
    "=": ("SEA", 140), "-": ("SHALLOW", 200),                       # shallow overlay body, ripple
    "t": ("STONE_DARK", 255), "T": ("STONE", 255), "L": ("STONE_LIGHT", 255),
    "n": ("SAND_DARK", 255), "N": ("SAND", 255), "M": ("SAND_LIGHT", 255),
    "v": ("BONE_DARK", 255), "B": ("BONE", 255), "V": ("BONE_LIGHT", 255),
    "$": ("TAR", 255), "x": ("WOOD", 255), "X": ("WOOD_LIGHT", 255), "r": ("ROPE", 255), "R": ("WEATHERED_BROWN", 255),
    "h": ("IRON_DARK", 255), "i": ("IRON", 255), "I": ("IRON_LIGHT", 255),
    "u": ("RUST", 255), "U": ("RUST_LIGHT", 255),
    "~": ("BRONZE_DARK", 255), "%": ("BRONZE", 255), "&": ("BRONZE_LIGHT", 255),
    "_": ("MOSS_DARK", 255), "g": ("MOSS", 255), "l": ("KELP", 255), "G": ("KELP_LIGHT", 255),
    "s": ("SKIN_SHADE", 255), "f": ("SKIN", 255), "m": ("DROWNED_SHADE", 255), "F": ("DROWNED_SKIN", 255),
    "d": ("OILSKIN_DARK", 255), "o": ("OILSKIN", 255), "O": ("OILSKIN_LIGHT", 255),
    "b": ("WOOL_DARK", 255), "w": ("WOOL", 255), "A": ("WOOL_LIGHT", 255),
    "@": ("AMBER_DEEP", 255), "a": ("AMBER", 255), "y": ("WARM_YELLOW", 255), "c": ("PALE_CREAM", 255),
    "#": ("SALT_RED", 255), "D": ("DEEP_VIOLET", 255), "Q": ("VIOLET_LIGHT", 255),
}


def grid(text, w=None, h=None):
    rows = [r for r in text.strip("\n").split("\n")]
    gw = max(len(r) for r in rows)
    if w:
        assert gw <= w, "grid wider than %d: %d" % (w, gw)
    im = Image.new("RGBA", (w or gw, h or len(rows)), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            v = LEG.get(ch)
            if v is None and ch != ".":
                raise KeyError("unknown legend char %r" % ch)
            if v:
                px[x, y] = P.rgb(v[0]) + (v[1],)
    return im


def cell24(text):
    rows = text.strip("\n").split("\n")
    for i, r in enumerate(rows):
        assert len(r) == 24, "row %d is %d wide: %r" % (i, len(r), r)
    assert len(rows) == 24, "%d rows" % len(rows)
    return grid(text, 24, 24)


def zoom(im, z):
    return im.resize((im.width * z, im.height * z), Image.NEAREST)


# =============================================================================
# 1-2. Tam.  Hood rows 2-8 (7 wide), shoulders row 9 (9 wide), torso 10-16 (10 wide),
# legs 17-21, feet on row 21.  Lantern 5x7 hangs from the left hip (the off side).
# Facing right.  Eyes: two 1 px Ink.  Wet rim: Salt white on the hood crown and shoulder.
# =============================================================================
TAM_A = """
........................
..........kk............
.........kOok...........
........kOWook..........
.......kOoooooook.......
.......koddddddok.......
.......kodffffok........
.......kodfkfkok........
........kdffssdk........
.......kOWWOOOOOOk......
......koodooooodook.....
......koodooooodook.....
......koodooooodook.....
......koodooooodook.....
......koodooooodook.....
......kffdooooodffk.....
......kkkdddddddkkk.....
........kdddkdddk.......
........kdddkdddk.......
........kbbbkbbbk.......
........kbbbkbbbk.......
........kkkkkkkkk.......
........................
........................
"""

# B: rounder, deeper hood, a Wool scarf at the neck, slightly broader coat.
TAM_B = """
........................
........................
.........kkkkk..........
........kOWWOok.........
.......kOoooooook.......
.......koooooooook......
.......koddddddok.......
.......kodfkfkdok.......
........kdffssdk........
.......kAAOOOOOOAk......
......koodooooodook.....
......koodooooodook.....
......koodooooodook.....
......koodooooodook.....
......koodooooodook.....
......kffdooooodffk.....
......kkkdddddddkkk.....
........kdddkdddk.......
........kdddkdddk.......
........kbbbkbbbk.......
........kbbbkbbbk.......
........kkkkkkkkk.......
........................
........................
"""

# C: sou'wester hat (brim in Oilskin light), face more open, hair strand in Wool.
TAM_C = """
........................
........................
.........kkkkkk.........
........kOWWOook........
........kooooook........
......kOOOOOOOOOOk......
.......kddffffdk........
.......kodfkfkbk........
........kdffssdk........
.......kOWWOOOOOOk......
......koodooooodook.....
......koodooooodook.....
......koodooooodook.....
......koodooooodook.....
......koodooooodook.....
......kffdooooodffk.....
......kkkdddddddkkk.....
........kdddkdddk.......
........kdddkdddk.......
........kbbbkbbbk.......
........kbbbkbbbk.......
........kkkkkkkkk.......
........................
........................
"""

# Walk frame: legs apart (front boot forward and up, back boot behind), coat sways, arm swings.
TAM_WALK = """
........................
..........kk............
.........kOok...........
........kOWook..........
.......kOoooooook.......
.......koddddddok.......
.......kodffffok........
.......kodfkfkok........
........kdffssdk........
.......kOWWOOOOOOk......
......koodooooodook.....
......koodooooodook.....
......koodooooodook.....
......kffdooooodook.....
......kkkdooooodook.....
.........dooooodffk.....
.......kkdddddddkkk.....
.......kdddkkdddk.......
......kdddk..kdddk......
......kbbbk..kbbbk......
......kbbbk...kbbbk.....
......kkkkk...kkkkk.....
........................
........................
"""

LANTERN = """
.kIk.
khIhk
k%%%k
kyayk
kycyk
kyayk
k%%%k
.kkk.
"""


def tam(body_text, lantern_at=(2, 11)):
    im = cell24(body_text)
    im.alpha_composite(grid(LANTERN), lantern_at)
    return im


# =============================================================================
# 3. Shellback: a slow tank.  A stone-and-barnacle dome carried on a crab body.
# 22 wide, feet on row 21.  Claws Salt red (the only red).  Wet rim on the shell.
# =============================================================================
SHELLBACK = """
........................
........................
........................
........................
........................
........................
.........kkkkkkk........
.......kkvvBBBBvvkk.....
......kvvBBWWWBBvvvk....
.....kvvBvvvBBvvvBvvk...
....kvvBvvvvvvvvvvBvvk..
....kvvvvvBvvvvBvvvvvk..
...kvvBvvvvvvvvvvvvBvvk.
...kvvvvvvvvvBvvvvvvvvk.
...kvvvvvvvvvvvvvvvvvvkk
...kkkkkkkkkkkkkkkkkkk#k
..k#kuUuuuuuuuuukukukk#k
..k##kuuuuuuuuuuuuuk##kk
...kkuuk.kuuk..kuukk#k#k
..kuk...kuk....kuk..kkk.
.kuk....kuk....kuk......
.kk.....kk......kk......
........................
........................
"""

# =============================================================================
# 4. Still Citizen: a drowned villager standing very still.  Tam's skeleton, arms pinned,
# feet together.  Drowned skin, Slate coat, moss crust on the lower half, salt on the
# shoulders, a Sea pale rim on the crown and shoulders, one kelp strand.
# =============================================================================
# A fishwife in a headscarf and shawl, hands clasped, head a little bowed.  Drowned skin
# only on the face and hands; salt on the shoulders; moss as a low band at the hem; one
# kelp strand at the shoulder.  A person waiting, not a corpse.
CITIZEN = """
........................
........................
........kkkkkkkk........
.......kP3333333k.......
.......k3bFFFFb3k.......
.......k3bFFFFb3k.......
.......k3bFkFkb3k.......
........k3mFFm3k........
.......kW333333Wk.......
......k33333333l3k......
......k3332222333k......
......k3332222333k......
......k3332222333k......
......k3322222233k......
......k3322222233k......
......kkmFFFFmkkk.......
.......k22222222k.......
.......k22222222k.......
.......k2g2222g2k.......
.......kgg_gg_ggk.......
.......k_gg__gg_k.......
.......kkkkkkkkkk.......
........................
........................
"""

# =============================================================================
# 5. Flats floor: Sand base, two variants, low ground.  2-3 ripple lines, never noise.
# =============================================================================
FLOOR_BASE = """
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
"""
FLOOR_V1 = """
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNMMMMNNNNNNNNN
NNNNNNNMMNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNMMMMN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NMMMNNNNNNNNNNNN
NNNNMMNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
"""
FLOOR_V2 = """
NNNNNNNNNNNNNNNN
NNNNNNNNNMMMNNNN
NNNNNNNNNNNNMMNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
"""
FLOOR_LOW = """
nnnnnnnnnnnnnnnn
nnnnnnnnnnnnnnnn
nnNNNNnnnnnnnnnn
nnnnnnNNnnnnnnnn
nnnnnnnnnnnnnnnn
nnnnnnnnnnnnnnnn
nnnnnnnnnnnnnnnn
nnnnnnnnnnnnNNNn
nnnnnnnnnnnnnnnn
nnnnnnnnnnnnnnnn
nnnnnnnnnnnnnnnn
nNNNnnnnnnnnnnnn
nnnnNNnnnnnnnnnn
nnnnnnnnnnnnnnnn
nnnnnnnnnnnnnnnn
nnnnnnnnnnnnnnnn
"""

# =============================================================================
# 6. Flats wall.  North wall in one tile: 5 px top (Stone light, salt crust),
# 10 px face (Stone dark with 3-5 drawn stones), 1 px Ink foot.  Other sides: top only
# with an Ink foot line on the inner edge (drawn by the composer per side).
# =============================================================================
WALL_FACE = """
LLLLLLLLLLLLLLLL
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
tttttttttttttttt
ttTTTTTttTTTTTtt
ttTTTTTttTTTTTtt
tttttttttttttttt
tTTTTttTTTTTTTtt
tTTTTttTTTTTTTtt
tttttttttttttttt
ttTTTTTTTttTTTTt
ttTTTTTTTttTTTTt
tttttttttttttttt
tttttttttttttttt
kkkkkkkkkkkkkkkk
"""
WALL_TOP = """
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTLLLTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTLLTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
"""
# 1 in 6 wall-top tiles carries a salt crust cluster (2-3 px, Salt white on a Stone light lift).
WALL_TOP_CRUST = """
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTLWWLTTTT
TTTTTTTTTLWTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTT
"""
BAND_S = "\n".join(["j" * 16] * 3 + ["." * 16] * 13)       # 3 px south band overlay
BAND_W = "\n".join(["j" + "." * 15] * 16)                   # 1 px band along a west wall's east edge
BAND_E = "\n".join(["." * 15 + "j"] * 16)

# =============================================================================
# 7. Water.  Shallow overlay: Sea at 55 % with one Shallow ripple run.  Foam edge (shore to
# the north): 2 px Salt white body, 1 px Foam white crest, 3 frames.  Deep: opaque.
# =============================================================================
SHALLOW = """
================
================
================
================
================
=====-----======
================
================
================
================
================
================
==========---===
================
================
================
"""
FOAM = [
    """
ZZZZWWZZZZZWWWZZ
WWWWWWWWWWWWWWWW
=WW=====WW======
================
================
================
================
================
================
================
================
================
================
================
================
================
""",
    """
ZZWWZZZZWWZZZZWW
WWWWWWWWWWWWWWWW
====WW=====WW===
================
================
================
================
================
================
================
================
================
================
================
================
================
""",
    """
WZZZZWWZZZZZZWWZ
WWWWWWWWWWWWWWWW
==WW======WW====
================
================
================
================
================
================
================
================
================
================
================
================
================
""",
]
DEEP = """
EEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEE
EEEEEeeeEEEEEEEE
EEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEE
EEEEEEEEEEEEeeEE
EEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEE
"""
WET_BAND = "\n".join(["." * 16] * 14 + ["n" * 16] * 2)      # 2 px of the floor's dark colour on the dry side
TIDE_LINE = "\n".join(["." * 16] * 15 + ["W" * 16])          # 1 px Salt white where low meets normal floor

# =============================================================================
# 8. Fountain 32x32: a stone basin, water inside with a Salt white rim, a column with a
# Sea pale spout.  Grounding edge Stone dark on the bottom and right, open on top/left.
# =============================================================================
FOUNTAIN = """
..............PP................
.............kPPk...............
.............kPPk...............
............LLPPLL..............
............LTPPTLt.............
............LTPPTLt.............
............LTPPTLt.............
............LTTTTLt.............
..........LLLTTTTLLLt...........
.........LLTTTTTTTTLLt..........
........LLTTTTTTTTTTLLt.........
....LLLLLLLLLLLLLLLLLLLLLLt.....
...LLWWWWLLLLLLLLLLLLLLLLLLt....
..LLTTTTTTTTTTTTTTTTTTTTTTTTt...
..LTTTTTTTTTTTTTTTTTTTTTTTTTTt..
..LTTeeeeeeeeeeeeeeeeeeeeeeTTt..
..LTeeeeeeeeeeeePPeeeeeeeeeeTt..
..LTeeeSSeeeeeePWWPeeeeSSeeeTt..
..LTeeeeeeeeeeeePPeeeeeeeeeeTt..
..LTTeeeeeeeeeeeeeeeeeeeeeeTTt..
..LTTTTTTTTTTTTTTTTTTTTTTTTTTt..
..LTTTTTTTTTTTTTTTTTTTTTTTTTTt..
..LtTTTTTTTTTTTTTTTTTTTTTTTTtt..
..LtTTTTTTTTTTTTTTTTTTTTTTTTtt..
..LttTTTTTTTTTTTTTTTTTTTTTTttt..
..ttttTTTTTTTTTTTTTTTTTTTttttt..
..tttttttttttttttttttttttttttt..
.jjjjjjjjjjjjjjjjjjjjjjjjjjjjjj.
.jjjjjjjjjjjjjjjjjjjjjjjjjjjjjj.
................................
................................
................................
"""

# =============================================================================
# 9. Gaff hook 20x6, pivot at the left edge, pointing right.
# =============================================================================
GAFF = """
kkkkkkkkkkkkkkkk.kk.
krrxXXXXXXXXXXXkkIIk
krrxxxxxxxxxxxxkiihk
kkkkkkkkkkkkkkkkhkkk
...............kkk..
....................
"""

# =============================================================================
# 10. Salt family icon: a crystal cluster, Salt white on Salt red.  7x7 and 15x15.
# =============================================================================
ICON7 = """
.kkkkk.
k##W##k
k#WWW#k
k#WWW#k
k##W##k
k##W##k
.kkkkk.
"""
ICON15 = """
....kkkkkkk....
..kk#######kk..
.k####Z######k.
.k###WW######k.
k###WWWW#####Wk
k##WWWWW##Z#W#k
k##WWWWW#WW#W#k
k###WWW#WWW##Wk
k###WWW#WWWW##k
k####W##WWW###k
k####W###W####k
.k###W###W###k.
.k###########k.
..kk#######kk..
....kkkkkkk....
"""

# =============================================================================
# 11. Panel: outer 1 px Iron light, 1 px Ink, Night 1 face; 2x2 Iron light rivets in the
# corners; header band Night 2 with a Rope underline.  24x24 nine-slice source (8 px corners).
# =============================================================================
PANEL9 = """
IIIIIIIIIIIIIIIIIIIIIIII
IkkkkkkkkkkkkkkkkkkkkkkI
IkIIkkkkkkkkkkkkkkkkIIkI
IkII1111111111111111IIkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
Ikk111111111111111111kkI
IkII1111111111111111IIkI
IkIIkkkkkkkkkkkkkkkkIIkI
IkkkkkkkkkkkkkkkkkkkkkkI
IIIIIIIIIIIIIIIIIIIIIIII
"""
ROW = """
hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
h##2222222222222222222222222222222222222222222h
h##2222222222222222222222222222222222222222222h
h##2222222222222222222222222222222222222222222h
h##2222222222222222222222222222222222222222222h
h##2222222222222222222222222222222222222222222h
h##2222222222222222222222222222222222222222222h
h##2222222222222222222222222222222222222222222h
h##2222222222222222222222222222222222222222222h
h##2222222222222222222222222222222222222222222h
h##2222222222222222222222222222222222222222222h
hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
"""


def nine_slice(src, w, h, c=8):
    """Stretch a 24x24 nine-slice source to w x h."""
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sw, sh = src.size
    mid_w, mid_h = sw - 2 * c, sh - 2 * c
    xs = [(0, c, 0, c), (c, sw - c, c, w - c), (sw - c, sw, w - c, w)]
    ys = [(0, c, 0, c), (c, sh - c, c, h - c), (sh - c, sh, h - c, h)]
    for sy0, sy1, dy0, dy1 in ys:
        for sx0, sx1, dx0, dx1 in xs:
            part = src.crop((sx0, sy0, sx1, sy1))
            if (dx1 - dx0, dy1 - dy0) != part.size:
                part = part.resize((max(1, dx1 - dx0), max(1, dy1 - dy0)), Image.NEAREST)
            out.alpha_composite(part, (dx0, dy0))
    return out


def panel(w, h, header=12):
    src = grid(PANEL9)
    im = nine_slice(src, w, h)
    if header:
        band = Image.new("RGBA", (w - 6, header), P.rgba("NIGHT_2"))
        im.alpha_composite(band, (3, 3))
        line = Image.new("RGBA", (w - 6, 1), P.rgba("ROPE"))
        im.alpha_composite(line, (3, 3 + header))
    return im


# =============================================================================
# Shadows, lights, composition
# =============================================================================
def blob(w, h=4):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, w - 1, h - 1], fill=P.rgb("INK") + (115,))
    return im


def light_layer(size, sources):
    """Additive light: two-zone falloff (flat core, steep edge).  Returns an RGB float image."""
    w, h = size
    acc = [[(0.0, 0.0, 0.0)] * w for _ in range(h)]
    for (cx, cy, radius, core, colour, energy) in sources:
        col = P.rgb(colour) if isinstance(colour, str) else colour
        r2 = radius * radius
        x0, x1 = max(0, int(cx - radius)), min(w, int(cx + radius) + 1)
        y0, y1 = max(0, int(cy - radius)), min(h, int(cy + radius) + 1)
        for y in range(y0, y1):
            row = acc[y]
            for x in range(x0, x1):
                dx, dy = x - cx, y - cy
                d2 = dx * dx + dy * dy
                if d2 >= r2:
                    continue
                dist = math.sqrt(d2)
                if dist <= core:
                    f = 0.4
                else:
                    t = (dist - core) / (radius - core)
                    f = 0.4 * (1.0 - t) ** 1.5
                f *= energy
                r, g, b = row[x]
                row[x] = (r + col[0] * f, g + col[1] * f, b + col[2] * f)
    return acc


def apply_lights(im, acc, tint):
    px = im.load()
    w, h = im.size
    for y in range(h):
        row = acc[y]
        for x in range(w):
            r, g, b, a = px[x, y]
            lr, lg, lb = row[x]
            r = min(255, int((r + lr) * tint[0]))
            g = min(255, int((g + lg) * tint[1]))
            b = min(255, int((b + lb) * tint[2]))
            px[x, y] = (r, g, b, 255)
    return im


def draw_text_px(im, x, y, s, colour, shadow=True):
    """Crude 3x5 pixel caps for HUD numbers/labels in the mock (not the game font)."""
    glyphs = {
        "0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
        "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001001001",
        "8": "111101111101111", "9": "111101111001111", "H": "101101111101101", "P": "111101111100100",
        "S": "111100111001111", "A": "010101111101101", "L": "100100100100111", "T": "111010010010010",
        "F": "111100111100100", " ": "000000000000000", "E": "111100111100111", "M": "101111111101101",
        "R": "111101111110101", "O": "111101101101111", "W": "101101101111101", "K": "101110100110101",
        "C": "111100100100111", "D": "110101101101110", "I": "111010010010111", "N": "110101101101101",
    }
    px = im.load()
    for ch in s.upper():
        g = glyphs.get(ch, glyphs[" "])
        for i, bit in enumerate(g):
            if bit == "1":
                gx, gy = x + i % 3, y + i // 3
                if shadow:
                    px[gx + 1, gy + 1] = P.rgb("INK") + (255,)
        for i, bit in enumerate(g):
            if bit == "1":
                px[x + i % 3, y + i // 3] = P.rgb(colour) + (255,)
        x += 4
    return x


def compose_mock(assets, ents=None, hud=True, extra=None):
    """ents: list of (asset key, x, y, blob width) drawn in feet order; extra: list of
    (image, x, y) drawn over the entities before lighting (projectiles, effects)."""
    W, H = 640, 360
    im = Image.new("RGBA", (W, H), P.rgba("ABYSS"))
    TW = 16
    cols, rows = 40, 22
    # height map: 0 = floor, -1 = low, 9 = wall
    hm = [[0] * cols for _ in range(rows)]
    for x in range(cols):
        hm[0][x] = 9
        hm[rows - 1][x] = 9
    for y in range(rows):
        hm[y][0] = 9
        hm[y][cols - 1] = 9
    # a rock shelf wall jutting in from the left, a low-ground bay on the right
    for x in range(1, 8):
        hm[9][x] = 9
    for y in range(4, 19):
        for x in range(27, 39):
            if (x - 27) + abs(y - 11) * 0.6 > 3:
                hm[y][x] = -1
    # water covers the outer part of the bay
    water = [[False] * cols for _ in range(rows)]
    for y in range(rows):
        for x in range(cols):
            if hm[y][x] == -1 and (x - 27) + abs(y - 11) * 0.6 > 6:
                water[y][x] = True

    floors = [assets["floor_base"], assets["floor_v1"], assets["floor_v2"]]
    import random
    rnd = random.Random(5)
    for y in range(rows):
        for x in range(cols):
            h = hm[y][x]
            if h == 9:
                # north wall shows its face; others show the top
                face = (y == 0) or (y + 1 < rows and hm[y + 1][x] != 9 and y < rows - 1 and hm[y][x] == 9 and y != rows - 1 and (y == 0 or hm[y - 1][x] == 9 or True) and y != rows - 1 and (y + 1 < rows and hm[y + 1][x] != 9))
                tile = assets["wall_face"] if face and y != rows - 1 else (assets["wall_top_crust"] if (x * 7 + y * 3) % 6 == 0 else assets["wall_top"])
                im.alpha_composite(tile, (x * TW, y * TW))
            elif h == -1:
                im.alpha_composite(assets["floor_low"], (x * TW, y * TW))
            else:
                pick = floors[0] if rnd.random() < 0.6 else rnd.choice(floors[1:])
                im.alpha_composite(pick, (x * TW, y * TW))
    # tide line where low meets normal floor (on the normal side), cast bands, foot lines
    for y in range(rows):
        for x in range(cols):
            h = hm[y][x]
            if h == 0:
                for (dx, dy, rot) in ((0, 1, 0), (1, 0, 90), (0, -1, 180), (-1, 0, 270)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < cols and 0 <= ny < rows and hm[ny][nx] == -1:
                        im.alpha_composite(assets["tide_line"].rotate(rot), (x * TW, y * TW))
                if y > 0 and hm[y - 1][x] == 9:
                    im.alpha_composite(assets["band_s"], (x * TW, y * TW))
                if x > 0 and hm[y][x - 1] == 9:
                    im.alpha_composite(assets["band_w"], (x * TW, y * TW))
                    foot = Image.new("RGBA", (1, TW), P.rgba("INK"))
                    im.alpha_composite(foot, (x * TW - 1, y * TW))
                if x + 1 < cols and hm[y][x + 1] == 9:
                    im.alpha_composite(assets["band_e"], (x * TW, y * TW))
                    foot = Image.new("RGBA", (1, TW), P.rgba("INK"))
                    im.alpha_composite(foot, ((x + 1) * TW, y * TW))
                if y + 1 < rows and hm[y + 1][x] == 9:
                    foot = Image.new("RGBA", (TW, 1), P.rgba("INK"))
                    im.alpha_composite(foot, (x * TW, (y + 1) * TW))
    # water overlay: shallow with foam on shore sides, wet band on the dry side
    for y in range(rows):
        for x in range(cols):
            if not water[y][x]:
                continue
            im.alpha_composite(assets["shallow"], (x * TW, y * TW))
            # foam faces whichever neighbour is dry; the anchor foam tile has the shore to the north
            for (dx, dy, rot) in ((0, -1, 0), (-1, 0, 90), (0, 1, 180), (1, 0, 270)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < cols and 0 <= ny < rows and not water[ny][nx] and hm[ny][nx] != 9:
                    f = assets["foam"][(x + y) % 3].rotate(rot)
                    im.alpha_composite(f, (x * TW, y * TW))
                    wb = assets["wet_band"].rotate(rot)
                    im.alpha_composite(wb, (nx * TW, ny * TW))
    # entities (sorted by feet y)
    tam_x, tam_y = 296, 168
    if ents is None:
        ents = [("tam", tam_x, tam_y, 14), ("shellback", 400, 120, 20), ("shellback", 200, 232, 20),
                ("shellback", 470, 250, 20), ("citizen", 120, 130, 14), ("citizen", 380, 300, 14)]
    else:
        for e in ents:
            if e[0] == "tam":
                tam_x, tam_y = e[1], e[2]
    ents = list(ents) + [("fountain", 304, 24, 0)]
    for kind, x, y, bw in sorted(ents, key=lambda e: e[2]):
        spr = assets[kind]
        if kind == "fountain":
            im.alpha_composite(spr, (x, y))
            continue
        if bw:
            im.alpha_composite(blob(bw), (x + (spr.width - bw) // 2, y + spr.height - 4))
        im.alpha_composite(spr, (x, y))
    # gaff held by Tam, pointing right from the hip
    im.alpha_composite(assets["gaff"], (tam_x + 14, tam_y + 12))
    for img, x, y in (extra or []):
        im.alpha_composite(img, (x, y))
    # lights: Tam's lantern (warm) and the fountain (cold)
    warm = tuple(int(a * 0.4 + b * 0.6) for a, b in zip(P.rgb("WARM_YELLOW"), P.rgb("PALE_CREAM")))
    acc = light_layer((W, H), [
        (tam_x + 4, tam_y + 15, 75, 30, warm, 0.7),
        (320, 40, 40, 12, "SEA_PALE", 0.4),
    ])
    apply_lights(im, acc, P.NIGHT_TINT_RUN)
    if not hud:
        return im
    # HUD: health in an iron frame, dash pips, a salt count with the family icon
    hud = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    frame = Image.new("RGBA", (66, 8), P.rgba("IRON_LIGHT"))
    inner = Image.new("RGBA", (64, 6), P.rgba("NIGHT_1"))
    fill = Image.new("RGBA", (44, 6), P.rgba("SALT_RED"))
    top = Image.new("RGBA", (44, 1), P.rgba("PALE_CREAM"))
    frame.alpha_composite(inner, (1, 1))
    frame.alpha_composite(fill, (1, 1))
    frame.alpha_composite(top, (1, 1))
    hud.alpha_composite(frame, (8, 8))
    draw_text_px(hud, 78, 9, "34", "SALT_WHITE")
    for i in range(3):
        pip = Image.new("RGBA", (5, 5), P.rgba("IRON_LIGHT"))
        pip.alpha_composite(Image.new("RGBA", (3, 3), P.rgba("SEA_PALE" if i < 2 else "NIGHT_1")), (1, 1))
        hud.alpha_composite(pip, (8 + i * 7, 19))
    hud.alpha_composite(assets["icon7"], (W - 40, 8))
    draw_text_px(hud, W - 30, 9, "30", "SALT_WHITE")
    # a small dialog-style panel bottom-left to show the nine-slice in place
    p = panel(120, 28)
    hud.alpha_composite(p, (8, H - 36))
    draw_text_px(hud, 14, H - 32, "THE FLATS", "SALT_WHITE", shadow=False)
    draw_text_px(hud, 14, H - 22, "TIDE 1", "PALE_SLATE", shadow=False)
    im.alpha_composite(hud)
    return im


def build_assets():
    A = {}
    A["tam_a"] = tam(TAM_A)
    A["tam_b"] = tam(TAM_B)
    A["tam_c"] = tam(TAM_C)
    A["tam_walk"] = tam(TAM_WALK, (1, 12))
    A["tam"] = A["tam_a"]
    A["shellback"] = cell24(SHELLBACK)
    A["citizen"] = cell24(CITIZEN)
    A["floor_base"], A["floor_v1"], A["floor_v2"], A["floor_low"] = [grid(t, 16, 16) for t in (FLOOR_BASE, FLOOR_V1, FLOOR_V2, FLOOR_LOW)]
    A["wall_face"], A["wall_top"], A["wall_top_crust"] = grid(WALL_FACE, 16, 16), grid(WALL_TOP, 16, 16), grid(WALL_TOP_CRUST, 16, 16)
    A["band_s"], A["band_w"], A["band_e"] = grid(BAND_S, 16, 16), grid(BAND_W, 16, 16), grid(BAND_E, 16, 16)
    A["shallow"], A["deep"] = grid(SHALLOW, 16, 16), grid(DEEP, 16, 16)
    A["foam"] = [grid(f, 16, 16) for f in FOAM]
    A["wet_band"], A["tide_line"] = grid(WET_BAND, 16, 16), grid(TIDE_LINE, 16, 16)
    A["fountain"] = grid(FOUNTAIN, 32, 32)
    A["gaff"] = grid(GAFF, 20, 6)
    A["icon7"], A["icon15"] = grid(ICON7, 7, 7), grid(ICON15, 15, 15)
    A["panel9"] = grid(PANEL9, 24, 24)
    A["panel"] = panel(64, 40)
    A["row"] = grid(ROW, 48, 12)
    return A


def main():
    os.makedirs(OUT, exist_ok=True)
    A = build_assets()

    def save(name, im):
        im.save(os.path.join(OUT, name + ".png"))

    for k in ("tam_a", "tam_b", "tam_c", "tam_walk", "shellback", "citizen", "fountain", "gaff", "panel9"):
        save(k, A[k])
    strip = Image.new("RGBA", (64, 16))
    for i, k in enumerate(("floor_base", "floor_v1", "floor_v2", "floor_low")):
        strip.alpha_composite(A[k], (i * 16, 0))
    save("flats_floor", strip)
    strip = Image.new("RGBA", (64, 16))
    for i, k in enumerate(("wall_face", "wall_top", "wall_top_crust", "band_s")):
        strip.alpha_composite(A[k], (i * 16, 0))
    save("flats_wall", strip)
    strip = Image.new("RGBA", (80, 16))
    strip.alpha_composite(A["shallow"], (0, 0))
    for i in range(3):
        strip.alpha_composite(A["shallow"], (16 + i * 16, 0))
        strip.alpha_composite(A["foam"][i], (16 + i * 16, 0))
    strip.alpha_composite(A["deep"], (64, 0))
    save("water", strip)
    strip = Image.new("RGBA", (24, 15))
    strip.alpha_composite(A["icon7"], (0, 4))
    strip.alpha_composite(A["icon15"], (9, 0))
    save("icon_salt", strip)
    strip = Image.new("RGBA", (24 + 4 + 64 + 4 + 48, 40))
    strip.alpha_composite(A["panel9"], (0, 0))
    strip.alpha_composite(A["panel"], (28, 0))
    strip.alpha_composite(A["row"], (96, 0))
    save("panel", strip)

    mock = compose_mock(A)
    save("mock_flats", mock)
    save("mock_flats_2x", zoom(mock, 2))

    # --- anchor sheet ---
    try:
        font = ImageFont.load_default(size=11)
        big = ImageFont.load_default(size=15)
        small = ImageFont.load_default(size=9)
    except TypeError:
        font = big = small = ImageFont.load_default()
    sand = P.rgba("SAND")
    items = [
        ("1. Tam idle A: peaked hood", A["tam_a"], sand),
        ("1. Tam idle B: round hood, scarf", A["tam_b"], sand),
        ("1. Tam idle C: sou'wester", A["tam_c"], sand),
        ("2. Tam walk (from A)", A["tam_walk"], sand),
        ("3. Shellback idle", A["shellback"], sand),
        ("4. Still Citizen idle", A["citizen"], P.rgba("STONE")),
        ("5. Flats floor: base, v1, v2, low", Image.open(os.path.join(OUT, "flats_floor.png")), None),
        ("6. Flats wall: face, top, cast band", Image.open(os.path.join(OUT, "flats_wall.png")), sand),
        ("7. Water: shallow, foam x3, deep (over Sand)", Image.open(os.path.join(OUT, "water.png")), sand),
        ("8. Fountain 32x32", A["fountain"], sand),
        ("9. Gaff hook 20x6", A["gaff"], sand),
        ("10. Salt icon 7 / 15", Image.open(os.path.join(OUT, "icon_salt.png")), P.rgba("NIGHT_1")),
        ("11. Panel nine-slice, panel, row", Image.open(os.path.join(OUT, "panel.png")), P.rgba("NIGHT_2")),
    ]
    W = 1180
    sheet = Image.new("RGBA", (W, 900), (30, 33, 42, 255))
    d = ImageDraw.Draw(sheet)
    d.text((12, 10), "EBB visual anchors  -  Stage 05  -  1x and 4x  -  drawn from STYLE.md 6, 7, 12, 15, 18 and the pixel rule sheet", fill=P.rgb("SALT_WHITE"), font=big)
    d.text((12, 30), "Backgrounds are the floor the thing usually stands on. The lit composition is mock_flats.png.", fill=P.rgb("PALE_SLATE"), font=font)
    x, y, row_h = 12, 56, 0
    for cap, img, bg in items:
        base = Image.new("RGBA", (img.width + 4, img.height + 4), bg or (0, 0, 0, 0))
        if bg is None:
            base = Image.new("RGBA", (img.width + 4, img.height + 4), (60, 64, 74, 255))
        base.alpha_composite(img, (2, 2))
        four = zoom(base, 4)
        w = max(four.width, 140) + base.width + 8
        if x + w > W - 12:
            x = 12
            y += row_h + 26
            row_h = 0
        sheet.alpha_composite(base, (x, y))
        sheet.alpha_composite(four, (x + base.width + 6, y))
        d.text((x, y + four.height + 3), cap, fill=P.rgb("VERDIGRIS"), font=small)
        x += w + 16
        row_h = max(row_h, four.height)
    y += row_h + 30
    sheet = sheet.crop((0, 0, W, y))
    sheet.convert("RGB").save(os.path.join(OUT, "anchor_sheet.png"))
    print("wrote", OUT, sheet.size)


if __name__ == "__main__":
    main()
