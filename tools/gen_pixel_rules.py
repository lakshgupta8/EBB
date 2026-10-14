"""Draws the pixel rule sheet: assets/reference/pixel_rules.png.

Every example is drawn at 1x from a text grid using only tools/palette.py colours, then
shown at 1x and 4x side by side.  STYLE.md sections 2-5 point here.  Nothing in this file
is a production sprite; it is the visual contract the production sprites are checked against.

Run:  python tools/gen_pixel_rules.py
"""
import os
import random

from PIL import Image, ImageDraw, ImageFont

import palette as P

OUT = os.path.join(P.ROOT, "assets", "reference", "pixel_rules.png")
ZOOM = 4

# Letter legend shared by every grid.  Upper/lower pairs are ramp steps.
LEG = {
    ".": None,
    "k": ("INK", 255), "K": ("INK", 115), "j": ("INK", 90),      # ink, 45 % blob, 35 % cast band
    "o": ("OILSKIN", 255), "O": ("OILSKIN_LIGHT", 255), "d": ("OILSKIN_DARK", 255),
    "f": ("SKIN", 255), "s": ("SKIN_SHADE", 255),
    "W": ("SALT_WHITE", 255), "Z": ("FOAM_WHITE", 255),
    "b": ("WOOL_DARK", 255), "w": ("WOOL", 255),
    "y": ("WARM_YELLOW", 255), "c": ("PALE_CREAM", 255), "a": ("AMBER", 255),
    "i": ("IRON", 255), "I": ("IRON_LIGHT", 255), "h": ("IRON_DARK", 255),
    "t": ("STONE_DARK", 255), "T": ("STONE", 255), "L": ("STONE_LIGHT", 255),
    "n": ("SAND_DARK", 255), "N": ("SAND", 255), "M": ("SAND_LIGHT", 255),
    "e": ("SEA", 255), "E": ("DEEP_SEA", 255), "S": ("SHALLOW", 255),
    "r": ("ROPE", 255), "R": ("WEATHERED_BROWN", 255),
    "B": ("BONE", 255), "v": ("BONE_DARK", 255), "V": ("BONE_LIGHT", 255),
    "1": ("NIGHT_1", 255), "2": ("NIGHT_2", 255), "3": ("SLATE", 255),
    "x": ("ABYSS", 255),
    "p": ("PALE_CREAM", 60), "q": ("PALE_CREAM", 30),                # lantern pool
    "u": ("BONE", 128),                                            # anti-aliased pixel (forbidden)
}


def grid(text, legend=LEG):
    rows = [r for r in text.strip("\n").split("\n")]
    w = max(len(r) for r in rows)
    im = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            v = legend.get(ch)
            if v:
                px[x, y] = P.rgb(v[0]) + (v[1],)
    return im


def over(fg, bg_key, pad=2, bg=None):
    """Composite a grid over a flat floor colour (or a given background image)."""
    if bg is None:
        bg = Image.new("RGBA", (fg.width + pad * 2, fg.height + pad * 2), P.rgba(bg_key))
    bg.alpha_composite(fg, (pad, pad))
    return bg


