"""Map Stage 05: set pieces.  The large drawn things a room is built round (STYLE.md 22, Set
pieces): a wreck on the Flats, a house front in the Streets, a crane on the quay, a column in
the Hall. Seen as the walls are: from the south and above, lit from the top, no outline, an Ink
foot line where they meet the ground and their shadow thrown south (Ink at 35 %).

Each piece has a footprint (the cells that become solid) and a sprite whose bottom sits on the
footprint's south edge plus its shadow. room.gd splits the sprite at the footprint's north edge:
what rises above it draws over the keeper and the drowned (who can stand behind it), the rest
under them.

    assets/sprites/set_pieces.png    every piece, packed in a row per look
    data/set_pieces.json             id -> look, region, footprint rows ('#' solid, '.' open),
                                     origin (footprint top-left in sprite px), light
    assets/reference/maps/set_pieces_sheet.png   1x over each look's floor, and 3x

First batch (the sample, three per look): flats wreck, arch, boat; streets house, well, stall;
harbour crane, warehouse, netrack; hall column, altar, statue. Second batch (five per look):
flats tidepool, stones, cairn (the lit beacon), mast, whalebone; streets tower, steps, lamps,
fallen, bridge; harbour pier, moored, capstan, slipway, crates; hall gate, organ, rose, apse,
font (cold brine). Footprint rows: '#' solid, '.' open, '=' lays a deck, '_' lays water.

Run:  python tools/gen_set_pieces.py
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
DATA = os.path.join(P.ROOT, "data")
REF = os.path.join(P.ROOT, "assets", "reference", "maps")
T = 16
SHADOW_A = 90


class Canvas:
    def __init__(self, w, h):
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
        self.w, self.h = w, h

    def px(self, x, y, key, a=255):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((x, y), P.rgba(key, a))

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.im.getpixel((int(x), int(y)))
        return (0, 0, 0, 0)

    def rect(self, x0, y0, x1, y1, key, a=255):
        self.d.rectangle([x0, y0, x1, y1], fill=P.rgba(key, a))

    def poly(self, pts, key, a=255):
        self.d.polygon([(round(x), round(y)) for x, y in pts], fill=P.rgba(key, a))

    def line(self, x0, y0, x1, y1, key, a=255):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n):
            t = i / max(1, n - 1)
            self.px(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, key, a)

    def ellipse(self, x0, y0, x1, y1, key, a=255):
        self.d.ellipse([x0, y0, x1, y1], fill=P.rgba(key, a))

    def shadow(self, x0, y0, x1, y1):
        """The piece's shadow on the ground, under everything drawn after it."""
        self.d.ellipse([x0, y0, x1, y1], fill=P.rgba("INK", SHADOW_A))

    def foot(self, x0, x1, y, key="INK"):
        for x in range(int(x0), int(x1) + 1):
            if self.get(x, y - 1)[3] == 255:
                self.px(x, y, key)


# --- the Flats --------------------------------------------------------------------------------

def wreck():
    """A fishing boat on its side in the sand, keel to the north, its deck toward the viewer
    broken open: ribs over a dark hold, strakes in Wood and Tar, barnacles, kelp, a broken mast."""
    c = Canvas(128, 80)
    c.shadow(4, 61, 124, 72)
    # The hull's outline: bow to the east, stern square to the west.
    top = lambda x: 26 + 10 * ((x - 64) / 60) ** 2
    bot = lambda x: 66 - 4 * ((x - 64) / 60) ** 2
    for x in range(6, 123):
        t0, b0 = top(x), bot(x)
        if x > 112:  # the bow narrows to a point
            k = (x - 112) / 10
            t0, b0 = t0 + k * 14, b0 - k * 12
        for y in range(int(t0), int(b0)):
            # Strakes: horizontal planks, Wood light on the upper face, Tar seams every 5 px.
            band = int((y - t0)) % 5
            key = "TAR" if band == 0 else ("WOOD_LIGHT" if y < t0 + 10 else "WOOD")
            c.px(x, y, key)
    # The keel along the top, lit from above.
    for x in range(8, 118):
        c.px(x, top(x) - 1, "WEATHERED_BROWN")
        c.px(x, top(x), "WOOD_LIGHT")
    # A hole broken in the side: the dark hold, ribs crossing it.
    for x in range(38, 82):
        y0 = 38 + 3 * math.sin((x - 38) / 44 * math.pi) * -1
        y1 = 58 - 2 * math.sin((x - 38) / 9.0)
        for y in range(int(y0), int(y1)):
            c.px(x, y, "NIGHT_1" if y > y0 + 2 else "INK")
    for x in range(41, 80, 7):
        for y in range(36, 60):
            c.px(x, y, "WOOD_LIGHT" if y < 44 else "WOOD")
            c.px(x + 1, y, "WOOD")
    # Barnacles and weed low on the hull where the tide reaches.
    rnd = random.Random("wreck")
    for _ in range(40):
        x = rnd.randint(10, 118)
        y = rnd.randint(int(bot(x)) - 8, int(bot(x)) - 2)
        if c.get(x, y)[3] == 255 and not (38 <= x < 82 and 38 <= y < 58):
            c.px(x, y, rnd.choice(["BONE_DARK", "BONE", "KELP", "KELP"]))
    # The mast, snapped, lying back over the keel; a rag of sail.
    c.line(70, 30, 98, 8, "WOOD")
    c.line(71, 30, 99, 8, "WEATHERED_BROWN")
    for k in range(6):
        c.line(92 - k, 12 + k, 100 - k, 16 + k, "BONE_DARK" if k % 2 else "BONE")
    # Kelp draped down the hull, sand drifted against its foot.
    for x0 in (20, 31, 95, 104):
        for y in range(int(top(x0)) + 2, int(bot(x0)) - 2):
            c.px(x0 + int(math.sin(y / 3.0)), y, "KELP" if y % 3 else "KELP_LIGHT")
    for x in range(6, 120):
        for k in range(1 + int(2 * (math.sin(x / 7.0) + 1))):
            c.px(x, bot(x) - k, "SAND_LIGHT" if k == 0 else "SAND")
    c.foot(6, 122, 67)
    return c, ["########", "########"], (0, 67 - 32)


