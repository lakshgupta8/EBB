"""Map Stage 11a review sheet: the Reef's palette, source tiles and a mock room, beside the Flats.

    python tools/gen_reef_sheet.py   (after tools/gen_terrain.py) -> assets/reference/maps/s11_reef_sheet.png
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from PIL import Image, ImageDraw  # noqa: E402

import gen_terrain as G  # noqa: E402
import palette as P  # noqa: E402

T = 16
terrain = Image.open(os.path.join(G.SPRITES, "terrain.png")).convert("RGBA")
wedge = Image.open(os.path.join(G.SPRITES, "water_edge.png")).convert("RGBA")
patches = Image.open(os.path.join(G.SPRITES, "patch.png")).convert("RGBA")

# A reef room: the sea wall runs across (straight courses, broken), coral heads on either side
# (raised, lumpy), sand channels where the current runs (low), a breach in the wall.
PLAN = """
########################################
########################################
###....====.......__.......=====....####
##....======.....____.....=======.....##
##.....====.....______.....=====......##
#...............______..................#
#....######.....______.....#########....#
#....######......____......#########....#
#.................__....................#
#..===.......__.......__........===.....#
#.=====.....____.....____......=====....#
#..===......____......___.......===.....#
#............__..........................#
##....______.......====.......______...##
##...________.....======.....________..##
###...______.......====.......______..###
####...................................##
########################################
########################################
"""


def lay(look, plan, with_patches):
    rows = [r.ljust(40, "#")[:40] for r in plan.strip("\n").split("\n")]
    img = G.mock(terrain, wedge, look, "\n".join(rows), tide_water=False)
    if not with_patches:
        return img
    li = G.LOOKS.index(look)
    h, w = len(rows), len(rows[0])

    def at(x, y):
        x, y = min(max(x, 0), w - 1), min(max(y, 0), h - 1)
        return rows[y][x]

    def near(x, y, ch, r):
        return any(at(x + dx, y + dy) == ch for dx in range(-r, r + 1) for dy in range(-r, r + 1))

    # Patch 0 (living) by the channels, 2 (rubble) at the foot of the wall, 1 (bleached) in blobs.
    preds = [
        lambda x, y: at(x, y) == "." and near(x, y, "_", 1),
        lambda x, y: at(x, y) == "." and (x // 4 * 5 + y // 3 * 3) % 7 < 2 and not near(x, y, "_", 1),
        lambda x, y: at(x, y) == "." and near(x, y, "#", 1) and not near(x, y, "_", 1),
    ]
    out = Image.new("RGBA", img.size)
    out.alpha_composite(img)
    for pi, pred in enumerate(preds):
        row = li * 3 + pi
        for j in range(h + 1):
            for i in range(w + 1):
                c = (pred(i - 1, j - 1) << 0) | (pred(i, j - 1) << 1) | (pred(i - 1, j) << 2) | (pred(i, j) << 3)
                if c == 0:
                    continue
                col = G.FILL_COL + (i + j) % 3 if c == 15 else c * 3 + (i * 7 + j * 13) % 3
                out.alpha_composite(patches.crop((col * T, row * T, col * T + T, row * T + T)), (i * T - T // 2, j * T - T // 2))
    # Raised and wall layers go back over the patches (patches lie under them in the game).
    for y in range(out.height):
        for x in range(out.width):
            cy, cx = y // T, x // T
            if rows[min(cy, h - 1)][min(cx, w - 1)] in "#=":
                out.putpixel((x, y), img.getpixel((x, y)))
    return out


reef = lay("reef", PLAN, True)
flats = lay("flats", PLAN, True)
flooded = G.mock(terrain, wedge, "reef", "\n".join(r.ljust(40, "#")[:40] for r in PLAN.strip("\n").split("\n")), tide_water=True)

sw = 52
names = ["DROWNED_SHADE", "DROWNED_SKIN", "PALE_SLATE", "WET_GREY", "OILSKIN_LIGHT", "OILSKIN", "STONE", "STONE_DARK",
         "BASALT", "SALT_WHITE", "SALT_RED", "VIOLET_LIGHT", "AMBER_DEEP", "SEA_PALE"]
W = reef.width * 2 + 24
H = 30 + reef.height * 2 + 30 + flats.height * 2 + 120
sheet = Image.new("RGBA", (W, H), P.rgba("INK"))
d = ImageDraw.Draw(sheet)
y = 6
d.text((8, y), "THE REEF (map Stage 11a): the mock room at 2x, patches laid by reason (living coral by the channels)", fill=P.rgba("SALT_WHITE"))
y += 20
sheet.alpha_composite(reef.resize((reef.width * 2, reef.height * 2), Image.NEAREST), (8, y))
y += reef.height * 2 + 10
d.text((8, y), "the same plan at 1x: the Reef / the Flats / the Reef flooded", fill=P.rgba("SALT_WHITE"))
y += 18
sheet.alpha_composite(reef, (8, y))
sheet.alpha_composite(flats, (16 + reef.width, y))
y += flats.height + 8
sheet.alpha_composite(flooded, (8, y))
src = G.reef_sources()
sheet.alpha_composite(src.resize((src.width * 4, src.height * 4), Image.NEAREST), (16 + reef.width, y))
d.text((16 + reef.width, y + 68), "floor  floor2  low  raised  wall top  wall face", fill=P.rgba("PALE_SLATE"))
y += flooded.height + 10
for k, n in enumerate(names):
    x = 8 + k * (sw + 6)
    d.rectangle((x, y, x + sw, y + 24), fill=P.rgba(n))
    d.text((x, y + 28), n.lower().replace("_", " ").replace("drowned", "drn").replace("light", "lt")[:8], fill=P.rgba("PALE_SLATE"))
sheet = sheet.crop((0, 0, W, y + 44))
out = os.path.join(ROOT, "assets", "reference", "maps", "s11_reef_sheet.png")
sheet.save(out)
print(out, sheet.size)