def checker(w, h):
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            px[x, y] = (70, 74, 84, 255) if ((x // 4 + y // 4) % 2 == 0) else (56, 60, 70, 255)
    return im


# --- the 24 px figure (STYLE.md 7): hood rows 2-8, torso 9-16, legs 17-21, feet row 21 ---
FIGURE = """
........................
........................
.........kkkkkk.........
........kOWWWOok........
.......kOoooooook.......
.......koodddddok.......
.......kodfffffdk.......
.......kodfkffsdk.......
........kdfffsdk........
.......kOOOOOOOOk.......
......kOooooooooOk......
......koooodoooook......
......kooooodooook......
......kodoooooodok......
.......kdoooooodk.......
.......kbbdddddbk.......
........kbbbkbbbk.......
........kbbbkbbbk.......
........kbbkkkbbk.......
........kbbk.kbbk.......
........kbbk.kbbk.......
.......kkkkk.kkkkk......
........................
........................
"""

# Same figure, wrong: Ink used for every internal line and a second, scattered set of highlights.
FIGURE_BAD_INK = FIGURE.replace("d", "k").replace("s", "k")
FIGURE_BAD_HL = FIGURE.replace("kOooooooooOk", "kOoWoooWooOk").replace("kbbbkbbbk", "kbWbkbWbk")
# Same figure with no outline at all.
FIGURE_NO_OUTLINE = FIGURE.replace("k", ".")

BLOB = """
....KKKKKKKK....
...KKKKKKKKKK...
...KKKKKKKKKK...
....KKKKKKKK....
"""

# --- wall foot and cast band: 3x3 tiles, wall along the top and the left ---
WALL_TILES = """
LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL
LLWLLLLLLLLLLLLLLLLLWLLLLLLLLLLLLLLLLLLLLLLLLWLL
LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL
LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL
tttttttttttttttttttttttttttttttttttttttttttttttt
tttttttttttttttttttttttttttttttttttttttttttttttt
ttttttTTTTTttttttttttTTTTTTttttttttttTTTTTTttttt
ttttttTTTTTttttttttttTTTTTTttttttttttTTTTTTttttt
tttttttttttttttttttttttttttttttttttttttttttttttt
ttTTTTTTttttttTTTTTTTTttttttttTTTTTTTTttttttTTTT
ttTTTTTTttttttTTTTTTTTttttttttTTTTTTTTttttttTTTT
tttttttttttttttttttttttttttttttttttttttttttttttt
tttttttttttttttttttttttttttttttttttttttttttttttt
tttttttttttttttttttttttttttttttttttttttttttttttt
tttttttttttttttttttttttttttttttttttttttttttttttt
kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk
LLLLLkjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
LLLLLkjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
LLLLLkjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
LLLLLkjNNNNNNNNNNNNNNNNNMMMMMNNNNNNNNNNNNNNNNNNN
LLLLLkjNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
LLLLLkjNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
LLLLLkjNNNNNNNNNMMMMNNNNNNNNNNNNNNNNNNNNNNNNNNNN
LLLLLkjNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
LLLLLkjNNNNNNNNNNNNNNNNNNNNNNNNNNNNMMMMMMNNNNNNN
LLLLLkjNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
LLLLLkjNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
LLLLLkjNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
LLLLLkjNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
LLLLLkjNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
LLLLLkjNNNNNNNNNNNMMMMMNNNNNNNNNNNNNNNNNNNNNNNNN
LLLLLkjNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
"""

# --- a 16x24 stone altar block: grounding edge (Stone dark) on bottom + right only ---
PROP = """
................
......LLLLL.....
....LLLLTTTLL...
...LLTTTTTTTTL..
...LTTTTTTTTTTt.
...LTTTTTTTTTTt.
...LWTTTTTTTTTt.
...LTTTTTTTTTTt.
...LtttttttttTt.
....LTTTTTTTTt..
....LTTTTTTTTt..
....LTTTTTTTTt..
....LTTTTTTTTt..
....LTTTTTTTTt..
....LTTTTTTTTt..
....LTTTTTTTTt..
....LTTTTTTTTt..
....LTTTTTTTTt..
...LTTTTTTTTTTt.
...LTTTTTTTTTTt.
...LTTTTTTTTTTt.
...tttttttttttt.
..jjjjjjjjjjjjjj
..jjjjjjjjjjjjjj
"""
PROP_BAD = PROP.replace("t", "k").replace("L", "k")   # Ink all round: reads as an enemy

# --- key light on primitives (16x16 each) ---
CUBE = """
................
....LLLLLLL.....
...LLLLLLLLLT...
..LLLLLLLLLTTT..
..TTTTTTTTTTTt..
..TTTTTTTTTTTt..
..TTTTTTTTTTTt..
..TTTTTTTTTTtt..
..TTTTTTTTTTtt..
..TTTTTTTTTTtt..
..TTTTTTTTTTtt..
..TTTTTTTTTTtt..
..TTTTTTTTTTtt..
..tttttttttttt..
...jjjjjjjjjjjj.
................
"""
CYLINDER = """
................
.....LLLLLL.....
....LLLLLLLTT...
....LLLLLLTTT...
....TLLLLTTTt...
....TTTTTTTTt...
....TTTTTTTTt...
....TTTTTTTTt...
....TTTTTTTTt...
....TTTTTTTTt...
....TTTTTTTTt...
....TTTTTTTTt...
....TTTTTTTTt...
....tTTTTTTtt...
.....tttttt.....
......jjjjjjj...
"""
HEAD = """
................
......kkkkk.....
.....kOWWOok....
....kOoooooOk...
....koodddook...
....kodfffdok...
....kodfkfsok...
....kodfffsdk...
.....kdfssdk....
......kkkkk.....
................
................
................
................
................
................
"""

# --- one highlight per ramp: a wet stone top ---
STONE_WET = """
................
...WWWWWWWW.....
..LLLLLLLLLL....
.LLLLLLLLLLLL...
.TTTTTTTTTTTT...
.TTTTTTTTTTTT...
.TTTTTTTTTTTT...
.tTTTTTTTTTTt...
.tttttttttttt...
................
"""
STONE_WET_BAD = STONE_WET.replace(".TTTTTTTTTTTT...\n.TTTTTTTTTTTT...\n.TTTTTTTTTTTT...",
                                  ".TTWTTTTWTTTT...\n.TTTTTWTTTTWT...\n.TWTTTTTTWTTT...")
ROPE_DRY = """
................
...rrrrrrrrr....
..rRrrRrrRrrr...
..rrRrrRrrRrr...
..RrrRrrRrrRr...
...rrrrrrrrr....
................
"""
ROPE_DRY_BAD = ROPE_DRY.replace("..rRrrRrrRrrr...", "..WWrrRrrRrrr...")

# --- clusters: a drawn stone floor tile vs sprinkled noise ---
STONE_TILE = """
TTTTTTTTTTTTTTTT
TLLLLTTTTLLLLLTT
TLTTTtTTTLTTTTtT
TLTTTtTTTLTTTTtT
TtttttTTTLTTTTtT
TTTTTTTTTtttttTT
TTLLLLLLTTTTTTTT
TTLTTTTtTTLLLLTT
TTLTTTTtTTLTTTtT
TTtttttttTLTTTtT
TTTTTTTTTTtttttT
TLLLLTTTTTTTTTTT
TLTTTtTTLLLLLLTT
TLTTTtTTLTTTTTtT
TtttttTTLTTTTTtT
TTTTTTTTttttttTT
"""
SAND_TILE = """
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNMMMMNNNNNNNNNN
NNNNNNMMMNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNMMMMN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNnnnNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
NNNMMMNNNNNNNNNN
NNNNNNMMMNNNNNNN
NNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNN
"""


def noise_tile(base, a, b, n, seed):
    rnd = random.Random(seed)
    rows = [[base] * 16 for _ in range(16)]
    for _ in range(n):
        rows[rnd.randrange(16)][rnd.randrange(16)] = rnd.choice([a, b])
    return "\n".join("".join(r) for r in rows)


# --- dithers: the two permitted, and the forbidden one ---
WATER_EDGE = """
eeeeeeeeeeeeeeeeeeeeeEeEeEEEEEEEEEEE
eeeeeeeeeeeeeeeeeeeeeEeEEEEEEEEEEEEE
eeeeeeeeeeeeeeeeeeeeEeEeEEEEEEEEEEEE
eeeeeeeeeeeeeeeeeeeeEeEEEEEEEEEEEEEE
eeeeeeeeeeeeeeeeeeeeeEeEeEEEEEEEEEEE
eeeeeeeeeeeeeeeeeeeeeEeEEEEEEEExxEEE
eeeeeeeeeeeeeeeeeeeeEeEeEEEEEEEEEEEE
eeeeeeeeeeeeeeeeeeeeEeEEEEEEEEEEEEEE
eeeeeeeeeeeeeeeeeeeeeEeEeEEEEEEEEEEE
eeeeeeeeeeeeeeeeeeeeeEeEEEEEEEEEEEEE
eeeeeeeeeeeeeeeeeeeeEeEeEEEEEEEEEEEE
eeeeeeeeeeeeeeeeeeeeEeEEEEEEEEEEEEEE
"""
POOL = """
........................
........q.q.q.q.q.......
......q.pppppppp.q......
.....q.pppppppppp.q.....
....q.pppppppppppp.q....
....pppppppppppppp.q....
...q.pppppppppppppp.q...
...pppppppppppppppp.....
...q.pppppppppppppp.q...
...pppppppppppppppp.....
...q.pppppppppppppp.q...
....pppppppppppppp.q....
....q.pppppppppppp.q....
.....q.pppppppppp.q.....
......q.pppppppp.q......
........q.q.q.q.q.......
........................
"""
COAT_DITHER_BAD = """
.......kkkkkkkk.......
......kOoOoOoOok......
......koOoOoOoOk......
......kOoOoOoOok......
......koOoOoOoOk......
......kdodododok......
......kodododdok......
.......kkkkkkkk.......
"""

# --- curves and diagonals ---
CIRCLE_OK = """
....BBBB....
..BBvvvvBB..
.BvvvvvvvvB.
.BvvvvvvvvB.
BvvvvvvvvvvB
BvvvvvvvvvvB
BvvvvvvvvvvB
BvvvvvvvvvvB
.BvvvvvvvvB.
.BvvvvvvvvB.
..BBvvvvBB..
....BBBB....
"""
CIRCLE_BAD = """
...BBBBBB...
..BvvvvvvB..
.BvvvvvvvvB.
BvvvvvvvvvvB
BvvvvvvvvvvB
BvvvvvvvvvvB
BvvvvvvvvvvB
BvvvvvvvvvvB
BvvvvvvvvvvB
.BvvvvvvvvB.
..BvvvvvvB..
...BBBBBB...
"""
DIAG_OK = """
BB..............
.BB.............
..BB............
...BB...........
....BB..........
.....BB.........
......BB........
.......BB.......
"""
DIAG_BAD = """
BB..............
.BBB............
...BB...........
....BBB.........
......BB........
.......B........
........BB......
.........BBB....
"""

# --- anti-aliasing against transparency ---
AA_OK = """
....BB....
...BBBB...
..BBBBBB..
.BBBBBBBB.
BBBBBBBBBB
.BBBBBBBB.
..BBBBBB..
...BBBB...
....BB....
"""
AA_BAD = """
...uBBu...
..uBBBBu..
.uBBBBBBu.
uBBBBBBBBu
BBBBBBBBBB
uBBBBBBBBu
.uBBBBBBu.
..uBBBBu..
...uBBu...
"""


def zoom(im, z=ZOOM):
    return im.resize((im.width * z, im.height * z), Image.NEAREST)


def figure_with_blob(fig_text, blob=True, floor="SAND"):
    bg = Image.new("RGBA", (28, 28), P.rgba(floor))
    if blob:
        bg.alpha_composite(grid(BLOB), (6, 21))
    bg.alpha_composite(grid(fig_text), (2, 2))
    return bg


def main():
    try:
        font = ImageFont.load_default(size=11)
        big = ImageFont.load_default(size=15)
        small = ImageFont.load_default(size=9)
    except TypeError:
        font = big = small = ImageFont.load_default()

    sand = "SAND"
    # Each panel: (title, note, [(caption, image, good?)])
    panels = [
        ("A. OUTLINE LAW (STYLE.md 3)",
         "Gameplay entities: full 1 px Ink outline. Inside, lines use the material's darkest ramp step (Oilskin dark), never Ink. "
         "Ink inside a face is the eye only. Hood rows 2-8, torso 9-16, legs 17-21, feet on row 21 (STYLE.md 7).",
         [("DO: Ink outside, ramp-dark inside", figure_with_blob(FIGURE), True),
          ("DON'T: Ink for every internal line", figure_with_blob(FIGURE_BAD_INK), False),
          ("DON'T: no outline (melts into floor)", figure_with_blob(FIGURE_NO_OUTLINE), False)]),
        ("B. DROP SHADOW BLOB (STYLE.md 4)",
         "A separate blob under every grounded entity: Ink at 45 %, 60 % of body width, 4 px tall (6 px on bosses). "
         "No painted lantern shadows, no long cast shadows from characters.",
         [("DO: blob, 45 % Ink", figure_with_blob(FIGURE), True),
          ("DON'T: none (floats)", figure_with_blob(FIGURE, blob=False), False)]),
        ("C. WALL FOOT AND CAST BAND (STYLE.md 3, 4)",
         "Tiles never carry an outline. Where a wall meets the floor there is a 1 px Ink line, then a 3 px Ink-35 % band on "
         "the south side and a 1 px band on the west and east. Wall top Stone light, face Stone dark with 3-5 drawn stones.",
         [("DO: Flats wall corner over Sand", over(grid(WALL_TILES), sand, pad=0), True)]),
        ("D. PROP GROUNDING EDGE (STYLE.md 3)",
         "Major props are outlined on the bottom and the shadow side only, in the material's darkest step (Stone dark), "
         "with a 2 px Ink-35 % band on the south side inside the sprite. The top and the lit (left) side stay open.",
         [("DO: grounding edge", over(grid(PROP), sand), True),
          ("DON'T: full Ink (reads as an enemy)", over(grid(PROP_BAD), sand), False)]),
        ("E. KEY LIGHT (STYLE.md 4)",
         "Top-down, slightly top-left. Top face lightest, vertical faces mid, undersides and the right side darkest. "
         "Shadow is the ramp's dark step, never black.",
         [("cube", over(grid(CUBE), sand), True),
          ("cylinder", over(grid(CYLINDER), sand), True),
          ("hooded head", over(grid(HEAD), sand), True)]),
        ("F. ONE HIGHLIGHT PER RAMP; WET HIGHLIGHT (STYLE.md 5)",
         "A ramp has at most one highlight, placed on the top edge of a rounded form, never scattered. Wet things get a 1 px "
         "Salt white run on their top edge. Dry things (rope, wool, wood interiors) never get Salt white.",
         [("DO: wet stone, one Salt white run", over(grid(STONE_WET), sand), True),
          ("DON'T: highlights sprinkled", over(grid(STONE_WET_BAD), sand), False),
          ("DO: dry rope, Weathered brown only", over(grid(ROPE_DRY), sand), True),
          ("DON'T: Salt white on dry rope", over(grid(ROPE_DRY_BAD), sand), False),
          ("DON'T: second highlight set on a figure", figure_with_blob(FIGURE_BAD_HL), False)]),
        ("G. CLUSTERS, NOT NOISE (STYLE.md 2)",
         "Minimum cluster 2x2 unless it is a named accent. A stone tile is 3-5 drawn stones; a sand tile is 2-3 ripple "
         "lines. Texture is drawn, never sprinkled.",
         [("DO: drawn stones", grid(STONE_TILE), True),
          ("DON'T: 40 random pixels", grid(noise_tile("T", "L", "t", 40, 7)), False),
          ("DO: sand ripples", grid(SAND_TILE), True),
          ("DON'T: sand noise", grid(noise_tile("N", "M", "n", 40, 3)), False)]),
        ("H. THE TWO PERMITTED DITHERS (STYLE.md 2)",
         "Only here: the shallow-to-deep water boundary (2-colour checker band, 3-4 px wide) and the soft edge of a large "
         "effect (lantern pool, mist). Never on characters, props, tiles or UI.",
         [("DO: shallow -> deep boundary", grid(WATER_EDGE), True),
          ("DO: lantern pool edge over floor", over(grid(POOL), sand, pad=0), True),
          ("DON'T: dither as shading on a coat", over(grid(COAT_DITHER_BAD), sand), False)]),
        ("I. CURVES AND DIAGONALS (STYLE.md 2)",
         "Circles follow the 8-fold templates with 1-2-3 stepping. Diagonals keep one run length per edge (here 2:1). "
         "No lone corner pixels, no mixed runs.",
         [("DO: 12 px circle", grid(CIRCLE_OK), True),
          ("DON'T: lone corners", grid(CIRCLE_BAD), False),
          ("DO: 2:1 run", grid(DIAG_OK), True),
          ("DON'T: 2:1 and 3:1 mixed", grid(DIAG_BAD), False)]),
        ("J. NO ANTI-ALIASING AGAINST TRANSPARENCY (STYLE.md 2)",
         "Edges against alpha are hard. Half-alpha pixels turn into fringes under the night tint and the lights. "
         "Internal anti-aliasing is allowed only between two adjacent ramp colours on large curves (bosses, props, logo).",
         [("DO: hard edge", grid(AA_OK), True),
          ("DON'T: half-alpha rim", grid(AA_BAD), False)]),
    ]

    W = 1180
    paper = (30, 33, 42)
    im = Image.new("RGBA", (W, 3200), paper + (255,))
    d = ImageDraw.Draw(im)
    green = P.rgb("VERDIGRIS")
    red = P.rgb("SALT_RED")
    white = P.rgb("SALT_WHITE")
    grey = P.rgb("PALE_SLATE")

    y = 12
    d.text((12, y), "EBB pixel rules  -  STYLE.md sections 2-5, drawn  -  every example at 1x (left) and 4x", fill=white, font=big)
    y += 22
    d.text((12, y), "Palette-only. These are not production sprites; they are what production sprites are checked against. Generated by tools/gen_pixel_rules.py.", fill=grey, font=font)
    y += 26

    for title, note, items in panels:
        d.text((12, y), title, fill=white, font=font)
        y += 15
        # wrap the note by hand at ~150 chars
        words, line, lines = note.split(" "), "", []
        for wd in words:
            if len(line) + len(wd) > 165:
                lines.append(line)
                line = ""
            line += wd + " "
        lines.append(line)
        for ln in lines:
            d.text((12, y), ln, fill=grey, font=small)
            y += 11
        y += 4
        x = 12
        row_h = 0
        for caption, img, good in items:
            # tint the transparent checker behind anything with alpha holes
            base = checker(img.width, img.height)
            base.alpha_composite(img)
            one = base
            four = zoom(base)
            w = max(four.width, 150)
            if x + w + one.width + 24 > W:
                x = 12
                y += row_h + 26
                row_h = 0
            im.alpha_composite(one, (x, y))
            im.alpha_composite(four, (x + one.width + 6, y))
            col = green if good else red
            d.text((x, y + four.height + 3), caption, fill=col, font=small)
            x += one.width + 6 + w + 18
            row_h = max(row_h, four.height)
        y += row_h + 30

    im = im.crop((0, 0, W, y + 6))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    im.convert("RGB").save(OUT)
    print("wrote", os.path.relpath(OUT, P.ROOT), im.size)


if __name__ == "__main__":
    main()