def arch():
    """A sea arch: two legs of rock and the span over a gap you can walk through. Natural rock:
    every edge wanders, the strata run across it, the faces darken toward the ground."""
    c = Canvas(112, 88)
    c.shadow(0, 74, 36, 85)
    c.shadow(76, 74, 112, 85)
    rnd = random.Random("arch")

    def wob(v, k, a=2.0):
        return a * math.sin(v * 0.17 + k) + 0.5 * a * math.sin(v * 0.41 + 2 * k)

    def leg(cx, half, k):
        for y in range(22, 80):
            w = half + (y - 22) * 0.12
            x0, x1 = cx - w + wob(y, k), cx + w + wob(y, k + 1.7)
            for x in range(int(x0), int(x1) + 1):
                face = y > 62
                key = "STONE_DARK" if face else "STONE"
                if not face and x < x0 + 3:
                    key = "STONE_LIGHT"
                if face and x < x0 + 2:
                    key = "STONE"
                if (y + int(wob(x, k, 2.0))) % 11 == 0 and x0 + 3 < x < x1 - 2 and not face:
                    key = "STONE_DARK"
                c.px(x, y, key)

    leg(18, 13, 0.3)
    leg(94, 13, 2.1)
    # The span, its top wandering, its underside a dark face over the gap.
    for x in range(10, 103):
        y0 = 9 + wob(x, 0.9, 2.5)
        y1 = 40 - 10 * math.sin(min(1.0, max(0.0, (x - 24) / 64)) * math.pi) + wob(x, 3.1, 1.2)
        for y in range(int(y0), int(y1)):
            key = "STONE_LIGHT" if y < y0 + 3 else ("STONE" if y < y1 - 5 else "STONE_DARK")
            if (y + int(wob(x, 1.0, 2.0))) % 11 == 0 and y0 + 3 < y < y1 - 5:
                key = "STONE_DARK"
            c.px(x, y, key)
        c.px(x, int(y1), "INK")
    # Salt dried on the top, kelp hanging under the span, a few cracks.
    for x in range(12, 100, 4):
        c.px(x, 9 + wob(x, 0.9, 2.5), "SALT_WHITE")
    for x0 in (42, 53, 66):
        for y in range(int(31 - 10 * math.sin((x0 - 24) / 64 * math.pi)), 40 + (x0 % 5)):
            c.px(x0 + (y % 2), y, "KELP" if y % 3 else "KELP_LIGHT")
    for _ in range(6):
        x, y = rnd.randint(6, 106), rnd.randint(26, 70)
        if c.get(x, y)[3]:
            for k in range(rnd.randint(3, 6)):
                c.px(x + k // 2, y + k, "STONE_DARK")
    c.foot(0, 112, 80)
    return c, ["##...##", "##...##"], (0, 80 - 32)


def boat():
    """A rowboat turned over on the sand, an oar beside it."""
    c = Canvas(56, 40)
    c.shadow(2, 24, 52, 35)
    for x in range(4, 50):
        h = 12 * math.sin((x - 4) / 46 * math.pi) ** 0.6
        y0, y1 = 22 - h, 30
        for y in range(int(y0), y1):
            key = "WOOD_LIGHT" if y < y0 + 3 else ("TAR" if (y - int(y0)) % 4 == 0 else "WOOD")
            c.px(x, y, key)
        c.px(x, int(y0), "WEATHERED_BROWN")
    for x in range(6, 48):
        c.px(x, 29, "TAR")
    c.line(8, 34, 44, 32, "WOOD_LIGHT")
    c.line(44, 32, 50, 31, "WOOD")
    c.rect(44, 30, 49, 33, "WOOD")
    for x in (12, 30, 40):
        c.px(x, 27, "BONE_DARK")
    c.foot(4, 49, 30)
    return c, ["###"], (4, 30 - 16)


# --- the Streets ------------------------------------------------------------------------------

def house():
    """A drowned house front: two storeys of brick, a slate roof, a door and four windows dark
    and wet, the high-water line a band of moss across it, salt dried white above."""
    c = Canvas(96, 96)
    c.shadow(0, 78, 96, 89)
    # The roof: slate rows seen from above, the eave a dark line.
    for y in range(4, 24):
        for x in range(2, 94):
            key = "SLATE" if (y - 4) % 4 else "NIGHT_2"
            if y < 6:
                key = "WET_GREY"
            if (x + (y // 4) * 5) % 9 == 0 and (y - 4) % 4:
                key = "NIGHT_2"
            c.px(x, y, key)
    for x in range(0, 96):
        c.px(x, 24, "INK")
        c.px(x, 25, "NIGHT_1")
    # The front: brick courses, Night 2 with Night 1 mortar.
    for y in range(26, 84):
        for x in range(4, 92):
            row = (y - 26) // 4
            mortar = (y - 26) % 4 == 3 or (x + (row % 2) * 4) % 8 == 0
            c.px(x, y, "NIGHT_1" if mortar else "NIGHT_2")
    # Corner stones, lit on the left.
    for y in range(26, 84):
        c.px(4, y, "SLATE")
        c.px(5, y, "SLATE" if (y // 4) % 2 else "NIGHT_2")
        c.px(91, y, "NIGHT_1")

    def window(x, y, w=12, h=14):
        c.rect(x - 1, y - 1, x + w, y + h, "STONE")
        c.rect(x, y, x + w - 1, y + h - 1, "ABYSS")
        c.line(x + w // 2, y, x + w // 2, y + h - 1, "NIGHT_2")
        c.line(x, y + h // 2, x + w - 1, y + h // 2, "NIGHT_2")
        c.px(x + 1, y + 1, "SEA_PALE")
        c.px(x + 2, y + 1, "SEA_PALE")
        c.rect(x - 1, y + h, x + w, y + h, "STONE_LIGHT")

    for x in (14, 70):
        window(x, 32)
    window(14, 58)
    window(70, 58)
    # The door, an arch, shut and black with water standing in it.
    c.rect(41, 52, 54, 82, "STONE")
    c.rect(42, 54, 53, 82, "ABYSS")
    c.ellipse(41, 47, 54, 60, "STONE")
    c.ellipse(42, 49, 53, 60, "ABYSS")
    for y in range(74, 83):
        c.line(42, y, 53, y, "DEEP_SEA" if y % 2 else "SEA")
    # The high-water line: moss below, salt crust above.
    for x in range(4, 92):
        y = 66 + int(math.sin(x / 6.0))
        c.px(x, y, "MOSS")
        c.px(x, y + 1, "MOSS_DARK")
        if x % 5 == 0:
            c.px(x, y - 1, "SALT_WHITE")
    # A sign on a bracket, its letters long gone.
    c.line(60, 40, 66, 40, "IRON")
    c.rect(61, 41, 66, 47, "WEATHERED_BROWN")
    c.foot(4, 91, 84)
    return c, ["######", "######"], (0, 52)


def well():
    """A stone well with a little roof over the winding post, the bucket left on its rim."""
    c = Canvas(40, 56)
    c.shadow(2, 41, 38, 52)
    # The roof on two posts.
    c.poly([(4, 14), (20, 4), (36, 14), (33, 16), (7, 16)], "SLATE")
    c.line(4, 14, 20, 4, "WET_GREY")
    c.line(7, 16, 33, 16, "INK")
    c.rect(7, 16, 8, 34, "WOOD")
    c.rect(32, 16, 33, 34, "WOOD")
    c.line(8, 22, 32, 22, "WOOD_LIGHT")
    c.line(20, 22, 20, 30, "ROPE")
    # The drum: a ring of stone, dark water inside.
    c.ellipse(4, 26, 36, 40, "STONE_LIGHT")
    c.ellipse(8, 28, 32, 38, "ABYSS")
    c.ellipse(11, 31, 29, 37, "DEEP_SEA")
    c.rect(4, 33, 36, 46, "STONE")
    for y in range(36, 46, 4):
        c.line(4, y, 36, y, "STONE_DARK")
    for x in range(8, 36, 7):
        c.line(x, 33, x, 46, "STONE_DARK")
    c.rect(26, 28, 30, 31, "WOOD")
    c.px(28, 27, "IRON")
    c.foot(4, 36, 47)
    return c, ["##", "##"], (4, 47 - 32)


def stall():
    """A market stall left as it was: a counter, a torn awning, fish boxes nobody came back for."""
    c = Canvas(64, 56)
    c.shadow(0, 41, 64, 52)
    # The awning, faded stripes, torn at one end.
    for x in range(2, 62):
        sag = int(2 * math.sin((x - 2) / 60 * math.pi))
        torn = 6 if x > 50 and (x * 3) % 7 < 3 else 0
        for y in range(6 + sag, 18 + sag - torn):
            stripe = ((x - 2) // 6) % 2
            key = ("BONE_DARK" if stripe else "WEATHERED_BROWN") if y > 7 + sag else "BONE"
            c.px(x, y, key)
        c.px(x, 18 + sag - torn, "INK")
    # Posts and the counter.
    c.rect(4, 18, 5, 46, "WOOD")
    c.rect(58, 18, 59, 46, "WOOD")
    c.rect(2, 30, 61, 33, "WOOD_LIGHT")
    c.rect(2, 34, 61, 46, "WOOD")
    for x in range(8, 60, 9):
        c.line(x, 34, x, 46, "TAR")
    # Boxes on the counter: fish gone grey, a scale, ice long melted.
    for x0, key in ((8, "DROWNED_SHADE"), (22, "PALE_SLATE"), (36, "DROWNED_SHADE")):
        c.rect(x0, 25, x0 + 11, 30, "WOOD")
        for k in range(4):
            c.line(x0 + 1, 26 + k % 2, x0 + 10, 26 + k % 2, key)
        c.px(x0 + 3, 26, "SALT_WHITE")
    c.rect(50, 24, 55, 29, "BRONZE_DARK")
    c.px(52, 23, "BRONZE")
    c.foot(2, 61, 47)
    return c, ["####", "####"], (0, 15)


# --- the Harbour ------------------------------------------------------------------------------

def crane():
    """A dock crane: a quay block, a timber mast banded in iron, the jib over the water with its
    chain and hook, a lamp hung from it (the Harbour's one warm light)."""
    c = Canvas(72, 104)
    c.shadow(2, 88, 54, 99)
    # The quay block it stands on.
    for y in range(68, 94):
        for x in range(4, 52):
            course = (y - 68) // 6
            mortar = (y - 68) % 6 == 5 or (x + course * 7) % 14 == 0
            key = "STONE_DARK" if mortar else ("STONE_LIGHT" if y < 72 else "STONE")
            c.px(x, y, key)
    # The mast.
    c.rect(22, 14, 31, 70, "WOOD")
    c.rect(22, 14, 23, 70, "WOOD_LIGHT")
    c.rect(30, 14, 31, 70, "TAR")
    for y in (22, 40, 58):
        c.rect(21, y, 32, y + 2, "IRON")
        c.line(21, y, 32, y, "IRON_LIGHT")
    # The jib, out over the water to the east, and its stay.
    c.line(28, 18, 66, 8, "WOOD_LIGHT")
    c.line(28, 19, 66, 9, "WOOD")
    c.line(28, 20, 66, 10, "TAR")
    c.line(26, 40, 64, 10, "IRON")
    # Chain and hook.
    for y in range(11, 40):
        c.px(64, y, "IRON_LIGHT" if y % 2 else "IRON")
    c.px(63, 40, "IRON")
    c.px(65, 40, "IRON")
    c.px(65, 41, "IRON")
    c.px(64, 42, "IRON")
    # The winch drum on the block, rope wound on it.
    c.rect(12, 60, 20, 68, "WOOD")
    for y in range(61, 68, 2):
        c.line(12, y, 20, y, "ROPE")
    # The lamp under the jib.
    c.line(46, 13, 46, 18, "IRON")
    c.rect(44, 19, 48, 23, "IRON_DARK")
    c.rect(45, 20, 47, 22, "WARM_YELLOW")
    c.px(46, 21, "PALE_CREAM")
    c.foot(4, 51, 94)
    return c, ["###", "###"], (4, 94 - 32), {"color": "WARM", "energy": 0.7, "scale": 2.4, "at": [46, 21]}


def warehouse():
    """A warehouse front on the quay: tarred planks, big doors with a gap, a hoist beam above
    with its pulley, rust weeping from the iron."""
    c = Canvas(112, 88)
    c.shadow(0, 70, 112, 81)
    # The roof edge, iron sheet.
    for y in range(6, 18):
        for x in range(0, 112):
            key = "IRON_LIGHT" if y < 9 else ("IRON" if (x // 6) % 2 else "IRON_DARK")
            c.px(x, y, key)
    for x in range(0, 112):
        c.px(x, 18, "INK")
    # Planks, vertical, Wood with Tar seams.
    for y in range(19, 76):
        for x in range(2, 110):
            seam = x % 7 == 0
            key = "TAR" if seam else ("WOOD" if (x * 13 + y // 9) % 5 else "WEATHERED_BROWN")
            c.px(x, y, key)
    # The doors, one ajar on the dark.
    c.rect(36, 38, 75, 76, "WOOD_LIGHT")
    c.rect(37, 39, 74, 76, "WOOD")
    c.rect(56, 39, 63, 76, "ABYSS")
    c.line(37, 50, 55, 62, "WOOD_LIGHT")
    c.line(64, 50, 74, 62, "WOOD_LIGHT")
    for y in (44, 68):
        c.line(38, y, 54, y, "IRON")
        c.line(65, y, 73, y, "IRON")
    # The hoist beam and its pulley, a rope down.
    c.rect(52, 20, 67, 24, "WOOD_LIGHT")
    c.rect(52, 24, 67, 25, "TAR")
    c.ellipse(57, 25, 62, 30, "IRON")
    c.line(59, 30, 59, 37, "ROPE")
    # Rust weeping from the roof's nails.
    for x in range(5, 110, 13):
        for k in range(4 + x % 5):
            c.px(x, 19 + k, "RUST" if k < 3 else "RUST_LIGHT")
    # A painted number, flaking.
    for x, y in ((14, 30), (15, 30), (16, 30), (16, 31), (15, 32), (14, 33), (14, 34), (16, 34)):
        c.px(x, y, "BONE_DARK")
    c.foot(2, 109, 76)
    return c, ["#######", "#######"], (0, 44)


def netrack():
    """A rack of posts with nets hung to dry, cork floats, weed caught in the mesh."""
    c = Canvas(64, 48)
    c.shadow(0, 33, 64, 44)
    for x in (3, 30, 58):
        c.rect(x, 8, x + 2, 38, "WOOD")
        c.line(x, 8, x, 38, "WOOD_LIGHT")
    c.line(3, 9, 60, 9, "WOOD_LIGHT")
    c.line(3, 10, 60, 10, "WOOD")
    # The net: a drooping mesh.
    for x in range(5, 58):
        droop = 20 + int(6 * math.sin((x - 5) / 26 * math.pi) ** 2)
        for y in range(11, droop):
            if (x + y) % 4 == 0 or (x - y) % 4 == 0:
                c.px(x, y, "ROPE")
        if x % 6 == 0:
            c.px(x, droop, "SALT_RED")
            c.px(x, droop - 1, "BONE")
    for x, y in ((12, 18), (13, 19), (40, 16), (41, 17), (41, 18)):
        c.px(x, y, "KELP")
    c.foot(3, 60, 39)
    return c, ["####"], (0, 39 - 16)


# --- the Hall ---------------------------------------------------------------------------------

def column():
    """A column of the Deep Hall: a plinth, a fluted basalt shaft lit from the left, the capital
    broken, kelp hanging from it and a chain."""
    c = Canvas(32, 96)
    c.shadow(0, 79, 32, 90)
    c.rect(2, 74, 29, 84, "BASALT_LIGHT")
    c.line(2, 74, 29, 74, "IRON_LIGHT")
    c.rect(2, 80, 29, 84, "BASALT")
    for y in range(12, 74):
        for x in range(6, 26):
            flute = (x - 6) % 4
            key = "BASALT_LIGHT" if x < 10 else ("BASALT_DARK" if x > 21 else "BASALT")
            if flute == 0:
                key = "BASALT_DARK" if x > 9 else "BASALT"
            c.px(x, y, key)
    # The capital, one corner gone.
    c.rect(3, 6, 28, 12, "BASALT_LIGHT")
    c.line(3, 6, 28, 6, "IRON_LIGHT")
    c.rect(3, 10, 28, 12, "BASALT")
    for x in range(22, 29):
        for y in range(6, 6 + (x - 21)):
            c.px(x, y, (0, 0, 0, 0)) if False else None
    c.poly([(22, 5), (29, 5), (29, 11)], "BASALT_DARK")
    for y in range(12, 40):
        c.px(9 + (y // 5) % 2, y, "KELP" if y % 3 else "KELP_LIGHT")
    for y in range(12, 30):
        c.px(20, y, "IRON" if y % 2 else "IRON_DARK")
    c.foot(2, 29, 85)
    return c, ["##", "##"], (0, 85 - 32)


def altar():
    """The keepers' altar: a slab on two steps, a basin on it, candles burned down at its feet
    (the Hall's small warm light)."""
    c = Canvas(64, 64)
    c.shadow(0, 47, 64, 58)
    # Steps.
    c.rect(2, 44, 61, 52, "BASALT_LIGHT")
    c.line(2, 44, 61, 44, "IRON_LIGHT")
    c.rect(2, 49, 61, 52, "BASALT")
    c.rect(8, 36, 55, 44, "BASALT_LIGHT")
    c.line(8, 36, 55, 36, "IRON_LIGHT")
    c.rect(8, 41, 55, 44, "BASALT")
    # The slab.
    c.rect(14, 18, 49, 36, "BASALT")
    c.rect(14, 18, 49, 22, "BASALT_LIGHT")
    c.line(14, 18, 49, 18, "IRON_LIGHT")
    c.line(14, 36, 49, 36, "INK")
    for x in (20, 43):
        c.line(x, 23, x, 35, "BASALT_DARK")
    # A tide mark carved on the front.
    for x in range(22, 42):
        c.px(x, 29 + int(2 * math.sin((x - 22) / 20 * 2 * math.pi)), "IRON")
    # The basin.
    c.ellipse(24, 12, 40, 20, "BRONZE_DARK")
    c.ellipse(26, 13, 38, 18, "DEEP_SEA")
    c.line(25, 12, 39, 12, "BRONZE")
    # Candles in drifts on the steps.
    for x, h in ((5, 5), (8, 3), (11, 6), (52, 4), (55, 6), (58, 3)):
        c.rect(x, 44 - h, x + 1, 43, "BONE")
        c.px(x, 44 - h, "BONE_LIGHT")
        c.px(x, 43 - h, "AMBER")
        c.px(x + 1, 46, "BONE_DARK")
    c.foot(2, 61, 53)
    return c, ["####", "####"], (0, 21), {"color": "FLAME", "energy": 0.45, "scale": 1.6, "at": [8, 40]}


def statue():
    """A keeper turned to stone where they stood, hood up, a cold lantern held out, on a plinth;
    the crown of the hood rimmed in salt as the drowned are."""
    c = Canvas(32, 72)
    c.shadow(0, 55, 32, 66)
    c.rect(3, 50, 28, 60, "BASALT_LIGHT")
    c.line(3, 50, 28, 50, "IRON_LIGHT")
    c.rect(3, 56, 28, 60, "BASALT")
    # The robe: a tapering block, lit on its left.
    for y in range(18, 50):
        half = 5 + (y - 18) * 0.28
        for x in range(int(16 - half), int(16 + half) + 1):
            key = "WET_GREY" if x < 16 - half + 3 else ("SLATE" if x < 16 + half - 2 else "NIGHT_2")
            c.px(x, y, key)
    # The hood and the dark inside it.
    c.ellipse(9, 6, 23, 22, "SLATE")
    c.ellipse(9, 6, 19, 20, "WET_GREY")
    c.ellipse(12, 11, 20, 20, "ABYSS")
    c.px(14, 15, "SEA_PALE")
    c.px(18, 15, "SEA_PALE")
    for x in range(10, 22):
        if c.get(x, 7)[3]:
            c.px(x, 6 + (1 if x in (10, 21) else 0), "SALT_WHITE")
    # The arm out, the lantern cold.
    c.line(20, 26, 26, 30, "SLATE")
    c.line(26, 30, 26, 33, "IRON")
    c.rect(24, 33, 28, 38, "IRON_DARK")
    c.rect(25, 34, 27, 37, "SEA_PALE")
    c.foot(3, 28, 61)
    return c, ["##", "##"], (0, 61 - 32)


# --- the second batch (map Stage 05, after the Stage 06 gate) ----------------------------------
# Footprint rows may now lay ground as well as stand on it: '=' a deck (raised: a pier, a bridge,
# steps; it floods last), '_' water (a tide pool inside its rim). '.' leaves the plan alone.

def fin(c, foot, foot_y, ox=0, light=None):
    """The piece's return: its footprint ends on the foot line at foot_y."""
    out = (c, foot, (ox, foot_y - T * len(foot)))
    return out + (light,) if light else out


def rock_mass(c, cx, base, rx, ry, seed, top="STONE_LIGHT", face="STONE", dark="STONE_DARK"):
    """A rock whose outline wanders: lit top, face, dark at the foot."""
    rnd = random.Random(seed)
    bumps = [rnd.uniform(-0.14, 0.14) for _ in range(10)]
    for y in range(int(base - 2 * ry) - 1, int(base) + 1):
        for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
            dx, dy = (x - cx) / rx, (y - (base - ry)) / ry
            a = math.atan2(dy, dx)
            r = 1.0 + bumps[int((a + math.pi) / (2 * math.pi) * 10) % 10]
            if dx * dx + dy * dy <= r * r and y <= base:
                rel = (y - (base - 2 * ry)) / (2 * ry)
                c.px(x, y, top if rel < 0.35 else (face if rel < 0.8 else dark))


GLOW = {
    # glass ground, flame body, flame core
    "cold": ("SEA", "SEA_PALE", "SALT_WHITE"),
    "warm": ("AMBER_DEEP", "WARM_YELLOW", "PALE_CREAM"),
    "dark": ("NIGHT_2", "NIGHT_2", "NIGHT_2"),
}


def lantern(c, cx, top, glow="cold", metal=("IRON_DARK", "IRON", "IRON_LIGHT")):
    """An old ship's lantern, 7 px wide and 13 tall from its hanging ring at (cx, top): a pointed
    cap, four panes split by a mullion with the flame showing through, a dished base. Returns
    the flame's centre (where the light goes)."""
    dark, mid, lit = metal
    ground, body, core = GLOW[glow]
    c.px(cx, top, mid)                      # ring
    c.px(cx, top + 1, dark)
    c.rect(cx - 1, top + 2, cx + 1, top + 2, mid)   # cap, widening down
    c.px(cx, top + 2, lit)
    c.rect(cx - 2, top + 3, cx + 2, top + 3, mid)
    c.px(cx - 1, top + 3, lit)
    c.rect(cx - 3, top + 4, cx + 3, top + 4, dark)
    gy0, gy1 = top + 5, top + 10
    c.rect(cx - 3, gy0, cx + 3, gy1, dark)      # frame
    c.rect(cx - 2, gy0, cx + 2, gy1, ground)    # glass
    if glow != "dark":
        # The flame: a teardrop standing on the wick, brightest at its heart.
        c.px(cx, gy0 + 1, body)
        c.rect(cx - 1, gy0 + 2, cx + 1, gy1 - 1, body)
        c.px(cx, gy0 + 2, core)
        c.px(cx, gy0 + 3, core)
        c.px(cx - 2, gy0, body, 150)            # the glass catching it at the top
        c.px(cx + 2, gy0, body, 150)
    else:
        c.px(cx - 1, gy0 + 1, "SEA_PALE")       # a cold glint on the dead glass
    c.line(cx, gy0, cx, gy1, dark if glow == "dark" else mid)  # mullion, over the flame
    if glow != "dark":
        c.px(cx, gy0 + 2, core)                 # the heart shows either side of the bar
    c.rect(cx - 3, gy1 + 1, cx + 3, gy1 + 1, mid)   # base
    c.px(cx - 3, gy1 + 1, lit)
    c.rect(cx - 2, gy1 + 2, cx + 2, gy1 + 2, dark)
    return (cx, gy0 + 3)


def crook_post(c, x, base, top, reach, dark="IRON_DARK", mid="IRON", lit="IRON_LIGHT"):
    """A cast-iron street post: a stepped plinth, a fluted shaft with a collar, and a shepherd's
    crook at the top curling out `reach` px (negative curls left). Returns the crook's tip,
    where a lantern hangs."""
    c.rect(x - 3, base - 3, x + 4, base, dark)          # plinth
    c.line(x - 3, base - 3, x + 4, base - 3, mid)
    c.rect(x - 2, base - 6, x + 3, base - 4, mid)
    c.line(x - 2, base - 6, x + 3, base - 6, lit)
    c.rect(x, top, x + 1, base - 7, mid)                # shaft
    c.line(x, top, x, base - 7, lit)
    for y in (base - 16, top + 6):                       # collars
        c.rect(x - 1, y, x + 2, y + 1, dark)
        c.px(x - 1, y, mid)
    c.px(x, top - 1, lit)                                # finial
    c.px(x, top - 2, mid)
    # The crook: up and over in a quarter circle, then a short drop to the hook.
    s = 1 if reach > 0 else -1
    r = abs(reach) // 2
    for k in range(0, 91, 6):
        a = math.radians(k)
        px_ = x + s * (r - r * math.cos(a))
        py_ = top + 1 - r * math.sin(a)
        c.px(px_, py_, mid)
        c.px(px_, py_ + 1, dark)
    for k in range(0, 91, 6):
        a = math.radians(k)
        px_ = x + s * (r + r * math.sin(a))
        py_ = top + 1 - r * math.cos(a)
        c.px(px_, py_, mid)
        c.px(px_, py_ + 1, dark)
    tip = (x + s * 2 * r, top + 2)
    c.px(tip[0] - s, tip[1] - 3, lit)                    # a curl of scrollwork under the arm
    c.px(tip[0] - 2 * s, tip[1] - 2, mid)
    return tip


def tidepool():
    """A ring of barnacled rock round a pool the tide leaves behind; anemones on the inner rim,
    weed trailing into the water. The middle lays water into the plan; the east side is open."""
    c = Canvas(72, 76)
    c.shadow(2, 62, 70, 73)
    for i, (cx, base, rx, ry) in enumerate([(26, 22, 9, 6), (46, 21, 10, 7), (12, 38, 7, 8), (60, 40, 6, 6),
                                             (14, 56, 8, 7), (34, 69, 11, 6), (54, 67, 9, 6), (62, 54, 4, 4)]):
        rock_mass(c, cx, base, rx, ry, "tp%d" % i)
    rnd = random.Random("tidepool")
    for _ in range(26):
        a = rnd.uniform(0, 2 * math.pi)
        x, y = 36 + 22 * math.cos(a), 44 + 20 * math.sin(a)
        if c.get(x, y)[3]:
            c.px(x, y, rnd.choice(["BONE_DARK", "BONE", "SALT_RED", "KELP"]))
    for x0, y0 in ((22, 28), (48, 28), (20, 50)):
        for k in range(5):
            c.px(x0 + k % 2, y0 + k, "KELP" if k % 2 else "KELP_LIGHT")
    c.foot(0, 72, 72)
    return fin(c, [".##.", "#__#", "#__.", ".##."], 72, 4)


def stones():
    """Standing stones: three slabs older than the village, one leaning, lichen and salt on them."""
    c = Canvas(88, 72)
    c.shadow(0, 58, 88, 69)
    for i, (cx, h, w, lean) in enumerate([(12, 46, 9, 0.0), (44, 34, 10, 0.12), (76, 52, 8, -0.05)]):
        for y in range(64 - h, 64):
            t = (y - (64 - h)) / h
            half = w * (0.75 + 0.25 * t)
            sx = cx + lean * (64 - y)
            for x in range(int(sx - half), int(sx + half) + 1):
                key = "STONE_LIGHT" if x < sx - half + 3 else ("STONE_DARK" if x > sx + half - 3 else "STONE")
                if y < 64 - h + 3:
                    key = "STONE_LIGHT"
                c.px(x, y, key)
        rnd = random.Random("stone%d" % i)
        for _ in range(14):
            x, y = rnd.randint(int(cx - w), int(cx + w)), rnd.randint(64 - h + 4, 60)
            if c.get(x, y)[3]:
                c.px(x, y, rnd.choice(["MOSS", "MOSS_DARK", "SALT_WHITE", "VERDIGRIS"]))
        # A spiral cut in the tallest.
        if i == 2:
            for k in range(18):
                a = k * 0.7
                c.px(cx + (1 + k * 0.25) * math.cos(a), 32 + (1 + k * 0.25) * math.sin(a), "STONE_DARK")
    c.foot(0, 88, 64)
    return fin(c, ["#.#.#"], 64, 4)


def cairn():
    """The beacon: a cairn of piled stones, an iron basket on it with the fire lit (the one warm
    light the Flats have besides the keeper)."""
    c = Canvas(40, 68)
    c.shadow(0, 54, 40, 65)
    rnd = random.Random("cairn")
    for row, (y, n, w) in enumerate([(60, 4, 8), (52, 3, 8), (44, 3, 7), (37, 2, 7), (31, 1, 7)]):
        x0 = 20 - n * w / 2
        for k in range(n):
            rock_mass(c, x0 + w / 2 + k * w + rnd.uniform(-1, 1), y, w / 2 + 0.5, 4, "cairn%d%d" % (row, k))
    # The basket.
    c.line(13, 14, 15, 27, "IRON")
    c.line(27, 14, 25, 27, "IRON")
    c.line(13, 14, 27, 14, "IRON_LIGHT")
    for x in range(14, 27, 3):
        c.line(x, 15, 20 + (x - 20) // 2, 26, "IRON_DARK")
    c.rect(17, 26, 23, 30, "IRON")
    # The fire.
    for x, y0 in ((16, 8), (18, 4), (20, 2), (22, 5), (24, 9)):
        for y in range(y0, 14):
            c.px(x, y, "AMBER" if y > y0 + 4 else ("WARM_YELLOW" if y > y0 + 1 else "PALE_CREAM"))
            c.px(x + 1, y, "AMBER_DEEP" if y > y0 + 3 else "AMBER")
    c.foot(0, 40, 64)
    return fin(c, ["##", "##"], 64, 4, {"color": "WARM", "energy": 0.6, "scale": 2.0, "at": [20, 10]})


def mast():
    """A ship's mast snapped and half buried in the sand: the yard still crossed on it, a rag of
    sail, a coil of rope, sand drifted over its foot."""
    c = Canvas(88, 44)
    c.shadow(2, 30, 86, 41)
    for x in range(4, 84):
        y = 30 - (x - 4) * 0.08
        for k in range(5):
            c.px(x, y - k, "WOOD_LIGHT" if k == 4 else ("TAR" if k == 0 else "WOOD"))
        if x % 17 == 0:
            for k in range(5):
                c.px(x, y - k, "IRON")
    # The yard, across it.
    c.line(50, 12, 64, 38, "WOOD")
    c.line(51, 12, 65, 38, "WOOD_LIGHT")
    c.line(52, 12, 66, 38, "TAR")
    # The sail's rag, dragged out over the sand.
    for k in range(9):
        c.line(54 + k, 15 + k * 2, 72 + k, 13 + k * 2, "BONE" if k % 3 else "BONE_DARK")
    # A coil of rope by the foot.
    c.ellipse(10, 31, 22, 37, "ROPE")
    c.ellipse(13, 33, 19, 35, "WEATHERED_BROWN")
    # Sand drifted over the snapped end.
    for x in range(70, 88):
        for k in range(int(3 + 3 * math.sin((x - 70) / 18 * math.pi))):
            c.px(x, 31 - k, "SAND_LIGHT" if k == 0 else "SAND")
    c.foot(2, 86, 36)
    return fin(c, ["#####"], 36, 4)


def whalebone():
    """An arch of two whale ribs set in the sand by someone, long ago; you walk under it."""
    c = Canvas(88, 84)
    c.shadow(0, 70, 22, 81)
    c.shadow(66, 70, 88, 81)
    for side in (-1, 1):
        for t in range(0, 101):
            u = t / 100
            # From the foot (u=0) up and in to the crown (u=1).
            x = 44 + side * (34 - 30 * u ** 2.2)
            y = 76 - 70 * math.sin(u * math.pi / 2)
            w = 5 - 2.5 * u
            for k in range(int(-w), int(w) + 1):
                key = "BONE" if k < -w + 2 else ("WEATHERED_BROWN" if k > w - 1 else "BONE_DARK")
                c.px(x + k, y, key)
        # Barnacles at the foot.
        for k in range(6):
            c.px(44 + side * 34 + (k % 3) - 1, 70 - k, "STONE" if k % 2 else "BONE_DARK")
    c.ellipse(41, 3, 47, 9, "BONE")
    c.line(42, 8, 46, 8, "BONE_DARK")
    for y in range(9, 22):
        c.px(44 + (y // 4) % 2, y, "KELP" if y % 3 else "KELP_LIGHT")
    c.foot(0, 88, 76)
    return fin(c, ["#...#"], 76, 4)


# --- the Streets, second batch ------------------------------------------------------------------

def tower():
    """A collapsed tower: the round stump of a watchtower, its top broken off in a jagged line, a
    window slit black, moss to the high-water line, rubble spilled round."""
    c = Canvas(88, 124)
    c.shadow(0, 104, 88, 120)
    rnd = random.Random("tower")
    # Broken off on a slant, high on the west, jagged along the break.
    top = [12 + (x - 14) * 0.55 + 4 * abs(math.sin(x * 0.9)) + 3 * math.sin(x * 0.37) for x in range(88)]
    for x in range(14, 74):
        u = (x - 44) / 30
        for y in range(int(top[x]), 104):
            course = (y - 10) // 6
            mortar = (y - 10) % 6 == 5 or (x + course * 5) % 11 == 0
            key = "NIGHT_1" if mortar else ("SLATE" if u < -0.55 else ("NIGHT_2" if u > 0.55 else "STONE_DARK"))
            if y > 70 and not mortar and rnd.random() < 0.2:
                key = "MOSS_DARK"
            c.px(x, y, key)
        c.px(x, int(top[x]), "WET_GREY")
    for x in range(14, 74):
        if rnd.random() < 0.5:
            c.px(x, 70 + int(2 * math.sin(x / 5.0)), "MOSS")
    c.rect(40, 44, 45, 60, "ABYSS")
    c.line(40, 44, 45, 44, "SLATE")
    c.rect(26, 80, 33, 100, "ABYSS")
    c.line(26, 79, 33, 79, "SLATE")
    # Rubble spilled at its foot.
    for i, (cx, base, rx, ry) in enumerate([(10, 108, 7, 5), (78, 110, 8, 5), (66, 112, 6, 4), (22, 112, 5, 3)]):
        rock_mass(c, cx, base, rx, ry, "tw%d" % i, "STONE_LIGHT", "STONE", "SLATE")
    c.foot(0, 88, 112)
    return fin(c, ["#####", "#####", ".###."], 112, 4)


def steps():
    """Steps up to a terrace, a balustrade either side: the treads lay a deck (raised ground)."""
    c = Canvas(88, 52)
    c.shadow(0, 40, 88, 50)
    for side_x in (4, 68):
        c.rect(side_x, 2, side_x + 15, 44, "STONE")
        c.rect(side_x, 2, side_x + 15, 5, "STONE_LIGHT")
        for x in range(side_x + 2, side_x + 15, 4):
            c.rect(x, 8, x + 1, 40, "WET_GREY")
            c.px(x, 8, "PALE_SLATE")
        c.line(side_x, 6, side_x + 15, 6, "NIGHT_2")
        c.rect(side_x, 41, side_x + 15, 44, "SLATE")
    for k, y in enumerate(range(12, 44, 6)):
        c.rect(20, y, 67, y + 3, "WET_GREY")
        c.rect(20, y + 4, 67, y + 5, "SLATE")
        c.line(20, y, 67, y, "PALE_SLATE")
        if k % 2:
            c.px(30 + k * 5, y + 2, "MOSS")
    c.foot(4, 84, 44)
    return fin(c, ["#===#", "#===#"], 44, 4)


def lamps():
    """Two cast-iron street lamps, one knocked crooked, their lanterns dark (they are lit only in
    story moments), a tavern sign still hanging from the first."""
    c = Canvas(72, 72)
    c.shadow(0, 60, 26, 70)
    c.shadow(46, 60, 72, 70)
    tip = crook_post(c, 10, 63, 20, 10)
    c.px(tip[0], tip[1], "IRON_DARK")
    lantern(c, tip[0], tip[1] + 1, "dark")
    # The sign: a plank on two chains from a bar on the shaft, below the lantern.
    c.line(11, 40, 25, 40, "IRON")
    c.px(25, 39, "IRON_LIGHT")
    for x in (14, 22):
        c.px(x, 41, "IRON_DARK")
        c.px(x, 42, "IRON")
    c.rect(12, 43, 24, 50, "WOOD")
    c.line(12, 43, 24, 43, "WOOD_LIGHT")
    c.line(12, 50, 24, 50, "TAR")
    for x, y in ((15, 46), (16, 45), (17, 46), (18, 47), (19, 46), (20, 45), (21, 46)):
        c.px(x, y, "BONE_DARK")          # a painted fish, half worn off
    c.px(16, 47, "BONE_DARK")
    # The second post, its crook turned the other way, the lantern hanging by one chain, tipped.
    t2 = crook_post(c, 61, 63, 20, -10)
    c.px(t2[0], t2[1], "IRON_DARK")
    lantern(c, t2[0], t2[1] + 1, "dark")
    c.foot(0, 72, 64)
    return fin(c, ["#..#"], 64, 4)


def fallen():
    """A statue of some harbourmaster, off its plinth and on its back in the street, an arm broken
    off beside it; moss where the water lay on it."""
    c = Canvas(72, 52)
    c.shadow(0, 38, 72, 49)
    c.poly([(54, 14), (70, 18), (68, 44), (52, 42)], "STONE")
    c.poly([(54, 14), (70, 18), (70, 22), (54, 18)], "STONE_LIGHT")
    for x in range(10, 52):
        h = 10 + 3 * math.sin((x - 10) / 42 * math.pi)
        for y in range(int(32 - h), 40):
            key = "STONE_LIGHT" if y < 32 - h + 3 else ("STONE" if y < 36 else "STONE_DARK")
            c.px(x, y, key)
    c.ellipse(2, 24, 16, 38, "STONE")
    c.ellipse(4, 26, 14, 34, "STONE_LIGHT")
    c.px(7, 29, "STONE_DARK")
    c.px(11, 29, "STONE_DARK")
    c.line(22, 26, 40, 25, "STONE")
    c.rect(30, 44, 44, 47, "STONE")
    c.line(30, 47, 44, 47, "STONE_DARK")
    for x in range(12, 50, 3):
        c.px(x, 38 + (x % 2), "MOSS")
    c.foot(0, 72, 44)
    return fin(c, ["####", "####"], 44, 4)


def bridge():
    """A stone bridge over the canal: parapets north and south, the deck between (it lays a deck,
    raised ground the canal floods last), the arch's face dark over the water below."""
    c = Canvas(104, 84)
    c.shadow(0, 72, 104, 82)
    # The deck.
    for y in range(24, 56):
        for x in range(4, 100):
            joint = (y - 24) % 8 == 7 or (x + ((y - 24) // 8) * 6) % 12 == 0
            c.px(x, y, "SLATE" if joint else "WET_GREY")
    # The parapets: coping lit, the wall below it.
    for y0 in (6, 56):
        c.rect(2, y0, 101, y0 + 3, "PALE_SLATE")
        c.rect(2, y0 + 4, 101, y0 + 17, "STONE")
        for x in range(2, 102, 8):
            c.line(x, y0 + 4, x, y0 + 17, "STONE_DARK")
        c.line(2, y0 + 17, 101, y0 + 17, "NIGHT_2")
    # The arch's face under the south parapet, dark over the water.
    for x in range(2, 102):
        y1 = 74 + 6 * math.sin((x - 2) / 99 * math.pi)
        for y in range(74, 80):
            if y < y1:
                c.px(x, y, "NIGHT_2" if y < 76 else "NIGHT_1")
    c.rect(2, 74, 7, 82, "STONE_DARK")
    c.rect(96, 74, 101, 82, "STONE_DARK")
    for x in (30, 70):
        c.px(x, 60, "MOSS")
    return fin(c, ["######", "======", "======", "######"], 72, 4)


# --- the Harbour, second batch ------------------------------------------------------------------

def pier():
    """A timber pier over the water: planks across, tarred side beams, posts going down at its
    end, a rope coil, a bollard. It lays a deck: raised ground, the last to flood."""
    c = Canvas(56, 108)
    for y in range(2, 100):
        for x in range(4, 52):
            seam = (y - 2) % 6 == 5
            key = "TAR" if seam else ("WOOD_LIGHT" if (y // 6 + x // 13) % 5 == 0 else "WOOD")
            if x < 7 or x > 48:
                key = "TAR" if x in (4, 51) else "WEATHERED_BROWN"
            c.px(x, y, key)
    # The posts down into the water at the end.
    for x in (5, 26, 47):
        c.rect(x, 100, x + 3, 106, "TAR")
        c.px(x + 1, 106, "FOAM_WHITE")
    c.rect(4, 98, 51, 100, "TAR")
    c.rect(8, 8, 13, 14, "IRON")
    c.line(8, 8, 13, 8, "IRON_LIGHT")
    c.ellipse(34, 60, 46, 68, "ROPE")
    c.ellipse(37, 62, 43, 66, "WEATHERED_BROWN")
    return fin(c, ["==="] * 6, 100, 4)


def moored():
    """A fishing boat moored in the channel: a tarred hull, a mast stepped and its sail furled, the
    line to the quay slack, foam along its waterline."""
    c = Canvas(84, 64)
    for x in range(4, 80):
        u = (x - 4) / 76
        k = math.sin(min(u, 0.85) * math.pi) ** 0.5
        half = 13 * k if u < 0.85 else 13 * k * (1 - (u - 0.85) / 0.15)
        for y in range(int(44 - half), int(44 + half * 0.6) + 1):
            dy = y - 44
            key = "TAR" if dy > half * 0.35 else ("WOOD" if dy > -half + 3 else "WOOD_LIGHT")
            if -half + 3 < dy < half * 0.3 and abs(dy) < half - 5:
                key = "WEATHERED_BROWN"
            c.px(x, y, key)
        c.px(x, int(44 + half * 0.6) + 1, "FOAM_WHITE" if x % 3 else "SEA_PALE")
    for x in (28, 50):
        c.line(x, 36, x, 50, "WOOD_LIGHT")
    c.rect(38, 6, 40, 44, "WOOD")
    c.line(38, 6, 38, 44, "WOOD_LIGHT")
    c.rect(32, 20, 46, 24, "BONE_DARK")
    c.line(32, 20, 46, 20, "BONE")
    c.line(4, 40, 0, 30, "ROPE")
    return fin(c, ["####", "####"], 56, 10)


def capstan():
    """A capstan on the quay: an iron drum with rope wound on, its bars out like spokes."""
    c = Canvas(40, 56)
    c.shadow(0, 42, 40, 53)
    c.rect(10, 18, 29, 46, "IRON")
    c.rect(10, 18, 12, 46, "IRON_LIGHT")
    c.rect(27, 18, 29, 46, "IRON_DARK")
    for y in range(26, 42, 2):
        c.line(10, y, 29, y, "ROPE")
    c.ellipse(8, 12, 31, 22, "IRON_LIGHT")
    c.ellipse(11, 14, 28, 20, "IRON")
    for (x0, y0, x1, y1) in ((2, 16, 12, 17), (28, 17, 38, 15), (16, 8, 20, 14), (20, 20, 24, 26)):
        c.line(x0, y0, x1, y1, "WOOD_LIGHT")
        c.line(x0, y0 + 1, x1, y1 + 1, "WOOD")
    c.rect(8, 44, 31, 48, "STONE")
    c.foot(8, 31, 48)
    return fin(c, ["##", "##"], 48, 4)


def slipway():
    """A slipway: timber sleepers and two iron rails running down off the quay into the water,
    the low end under the tide. Walkable: it lays nothing."""
    c = Canvas(72, 84)
    for y in range(2, 82):
        a = 255 if y < 50 else max(70, 255 - (y - 50) * 6)
        if (y - 2) % 8 < 4:
            c.rect(6, y, 65, y, "WOOD", a)
            if (y - 2) % 8 == 0:
                c.rect(6, y, 65, y, "WOOD_LIGHT", a)
        for x in (16, 54):
            c.px(x, y, "IRON_LIGHT", a)
            c.px(x + 1, y, "IRON", a)
    for x in range(6, 66, 2):
        c.px(x, 58 + (x % 4), "FOAM_WHITE", 200)
    return fin(c, ["...."] * 5, 82, 4)


def crates():
    """Cargo stacked on the quay: crates two high, a barrel, a tarp pulled half over, roped."""
    c = Canvas(56, 68)
    c.shadow(0, 54, 56, 65)

    def box(x0, y0, x1, y1):
        c.rect(x0, y0, x1, y1, "WOOD")
        c.rect(x0, y0, x1, y0 + 2, "WOOD_LIGHT")
        for y in range(y0 + 5, y1, 4):
            c.line(x0, y, x1, y, "WEATHERED_BROWN")
        c.line(x0, y0 + 3, x1, y1, "TAR")
        c.rect(x0, y0, x0, y1, "TAR")
        c.rect(x1, y0, x1, y1, "TAR")
    box(2, 38, 19, 59)
    box(20, 38, 37, 59)
    box(10, 18, 27, 37)
    c.rect(40, 34, 53, 59, "WOOD")
    c.rect(40, 34, 53, 37, "WOOD_LIGHT")
    for y in (40, 52):
        c.line(40, y, 53, y, "IRON")
    c.line(43, 38, 43, 58, "WEATHERED_BROWN")
    c.poly([(8, 16), (30, 18), (38, 40), (26, 42)], "OILSKIN_DARK")
    c.poly([(8, 16), (30, 18), (31, 21), (10, 19)], "OILSKIN")
    c.line(2, 47, 37, 47, "ROPE")
    c.line(18, 18, 18, 59, "ROPE")
    c.foot(2, 53, 60)
    return fin(c, ["###", "###"], 60, 4)


# --- the Hall, second batch ---------------------------------------------------------------------

def _shaft(c, x0, top, base):
    """A fluted basalt column: plinth, shaft lit from the left, capital."""
    c.rect(x0 + 2, base - 10, x0 + 29, base, "BASALT_LIGHT")
    c.line(x0 + 2, base - 10, x0 + 29, base - 10, "IRON_LIGHT")
    c.rect(x0 + 2, base - 4, x0 + 29, base, "BASALT")
    for y in range(top + 6, base - 10):
        for x in range(x0 + 6, x0 + 26):
            flute = (x - x0 - 6) % 4
            key = "BASALT_LIGHT" if x < x0 + 10 else ("BASALT_DARK" if x > x0 + 21 else "BASALT")
            if flute == 0:
                key = "BASALT_DARK" if x > x0 + 9 else "BASALT"
            c.px(x, y, key)
    c.rect(x0 + 3, top, x0 + 28, top + 6, "BASALT_LIGHT")
    c.rect(x0 + 3, top + 4, x0 + 28, top + 6, "BASALT")


def gate():
    """Two columns and the lintel still on them: a doorway with no wall left round it."""
    c = Canvas(96, 112)
    c.shadow(0, 95, 32, 108)
    c.shadow(64, 95, 96, 108)
    _shaft(c, 0, 20, 104)
    _shaft(c, 64, 20, 104)
    c.rect(0, 6, 95, 19, "BASALT")
    c.rect(0, 6, 95, 9, "BASALT_LIGHT")
    c.line(0, 6, 95, 6, "IRON_LIGHT")
    c.line(0, 19, 95, 19, "INK")
    for x in range(30, 66):
        c.px(x, 13 + int(2 * math.sin((x - 30) / 36 * 4 * math.pi)), "IRON")
    for x0 in (36, 52, 60):
        for y in range(20, 34 + x0 % 7):
            c.px(x0 + (y // 4) % 2, y, "KELP" if y % 3 else "KELP_LIGHT")
    c.foot(0, 96, 104)
    return fin(c, ["##..##", "##..##"], 104, 0)


def organ():
    """The organ: a basalt case and its console, pipes rising behind in bronze and iron, some
    bent, one fallen across the others, weed hung from their mouths."""
    c = Canvas(104, 132)
    c.shadow(0, 112, 104, 128)
    rnd = random.Random("organ")
    for i, x in enumerate(range(8, 96, 6)):
        bronze = i % 4 == 2  # a few bronze pipes among the iron: the Hall stays near-black
        h = 70 + 30 * math.sin(i / 14 * math.pi) + rnd.randint(-6, 6)
        y0 = int(92 - h)
        for y in range(y0, 92):
            c.rect(x, y, x + 4, y, "BRONZE_DARK" if bronze else "IRON_DARK")
            c.px(x + 1, y, "BRONZE" if bronze else "IRON")
            c.px(x + 4, y, "BASALT_DARK")
        c.rect(x + 1, y0 + 22, x + 3, y0 + 25, "ABYSS")
        c.rect(x, y0, x + 4, y0 + 1, "BRONZE" if bronze else "IRON")
        if i % 4 == 1:
            for y in range(y0 + 26, y0 + 34):
                c.px(x + 2, y, "KELP")
    c.line(14, 20, 70, 60, "IRON_DARK")
    c.line(14, 21, 70, 61, "IRON")
    c.rect(2, 86, 101, 120, "BASALT")
    c.rect(2, 86, 101, 89, "BASALT_LIGHT")
    c.line(2, 86, 101, 86, "IRON_LIGHT")
    c.rect(26, 94, 77, 104, "BASALT_DARK")
    for x in range(28, 76, 3):
        c.rect(x, 98, x + 1, 103, "BONE")
        c.px(x + 2, 98, "ABYSS")
    for x in (10, 90):
        c.line(x, 92, x, 118, "BASALT_DARK")
    c.foot(2, 101, 120)
    return fin(c, ["######", "######"], 120, 4)


def rose():
    """The rose window fallen flat on the floor: iron tracery in rings and spokes, a few panes of
    glass left in it, most broken out. Flat: you walk over it."""
    c = Canvas(72, 72)
    cx, cy, R = 36, 36, 32
    glass = ["DEEP_VIOLET", "SEA", "SHALLOW", "AMBER_DEEP", "VIOLET_LIGHT"]
    rnd = random.Random("rose")
    kept = {}
    for ring in range(3):
        for sector in range(16):
            kept[(ring, sector)] = rnd.random() < 0.4
    for y in range(72):
        for x in range(72):
            d = math.hypot(x - cx, y - cy)
            if d > R:
                continue
            a = (math.atan2(y - cy, x - cx) + math.pi) / (2 * math.pi)
            ring = min(2, int(d / 11))
            sector = int(a * 16) % 16
            if kept[(ring, sector)]:
                c.px(x, y, glass[(ring * 3 + sector) % len(glass)], 200)
    for r in (10, 21, 31, 32):
        for k in range(360):
            a = k / 360 * 2 * math.pi
            c.px(cx + r * math.cos(a), cy + r * math.sin(a), "IRON")
    for k in range(16):
        a = k / 16 * 2 * math.pi
        r0 = 10 if k % 2 else 0
        for r in range(r0, 32):
            c.px(cx + r * math.cos(a), cy + r * math.sin(a), "IRON_DARK" if r > 21 else "IRON")
    c.ellipse(cx - 4, cy - 4, cx + 4, cy + 4, "IRON_LIGHT")
    for _ in range(18):
        x, y = rnd.randint(4, 68), rnd.randint(4, 68)
        c.px(x, y, rnd.choice(glass))
    return fin(c, ["...."] * 4, 68, 4)


def apse():
    """A length of apse wall: coursed basalt curving, two niches with nothing left in them but a
    candle stub, a cornice above."""
    c = Canvas(104, 104)
    c.shadow(0, 88, 104, 100)
    for x in range(2, 102):
        top = 14 + 8 * ((x - 52) / 50) ** 2
        for y in range(int(top), 96):
            course = (y - 14) // 7
            mortar = (y - 14) % 7 == 6 or (x + course * 9) % 18 == 0
            c.px(x, y, "BASALT_DARK" if mortar else ("BASALT_LIGHT" if x < 8 else "BASALT"))
        for y in range(int(top) - 6, int(top)):
            c.px(x, y, "BASALT_LIGHT" if y < top - 3 else "BASALT")
        c.px(x, int(top) - 6, "IRON_LIGHT")
    for nx in (24, 66):
        for y in range(36, 80):
            for x in range(nx, nx + 15):
                if y > 43 or math.hypot(x - nx - 7, y - 43) <= 7.5:
                    c.px(x, y, "ABYSS")
        c.rect(nx - 1, 80, nx + 15, 82, "BASALT_LIGHT")
    c.rect(30, 74, 31, 79, "BONE")
    c.px(30, 74, "BONE_LIGHT")
    for x in range(2, 102, 9):
        for y in range(20, 30 + x % 7):
            c.px(x + (y // 3) % 2, y, "KELP")
    c.foot(2, 101, 96)
    return fin(c, ["######", "######"], 96, 4)


def font():
    """A font of brine on a pedestal: the water in it glows cold, as the drowned do."""
    c = Canvas(40, 60)
    c.shadow(0, 46, 40, 57)
    c.rect(4, 48, 35, 52, "BASALT_LIGHT")
    c.rect(4, 51, 35, 52, "BASALT")
    c.rect(14, 28, 25, 48, "BASALT")
    c.line(14, 28, 14, 48, "BASALT_LIGHT")
    c.line(25, 28, 25, 48, "BASALT_DARK")
    c.ellipse(2, 14, 37, 30, "BASALT_LIGHT")
    c.ellipse(2, 20, 37, 32, "BASALT")
    c.ellipse(6, 16, 33, 26, "DEEP_SEA")
    c.ellipse(9, 17, 30, 24, "SEA")
    for x, y in ((14, 19), (22, 21), (26, 18), (18, 22)):
        c.px(x, y, "SEA_PALE")
    c.line(4, 22, 4, 30, "KELP")
    c.foot(4, 35, 52)
    return fin(c, ["##", "##"], 52, 4, {"color": "COLD", "energy": 0.4, "scale": 1.4, "at": [20, 20]})


# --- world light (map Stage 07) -----------------------------------------------------------------
# Small pieces that carry a light, placed by the plan to mark fight pockets and doors (STYLE.md 22,
# Light; 11 for the colours). Each biome keeps its warm rule: the Flats' only warm light is the
# beacon (the cairn), the Harbour has one hanging lamp a room, the Streets' lamps burn cold (they
# are relit warm only in story moments), the Hall has its candle drifts. Everything else is cold:
# Sea pale, low energy, small.

def kelplight():
    """A clump of kelp on a stone at the tide line, its bladders glowing cold."""
    c = Canvas(24, 40)
    c.shadow(2, 30, 22, 38)
    rock_mass(c, 12, 35, 7, 3, "kl", "STONE", "STONE_DARK", "STONE_DARK")
    for x0, h, ph in ((7, 22, 0.0), (11, 28, 1.3), (15, 24, 2.1), (18, 16, 0.7)):
        for y in range(34 - h, 33):
            x = x0 + 1.5 * math.sin(y * 0.35 + ph)
            c.px(x, y, "KELP" if y % 3 else "KELP_LIGHT")
        for k in range(3):
            c.px(x0 + 1.5 * math.sin((34 - h + 3 + k * 6) * 0.35 + ph) + 1, 34 - h + 3 + k * 6, "SEA_PALE")
        c.px(x0 + 1.5 * math.sin((34 - h) * 0.35 + ph), 34 - h, "FOAM_WHITE")
    c.foot(4, 20, 36)
    return fin(c, ["#"], 36, 4, {"color": "COLD", "energy": 0.4, "scale": 1.6, "at": [12, 16]})


def lamppost():
    """A quay lamp: a tarred timber post, an iron bracket with a brace, the lantern hung from it
    on a hook (the Harbour's one warm light in a room without the crane)."""
    c = Canvas(32, 72)
    c.shadow(2, 60, 24, 70)
    c.rect(10, 8, 13, 66, "WOOD")
    c.line(10, 8, 10, 66, "WOOD_LIGHT")
    c.line(13, 8, 13, 66, "TAR")
    c.rect(10, 7, 13, 7, "TAR")
    c.rect(9, 59, 14, 66, "TAR")
    c.line(9, 59, 14, 59, "WOOD")
    for y in (28, 44):                       # iron bands
        c.line(10, y, 13, y, "IRON")
        c.px(10, y, "IRON_LIGHT")
    for y in range(36, 52, 5):               # weed at the tide line
        c.px(10, y, "MOSS")
    c.line(13, 11, 25, 11, "IRON")           # the arm
    c.line(13, 12, 25, 12, "IRON_DARK")
    c.line(14, 19, 22, 12, "IRON_DARK")      # brace
    c.px(15, 18, "IRON")
    c.px(25, 10, "IRON_LIGHT")
    c.px(24, 13, "IRON")
    flame = lantern(c, 24, 14, "warm", ("IRON_DARK", "BRONZE_DARK", "BRONZE"))
    c.foot(9, 14, 67)
    return fin(c, ["#"], 67, 4, {"color": "WARM", "energy": 0.6, "scale": 2.2, "at": list(flame)})


def buoy():
    """A channel buoy afloat: a rusted can hull with a pale band, an iron cage tower on it and the
    lantern at the top burning cold."""
    c = Canvas(24, 36)
    # Hull, seen from the south: a squat drum, lit on top.
    c.ellipse(3, 19, 20, 33, "RUST")
    c.ellipse(4, 19, 19, 25, "RUST_LIGHT")
    c.ellipse(6, 20, 17, 24, "RUST")
    c.rect(3, 26, 20, 27, "BONE_DARK")
    c.line(3, 26, 20, 26, "BONE")
    c.ellipse(4, 28, 19, 33, "IRON_DARK")
    # The cage: two legs leaning in, cross braced.
    c.line(6, 22, 9, 12, "IRON")
    c.line(17, 22, 14, 12, "IRON_DARK")
    c.line(7, 19, 16, 19, "IRON_DARK")
    c.line(8, 15, 15, 15, "IRON_DARK")
    c.line(7, 19, 15, 15, "IRON")
    flame = lantern(c, 11, 0, "cold")
    c.line(9, 12, 14, 12, "IRON")
    # Water slapping round the waterline.
    for x in range(1, 23):
        c.px(x, 32 + (x % 3 == 0), "FOAM_WHITE" if x % 4 else "SEA_PALE")
    return fin(c, ["#"], 32, 4, {"color": "COLD", "energy": 0.45, "scale": 1.6, "at": list(flame)})


def shrine():
    """A wayside shrine: a stone stele under a pitched slate cap, an arched niche with a glass jar
    of sea-light in it, shells and a stub of candle left on the ledge by whoever still comes."""
    c = Canvas(24, 48)
    c.shadow(1, 38, 23, 46)
    # Plinth and shaft.
    c.rect(3, 38, 20, 43, "STONE_DARK")
    c.line(3, 38, 20, 38, "STONE")
    c.rect(5, 11, 18, 37, "STONE")
    c.line(5, 11, 5, 37, "STONE_LIGHT")
    c.line(18, 11, 18, 37, "STONE_DARK")
    for y in (17, 24, 31):                       # courses, offset joints
        c.line(6, y, 17, y, "STONE_DARK")
    # Pitched cap with a cross-stone on the ridge.
    c.poly([(2, 12), (11.5, 3), (21, 12)], "SLATE")
    c.line(2, 12, 11, 3, "WET_GREY")
    c.line(12, 3, 21, 12, "NIGHT_2")
    c.line(2, 12, 21, 12, "NIGHT_1")
    c.rect(11, 0, 12, 3, "STONE_LIGHT")
    c.line(10, 1, 13, 1, "STONE_LIGHT")
    # The niche: a round-headed arch cut into the shaft.
    for y in range(15, 31):
        for x in range(7, 17):
            if y > 19 or math.hypot(x - 11.5, y - 19.5) <= 4.6:
                c.px(x, y, "ABYSS")
    c.line(7, 20, 7, 30, "STONE_DARK")                # the niche's shadowed jamb
    # The jar: a rounded glass body, a cord at the neck, light inside.
    c.rect(10, 21, 13, 21, "IRON")                  # lid
    c.rect(10, 22, 13, 22, "SEA")                   # neck
    c.ellipse(8, 22, 15, 30, "SEA")
    c.ellipse(9, 23, 14, 29, "SEA_PALE")
    c.rect(11, 25, 12, 27, "SALT_WHITE")
    c.px(9, 24, "FOAM_WHITE")                       # catch-light on the glass
    c.line(10, 22, 13, 22, "ROPE")
    # Ledge with offerings.
    c.rect(6, 31, 17, 32, "STONE_LIGHT")
    c.line(6, 32, 17, 32, "STONE_DARK")
    c.px(7, 30, "BONE")
    c.px(8, 30, "BONE_LIGHT")
    c.px(15, 30, "BONE")
    c.rect(16, 28, 16, 30, "BONE")                  # candle stub, cold
    for x in range(5, 19, 3):
        c.px(x, 36, "MOSS")
        c.px(x + 1, 37, "MOSS_DARK")
    c.foot(3, 20, 44)
    return fin(c, ["#"], 44, 4, {"color": "COLD", "energy": 0.4, "scale": 1.6, "at": [11, 26]})


def coldlamp():
    """A cast-iron street lamp with a shepherd's crook, its lantern burning cold: the drowned
    have lit it with the sea. Kelp hangs from the arm."""
    c = Canvas(24, 68)
    c.shadow(2, 56, 22, 66)
    tip = crook_post(c, 7, 63, 18, 10)
    c.px(tip[0], tip[1], "IRON_DARK")
    c.px(tip[0], tip[1] + 1, "IRON")
    flame = lantern(c, tip[0], tip[1] + 2, "cold")
    for y in range(13, 20):
        c.px(10 + (y // 2) % 2, y + 3, "KELP" if y % 3 else "KELP_LIGHT")
    c.foot(4, 11, 64)
    return fin(c, ["#"], 64, 4, {"color": "COLD", "energy": 0.5, "scale": 2.0, "at": list(flame)})


def candles():
    """A drift of candles burned down on the flags, wax run together (a warm light of the Hall)."""
    c = Canvas(28, 32)
    c.shadow(2, 22, 26, 30)
    c.ellipse(3, 21, 25, 28, "BONE_DARK")
    for x, h in ((5, 6), (8, 10), (11, 4), (14, 12), (17, 7), (20, 9), (23, 5)):
        c.rect(x, 25 - h, x + 1, 25, "BONE_DARK")
        c.px(x, 25 - h, "BONE")
        c.px(x, 24 - h, "AMBER")
        c.px(x, 23 - h, "WARM_YELLOW")
    c.foot(3, 25, 28)
    return fin(c, ["#"], 28, 6, {"color": "FLAME", "energy": 0.35, "scale": 1.2, "at": [14, 14]})


def kelpglow():
    """A kelp strand risen through a cracked flag, its bladders glowing cold in the dark Hall."""
    c = Canvas(24, 60)
    c.shadow(2, 48, 22, 58)
    c.rect(2, 50, 21, 55, "BASALT")
    c.line(2, 50, 21, 50, "BASALT_LIGHT")
    c.line(6, 51, 12, 55, "BASALT_DARK")
    c.line(12, 51, 17, 54, "BASALT_DARK")
    for y in range(6, 51):
        x = 12 + 3 * math.sin(y * 0.22)
        c.px(x, y, "KELP" if y % 4 else "KELP_LIGHT")
        c.px(x + 1, y, "KELP")
    for y in range(10, 48, 7):
        x = 12 + 3 * math.sin(y * 0.22)
        c.px(x - 2, y, "SEA_PALE")
        c.px(x + 3, y + 2, "SEA_PALE")
    c.px(12, 6, "FOAM_WHITE")
    c.foot(2, 21, 56)
    return fin(c, ["#"], 56, 4, {"color": "COLD", "energy": 0.4, "scale": 1.8, "at": [12, 24]})


PIECES = [
    ("wreck", "flats", wreck), ("arch", "flats", arch), ("boat", "flats", boat),
    ("house", "streets", house), ("well", "streets", well), ("stall", "streets", stall),
    ("crane", "harbour", crane), ("warehouse", "harbour", warehouse), ("netrack", "harbour", netrack),
    ("column", "deep", column), ("altar", "deep", altar), ("statue", "deep", statue),
    # The second batch.
    ("tidepool", "flats", tidepool), ("stones", "flats", stones), ("cairn", "flats", cairn),
    ("mast", "flats", mast), ("whalebone", "flats", whalebone),
    ("tower", "streets", tower), ("steps", "streets", steps), ("lamps", "streets", lamps),
    ("fallen", "streets", fallen), ("bridge", "streets", bridge),
    ("pier", "harbour", pier), ("moored", "harbour", moored), ("capstan", "harbour", capstan),
    ("slipway", "harbour", slipway), ("crates", "harbour", crates),
    ("gate", "deep", gate), ("organ", "deep", organ), ("rose", "deep", rose),
    ("apse", "deep", apse), ("font", "deep", font),
    # World light (map Stage 07).
    ("kelplight", "flats", kelplight), ("lamppost", "harbour", lamppost), ("buoy", "harbour", buoy),
    ("shrine", "streets", shrine), ("coldlamp", "streets", coldlamp),
    ("candles", "deep", candles), ("kelpglow", "deep", kelpglow),
]
LOOK_ROW = ["flats", "streets", "deep", "harbour"]
FLOOR = {"flats": "SAND", "streets": "STONE", "deep": "BASALT", "harbour": "WOOD"}


def main():
    built = {}
    for pid, look, fn in PIECES:
        out = fn()
        canvas, foot, origin = out[0], out[1], out[2]
        light = out[3] if len(out) > 3 else None
        assert all(len(r) == len(foot[0]) for r in foot), pid
        # The sprite's bottom must sit no higher than the footprint's south edge.
        assert origin[1] + len(foot) * T <= canvas.h, pid
        built[pid] = (look, canvas, foot, origin, light)
    # Pack: one row per look, pieces left to right, rows as tall as their tallest piece.
    rows = {look: [p for p in built if built[p][0] == look] for look in LOOK_ROW}
    heights = {look: max([built[p][1].h for p in rows[look]] or [0]) for look in LOOK_ROW}
    width = max(sum(built[p][1].w + 2 for p in rows[look]) for look in LOOK_ROW)
    atlas = Image.new("RGBA", (width, sum(heights.values()) + 2 * len(LOOK_ROW)), (0, 0, 0, 0))
    meta = {}
    y = 0
    for look in LOOK_ROW:
        x = 0
        for pid in rows[look]:
            _, canvas, foot, origin, light = built[pid]
            atlas.alpha_composite(canvas.im, (x, y))
            meta[pid] = {"look": look, "region": [x, y, canvas.w, canvas.h], "foot": foot, "origin": list(origin)}
            if light:
                meta[pid]["light"] = light
            x += canvas.w + 2
        y += heights[look] + 2
    atlas.save(os.path.join(SPRITES, "set_pieces.png"))
    with open(os.path.join(DATA, "set_pieces.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(meta, fh, indent=1)
        fh.write("\n")
    # Review sheet: each piece over its floor with its footprint ticked, at 1x and 3x.
    sheet_rows = []
    for look in LOOK_ROW:
        tiles = []
        for pid in rows[look]:
            _, canvas, foot, origin, _ = built[pid]
            bg = Image.new("RGBA", (canvas.w + 16, canvas.h + 8), P.rgba(FLOOR[look]))
            d = ImageDraw.Draw(bg)
            for fy, row in enumerate(foot):
                for fx, ch in enumerate(row):
                    # Solid in red, a deck it lays in amber, water in pale sea.
                    tick = {"#": "SALT_RED", "=": "AMBER", "_": "SEA_PALE"}.get(ch)
                    if tick:
                        x0, y0 = 8 + origin[0] + fx * T, 4 + origin[1] + fy * T
                        d.rectangle([x0, y0, x0 + T - 1, y0 + T - 1], outline=P.rgba(tick, 160))
            bg.alpha_composite(canvas.im, (8, 4))
            tiles.append(bg)
        w = sum(t.width for t in tiles)
        h = max(t.height for t in tiles)
        row = Image.new("RGBA", (w, h), P.rgba("INK"))
        xx = 0
        for t in tiles:
            row.alpha_composite(t, (xx, 0))
            xx += t.width
        sheet_rows.append(row)
    sw = max(r.width for r in sheet_rows)
    sh = sum(r.height for r in sheet_rows)
    sheet = Image.new("RGBA", (sw, sh), P.rgba("INK"))
    yy = 0
    for r in sheet_rows:
        sheet.alpha_composite(r, (0, yy))
        yy += r.height
    os.makedirs(REF, exist_ok=True)
    sheet.resize((sw * 3, sh * 3), Image.NEAREST).save(os.path.join(REF, "set_pieces_sheet.png"))
    print("wrote set_pieces.png %s, set_pieces.json (%d pieces), set_pieces_sheet.png" % (atlas.size, len(meta)))


if __name__ == "__main__":
    main()
