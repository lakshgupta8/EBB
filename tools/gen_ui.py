"""Stage 16: the UI as a Tidekeeper's kit (STYLE.md 15).  Weathered ledger paper in an iron
frame, lantern glass, a brass tide gauge, rope ties; everything on the 1x pixel grid.

    ui_panel.png      24x24  nine-slice (8 px corners): Iron light rim, Ink, Night 1 face, 2x2 rivets
    ui_paper.png      24x24  nine-slice: the paper inset (Bone at 12 % over Night 1)
    ui_row.png        4 x 12x12  row states (3 px slices): normal, hover, pressed, disabled
    ui_tab.png        2 x 12x12  ledger tabs: inactive, active (Wood, Rope underline)
    ui_tri.png        3x5    the gamepad cursor: a Warm yellow triangle
    hud_health.png    66x8   the health bar's iron frame
    hud_pip.png       2 x 5x5   a dash lozenge, empty and filled (Sea pale)
    hud_special.png   26x6   the special bar's bronze frame
    hud_lantern.png   12x14  the lantern whose glass fills with glow
    hud_staff.png     10x128 the tide staff: an iron pole, brass marks at 1, 2, 3
    hud_boss.png      244x12 the boss bar: iron frame, rope binding at each end
    pickups.png       7 x 8x8   salt, pearl, key, page, glass, shell, fish (world and HUD)
    family_icons.png  5 x 7x7   salt, brine, current, deep, echo
    family_icons_big.png  5 x 15x15  the same at card size
    cursor.png        2 x 8x8   the pointer and the hook
    assets/reference/anchors/ui_sheet.png   every piece, and a mock HUD at 3x

Run:  python tools/gen_ui.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
from gen_anchors import grid, zoom  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
REF = os.path.join(P.ROOT, "assets", "reference", "anchors")


def rgba(key, a=255):
    return P.rgb(key) + (a,)


def blend(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def blank(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def strip(frames):
    w, h = frames[0].size
    out = blank(w * len(frames), h)
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * w, 0))
    return out


def ring(im, x0, y0, x1, y1, col):
    px = im.load()
    for x in range(x0, x1 + 1):
        px[x, y0] = col
        px[x, y1] = col
    for y in range(y0, y1 + 1):
        px[x0, y] = col
        px[x1, y] = col


def fill(im, x0, y0, x1, y1, col):
    px = im.load()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px[x, y] = col


# --- panels -------------------------------------------------------------------------------
def panel():
    im = blank(24, 24)
    fill(im, 0, 0, 23, 23, rgba("NIGHT_1"))
    ring(im, 0, 0, 23, 23, rgba("IRON_LIGHT"))
    ring(im, 1, 1, 22, 22, rgba("INK"))
    for (x, y) in ((2, 2), (20, 2), (2, 20), (20, 20)):
        fill(im, x, y, x + 1, y + 1, rgba("IRON_LIGHT"))
        im.load()[x + 1, y + 1] = rgba("IRON")
    # the corner pixels of the rim are Ink: a rounded iron corner
    px = im.load()
    for (x, y) in ((0, 0), (23, 0), (0, 23), (23, 23)):
        px[x, y] = rgba("INK")
    return im


def paper():
    face = blend(P.rgb("NIGHT_1"), P.rgb("BONE"), 0.12)
    edge = blend(P.rgb("NIGHT_1"), P.rgb("BONE"), 0.28)
    im = blank(24, 24)
    fill(im, 0, 0, 23, 23, face)
    ring(im, 0, 0, 23, 23, edge)
    return im


def row(face, edge, tick=None):
    im = blank(12, 12)
    fill(im, 0, 0, 11, 11, rgba(face))
    ring(im, 0, 0, 11, 11, rgba(edge))
    if tick:
        fill(im, 1, 1, 1, 10, rgba(tick))
    return im


def tab(active):
    im = blank(12, 12)
    fill(im, 0, 0, 11, 11, rgba("WOOD_LIGHT" if active else "WOOD"))
    ring(im, 0, 0, 11, 11, rgba("TAR"))
    fill(im, 1, 10, 10, 10, rgba("ROPE"))
    if active:
        fill(im, 1, 1, 10, 1, rgba("BONE_DARK"))
    return im


TRI = """
y..
yy.
yyy
yy.
y..
"""


# --- HUD instruments ------------------------------------------------------------------------
def health_frame():
    im = blank(66, 8)
    ring(im, 0, 0, 65, 7, rgba("IRON_LIGHT"))
    px = im.load()
    for (x, y) in ((0, 0), (65, 0), (0, 7), (65, 7)):
        px[x, y] = rgba("INK")
    return im


PIP_EMPTY = """
..I..
.I1I.
I111I
.I1I.
..I..
"""
PIP_FULL = """
..I..
.IPI.
IPPPI
.IPI.
..I..
"""


def special_frame():
    im = blank(26, 6)
    ring(im, 0, 0, 25, 5, rgba("BRONZE"))
    px = im.load()
    for (x, y) in ((0, 0), (25, 0), (0, 5), (25, 5)):
        px[x, y] = rgba("BRONZE_DARK")
    return im


LANTERN = """
....&&&&....
...~....~...
..%%%%%%%%..
..%~~~~~~%..
.%k......k%.
.%k......k%.
.%k......k%.
.%k......k%.
.%k......k%.
.%k......k%.
.%k......k%.
..%~~~~~~%..
..%%%%%%%%..
....~~~~....
"""
# the glass is x 3..8, y 4..10: the engine paints Night 1, then Warm yellow from the bottom


def staff():
    """10x128.  A hook eye at the top (rows 0-4), the pole with its channel (rows 5-122), a
    foot (rows 123-127).  The channel is x 2..7, y 6..121; the engine fills it with Sea."""
    im = blank(10, 128)
    px = im.load()
    ink, il, ir, idk = rgba("INK"), rgba("IRON_LIGHT"), rgba("IRON"), rgba("IRON_DARK")
    n1 = rgba("NIGHT_1")
    # eye
    eye = ["...kkkk...", "..kIIIIk..", "..kI..Ik..", "..kIIIIk..", ".kkIIIIkk."]
    for y, r in enumerate(eye):
        for x, ch in enumerate(r):
            if ch == "k":
                px[x, y] = ink
            elif ch == "I":
                px[x, y] = il
    # pole
    for y in range(5, 123):
        px[0, y] = ink
        px[1, y] = il
        for x in range(2, 8):
            px[x, y] = n1
        px[8, y] = ir
        px[9, y] = ink
    fill(im, 1, 5, 8, 5, il)
    fill(im, 1, 122, 8, 122, idk)
    # foot
    foot = ["kIIIIIIIIk", "kiiiiiiiik", "khhhhhhhhk", ".kkkkkkkk.", ".........."]
    for y, r in enumerate(foot):
        for x, ch in enumerate(r):
            c = {"k": ink, "I": il, "i": ir, "h": idk}.get(ch)
            if c:
                px[x, 123 + y] = c
    # brass marks at tide 1, 2, 3 of 4 across the channel, with a notch on both rims
    top, bottom = 6, 121
    for i in (1, 2, 3):
        y = bottom - int(round((bottom - top) * i / 4.0))
        for x in range(2, 8):
            px[x, y] = rgba("BRONZE_LIGHT") if x in (2, 7) else rgba("BRONZE")
        px[1, y] = rgba("BRONZE_LIGHT")
        px[8, y] = rgba("BRONZE_DARK")
    return im


def boss_frame():
    im = blank(244, 12)
    ring(im, 2, 1, 241, 10, rgba("IRON_LIGHT"))
    ring(im, 1, 0, 242, 11, rgba("INK"))
    # rope bindings, four columns each end
    for x0 in (0, 240):
        for y in range(12):
            for x in range(x0, x0 + 4):
                im.load()[x, y] = rgba("ROPE") if (x + y) % 3 else rgba("WEATHERED_BROWN")
        ring(im, x0, 0, x0 + 3, 11, rgba("INK"))
    return im


# --- icons ---------------------------------------------------------------------------------
PICKUPS = {
    "salt": """
