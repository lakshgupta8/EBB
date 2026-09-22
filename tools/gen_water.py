"""Stage 10: the tide.  Water is a runtime overlay over any floor: transparent PNG cells the
room picks by height map, tide level and neighbours (room.gd), never painted into floors.

    assets/sprites/water.png   16 x 6 cells of 16x16 (256x96), atlas coords (col, row):
        row 0: shallow body A f0-2 (0-2), shallow body B f0-2 (3-5),
               deep ring A f0-1 (6-7), deep ring B f0-1 (8-9), deep body f0-1 (10-11),
               abyss ring f0-1 (12-13), abyss body f0-1 (14-15)
        rows 1-3: foam, one row per frame, 16 cases by dry neighbours (N=1 E=2 S=4 W=8)
        row 4: wet band, 16 cases by flooded neighbours (dry side of the shore line)
        row 5: tide line, 16 cases by higher-floor neighbours (edge of low ground)
    assets/sprites/fx_splash.png   3 x 16x16     entering water, dashing in water
    assets/sprites/fx_ripple.png   3 x 16x8      standing / walking in shallow water
    assets/sprites/fx_bubble.png   2 x 4x4       deep water, drowned things rising
    assets/sprites/fx_wet.png      16x2          the wet edge across an entity's feet
    assets/sprites/door.png        6 x 32x32     shut, open, shut+flooded (water-closed),
                                                 open+flooded, wet shortcut shut, wet shortcut open
    assets/reference/anchors/water_sheet.png     every cell, the overlay over five floors, three
                                                 mock pools (sand, cobble, basalt) at three tides

Run:  python tools/gen_water.py
"""
import os
import sys
from collections import deque

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
import gen_anchors as GA  # noqa: E402
from gen_anchors import grid, zoom, LEG  # noqa: E402
import gen_tiles as GT  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
REF = os.path.join(P.ROOT, "assets", "reference", "anchors")

# Local legend letters (only meaningful while this generator runs).
LEG[","] = ("DEEP_SEA", 170)     # a darker depth fleck in shallow water
LEG[";"] = ("SHALLOW", 120)      # a fading ripple ring
LEG["'"] = ("SALT_WHITE", 160)   # foam thinning out
LEG["`"] = ("SEA_PALE", 200)     # bubble ring

N, E, S, W = 1, 2, 4, 8


def rgba(key, a=255):
    return P.rgb(key) + (a,)


def g16(text):
    return grid(text, 16, 16)


def strip(images, w, h):
    im = Image.new("RGBA", (w * len(images), h), (0, 0, 0, 0))
    for i, f in enumerate(images):
        im.alpha_composite(f, (i * w, 0))
    return im


# =============================================================================
# Bodies.  Shallow: Sea at 55 % ("=") so the floor shows through, one Shallow ripple run
# per tile that drifts 1 px per frame, one darker fleck.  Two variants (A, B) break the
# tile lattice: the room picks by (x + y) % 2.  Deep: Deep sea opaque with 1 px Sea
# ripples, 2 frames.  Abyss: the centre of large pools, Abyss with Deep sea ripples.
# =============================================================================
def shallow(variant, f):
    im = Image.new("RGBA", (16, 16), rgba("SEA", 140))
    px = im.load()
    rip = rgba("SHALLOW", 200)
    fleck = rgba("DEEP_SEA", 170)
    if variant == 0:
        for x in range(2 + f, 6 + f):
            px[x, 3] = rip
        px[10, 11] = fleck
        px[11, 11] = fleck
    else:
        for x in range(8 + f, 13 + f):
            px[x, 9] = rip
        px[3, 1] = fleck
        px[4, 1] = fleck
    return im


def deep(f, base="DEEP_SEA", rip="SEA"):
    im = Image.new("RGBA", (16, 16), rgba(base))
    px = im.load()
    r = rgba(rip)
    for x in range(3 + f, 7 + f):
        px[x, 4] = r
    for x in range(9 + f, 12 + f):
        px[x, 12] = r
    return im


