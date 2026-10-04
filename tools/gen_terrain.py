"""Map Stage 03: terrain transitions.  The ground is drawn on a dual grid: every drawn tile sits
on the corner where four cells meet and is picked by which of those four cells hold its layer
(16 cases, TL=1 TR=2 BL=4 BR=8). Edges follow the cell boundaries, so collision is unchanged,
but they are drawn as natural lines with rounded corners. Layers stack per look: low ground,
floor, raised ground, wall; each draws its own material, its south face, its lip and the
shadow it throws, so any mix of heights reads (STYLE.md 22, Edges).

    assets/sprites/terrain.png   per look (Tiles.Look order: flats, streets, deep, harbour, hub)
        four rows (low, floor, raised, wall); columns: case c, variant v at c * 3 + v (0-47),
        then 48-50 full fills: clean (accents painted out), as drawn, and the floor's second
        tile (clean again for the other layers).
    assets/sprites/water_edge.png
        rows 0-2: shallow water, one row per frame: case c, variant v at c * 3 + v; 48 is the
                  second shallow body. Foam on the water's edge, the wet band on the dry side.
        rows 3-4: deep water over shallow, one row per frame, same layout.
        row 5:    full deep bodies copied from water.png: ring A f0-1, ring B f0-1, deep f0-1,
                  abyss ring f0-1, abyss f0-1 (cols 0-9).
    assets/reference/maps/terrain_sheet.png   every case per look, and mock patches

Edge shape: the bilinear blend of the four corners plus a noise whose value on a tile's border
is the same for every case and variant (so tiles always meet), and whose interior differs per
variant (so a long edge does not repeat). Each look sets how much the edges wander: soft rock on
the Flats, dressed stone in the Streets, cut basalt in the Hall, timber and quay in the Harbour.

Map Stage 04 adds patch.png: three overlay materials per look (see PATCHES).

Run:  python tools/gen_terrain.py
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
REF = os.path.join(P.ROOT, "assets", "reference", "maps")
T = 16
VARIANTS = 3
FILL_COL = 48
LOOKS = ["flats", "streets", "deep", "harbour", "hub"]
LAYERS = ["low", "floor", "raised", "wall"]

# Tile indices in tiles.png (Tiles enum) per look: low, floor, floor variant, raised, wall top, wall face.
SRC = {
    "flats":   dict(low=7, floor=0, floor2=1, raised=8, top=3, face=2),
    "streets": dict(low=18, floor=14, floor2=15, raised=19, top=17, face=16),
    "deep":    dict(low=24, floor=20, floor2=21, raised=25, top=23, face=22),
    "harbour": dict(low=30, floor=26, floor2=27, raised=31, top=29, face=28),
    "hub":     dict(low=36, floor=32, floor2=33, raised=37, top=35, face=34),
}
# How far each layer's edge wanders (share of a tile) and how fine the wander is, per look.
WANDER = {
    "flats":   {"floor": (0.30, 1.0), "raised": (0.24, 1.0), "wall": (0.22, 1.0)},
    "hub":     {"floor": (0.30, 1.0), "raised": (0.18, 1.0), "wall": (0.20, 1.0)},
    "streets": {"floor": (0.18, 2.0), "raised": (0.06, 1.0), "wall": (0.08, 2.0)},
    "harbour": {"floor": (0.20, 1.0), "raised": (0.04, 1.0), "wall": (0.06, 1.0)},
    "deep":    {"floor": (0.10, 1.0), "raised": (0.03, 1.0), "wall": (0.04, 1.0)},
}
# Face height (px) on the south side of each layer's edge, and its shadow band below.
FACE = {"floor": 2, "raised": 4, "wall": 8}
SHADOW = {"floor": 1, "raised": 2, "wall": 3}
SHADOW_A = 90  # Ink at 35 %, as the old shade tiles

PALETTE = [P.hex_to_rgb(c[2]) for c in P.COLOURS]


def snap(rgb):
    return min(PALETTE, key=lambda p: sum((a - b) ** 2 for a, b in zip(p, rgb)))


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def darker(rgb, t=0.35):
    return snap(mix(rgb, P.rgb("INK"), t))


def lighter(rgb, t=0.25):
    return snap(mix(rgb, P.rgb("SALT_WHITE"), t))


# --- the edge field ---------------------------------------------------------------------------

def border_noise(x, y):
    """Periodic over a tile, so its values on any border match the opposite border."""
    tau = 2 * math.pi / T
    # One swell a tile on each diagonal, so an edge wanders instead of bristling.
    return 0.6 * math.sin(tau * (x + y) + 1.3) + 0.4 * math.sin(tau * (x - y) + 0.4)


def interior_noise(x, y, variant, fine):
    rnd = random.Random(variant * 7919 + int(fine * 13))
    ph = [rnd.uniform(0, 6.283) for _ in range(4)]
    k = fine * 0.5
    return (0.7 * math.sin(k * 0.55 * x + ph[0]) * math.sin(k * 0.45 * y + ph[1])
            + 0.3 * math.sin(k * 0.9 * (x + y) + ph[2]))


def mask(case, variant, amp, fine):
    tl, tr, bl, br = (case >> 0) & 1, (case >> 1) & 1, (case >> 2) & 1, (case >> 3) & 1
    m = [[False] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            u, v = (x + 0.5) / T, (y + 0.5) / T
            b = tl * (1 - u) * (1 - v) + tr * u * (1 - v) + bl * (1 - u) * v + br * u * v
            # The interior term fades to nothing at the border: tiles meet whatever the variant.
            w = math.sin(math.pi * u) * math.sin(math.pi * v)
            n = 0.3 * border_noise(x + 0.5, y + 0.5) + 0.8 * w * interior_noise(x, y, variant, fine)
            m[y][x] = b + amp * n > 0.5
    return m


# --- drawing ---------------------------------------------------------------------------------

# Tiles drawn as single blocks carry a lit rim on their top row; as a fill that rim would
# stripe every 16 px, so the fill takes the row under it instead.
RIMMED = {8, 25}


# Colours swapped in a source tile (map Stage 06): the Streets' raised flags were Stone light,
# two steps over the cobbles and the brightest ground in the dark Streets; Wet grey is one step
# and damp.
RECOLOR = {19: {"STONE_LIGHT": "WET_GREY"}}


def tile_px(tiles, index):
    im = tiles.crop((index * T, 0, index * T + T, T))
    swap = {P.rgba(a): P.rgba(b) for a, b in RECOLOR.get(index, {}).items()}
    px = [[swap.get(im.getpixel((x, y)), im.getpixel((x, y))) for x in range(T)] for y in range(T)]
    if index in RIMMED:
        px[0] = list(px[1])
    return px


# Per source tile, the most pixels a colour may cover and still count as an accent. The Flats
# shelf's crack mark covers 19 px, and on every tile of a shelf it read as a slate roof (map
# Stage 06); cleaned, the mark is left to the one fill tile in five drawn as the tile is.
CLEAN_MAX = {8: 24}


def clean(src, index=None):
    """The tile with its accents (colours used on three pixels or fewer) painted over with the
    most common colour, so a fill does not set a crust or a nail every 16 px."""
    count = {}
    for row in src:
        for c in row:
            count[c] = count.get(c, 0) + 1
    base = max(count, key=count.get)
    most = CLEAN_MAX.get(index, 3)
    return [[base if count[c] <= most else c for c in row] for row in src]


def fill_at(src, x, y):
    """The material tile, shifted half a tile: the dual grid's tiles sit on cell corners."""
    return src[(y + T // 2) % T][(x + T // 2) % T]


def face_px(face_src, top_src, d, layer, x):
    """Face colour d px above the edge (1 = the foot)."""
    if layer == "wall":
        # The wall face tile is 4 px of top, a 10 px face and a foot line: walk up it from the foot.
        row = max(4, 15 - (d - 1))
        c = face_src[row][(x + T // 2) % T]
        # A step darker than the tile's face, which matches the top: the face has to read as height.
        return c if d == 1 else darker(c[:3], 0.3) + (255,)
    base = top_src[(T // 2) % T][(x + T // 2) % T][:3]
    return darker(base, 0.25 if d > 1 else 0.45) + (255,)


def draw_case(case, variant, layer, look, tiles):
    s = SRC[look]
    amp, fine = WANDER[look].get(layer, (0.25, 1.0))
    src_index = s[{"low": "low", "floor": "floor", "raised": "raised", "wall": "top"}[layer]]
    top = clean(tile_px(tiles, src_index), src_index)
    face = tile_px(tiles, s["face"])
    m = mask(case, variant, amp, fine)
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    F, S = FACE.get(layer, 0), SHADOW.get(layer, 0)
    for y in range(T):
        for x in range(T):
            if m[y][x]:
                # A face where the edge lies within F px below; the lip is its top row.
                d = next((k for k in range(1, F + 1) if y + k < T and not m[y + k][x]), 0)
                if d:
                    c = face_px(face, top, d, layer, x)
                    lip = d == F or (y > 0 and not m[y - 1][x])
                    if lip and layer != "wall":
                        c = lighter(fill_at(top, x, y)[:3], 0.2) + (255,)
                    im.putpixel((x, y), c)
                    continue
                if layer == "wall" and F and y + F + 1 < T and not m[y + F + 1][x] and all(m[y + k][x] for k in range(1, F + 1)):
                    # The lit rim of the cliff top, just above its face (the face tile's top row).
                    im.putpixel((x, y), face[0][(x + T // 2) % T])
                    continue
                c = fill_at(top, x, y)
                # A dark rim on the other edges (the side of a wall, a step seen from above).
                rim = any(0 <= x + dx < T and 0 <= y + dy < T and not m[y + dy][x + dx]
                          for dx, dy in ((1, 0), (-1, 0), (0, -1)))
                if rim and layer in ("wall", "raised"):
                    c = darker(c[:3], 0.3) + (255,)
                im.putpixel((x, y), c)
            elif S:
                # The shadow it throws: south of the edge, and a pixel to either side.
                k = next((k for k in range(1, S + 1) if y - k >= 0 and m[y - k][x]), 0)
                side = (x > 0 and m[y][x - 1]) or (x + 1 < T and m[y][x + 1])
                if k or side:
                    im.putpixel((x, y), P.rgba("INK", SHADOW_A))
    return im


def build_terrain(tiles):
    cols = FILL_COL + 3
    atlas = Image.new("RGBA", (cols * T, len(LOOKS) * len(LAYERS) * T), (0, 0, 0, 0))
    for li, look in enumerate(LOOKS):
        s = SRC[look]
        for la, layer in enumerate(LAYERS):
            row = li * len(LAYERS) + la
            for case in range(16):
                for v in range(VARIANTS):
                    atlas.alpha_composite(draw_case(case, v, layer, look, tiles), ((case * VARIANTS + v) * T, row * T))
            # Full fills: the material without its accents, the tile as drawn (the room picks
            # it one corner in five), and the floor's second tile (or the clean one again).
            key = {"low": "low", "floor": "floor", "raised": "raised", "wall": "top"}[layer]
            for k, idx in enumerate([s[key], s[key], s["floor2"] if layer == "floor" else s[key]]):
                src = tile_px(tiles, idx)
                if k == 0 or (k == 2 and layer != "floor"):
                    src = clean(src, idx)
                im = Image.new("RGBA", (T, T))
                for y in range(T):
                    for x in range(T):
                        im.putpixel((x, y), fill_at(src, x, y))
                atlas.alpha_composite(im, ((FILL_COL + k) * T, row * T))
    return atlas


# --- water -----------------------------------------------------------------------------------

def build_water(water):
    """Shallow water with foam on its edge and the wet band beside it; deep water over shallow."""
    atlas = Image.new("RGBA", ((FILL_COL + 1) * T, 6 * T), (0, 0, 0, 0))
    body = [[water.getpixel((c * T + x, y)) for x in range(T) for y in range(T)] for c in range(16)]

    def body_px(col, x, y):
        return water.getpixel((col * T + (x + T // 2) % T, (y + T // 2) % T))

    for frame in range(3):
        for case in range(16):
            for v in range(VARIANTS):
                m = mask(case, v, 0.26, 1.0)
                im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
                for y in range(T):
                    for x in range(T):
                        near = [k for k in range(1, 4) if any(
                            0 <= x + dx * k < T and 0 <= y + dy * k < T and m[y + dy * k][x + dx * k] != m[y][x]
                            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
                        dist = near[0] if near else 9
                        if m[y][x]:
                            # Foam 1-3 px deep, deepest where a slow swell along the shore says, sliding a pixel a frame.
                            depth = 1 + int(1.5 + 1.5 * math.sin(2 * math.pi * (x + y + frame * 2) / T))
                            if dist <= depth:
                                im.putpixel((x, y), P.rgba("FOAM_WHITE" if dist == 1 and depth >= 2 else "SALT_WHITE"))
                            else:
                                im.putpixel((x, y), body_px(frame, x, y))
                        elif dist <= 2:
                            im.putpixel((x, y), P.rgba("INK", SHADOW_A))  # the wet band on the dry side
                atlas.alpha_composite(im, ((case * VARIANTS + v) * T, frame * T))
        im = Image.new("RGBA", (T, T))
        for y in range(T):
            for x in range(T):
                im.putpixel((x, y), body_px(3 + frame, x, y))
        atlas.alpha_composite(im, (FILL_COL * T, frame * T))
    # Deep over shallow: the ring A body inside, a half checker of it on the edge's outer pixel.
    for frame in range(2):
        for case in range(16):
            for v in range(VARIANTS):
                m = mask(case, v, 0.20, 1.0)
                im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
                for y in range(T):
                    for x in range(T):
                        edge = any(0 <= x + dx < T and 0 <= y + dy < T and not m[y + dy][x + dx]
                                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                        if m[y][x] and (not edge or (x + y) % 2 == 0):
                            im.putpixel((x, y), body_px(6 + frame, x, y))
                atlas.alpha_composite(im, ((case * VARIANTS + v) * T, (3 + frame) * T))
    for c in range(10):
        im = Image.new("RGBA", (T, T))
        for y in range(T):
            for x in range(T):
                im.putpixel((x, y), body_px(6 + c, x, y))
        atlas.alpha_composite(im, (c * T, 5 * T))
    return atlas


# --- patches (map Stage 04) -------------------------------------------------------------------
# Ground at scale: three overlay materials per look, each a tone wash and sparse marks, drawn on
# the dual grid over the floor and under raised ground and walls. Overlays, not fills, so a patch
# can run up to a bank or a wall without hiding the edge drawn there. room.gd decides where each
# lies (wet by low ground, worn on the routes between doors, at the foot of walls, blobs by noise).
#   assets/sprites/patch.png   rows look * 3 + p, columns as terrain.png (48 edge tiles, 3 fills)
PATCHES = {
    # look: [(name, wash colour, wash alpha, marks), ...] in room.gd's order (Room.PATCH_REASONS)
    "flats":   [("wet", "INK", 30, "streaks:SAND_DARK"), ("ripples", None, 0, "ripples:SAND_LIGHT"),
                ("shingle", None, 0, "pebbles:STONE,STONE_LIGHT,BONE_DARK")],
    "hub":     [("wet", "INK", 28, "streaks:SAND"), ("ripples", None, 0, "ripples:BONE"),
                ("shingle", None, 0, "pebbles:STONE,STONE_LIGHT,BONE_DARK")],
    "streets": [("worn", "SALT_WHITE", 20, "glints:STONE_LIGHT"), ("moss", None, 0, "clumps:MOSS,MOSS_DARK,KELP_LIGHT"),
                ("grime", "INK", 46, "specks:SAND_DARK")],
    "harbour": [("worn", "SALT_WHITE", 16, "grain:WOOD_LIGHT"), ("tar", "INK", 30, "clumps:TAR,TAR,IRON_DARK"),
                ("silt", "INK", 24, "specks:SAND_DARK,WEATHERED_BROWN")],
    "deep":    [("polished", None, 0, "sheen:BASALT_LIGHT"), ("veins", None, 0, "veins:BASALT_DARK,IRON"),
                ("brine", "INK", 40, "specks:KELP,DEEP_SEA")],
}
PATCH_WANDER = {"flats": 0.36, "hub": 0.36, "streets": 0.26, "harbour": 0.22, "deep": 0.24}


def marks_map(kind, colours, variant):
    """A 16x16 map of opaque marks, kept off the tile's border so neighbours never cut one."""
    rnd = random.Random("%s-%d" % (kind, variant))
    cols = [P.rgb(c) for c in colours]
    m = {}

    def put(x, y, c):
        if 1 <= x < T - 1 and 1 <= y < T - 1:
            m[(x, y)] = c

    if kind == "streaks":
        for _ in range(7):
            x, y, n = rnd.randint(1, 11), rnd.randint(1, 14), rnd.randint(2, 5)
            for k in range(n):
                put(x + k, y, cols[0])
    elif kind == "ripples":
        ph = rnd.randint(0, 3)
        for y in range(2 + variant % 2, T - 1, 4):
            for x in range(1, T - 1):
                yy = y + (1 if math.sin((x + ph) * 0.8) > 0.4 else 0)
                if rnd.random() < 0.8:
                    put(x, yy, cols[0])
    elif kind == "pebbles":
        for _ in range(9):
            x, y = rnd.randint(1, 13), rnd.randint(1, 13)
            c = rnd.choice(cols)
            put(x, y, c)
            if rnd.random() < 0.5:
                put(x + 1, y, c)
            put(x, y + 1, P.rgb("STONE_DARK"))
    elif kind == "glints":
        for _ in range(5):
            put(rnd.randint(1, 14), rnd.randint(1, 14), cols[0])
    elif kind == "clumps":
        for _ in range(4):
            x, y = rnd.randint(2, 12), rnd.randint(2, 12)
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (-1, 0), (0, -1)):
                if rnd.random() < 0.7:
                    put(x + dx, y + dy, cols[min(len(cols) - 1, int(rnd.random() * len(cols)))])
    elif kind == "specks":
        for _ in range(14):
            put(rnd.randint(1, 14), rnd.randint(1, 14), rnd.choice(cols))
    elif kind == "grain":
        for _ in range(6):
            x, y, n = rnd.randint(1, 10), rnd.randint(1, 14), rnd.randint(3, 5)
            for k in range(n):
                put(x + k, y, cols[0])
    elif kind == "sheen":
        # A few short glints where feet have polished the stone, never a ruled line.
        for _ in range(3):
            x, y = rnd.randint(1, 12), rnd.randint(1, 13)
            for k in range(rnd.randint(2, 3)):
                put(x + k, y + (k if rnd.random() < 0.5 else 0), cols[0])
    elif kind == "veins":
        x, y = rnd.randint(2, 6), rnd.randint(2, 13)
        for _ in range(14):
            put(x, y, cols[0])
            x += 1
            y += rnd.choice((-1, 0, 0, 1))
            y = min(max(y, 1), T - 2)
        for _ in range(2):
            put(rnd.randint(1, 14), rnd.randint(1, 14), cols[1])
    return m


def draw_patch(case, variant, look, spec, full=False):
    name, wash, wash_a, marks = spec
    kind, cols = marks.split(":")
    mk = marks_map(kind, cols.split(","), variant)
    m = [[True] * T for _ in range(T)] if full else mask(case, variant + 3, PATCH_WANDER[look], 1.0)
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    for y in range(T):
        for x in range(T):
            if not m[y][x]:
                continue
            edge = any(0 <= x + dx < T and 0 <= y + dy < T and not m[y + dy][x + dx]
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            # The outer pixel of a patch is a half checker, so it fades into the floor.
            if edge and (x + y) % 2:
                continue
            if (x, y) in mk:
                im.putpixel((x, y), mk[(x, y)] + (255,))
            elif wash:
                im.putpixel((x, y), P.rgba(wash, wash_a))
    return im


def build_patches():
    atlas = Image.new("RGBA", ((FILL_COL + 3) * T, len(LOOKS) * 3 * T), (0, 0, 0, 0))
    for li, look in enumerate(LOOKS):
        for pi, spec in enumerate(PATCHES[look]):
            row = li * 3 + pi
            for case in range(16):
                for v in range(VARIANTS):
                    atlas.alpha_composite(draw_patch(case, v, look, spec), ((case * VARIANTS + v) * T, row * T))
            for k in range(3):
                atlas.alpha_composite(draw_patch(15, k, look, spec, True), ((FILL_COL + k) * T, row * T))
    return atlas


# --- the review sheet -------------------------------------------------------------------------

def mock(terrain, water, look, plan, tide_water=True):
    """Lay a little plan out on the dual grid the way room.gd does, at 1x."""
    rows = [r for r in plan.strip("\n").split("\n")]
    h, w = len(rows), len(rows[0])
    heights = {"_": 0, ".": 1, "=": 2, "#": 3}
    li = LOOKS.index(look)
    out = Image.new("RGBA", (w * T, h * T), P.rgba("ABYSS"))

    def at(x, y):
        x, y = min(max(x, 0), w - 1), min(max(y, 0), h - 1)
        return heights.get(rows[y][x], 1)

    def cases(pred):
        for j in range(h + 1):
            for i in range(w + 1):
                c = (pred(i - 1, j - 1) << 0) | (pred(i, j - 1) << 1) | (pred(i - 1, j) << 2) | (pred(i, j) << 3)
                yield i, j, c

    for la in range(4):
        row = li * 4 + la
        for i, j, c in cases(lambda x, y: int(at(x, y) >= la)):
            if c == 0:
                continue
            v = (i * 7 + j * 13) % VARIANTS
            col = c * VARIANTS + v
            if c == 15:
                pick = (i * 7 + j * 3) % 5
                col = FILL_COL + (1 if pick == 0 else 2 if pick == 1 and la == 1 else 0)
            out.alpha_composite(terrain.crop((col * T, row * T, col * T + T, row * T + T)), (i * T - T // 2, j * T - T // 2))
        if la == 2 and tide_water:
            for i, j, c in cases(lambda x, y: int(at(x, y) == 0)):
                if c == 0:
                    continue
                col = FILL_COL if c == 15 else c * VARIANTS + (i + j) % VARIANTS
                out.alpha_composite(water.crop((col * T, 0, col * T + T, T)), (i * T - T // 2, j * T - T // 2))
    return out


PLAN = """
###########################
###########.....###########
######........._.......####
###.........____...=====.##
##........______..======..#
##.......______...=====...#
#........____......===....#
#...##.............####...#
#...###...........#####...#
#....#....______..........#
##.......________.........#
###.....________.........##
#####..........._......####
###########################
"""


def main():
    tiles = Image.open(os.path.join(SPRITES, "tiles.png")).convert("RGBA")
    water = Image.open(os.path.join(SPRITES, "water.png")).convert("RGBA")
    terrain = build_terrain(tiles)
    terrain.save(os.path.join(SPRITES, "terrain.png"))
    wedge = build_water(water)
    wedge.save(os.path.join(SPRITES, "water_edge.png"))
    patches = build_patches()
    patches.save(os.path.join(SPRITES, "patch.png"))
    os.makedirs(REF, exist_ok=True)
    mocks = [mock(terrain, wedge, look, PLAN) for look in LOOKS]
    mw, mh = mocks[0].size
    sheet = Image.new("RGBA", (mw * 2 + 8, (mh + 4) * 3 + terrain.height // 2), P.rgba("INK"))
    for i, m in enumerate(mocks):
        sheet.alpha_composite(m, ((i % 2) * (mw + 8), (i // 2) * (mh + 4)))
    sheet.alpha_composite(terrain.resize((terrain.width // 2, terrain.height // 2), Image.NEAREST), (0, (mh + 4) * 3))
    sheet.save(os.path.join(REF, "terrain_sheet.png"))
    print("wrote terrain.png %s, water_edge.png %s, patch.png %s, terrain_sheet.png" % (terrain.size, wedge.size, patches.size))


if __name__ == "__main__":
    main()