...kk...
..kWWk..
.kWZWWk.
.kWWWWk.
kWZWWW6k
k6WWW66k
.k6666k.
..kkkk..
""",
    "pearl": """
........
..kkkk..
.k66Z6k.
k6Z6666k
k666666k
k666666k
.k6666k.
..kkkk..
""",
    "key": """
.kkk....
kIIIk...
kI.Ik...
kIIIkkk.
.kIkIkk.
..kI.k..
..kIIk..
..kkkk..
""",
    "page": """
.kkkkk..
.kVVVVk.
.kV33Vk.
.kVVVVk.
.kV3VVk.
.kVVVVk.
.kBBBBk.
.kkkkkk.
""",
    "glass": """
....kk..
...kPPk.
..kPZPk.
.kPPPPk.
kPZPPk..
kPPPk...
.kPk....
..k.....
""",
    "shell": """
...kkk..
..kVBVk.
.kVvBvBk
kBvBvBvk
kBBvBBvk
.kBBBBk.
..kvvk..
...kk...
""",
    "fish": """
........
...kkk..
..k66Wkk
.k6W66k6
kW6666k6
.k6666kk
..kkkk..
........
""",
}
PICKUP_ORDER = ["salt", "pearl", "key", "page", "glass", "shell", "fish"]

FAMILY_7 = {
    "salt": """