def ring(f, near, far, a):
    """The far tile laid over the near one at alpha `a`: a translucent step. These were
    1 px checkers (STYLE.md 12 allowed the dither) until the Stage 20 gameplay pass: a
    pool four tiles across is nothing but ring cells, and at the screen's 3x the checker
    read as a screen door over the whole pool. Steps of depth, not texture."""
    im = near(f).copy()
    over = far(f).copy()
    over.putalpha(over.split()[3].point(lambda v: int(v * a)))
    im.alpha_composite(over)
    return im


def deep_ring_a(f):   # next to shallow: the deep body at 45 % over the shallow one
    return ring(f, lambda f: shallow(0, f), deep, 0.45)


def deep_ring_b(f):   # two tiles in: 75 %
    return ring(f, lambda f: shallow(0, f), deep, 0.75)


def abyss_ring(f):
    return ring(f, deep, lambda f: deep(f, "ABYSS", "DEEP_SEA"), 0.5)


def abyss(f):
    return deep(f, "ABYSS", "DEEP_SEA")


# =============================================================================
# Foam: on the water tile, along every edge that touches dry floor.  Salt white body 1-3 px
# deep, Foam white crest on the outermost pixel where the body is deepest, and the whole
# profile slides one pixel along the shore per frame.
# =============================================================================
DEPTH = [2, 2, 3, 2, 1, 1, 2, 3, 3, 2, 1, 2, 2, 3, 2, 1]


def foam(case, f):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = im.load()
    body = rgba("SALT_WHITE")
    crest = rgba("FOAM_WHITE")
    prof = [DEPTH[(i - f) % 16] for i in range(16)]
    for i in range(16):
        d = prof[i]
        for k in range(d):
            c = crest if (k == 0 and d == 3) else body
            if case & N:
                px[i, k] = c
            if case & S:
                px[i, 15 - k] = c
            if case & W:
                px[k, i] = c
            if case & E:
                px[15 - k, i] = c
    return im


# =============================================================================
# Wet band: on the dry cell, 2 px of Ink at 35 % along every edge that touches water (the
# damp floor the last wave left).  Tide line: on low ground, 1 px of Salt white dashes along
# every edge that meets normal floor (the salt crust at the high-water mark).
# =============================================================================
def wet_band(case):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = im.load()
    ink = rgba("INK", 90)
    for i in range(16):
        for k in range(2):
            if case & N:
                px[i, k] = ink
            if case & S:
                px[i, 15 - k] = ink
            if case & W:
                px[k, i] = ink
            if case & E:
                px[15 - k, i] = ink
    return im


def tide_line(case):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = im.load()
    salt = rgba("SALT_WHITE")
    for i in range(16):
        if i % 6 >= 4:
            continue
        if case & N:
            px[i, 0] = salt
        if case & S:
            px[i, 15] = salt
        if case & W:
            px[0, i] = salt
        if case & E:
            px[15, i] = salt
    return im


def build_water():
    row0 = [shallow(0, f) for f in range(3)] + [shallow(1, f) for f in range(3)]
    row0 += [deep_ring_a(f) for f in range(2)] + [deep_ring_b(f) for f in range(2)]
    row0 += [deep(f) for f in range(2)] + [abyss_ring(f) for f in range(2)] + [abyss(f) for f in range(2)]
    assert len(row0) == 16
    rows = [row0]
    for f in range(3):
        rows.append([foam(c, f) for c in range(16)])
    rows.append([wet_band(c) for c in range(16)])
    rows.append([tide_line(c) for c in range(16)])
    im = Image.new("RGBA", (256, 96), (0, 0, 0, 0))
    for r, cells in enumerate(rows):
        for c, cell in enumerate(cells):
            im.alpha_composite(cell, (c * 16, r * 16))
    return im


