"""Stage 14: weapons.  One fisher's kit: iron, wood, rope, brass, bone (STYLE.md 6, 14).

Held weapons are drawn pointing right with the pivot at the left edge, vertical centre; the
engine rotates them to the aim and mirrors them across the shaft when Tam faces left, so a
hook never hangs upside down.  Every one keeps a full 1 px Ink outline and forms at least 2 px
thick, so it still reads at any angle.

    gaff_hook.png      22x8    a wood pole, rope-bound at the grip, an iron L-hook at the end
    knife.png          14x6    a bone handle wrapped in rope, an iron blade sharp along the top
    harpoon_gun.png    20x8    an iron barrel on a wood stock, a brass band, the bolt's tip showing
    harpoon_bolt.png   14x4    an iron shaft, a bone barb, a rope tail
    storm_lantern.png  16x10   a short iron rod with Tam's lantern (brass, warm glass, cream core)
    beacon.png         2x16x16 that lantern set down on the ground, its flame in two frames
    keepers_bell.png   16x10   a wood handle and a bronze hand bell, the iron clapper inside
    line_handle.png    12x6    a wood hand-line winder wound with rope
    sinker.png         8x8     a lead weight on a rope loop
    net.png            24x24   a round rope net with wood knots and a rope rim; never rotated
    lantern_shot.png   8x8     the lamplighter's thrown lantern
    toll.png           8x8     the bell's toll, a bronze crescent
    debris.png         8x8     a plank chunk off the Wreck
    assets/reference/anchors/weapons_sheet.png   every piece at 6x, and each held weapon in
                       Tam's hand at eight aims (mirrored past the vertical, as the engine does)

Run:  python tools/gen_weapons.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
from gen_anchors import grid, zoom  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
REF = os.path.join(P.ROOT, "assets", "reference", "anchors")

GAFF = """
..................kk..
.................khIk.
.................khhk.
kkkkkkkkkkkkkkkkkkhhk.
kXXXrXrXXXXXXXXXkhhhk.
kxxxrxrxxxxxxxxxxkhhk.
kkkkkkkkkkkkkkkkkkkkk.
......................
"""
KNIFE = """
......kkkkkkk.
.kkkkkIIIIIIkk
kBrBrBkiiiiiik
kvrvrvkhhhhhkk
.kkkkkkkkkkkk.
..............
"""
HARPOON_GUN = """
....kkkkkkkkkkkkkkk.
...kIIIiiiiiiiiiiiik
..kkhhhhhhhhhhhhhhhk
kkxXXk%%kkkkkkkkkkkk
kxXxxxk%k...........
kxxxk.kkk...........
kkkkk...............
....................
"""
HARPOON_BOLT = """
........kkkkk.
rrkiiiiiIIvBBk
rrkhhhhhhhvBk.
........kkkk..
"""
STORM_LANTERN = """
........kkkkkk..
........k~%%~k..
........k~yy~k..
kkkkkkkkk%ycy%k.
kiiiiiii%yccy%k.
kIIIIIIi%ycay%k.
kkkkkkkkk%aay%k.
........k~%%~k..
........kkkkkk..
................
"""
BEACON_A = """
......kkkk......
.....k~%%~k.....
......k~~k......
.....kkkkkk.....
....k~%%%%~k....
....k%aaaa%k....
....k%yccy%k....
....k%yccy%k....
....k%ycyy%k....
....k%yyay%k....
....k%aaaa%k....
....k~%%%%~k....
....kk~~~~kk....
.....kkkkkk.....
................
................
"""
BEACON_B = """
......kkkk......
.....k~%%~k.....
......k~~k......
.....kkkkkk.....
....k~%%%%~k....
....k%aaaa%k....
....k%yycy%k....
....k%yccy%k....
....k%yccy%k....
....k%yyay%k....
....k%aaaa%k....
....k~%%%%~k....
....kk~~~~kk....
.....kkkkkk.....
................
................
"""
KEEPERS_BELL = """
.......kkkkkk...
.......k&%%%~kk.
kkkkkkk&%%%%%~~k
kXXXXXk&%%%%%%~k
kxxxxxk%%%iii%~k
kkkkkkk~%%%%%~~k
.......k~~~~~~k.
.......kkkkkkkk.
................
................
"""
LINE_HANDLE = """
...kkkkkkkk.
kkkkrRrRrRkk
kXXkrrrrrrrk
kxxkRrRrRrkk
kkkkkkkkkkk.
............
"""
SINKER = """
...rr...
..r..r..
..kkkk..
.khiiik.
.khiiIk.
.khiiik.
..khhk..
...kk...
"""
LANTERN_SHOT = """
..kkkk..
.k~%%~k.
.k%ay%k.
.k%yc%k.
.k%ya%k.
.k~%%~k.
..kkkk..
........
"""
TOLL = """
...kkk..
..k&&k..
.k&%k...
.k&%k...
.k&%k...
.k&%k...
..k&&k..
...kkk..
"""
DEBRIS = """
..kkkk..
.kXXXxk.
kxXxxx$k
kx$xxxxk
.kxx$xk.
..kkkk..
........
........
"""


def net():
    """A round rope net: strands every 4 px on both diagonals, wood knots where they cross, a
    rope rim.  No outline (decor rule for rope), never rotated by the engine."""
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    px = im.load()
    rope = P.rgb("ROPE") + (255,)
    knot = P.rgb("WOOD") + (255,)
    tar = P.rgb("TAR") + (255,)
    cx = cy = 11.5
    r = 11.0
    for y in range(24):
        for x in range(24):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d > r:
                continue
            a = (x + y) % 5 == 0
            b = (x - y) % 5 == 0
            if d > r - 1.4:
                px[x, y] = rope
            elif a and b:
                px[x, y] = knot
            elif a or b:
                px[x, y] = rope
    # cork floats on the rim, four of them
    for (fx, fy) in ((11, 0), (11, 23), (0, 11), (23, 11)):
        for dx in (0, 1):
            for dy in (0, 1):
                xx, yy = min(23, fx + dx - (1 if fx == 23 else 0)), min(23, fy + dy - (1 if fy == 23 else 0))
                px[xx, yy] = tar
    return im


HELD = {
    "gaff_hook": (GAFF, 22, 8),
    "knife": (KNIFE, 14, 6),
    "harpoon_gun": (HARPOON_GUN, 20, 8),
    "storm_lantern": (STORM_LANTERN, 16, 10),
    "keepers_bell": (KEEPERS_BELL, 16, 10),
    "line_handle": (LINE_HANDLE, 12, 6),
}
OBJECTS = {
    "harpoon_bolt": (HARPOON_BOLT, 14, 4),
    "sinker": (SINKER, 8, 8),
    "lantern_shot": (LANTERN_SHOT, 8, 8),
    "toll": (TOLL, 8, 8),
    "debris": (DEBRIS, 8, 8),
}


def in_hand(tam, weapon, angle, mirror):
    """Tam (24x24, feet on row 21) with the weapon at the hand pivot (row 15), turned to
    `angle` degrees.  The engine mirrors the sprite across its shaft when Tam faces left."""
    W = 72
    out = Image.new("RGBA", (W, W), P.rgba("SAND"))
    tx, ty = (W - 24) // 2, (W - 24) // 2
    body = tam.transpose(Image.FLIP_LEFT_RIGHT) if mirror else tam
    out.alpha_composite(body, (tx, ty))
    w = weapon.transpose(Image.FLIP_TOP_BOTTOM) if mirror else weapon
    # a canvas with the pivot at its centre, the sprite starting 2 px right of it
    cw = 2 * (w.width + 4)
    can = Image.new("RGBA", (cw, cw), (0, 0, 0, 0))
    can.alpha_composite(w, (cw // 2 + 2, cw // 2 - w.height // 2))
    rot = can.rotate(-angle, resample=Image.NEAREST, center=(cw // 2, cw // 2))
    px, py = tx + 12, ty + 15
    out.alpha_composite(rot, (px - cw // 2, py - cw // 2))
    return out


def main():
    os.makedirs(REF, exist_ok=True)
    built = {}
    for name, (text, w, h) in list(HELD.items()) + list(OBJECTS.items()):
        built[name] = grid(text, w, h)
    built["net"] = net()
    beacon = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    beacon.alpha_composite(grid(BEACON_A, 16, 16), (0, 0))
    beacon.alpha_composite(grid(BEACON_B, 16, 16), (16, 0))
    built["beacon"] = beacon
    for name, im in built.items():
        im.save(os.path.join(SPRITES, name + ".png"))

    # --- review sheet ---
    try:
        font = ImageFont.load_default(size=11)
        small = ImageFont.load_default(size=9)
    except TypeError:
        font = small = ImageFont.load_default()
    W = 1800
    sheet = Image.new("RGBA", (W, 2200), (30, 33, 42, 255))
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "EBB weapons  -  Stage 14  -  one fisher's kit: iron, wood, rope, brass, bone", fill=P.rgb("SALT_WHITE"), font=font)
    y = 30
    d.text((12, y), "held weapons (pivot at the left edge, vertical centre) and the objects they throw, at 6x over Sand", fill=P.rgb("PALE_SLATE"), font=small)
    y += 14
    x = 12
    Z = 6
    for name, im in built.items():
        bg = Image.new("RGBA", im.size, P.rgba("SAND"))
        bg.alpha_composite(im)
        sheet.alpha_composite(zoom(bg, Z), (x, y))
        d.text((x, y + 24 * Z + 2), name, fill=P.rgb("PALE_SLATE"), font=small)
        x += max(im.width, 12) * Z + 14
    y += 24 * Z + 30
    d.text((12, y), "in Tam's hand at eight aims, mirrored past the vertical the way the engine does it (3x)", fill=P.rgb("PALE_SLATE"), font=small)
    y += 14
    tam = Image.open(os.path.join(SPRITES, "player.png")).convert("RGBA").crop((0, 0, 24, 24))
    for name in HELD:
        d.text((12, y), name, fill=P.rgb("SALT_WHITE"), font=small)
        y += 12
        x = 12
        for angle in (0, 45, 90, 135, 180, 225, 270, 315):
            mirror = 90 < angle < 270
            im = in_hand(tam, built[name], angle, mirror)
            sheet.alpha_composite(zoom(im, 3), (x, y))
            x += 72 * 3 + 6
        y += 72 * 3 + 16
    sheet = sheet.crop((0, 0, W, y))
    sheet.convert("RGB").save(os.path.join(REF, "weapons_sheet.png"))
    print("wrote %s, weapons_sheet.png" % ", ".join(built.keys()))


if __name__ == "__main__":
    main()