...W...
..WWW..
.#WZW#.
.#WWW#.
.##W##.
.#####.
.......
""",
    "brine": """
...z...
..zGz..
.zlzGz.
..zGz..
..lzl..
...z...
...l...
""",
    "current": """
.......
Z......
.PZ....
..PZ...
.PZ..Z.
PZ..PZ.
....P..
""",
    "deep": """
.DDDDD.
DDDQDDD
DQDDDDD
DDDDQDD
DDQDDDD
DDDDDDD
.DDDDD.
""",
    "echo": """
...a...
..aaa..
.a.c.a.
.a.c.a.
.a.c.a.
..aaa..
...a...
""",
}
FAMILY_15 = {
    "salt": """
.......W.......
......WWW......
.....WWZWW.....
..W..WWWWW..W..
.WWW.WWWWW.WWW.
##WWW#WWW#WWW##
###W#####W#W###
###############
###############
.#############.
.#############.
..###########..
...#########...
.....#####.....
...............
""",
    "brine": """
.......z.......
......zGz......
.....zGzGz.....
..z..zGlGz..z..
.zGz.zGlGz.zGz.
zGlGzzGlGzzGlGz
.zGlzzGlGzzlGz.
..zGl.zlz.lGz..
...zlz.l.zlz...
....zlzlzlz....
......zlz......
.......l.......
.......l.......
.......l.......
...............
""",
    "current": """
...............
Z..............
PZ.............
.PZ............
..PZ...........
...PZ..........
....PZ.....Z...
.....PZ...PZ...
..Z...PZ.PZ....
..PZ...PPZ.....
...PZ.........Z
....PZ.......PZ
.....PZ.....PZ.
......PZ...PZ..
.......PZ.PZ...
""",
    "deep": """
....DDDDDDD....
..DDDDDDDDDDD..
.DDDDDDQQDDDDD.
.DDDDDDQDDDDDD.
DDDDDDDDDDDDDDD
DDDQQDDDDDDDDDD
DDDQDDDDDDDDDDD
DDDDDDDDDQQDDDD
DDDDDDDDDQDDDDD
DDDDDDDDDDDDDDD
DDDDDQQDDDDDDDD
.DDDDQDDDDDDDD.
.DDDDDDDDDDDDD.
..DDDDDDDDDDD..
....DDDDDDD....
""",
    "echo": """