# =============================================================================
# Water effects.  Splash: no outline, Salt white drops with Foam white tips.
# Ripple ring: a 1 px Shallow ellipse that widens and fades.  Bubble: a Sea pale ring.
# =============================================================================
SPLASH = ["""
................
................
................
................
................
................
................
................
......Z..Z......
......W..W......
.....WW..WW.....
.....WWWWWW.....
......WWWW......
................
................
................
""", """
................
................
................
................
....Z......Z....
....W......W....
...W........W...
...W..Z.Z...W...
......W.W.......
.....W...W......
....W.....W.....
....'.....'.....
................
................
................
................
""", """
................
................
.Z............Z.
.W............W.
..'..........'..
................
......'..'......
....Z......Z....
....'......'....
................
................
.....'....'.....
................
................
................
................
"""]

RIPPLE = ["""
................
................
......SSSS......
.....S....S.....
.....S....S.....
......SSSS......
................
................
""", """
................
....--------....
...-........-...
..-..........-..
..-..........-..
...-........-...
....--------....
................
""", """
....;;;;;;;;....
..;;........;;..
.;............;.
;..............;
;..............;
.;............;.
..;;........;;..
....;;;;;;;;....
"""]

BUBBLE = ["""
....
.``.
.``.
....
""", """
.``.
`..`
`.Z`
.``.
"""]


def build_fx():
    return {
        "fx_splash": strip([g16(t) for t in SPLASH], 16, 16),
        "fx_ripple": strip([grid(t, 16, 8) for t in RIPPLE], 16, 8),
        "fx_bubble": strip([grid(t, 4, 4) for t in BUBBLE], 4, 4),
        "fx_wet": grid("\n".join(["'" + "e" * 14 + "'", "'" + "e" * 14 + "'"]), 16, 2),
    }


