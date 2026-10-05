"""The door arches, drawn for the wall they stand in (map review 2026-10-05).

The old door.png was one north-wall arch that door.gd turned to face the room, so on a side wall
it lay on its side and in the south wall it stood on its head. Now every wall has its own
drawing, seen as the rest of the room is (from the south and above, lit from the top):

    north wall   the arch face-on: coursed voussoirs, a keystone, the door in it
    south wall   the wall's top: two gate posts, the way out running down between them
    west / east  the posts seen from above, the passage running out sideways into the dark,
                 the door leaf turned to show its face toward the room

    assets/sprites/door.png   6 columns (shut, open, water-closed, flooded, wet shut, wet open)
                              x 5 rows (north, south, west, east, stair), 32x32 cells, centred
                              on the door cell. The stair row is the hub's way down: it stands in
                              the sea, not in a wall, so it is the sea going deep (a dark hole,
                              a swirl turning down, foam on its far lip), the same in every state
    assets/reference/maps/doors_sheet.png   every cell over Stone at 4x

The shut door is planks with iron straps and a ring (not bars); the wet way's shut door is a
rusted sea-gate hung with kelp, so the two read apart.

Run:  python tools/gen_doors.py   (gen_water.py calls build_doors() too)
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
from gen_set_pieces import Canvas  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
REF = os.path.join(P.ROOT, "assets", "reference", "maps")
C = 32
STATES = ["shut", "open", "water_closed", "flooded", "wet_shut", "wet_open"]
FACINGS = ["north", "south", "west", "east", "stair"]
# state -> (what fills the doorway, what water there is)
LOOK = {
    "shut": ("door", None), "open": ("open", None), "water_closed": ("door", "against"),
    "flooded": ("open", "flooded"), "wet_shut": ("grate", "sea"), "wet_open": ("open", "sea"),
}


def mix(c, x, y, key, k):
    """Lay `key` over what is at (x, y) at strength k (keeps the pixel's alpha)."""
    r, g, b, a = c.get(x, y)
    if a == 0:
        return
    t = P.rgb(key)
    c.im.putpixel((x, y), (int(r * (1 - k) + t[0] * k), int(g * (1 - k) + t[1] * k), int(b * (1 - k) + t[2] * k), a))


def planks_v(c, x0, y0, x1, y1, straps):
    """A plank door face-on: vertical boards, a lit left edge, iron straps with rivets, a ring."""
    c.rect(x0, y0, x1, y1, "WOOD")
    for x in range(x0 + 3, x1, 3):
        c.line(x, y0, x, y1, "TAR")
    c.line(x0, y0, x0, y1, "WOOD_LIGHT")
    c.line(x0, y0, x1, y0, "WOOD_LIGHT")
    for y in straps:
        c.line(x0, y, x1, y, "IRON_DARK")
        for x in range(x0 + 1, x1, 4):
            c.px(x, y, "IRON_LIGHT")
    rx, ry = x1 - 2, (y0 + y1) // 2 + 1
    c.px(rx, ry - 1, "IRON_LIGHT")
    c.px(rx - 1, ry, "IRON_LIGHT")
    c.px(rx + 1, ry, "IRON")
    c.px(rx, ry + 1, "IRON")


def grate_v(c, x0, y0, x1, y1):
    """The sea-gate: rusted bars on a cross rail, sea behind, kelp caught in it."""
    c.rect(x0, y0, x1, y1, "SEA")
    for x in range(x0 + 1, x1, 3):
        c.line(x, y0, x, y1, "RUST")
        c.px(x, y0, "RUST_LIGHT")
    c.line(x0, y0 + 3, x1, y0 + 3, "IRON_DARK")
    c.line(x0, y1 - 3, x1, y1 - 3, "IRON_DARK")
    for i, y in enumerate(range(y0 + 4, y1 - 1)):
        c.px(x0 + 2 + (i // 2) % 2, y, "KELP" if i % 3 else "KELP_LIGHT")


def water(c, mask, mode, top):
    """Water over the doorway pixels in `mask` from row `top` down: the tide against a shut
    door (translucent, a foam line), a flooded way (deep, rippled) or the sea-lit wet way."""
    for (x, y) in mask:
        if y < top:
            continue
        if mode == "against":
            mix(c, x, y, "SEA", 0.55)
        elif mode == "flooded":
            c.px(x, y, "DEEP_SEA" if (x + 2 * y) % 7 else "SEA")
        else:
            c.px(x, y, "SEA" if (x * 3 + y) % 9 else "SHALLOW")
            if (x * 5 + y * 3) % 23 == 0:
                c.px(x, y, "SEA_PALE")
    xs = sorted({x for (x, y) in mask if y == top})
    for x in xs:
        c.px(x, top, "FOAM_WHITE" if x % 3 == 0 else "SALT_WHITE")


# --- north: the arch face-on ------------------------------------------------------------------

def north(state):
    fill, wet = LOOK[state]
    c = Canvas(C, C)
    cx = 15.5
    # The opening: round-headed, 12 wide, from y 4 (crown) to 22 (sill).
    hole = [(x, y) for y in range(4, 23) for x in range(10, 22)
            if y >= 10 or (x - cx) ** 2 + (y - 10) ** 2 <= 6.2 ** 2]
    if fill == "open":
        for (x, y) in hole:
            c.px(x, y, "ABYSS")
        for i, y in enumerate((21, 19, 17)):      # steps going up into the dark
            c.line(10, y, 21, y, ("STONE", "STONE_DARK", "NIGHT_1")[i])
            c.line(10, y + 1, 21, y + 1, ("STONE_DARK", "NIGHT_1", "NIGHT_2")[i])
    elif fill == "door":
        planks_v(c, 10, 4, 21, 22, (11, 18))
        for (x, y) in [(x, y) for y in range(4, 10) for x in range(10, 22) if (x, y) not in hole]:
            c.im.putpixel((x, y), (0, 0, 0, 0))
    else:
        grate_v(c, 10, 4, 21, 22)
        for (x, y) in [(x, y) for y in range(4, 10) for x in range(10, 22) if (x, y) not in hole]:
            c.im.putpixel((x, y), (0, 0, 0, 0))
    if wet:
        water(c, hole, wet, 14 if wet == "against" else (15 if wet == "flooded" else 13))
    # The arch ring: voussoirs round the head, coursed jambs, a keystone.
    for y in range(1, 24):
        for x in range(5, 27):
            if (x, y) in hole:
                continue
            dx, dy = x - cx, y - 10
            ring = y < 10 and 6.2 ** 2 < dx * dx + dy * dy <= 10.2 ** 2
            jamb = y >= 10 and (6 <= x <= 9 or 22 <= x <= 25)
            if not (ring or jamb):
                continue
            key = "STONE_LIGHT" if (y < 6 or x <= 7) else ("STONE_DARK" if x >= 24 else "STONE")
            c.px(x, y, key)
    for y in (14, 18):                                 # jamb courses
        c.line(6, y, 9, y, "STONE_DARK")
        c.line(22, y, 25, y, "STONE_DARK")
    for ang in (-60, -25, 25, 60):                     # voussoir joints
        a = math.radians(ang - 90)
        for r in range(7, 11):
            c.px(cx + r * math.cos(a), 10 + r * math.sin(a), "STONE_DARK")
    c.rect(14, 0, 17, 4, "STONE_LIGHT")                # keystone
    c.line(17, 0, 17, 4, "STONE")
    c.px(14, 0, "BONE")
    c.line(10, 3, 12, 2, "BONE")                       # catch-light on the ring
    c.line(5, 23, 26, 23, "STONE_DARK")                # sill
    c.line(10, 22, 21, 22, "STONE_DARK" if fill != "open" else "STONE")
    if wet == "sea":
        for y in range(11, 21, 2):
            c.px(6 + (y // 2) % 2, y, "KELP")
    return c.im


# --- south: the wall's top, the way out running down ---------------------------------------------

def post(c, x0, x1, top, base):
    """A square gate post seen from the south and above: lit cap, coursed face, dark foot."""
    c.rect(x0, top, x1, top + 3, "STONE_LIGHT")
    c.line(x0, top, x1, top, "BONE")
    c.line(x1, top, x1, top + 3, "STONE")
    c.rect(x0, top + 4, x1, base, "STONE")
    c.line(x1, top + 4, x1, base, "STONE_DARK")
    for y in range(top + 8, base, 5):
        c.line(x0, y, x1, y, "STONE_DARK")
    c.line(x0, base, x1, base, "INK")


def south(state):
    fill, wet = LOOK[state]
    c = Canvas(C, C)
    gap = [(x, y) for y in range(8, 32) for x in range(10, 22)]
    # The way out: paving stepping down away from the room into the dark.
    for (x, y) in gap:
        k = (y - 8) / 23.0
        key = "STONE" if k < 0.2 else ("STONE_DARK" if k < 0.45 else ("NIGHT_2" if k < 0.65 else ("NIGHT_1" if k < 0.82 else "ABYSS")))
        c.px(x, y, key)
    for y in (12, 17, 22):
        c.line(10, y, 21, y, "NIGHT_1")
    if fill == "door":
        planks_v(c, 10, 9, 21, 22, (12, 19))
        c.line(10, 8, 21, 8, "WOOD_LIGHT")            # the leaf's top edge, seen from above
    elif fill == "grate":
        grate_v(c, 10, 9, 21, 22)
    if wet:
        water(c, gap, wet, 13 if wet == "against" else 10)
    post(c, 4, 9, 4, 24)
    post(c, 22, 27, 4, 24)
    c.line(10, 7, 21, 7, "STONE_DARK")                 # threshold slab
    c.line(10, 6, 21, 6, "STONE_LIGHT")
    return c.im


# --- west / east: the passage running out sideways ------------------------------------------------

def west(state):
    """Room to the east (right). Drawn for the west wall; east is its mirror."""
    fill, wet = LOOK[state]
    c = Canvas(C, C)
    gap = [(x, y) for y in range(10, 22) for x in range(0, 24)]
    for (x, y) in gap:
        k = x / 23.0                                   # 0 outside .. 1 at the room
        key = "ABYSS" if k < 0.22 else ("NIGHT_1" if k < 0.4 else ("NIGHT_2" if k < 0.55 else ("STONE_DARK" if k < 0.75 else "STONE")))
        c.px(x, y, key)
    for x in (6, 11, 16, 21):                          # slab joints across the passage
        c.line(x, 10, x, 21, "NIGHT_1" if x < 16 else "STONE_DARK")
    c.line(0, 15, 23, 15, "NIGHT_1")
    if wet:
        water(c, gap, wet, 10)
    if fill in ("door", "grate"):
        # The leaf stands across the passage; turned a little to show its face to the room.
        if fill == "door":
            c.rect(15, 3, 20, 21, "WOOD")
            for x in (17, 19):
                c.line(x, 3, x, 21, "TAR")
            c.line(20, 3, 20, 21, "WOOD_LIGHT")
            c.line(15, 3, 20, 3, "WOOD_LIGHT")
            for y in (8, 16):
                c.line(15, y, 20, y, "IRON_DARK")
                c.px(18, y, "IRON_LIGHT")
            c.px(19, 12, "IRON_LIGHT")
            c.px(19, 13, "IRON")
            c.line(14, 3, 14, 21, "TAR")               # its shadowed back edge
        else:
            c.rect(15, 3, 20, 21, "SEA")
            for x in (15, 18):
                c.line(x, 3, x, 21, "RUST")
                c.px(x, 3, "RUST_LIGHT")
            for y in (7, 17):
                c.line(15, y, 20, y, "IRON_DARK")
            for y in range(8, 17):
                c.px(16 + (y // 2) % 2, y, "KELP")
        if wet == "against":
            for y in range(14, 22):
                for x in range(14, 21):
                    mix(c, x, y, "SEA", 0.55)
            c.line(14, 14, 20, 14, "SALT_WHITE")
    # The posts: north on the wall above the passage, south below it (drawn last: it stands in
    # front of the passage's lower edge).
    post(c, 8, 20, 0, 9)
    post(c, 8, 20, 20, 30)
    if wet == "sea":
        c.px(9, 6, "KELP")
        c.px(10, 7, "KELP_LIGHT")
    return c.im


# --- the stair: the hub's way down into the sea ---------------------------------------------------

def stair():
    """The hub's way down: not a door but a place where the sea goes deep. The water darkens into
    a hole, a slow swirl of current turns down into it, and foam breaks in broken crests on its
    far lip the way it breaks on the shore. It sits in the water above the sea wall (the marker
    is the cell before the wall) and its outer rings dither to nothing, so it has no edge."""
    c = Canvas(C, C)
    cx, cy, rx, ry = 15.5, 13.0, 15.0, 8.5
    for y in range(C):
        for x in range(C):
            # Elliptical distance (wider than tall: seen from the south and above).
            d = math.hypot((x - cx) / rx, (y - cy) / ry)
            if d > 1.0:
                continue
            if d < 0.3:
                key, a = "ABYSS", 255
            elif d < 0.5:
                key, a = ("ABYSS" if (x + y) % 3 == 0 else "DEEP_SEA"), 255
            elif d < 0.7:
                key, a = ("DEEP_SEA" if (x + y) % 2 else "SEA"), 220
            elif d < 0.86:
                if (x + 2 * y) % 3:
                    continue
                key, a = "SEA", 150
            else:
                if (x * 3 + y) % 5:
                    continue
                key, a = "SEA", 90
            c.px(x, y, key, a)
    # The swirl: two arms of current spiralling in toward the dark.
    for arm in (0.0, math.pi):
        for i in range(26):
            t = i / 25.0
            ang = arm + t * 3.4
            r = 0.82 - 0.6 * t
            x, y = cx + rx * r * math.cos(ang), cy + ry * r * math.sin(ang)
            c.px(x, y, "SHALLOW" if t < 0.6 else "SEA", int(230 - 120 * t))
    # Foam: broken crests along the far lip, a few pale flecks on the near side.
    for t in range(190, 351, 4):
        r = math.radians(t)
        x, y = cx + (rx - 1.5) * math.cos(r), cy + (ry - 1.0) * math.sin(r)
        if (t // 4) % 5 == 4:
            continue                                   # a gap between crests
        c.px(x, y, "SALT_WHITE")
        if (t // 4) % 5 == 1:
            c.px(x, y - 1, "FOAM_WHITE")               # the crest's top
    for t in (40, 75, 110, 140):
        r = math.radians(t)
        c.px(cx + (rx - 2.5) * math.cos(r), cy + (ry - 1.5) * math.sin(r), "SEA_PALE", 200)
    # A glint of the cold light far down.
    c.px(15, 13, "SHALLOW")
    c.px(16, 14, "SEA")
    return c.im


def build_doors():
    sheet = Image.new("RGBA", (C * len(STATES), C * len(FACINGS)), (0, 0, 0, 0))
    for col, st in enumerate(STATES):
        w = west(st)
        cells = [north(st), south(st), w, w.transpose(Image.FLIP_LEFT_RIGHT), stair()]
        for row, im in enumerate(cells):
            sheet.alpha_composite(im, (col * C, row * C))
    return sheet


def main():
    sheet = build_doors()
    sheet.save(os.path.join(SPRITES, "door.png"))
    bg = Image.new("RGBA", sheet.size, P.rgba("STONE_DARK"))
    bg.alpha_composite(sheet)
    os.makedirs(REF, exist_ok=True)
    bg.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(os.path.join(REF, "doors_sheet.png"))
    print("wrote door.png %s, doors_sheet.png" % (sheet.size,))


if __name__ == "__main__":
    main()