......aaa......
.....a...a.....
......aaa......
....aaaaaaa....
...a..ccc..a...
...a.ccccc.a...
...a.ccccc.a...
...a.ccccc.a...
...a.cc@cc.a...
...a..c@c..a...
...a...@...a...
....aaaaaaa....
.....aaaaa.....
......aaa......
...............
""",
}
FAMILY_ORDER = ["salt", "brine", "current", "deep", "echo"]

CURSOR = """
k.......
kk......
kWk.....
kWWk....
kWWWk...
kWWWWk..
kWkkkk..
kk......
"""
HOOK = """
..kkk...
.kIIIk..
.kIkkIk.
.kIk.kIk
.kIk..k.
.kIk....
.kIIk...
..kk....
"""


def main():
    os.makedirs(REF, exist_ok=True)
    built = {
        "ui_panel": panel(),
        "ui_paper": paper(),
        "ui_row": strip([row("NIGHT_2", "IRON_DARK"), row("SLATE", "IRON_LIGHT"),
                         row("NIGHT_1", "IRON_DARK", "WARM_YELLOW"), row("NIGHT_1", "IRON_DARK")]),
        "ui_tab": strip([tab(False), tab(True)]),
        "ui_tri": grid(TRI, 3, 5),
        "hud_health": health_frame(),
        "hud_pip": strip([grid(PIP_EMPTY, 5, 5), grid(PIP_FULL, 5, 5)]),
        "hud_special": special_frame(),
        "hud_lantern": grid(LANTERN, 12, 14),
        "hud_staff": staff(),
        "hud_boss": boss_frame(),
        "pickups": strip([grid(PICKUPS[n], 8, 8) for n in PICKUP_ORDER]),
        "family_icons": strip([grid(FAMILY_7[n], 7, 7) for n in FAMILY_ORDER]),
        "family_icons_big": strip([grid(FAMILY_15[n], 15, 15) for n in FAMILY_ORDER]),
        "cursor": strip([grid(CURSOR, 8, 8), grid(HOOK, 8, 8)]),
    }
    for name, im in built.items():
        im.save(os.path.join(SPRITES, name + ".png"))

    # --- review sheet ---
    try:
        font = ImageFont.load_default(size=11)
        small = ImageFont.load_default(size=9)
    except TypeError:
        font = small = ImageFont.load_default()
    W = 1400
    sheet = Image.new("RGBA", (W, 1500), (30, 33, 42, 255))
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "EBB UI  -  Stage 16  -  a Tidekeeper's kit: iron, paper, brass, rope", fill=P.rgb("SALT_WHITE"), font=font)
    y = 30
    Z = 4
    x = 12
    row_h = 0
    for name, im in built.items():
        zz = 2 if im.width > 200 or im.height > 100 else Z
        w = im.width * zz
        if x + w > W - 12:
            x = 12
            y += row_h + 18
            row_h = 0
        bg = Image.new("RGBA", im.size, P.rgba("SAND"))
        bg.alpha_composite(im)
        sheet.alpha_composite(zoom(bg, zz), (x, y))
        d.text((x, y + im.height * zz + 2), name, fill=P.rgb("PALE_SLATE"), font=small)
        x += w + 14
        row_h = max(row_h, im.height * zz + 12)
    y += row_h + 24

    # a mock HUD at 3x over sand and sea
    d.text((12, y), "the HUD as instruments, at 3x (health 70 %, two dashes, special ready, lantern half, tide 1.6, boss 60 %)", fill=P.rgb("PALE_SLATE"), font=small)
    y += 14
    mock = Image.new("RGBA", (320, 180), P.rgba("SAND"))
    fill(mock, 0, 120, 319, 179, P.rgba("SEA"))
    hp_frac = 0.7
    mock.alpha_composite(built["hud_health"], (7, 7))
    fill(mock, 8, 8, 71, 13, rgba("NIGHT_1"))
    fill(mock, 8, 8, 8 + int(64 * hp_frac) - 1, 13, rgba("SALT_RED"))
    fill(mock, 8, 8, 8 + int(64 * hp_frac) - 1, 8, rgba("PALE_CREAM"))
    for i in range(3):
        mock.alpha_composite(built["hud_pip"].crop((5, 0, 10, 5) if i < 2 else (0, 0, 5, 5)), (8 + i * 7, 18))
    mock.alpha_composite(built["hud_special"], (32, 17))
    fill(mock, 33, 18, 56, 21, rgba("NIGHT_1"))
    fill(mock, 33, 18, 56, 21, rgba("WARM_YELLOW"))
    mock.alpha_composite(built["hud_lantern"], (8, 26))
    fill(mock, 11, 30, 16, 36, rgba("NIGHT_1"))
    fill(mock, 11, 33, 16, 36, rgba("WARM_YELLOW"))
    for i, n in enumerate(FAMILY_ORDER):
        mock.alpha_composite(built["family_icons"].crop((i * 7, 0, i * 7 + 7, 7)), (8 + i * 9, 43))
    # currency
    mock.alpha_composite(built["pickups"].crop((0, 0, 8, 8)), (262, 7))
    mock.alpha_composite(built["pickups"].crop((8, 0, 16, 8)), (292, 7))
    # staff
    sx, sy = 304, 24
    mock.alpha_composite(built["hud_staff"], (sx, sy))
    top, bottom = sy + 6, sy + 121
    lvl = bottom - int(round((bottom - top) * 1.6 / 4.0))
    fill(mock, sx + 2, lvl, sx + 7, bottom, rgba("SEA"))
    fill(mock, sx + 2, lvl, sx + 7, lvl, rgba("FOAM_WHITE"))
    # boss
    bx, by = 38, 158
    mock.alpha_composite(built["hud_boss"], (bx, by))
    fill(mock, bx + 4, by + 2, bx + 239, by + 9, rgba("NIGHT_1"))
    fill(mock, bx + 4, by + 2, bx + 4 + int(236 * 0.6), by + 9, rgba("SALT_RED"))
    fill(mock, bx + 4 + 118, by + 2, bx + 4 + 118, by + 9, rgba("BRONZE"))
    # a panel with rows and a paper inset, and the family cards
    def nine(src, w, h, m):
        out = blank(w, h)
        sw, sh = src.size
        parts = [(0, 0, m, m), (m, 0, sw - m, m), (sw - m, 0, sw, m),
                 (0, m, m, sh - m), (m, m, sw - m, sh - m), (sw - m, m, sw, sh - m),
                 (0, sh - m, m, sh), (m, sh - m, sw - m, sh), (sw - m, sh - m, sw, sh)]
        dst = [(0, 0, m, m), (m, 0, w - m, m), (w - m, 0, w, m),
               (0, m, m, h - m), (m, m, w - m, h - m), (w - m, m, w, h - m),
               (0, h - m, m, h), (m, h - m, w - m, h), (w - m, h - m, w, h)]
        for s, t in zip(parts, dst):
            piece = src.crop(s).resize((max(1, t[2] - t[0]), max(1, t[3] - t[1])), Image.NEAREST)
            out.alpha_composite(piece, (t[0], t[1]))
        return out

    pan = nine(built["ui_panel"], 150, 96, 8)
    fill(pan, 3, 3, 146, 14, rgba("NIGHT_2"))
    fill(pan, 3, 14, 146, 14, rgba("ROPE"))
    pan.alpha_composite(nine(built["ui_paper"], 138, 30, 3), (6, 62))
    for i, st in enumerate((0, 1, 2, 3)):
        pan.alpha_composite(nine(built["ui_row"].crop((st * 12, 0, st * 12 + 12, 12)), 66, 12, 3), (6 + (i % 2) * 70, 20 + (i // 2) * 15))
    pan.alpha_composite(built["ui_tri"], (2, 24))
    for i, n in enumerate(FAMILY_ORDER):
        card = nine(built["ui_row"].crop((0, 0, 12, 12)), 26, 20, 3)
        fill(card, 0, 0, 1, 19, P.rgba(["SALT_RED", "VERDIGRIS", "SEA_PALE", "DEEP_VIOLET", "AMBER"][i]))
        card.alpha_composite(built["family_icons_big"].crop((i * 15, 0, i * 15 + 15, 15)), (6, 2))
        pan.alpha_composite(card, (6 + i * 28, 50 - 2))
    mock.alpha_composite(pan, (90, 30))
    mock.alpha_composite(built["cursor"].crop((0, 0, 8, 8)), (200, 100))
    mock.alpha_composite(built["cursor"].crop((8, 0, 16, 8)), (212, 100))
    sheet.alpha_composite(zoom(mock, 3), (12, y))
    y += 180 * 3 + 16
    sheet = sheet.crop((0, 0, W, y))
    sheet.convert("RGB").save(os.path.join(REF, "ui_sheet.png"))
    print("wrote %s, ui_sheet.png" % ", ".join(built.keys()))


if __name__ == "__main__":
    main()