# =============================================================================
# Doors: the Stage 09 arch (shut, open) plus four water states.
#   2 water-closed: the grate is down and the water stands against it, a foam line across
#   3 flooded: the open arch shows dark water inside, foam on the sill
#   4 wet shortcut, shut: a low arch, dark and barred
#   5 wet shortcut, open: the same arch as a Sea-lit passage, water to the sill
# =============================================================================
DOOR_WATER_CLOSED = """
................................
................................
............LLLLLLLL............
..........LLTTTTTTTTLL..........
.........LTTTLLLLLLTTTL.........
........LTTLLkkkkkkLLTTt........
.......LTTLkkkkkkkkkkLTTt.......
.......LTLkkihihihihkkLTt.......
......LTTLkkihihihihkkLTTt......
......LTTLkkihihihihkkLTTt......
......LTTLkkihihihihkkLTTt......
......LTTLkkihihihihkkLTTt......
......LTTLkkihihihihkkLTTt......
......LTTLkkihihihihkkLTTt......
......LTTLWWZWWWWZWWWWLTTt......
......LTTL=E=E=E=E=E=ELTTt......
......LTTL=E=E=E=E=E=ELTTt......
......LTTL=E=E=E=E=E=ELTTt......
......LTTL=E=E=E=E=E=ELTTt......
......LTTL=E=E=E=E=E=ELTTt......
......LTTL=E=E=E=E=E=ELTTt......
......LTTL=E=E=E=E=E=ELTTt......
......ttttEEEEEEEEEEEEttttt.....
................................
................................
................................
................................
................................
................................
................................
................................
................................
"""
DOOR_FLOODED = """
................................
................................
............LLLLLLLL............
..........LLTTTTTTTTLL..........
.........LTTTLLLLLLTTTL.........
........LTTLL000000LLTTt........
.......LTTL0000000000LTTt.......
.......LTL000000000000LTt.......
......LTTL000000000000LTTt......
......LTTL000000000000LTTt......
......LTTL000000000000LTTt......
......LTTL000000000000LTTt......
......LTTL000000000000LTTt......
......LTTL000000000000LTTt......
......LTTL000000000000LTTt......
......LTTLEEEEEEEEEEEELTTt......
......LTTLEEEeeeEEEEEELTTt......
......LTTLEEEEEEEEEEEELTTt......
......LTTLEEEEEEEEeeEELTTt......
......LTTLEEEEEEEEEEEELTTt......
......LTTLEEEEEEEEEEEELTTt......
......LTTLWWZWWW'WWZWWLTTt......
......tttt'WWWWWWWWWW'ttttt.....
................................
................................
................................
................................
................................
................................
................................
................................
................................
"""
DOOR_WET_SHUT = """
................................
................................
................................
................................
................................
................................
............LLLLLLLL............
..........LLTTTTTTTTLL..........
.........LTTTLLLLLLTTTL.........
........LTTLL000000LLTTt........
.......LTTL0h00h00h00hLTTt......
.......LTL00h00h00h00hLTt.......
......LTTL00h00h00h00hLTTt......
......LTTL00h00h00h00hLTTt......
......LTTL00h00h00h00hLTTt......
......LTTL00h00h00h00hLTTt......
......LTTL00h00h00h00hLTTt......
......LTTL00h00h00h00hLTTt......
......LTTL00h00h00h00hLTTt......
......LTTL00h00h00h00hLTTt......
......LTTL00h00h00h00hLTTt......
......LTTLhhhhhhhhhhhhLTTt......
......tttt000000000000ttttt.....
................................
................................
................................
................................
................................
................................
................................
................................
................................
"""
DOOR_WET_OPEN = """
................................
................................
................................
................................
................................
................................
............LLLLLLLL............
..........LLTTTTTTTTLL..........
.........LTTTLLLLLLTTTL.........
........LTTLL000000LLTTt........
.......LTTL0000000000LTTt.......
.......LTL000000000000LTt.......
......LTTL000000000000LTTt......
......LTTL000000000000LTTt......
......LTTL000000000000LTTt......
......LTTLSSSSSSSSSSSSLTTt......
......LTTLeeSSSeeeeeeeLTTt......
......LTTLeeeeeeeeeeeeLTTt......
......LTTLeeeeeeeSSeeeLTTt......
......LTTLeeeeeeeeeeeeLTTt......
......LTTLeeeeeeeeeeeeLTTt......
......LTTLWWZWWW'WWZWWLTTt......
......tttt'WWWWWWWWWW'ttttt.....
................................
................................
................................
................................
................................
................................
................................
................................
................................
"""


def water_closed():
    """The shut arch with the tide standing against the grate: shallow water over the bars
    below the water line, a foam line across, the sill under water."""
    im = grid(GT.DOOR_SHUT, 32, 32)
    px = im.load()
    sea = rgba("SEA", 140)
    salt = rgba("SALT_WHITE")
    foam_w = rgba("FOAM_WHITE")
    for y in range(15, 23):
        for x in range(10, 22):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            # composite Sea at 55 % over what is there
            k = sea[3] / 255.0
            px[x, y] = (int(r * (1 - k) + sea[0] * k), int(g * (1 - k) + sea[1] * k), int(b * (1 - k) + sea[2] * k), 255)
    for x in range(10, 22):
        px[x, 14] = foam_w if x in (12, 17, 20) else salt
    return im


def build_doors():
    frames = [grid(GT.DOOR_SHUT, 32, 32), grid(GT.DOOR_OPEN_FRAME, 32, 32), water_closed(), grid(DOOR_FLOODED, 32, 32),
              grid(DOOR_WET_SHUT, 32, 32), grid(DOOR_WET_OPEN, 32, 32)]
    return strip(frames, 32, 32)


# =============================================================================
# Mock pools: the room's own selection rules, in Python, so the sheet shows exactly what
# room.gd will draw.  Heights: '#' wall, '_' low (0), '.' floor (1), '=' raised (2).
# =============================================================================
POOL = """
############
#..........#
#..____....#
#._______..#
#.________.#
#.________=#
#..______==#
#...____...#
#..........#
############
"""


def mock_pool(water, tiles, floor_idx, low_idx, raised_idx, wall_idx, tide, frame=0):
    rows = POOL.strip("\n").split("\n")
    h = len(rows)
    w = len(rows[0])

    def hgt(x, y):
        if x < 0 or y < 0 or x >= w or y >= h or rows[y][x] == "#":
            return 99
        return {"_": 0, ".": 1, "=": 2}[rows[y][x]]

    def solid(x, y):
        return hgt(x, y) == 99

    def flooded(x, y):
        return not solid(x, y) and tide > hgt(x, y)

    def is_deep(x, y):
        return not solid(x, y) and tide > hgt(x, y) + 1

    # distance from any non-deep cell
    dist = {}
    q = deque()
    for y in range(h):
        for x in range(w):
            if not is_deep(x, y):
                dist[(x, y)] = 0
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if 0 <= n[0] < w and 0 <= n[1] < h and n not in dist:
                dist[n] = dist[(x, y)] + 1
                q.append(n)

    def cell(col, row):
        return water.crop((col * 16, row * 16, col * 16 + 16, row * 16 + 16))

    def tile(i):
        return tiles.crop((i * 16, 0, i * 16 + 16, 16))

    im = Image.new("RGBA", (w * 16, h * 16), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            ch = rows[y][x]
            idx = {"#": wall_idx, "_": low_idx, ".": floor_idx, "=": raised_idx}[ch]
            im.alpha_composite(tile(idx), (x * 16, y * 16))
    dirs = ((N, 0, -1), (E, 1, 0), (S, 0, 1), (W, -1, 0))
    for y in range(h):
        for x in range(w):
            if solid(x, y):
                continue
            at = (x * 16, y * 16)
            if flooded(x, y):
                if is_deep(x, y):
                    d = dist[(x, y)]
                    col = 6 if d == 1 else 8 if d == 2 else 10 if d <= 4 else 12 if d == 5 else 14
                    im.alpha_composite(cell(col + (frame % 2), 0), at)
                else:
                    im.alpha_composite(cell(((x + y) % 2) * 3 + (frame % 3), 0), at)
                bits = 0
                for b, dx, dy in dirs:
                    if not solid(x + dx, y + dy) and not flooded(x + dx, y + dy):
                        bits |= b
                if bits:
                    im.alpha_composite(cell(bits, 1 + (frame % 3)), at)
            else:
                bits = 0
                for b, dx, dy in dirs:
                    if flooded(x + dx, y + dy):
                        bits |= b
                if bits:
                    im.alpha_composite(cell(bits, 4), at)
                if hgt(x, y) == 0:
                    bits = 0
                    for b, dx, dy in dirs:
                        if not solid(x + dx, y + dy) and hgt(x + dx, y + dy) >= 1:
                            bits |= b
                    if bits:
                        im.alpha_composite(cell(bits, 5), at)
    return im


def main():
    os.makedirs(REF, exist_ok=True)
    water = build_water()
    water.save(os.path.join(SPRITES, "water.png"))
    fx = build_fx()
    for name, im in fx.items():
        im.save(os.path.join(SPRITES, name + ".png"))
    doors = build_doors()
    doors.save(os.path.join(SPRITES, "door.png"))
    tiles = Image.open(os.path.join(SPRITES, "tiles.png")).convert("RGBA")

    try:
        font = ImageFont.load_default(size=11)
        small = ImageFont.load_default(size=9)
    except TypeError:
        font = small = ImageFont.load_default()
    Z = 4
    Wd = 1600
    sheet = Image.new("RGBA", (Wd, 2600), (30, 33, 42, 255))
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "EBB water  -  Stage 10  -  overlay cells, the overlay over five floors, mock pools at three tides, doors, effects  (4x)",
           fill=P.rgb("SALT_WHITE"), font=font)
    y = 30
    # the whole atlas over Sand
    d.text((12, y), "water.png over sand: bodies / foam f0 f1 f2 / wet band / tide line", fill=P.rgb("PALE_SLATE"), font=small)
    y += 14
    bg = Image.new("RGBA", water.size, (0, 0, 0, 0))
    sand = tiles.crop((0, 0, 16, 16))
    for r in range(6):
        for c in range(16):
            bg.alpha_composite(sand, (c * 16, r * 16))
    bg.alpha_composite(water)
    sheet.alpha_composite(zoom(bg, Z), (12, y))
    y += 96 * Z + 16

    # the shallow, deep and abyss bodies over five floors
    d.text((12, y), "shallow A / shallow B / deep ring A / ring B / deep / abyss ring / abyss  over  sand, cobble, basalt, hub sand, deck",
           fill=P.rgb("PALE_SLATE"), font=small)
    y += 14
    floors = [0, 14, 20, 32, 26]
    cols = [0, 3, 6, 8, 10, 12, 14]
    for fi, fidx in enumerate(floors):
        base = tiles.crop((fidx * 16, 0, fidx * 16 + 16, 16))
        for ci, col in enumerate(cols):
            block = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
            for by in (0, 16):
                for bx in (0, 16):
                    block.alpha_composite(base, (bx, by))
                    block.alpha_composite(water.crop((col * 16, 0, col * 16 + 16, 16)), (bx, by))
            sheet.alpha_composite(zoom(block, Z), (12 + ci * (32 * Z + 6), y + fi * (32 * Z + 6)))
    y += 5 * (32 * Z + 6) + 12

    # mock pools
    d.text((12, y), "mock pool (low basin, a raised corner) on the Flats, the Streets, the Hall at tide 0 (dry, tide line), 0.5 (low ground shallow), 1.5 (low deep, floor shallow), 2.5 (all deep)  (2x)",
           fill=P.rgb("PALE_SLATE"), font=small)
    y += 14
    Zp = 2
    themes = [(0, 7, 8, 2), (14, 18, 19, 16), (20, 24, 25, 22)]
    for ti, (fl, lo, ra, wa) in enumerate(themes):
        for ki, tide in enumerate((0.0, 0.5, 1.5, 2.5)):
            pool = mock_pool(water, tiles, fl, lo, ra, wa, tide, frame=ki)
            sheet.alpha_composite(zoom(pool, Zp), (12 + ki * (pool.width * Zp + 8), y + ti * (pool.height * Zp + 8)))
    y += 3 * (10 * 16 * Zp + 8) + 12

    # doors and effects
    d.text((12, y), "door.png: shut, open, water-closed, flooded, wet shortcut shut, wet shortcut open      fx: splash x3, ripple x3, bubble x2, wet edge",
           fill=P.rgb("PALE_SLATE"), font=small)
    y += 14
    x = 12
    for i in range(6):
        bg = Image.new("RGBA", (32, 32), P.rgba("SAND"))
        bg.alpha_composite(doors.crop((i * 32, 0, i * 32 + 32, 32)))
        sheet.alpha_composite(zoom(bg, Z), (x, y))
        x += 32 * Z + 8
    x += 12
    for key, cw, chh, bgk in (("fx_splash", 16, 16, "SEA"), ("fx_ripple", 16, 8, "SEA"), ("fx_bubble", 4, 4, "DEEP_SEA"), ("fx_wet", 16, 2, "SAND")):
        im = fx[key]
        bg = Image.new("RGBA", im.size, P.rgba(bgk))
        bg.alpha_composite(im)
        sheet.alpha_composite(zoom(bg, Z), (x, y))
        x += im.width * Z + 12
    y += 32 * Z + 24
    sheet = sheet.crop((0, 0, Wd, y))
    sheet.convert("RGB").save(os.path.join(REF, "water_sheet.png"))
    print("wrote water.png, fx_splash/ripple/bubble/wet.png, door.png (6 frames), water_sheet.png")


if __name__ == "__main__":
    main()
