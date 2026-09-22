"""Stage 18: the EBB wordmark and the title mark.

    assets/sprites/logo.png                  the wordmark at 1x (drawn on the pixel grid; never scaled)
    assets/reference/anchors/logo_sheet.png  the review sheet

The mark (STYLE.md 16, "The logo"): three slab capitals, the wood type of a ship's nameplate
at 30 rows with 5 px stems, painted in the Bone ramp and lit from the left, where the
lighthouse stands. The tide has gone out: a wet stain rings the letters four rows above the
water, foam breaks at their feet, and the sea below holds a broken reflection in the Sea
ramp. The lighthouse (the hub's whitewashed tower on its rock) is the only warm thing: its
lamp, and the lamp's glitter on the water. Ink outline around everything above the water,
a 1 px Ink shadow at (+1, +1); nothing under the water is outlined, so the reflection
dissolves. The letters carry no outline break and no anti-aliasing.

Run:  python tools/gen_logo.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
from gen_anchors import zoom  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
REF = os.path.join(P.ROOT, "assets", "reference", "anchors")

CAP = 30          # letter height
GAP = 5           # between letters
LX, LY = 24, 14   # the letter block in the canvas
W, H = 108, 58    # the canvas
WATER = LY + CAP  # the row the letters stand on (their Ink foot line); foam is the row under it


# --- masks --------------------------------------------------------------------------
def blank(w, h):
    return [[0] * w for _ in range(h)]


def fill(m, x0, y0, x1, y1, v=1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            m[y][x] = v


def rrect(m, x0, y0, x1, y1, r, v=1, corners=("tr", "br")):
    """A rectangle whose named corners are rounded to radius r (pixel circle test)."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            ok = True
            if "tr" in corners and x > x1 - r and y < y0 + r:
                dx, dy = x - (x1 - r) - 0.5, (y0 + r) - y - 0.5
                ok = dx * dx + dy * dy <= r * r
            if "br" in corners and x > x1 - r and y > y1 - r:
                dx, dy = x - (x1 - r) - 0.5, y - (y1 - r) - 0.5
                ok = ok and dx * dx + dy * dy <= r * r
            if ok:
                m[y][x] = v


def letter_E():
    m = blank(22, CAP)
    fill(m, 0, 0, 21, 4)        # top bar, overhanging the stem on the left (the serif)
    fill(m, 19, 5, 21, 6)       # the wood-type drop at its end
    fill(m, 2, 0, 6, 29)        # stem
    fill(m, 2, 12, 15, 14)      # middle bar, a high waist
    fill(m, 14, 10, 15, 16)     # its serif
    fill(m, 0, 25, 21, 29)      # bottom bar
    fill(m, 19, 23, 21, 24)     # the rise at its end
    return m


def letter_B():
    m = blank(24, CAP)
    rrect(m, 2, 0, 21, 14, 7)   # upper bowl
    rrect(m, 7, 5, 15, 10, 3, 0)
    rrect(m, 2, 11, 23, 29, 8)  # lower bowl, a little wider
    rrect(m, 7, 15, 17, 24, 3, 0)
    fill(m, 2, 0, 6, 29)        # stem
    fill(m, 0, 0, 1, 4)         # the serifs overhang on the left
    fill(m, 0, 25, 1, 29)
    return m


LETTERS = [letter_E(), letter_B(), letter_B()]


# --- paint --------------------------------------------------------------------------
def c(key, a=255):
    return P.rgb(key) + (a,)


# The three colourways tried for the letters (the sheet compares them). "bone" ships: a
# nameplate's bleached paint, the one made thing on a cold screen, without becoming a
# second lamp.
RAMPS = {
    "bone": ("BONE_LIGHT", "BONE", "BONE_DARK"),        # painted board
    "stone": ("STONE_LIGHT", "STONE", "STONE_DARK"),    # dressed stone
    "salt": ("SALT_WHITE", "PALE_SLATE", "WET_GREY"),   # salt-crusted whitewash
}
RAMP = "bone"


def ramp():
    return tuple(c(k) for k in RAMPS[RAMP])


def stain_of(col):
    light, body, dark = ramp()
    under = c("SLATE") if RAMP == "salt" else c("WET_GREY")
    return {light: body, body: dark, dark: under}.get(col, col)


def shade(m):
    """Bone light on the top and the left (the lamp is to the left), Bone dark on the
    right (2 px on a stem) and the underside, Bone between."""
    h, w = len(m), len(m[0])
    out = {}
    for y in range(h):
        for x in range(w):
            if not m[y][x]:
                continue
            up = y == 0 or not m[y - 1][x]
            left = x == 0 or not m[y][x - 1]
            right = x >= w - 2 or not m[y][x + 1] or not m[y][x + 2]
            down = y == h - 1 or not m[y + 1][x]
            light, body, dark = ramp()
            if up or left:
                out[(x, y)] = light
            elif right or down:
                out[(x, y)] = dark
            else:
                out[(x, y)] = body
    return out


def tide_mark(px):
    """The high-water stain, rows 22-25 of the letter: a Wet grey line with a ragged top,
    the rows under it a step darker, and moss in the seam where it meets the water."""
    _, body, dark = ramp()
    for (x, y), col in list(px.items()):
        r = y - LY
        if r == 22 and (x * 7 + 3) % 4 != 0:
            px[(x, y)] = c("WET_GREY") if col != dark else c("SLATE")
        elif 23 <= r <= 25:
            px[(x, y)] = stain_of(col)
        if r in (26, 27) and col == body and (x * 5 + r * 3) % 11 == 0:
            px[(x, y)] = c("MOSS")


def paint_letters(im):
    px = {}
    x = LX
    for m in LETTERS:
        for (lx, ly), col in shade(m).items():
            px[(x + lx, LY + ly)] = col
        x += len(m[0]) + GAP
    tide_mark(px)
    for (x, y), col in px.items():
        im.putpixel((x, y), col)
    return px


def paint_tower(im):
    """The whitewashed tower on its rock, the lamp lit, at the left of the letters."""
    cx = 12
    foot = WATER - 3               # the rock's top
    top = foot - 34
    body_top = top + 8
    px = {}
    # The shaft tapers 7 -> 15 over its 26 rows. A straight stem under a lit box reads as a
    # lowercase i; the taper and the wide foot are what make it a tower at this size.
    for y in range(body_top, foot):
        t = (y - body_top) / float(foot - 1 - body_top)
        w = 7 + int(round(t * 8))
        x0 = cx - w // 2
        for x in range(x0, x0 + w):
            col = c("PALE_SLATE")
            if x == x0:
                col = c("SALT_WHITE")
            elif x >= x0 + w - 2:
                col = c("WET_GREY")
            px[(x, y)] = col
        if y in (body_top + 8, body_top + 9, body_top + 18, body_top + 19):   # the two bands
            for x in range(x0, x0 + w):
                px[(x, y)] = c("SLATE") if x > x0 else c("WET_GREY")
    # the gallery, wider than the shaft under it
    for x in range(cx - 6, cx + 6):
        px[(x, top + 7)] = c("IRON_DARK")
        px[(x, top + 6)] = c("IRON")
    px[(cx - 7, top + 7)] = c("IRON_DARK")
    px[(cx + 6, top + 7)] = c("IRON_DARK")
    # the lamp room: iron posts, warm glass, a cream core
    for y in range(top + 2, top + 6):
        for x in range(cx - 4, cx + 4):
            px[(x, y)] = c("WARM_YELLOW")
        px[(cx - 4, y)] = c("IRON_DARK")
        px[(cx + 3, y)] = c("IRON_DARK")
    for y in (top + 3, top + 4):
        for x in (cx - 1, cx):
            px[(x, y)] = c("PALE_CREAM")
    # the cap
    for x in range(cx - 4, cx + 4):
        px[(x, top + 1)] = c("SLATE")
    for x in range(cx - 2, cx + 2):
        px[(x, top)] = c("SLATE")
    px[(cx - 1, top - 1)] = c("IRON_LIGHT")
    px[(cx, top - 1)] = c("IRON_LIGHT")
    # the rock: a low mound wider than the tower, its top a step lighter
    for i, w in enumerate((17, 21, 23)):
        y = foot + i
        x0 = cx - w // 2 - i
        for x in range(x0, x0 + w):
            px[(x, y)] = c("STONE") if i == 0 else c("STONE_DARK")
        if i > 0:
            px[(x0, y)] = c("STONE")
    px[(cx + 7, foot - 1)] = c("STONE")     # knuckles of rock beside the foot
    px[(cx + 8, foot - 1)] = c("STONE_DARK")
    px[(cx - 8, foot - 1)] = c("STONE")
    for (x, y), col in px.items():
        im.putpixel((x, y), col)
    return px, (cx, top + 3)


def outline_and_shadow(im, solid):
    """1 px Ink around every solid pixel above the water, then a 1 px Ink shadow at
    (+1, +1) outside that, at 45 %, so it stays a shadow on the night sky."""
    outline = set()
    for (x, y) in solid:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                p = (x + dx, y + dy)
                if p not in solid and 0 <= p[0] < W and 0 <= p[1] < H and p[1] <= WATER:
                    outline.add(p)
    for p in outline:
        im.putpixel(p, c("INK"))
    shape = solid | outline
    for (x, y) in shape:
        p = (x + 1, y + 1)
        if p not in shape and 0 <= p[0] < W and 0 <= p[1] < H and p[1] <= WATER + 1:
            if im.getpixel(p)[3] == 0:
                im.putpixel(p, c("INK", 115))


def paint_water(im, letters, tower, lamp):
    """Foam at the feet, a broken reflection of everything standing, the lamp's glitter."""
    foam_y = WATER + 1
    feet = {x for (x, y) in letters if y == WATER - 1} | {x for (x, y) in tower if y == WATER - 1}
    for x in range(W):
        if x in feet:
            im.putpixel((x, foam_y), c("FOAM_WHITE") if (x * 3) % 5 != 4 else c("SALT_WHITE"))
        elif (x - 1 in feet or x + 1 in feet):
            im.putpixel((x, foam_y), c("SALT_WHITE"))
        elif (x * 11 + 4) % 17 in (0, 1) and 4 < x < W - 3:
            im.putpixel((x, foam_y), c("SALT_WHITE"))
    standing = {}
    standing.update(letters)
    standing.update(tower)
    # The mirror: each row under the foam samples a row above it, two for one, so the
    # reflection is half the height of what stands. It is cut by wavelets (runs of
    # columns, never single pixels) and loses a step with depth: Shallow, Sea, Deep sea.
    # Nothing down here is outlined, so it dissolves instead of standing.
    steps = (c("SHALLOW"), c("SEA"), c("DEEP_SEA"))
    for k in range(8):
        y = foam_y + 1 + k
        if y >= H:
            break
        src = WATER - 1 - k * 2
        shift = (0, 0, 1, 1, 0, -1, -1, 0)[k]
        col = steps[0] if k < 2 else (steps[1] if k < 5 else steps[2])
        for (x, sy) in standing:
            if sy != src:
                continue
            if (x + k * 4) % 9 < (2 if k < 3 else 3 + k // 3):   # the wavelet cuts
                continue
            q = (x + shift, y)
            if 0 <= q[0] < W and q[1] < H and im.getpixel(q)[3] == 0:
                im.putpixel(q, col)
    # a few loose crests in the open water, so the surface is not only reflection
    for k, col in ((2, "SEA"), (4, "SHALLOW"), (6, "SEA")):
        y = foam_y + 1 + k
        for x in range(2, W - 2):
            if (x * 5 + k * 7) % 23 < 3 and y < H and im.getpixel((x, y))[3] == 0:
                im.putpixel((x, y), c(col))
    # the lamp on the water: the one warm road, straight down from the lamp
    lx = lamp[0]
    for k, col in ((0, "AMBER"), (1, "AMBER"), (3, "AMBER_DEEP"), (6, "AMBER_DEEP")):
        y = foam_y + 1 + k
        if y >= H:
            continue
        for x in (lx - 1, lx, lx + 1):
            if 0 <= x < W and (k < 2 or x != lx + 1):
                im.putpixel((x, y), c(col))


def build(which="bone"):
    global RAMP
    RAMP = which
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    letters = paint_letters(im)
    tower, lamp = paint_tower(im)
    outline_and_shadow(im, set(letters) | set(tower))
    paint_water(im, letters, tower, lamp)
    return im


# --- sheet ---------------------------------------------------------------------------
def sky(w, h):
    """The title's sky: the band the logo sits in."""
    im = Image.new("RGBA", (w, h), (0x13, 0x17, 0x27, 255))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w, h // 3], fill=P.rgb("INK"))
    rng = 7
    for i in range(w * h // 260):
        rng = (rng * 1103515245 + 12345) & 0x7fffffff
        x, y = rng % w, (rng >> 8) % h
        im.putpixel((x, y), P.rgb("SALT_WHITE") if rng % 5 == 0 else P.rgb("PALE_SLATE"))
    return im


def main():
    os.makedirs(REF, exist_ok=True)
    logo = build("bone")
    logo.save(os.path.join(SPRITES, "logo.png"))
    try:
        font = ImageFont.load_default(size=11)
        small = ImageFont.load_default(size=9)
    except TypeError:
        font = small = ImageFont.load_default()
    sheet = Image.new("RGBA", (1000, 700), (30, 33, 42, 255))
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "EBB logo  -  Stage 18  -  logo.png %dx%d: at 1x where the title puts it, at 4x over Abyss and Night 1, the three ramps tried, the old logo" % (W, H),
           fill=P.rgb("SALT_WHITE"), font=font)
    # 1x on the sky, as the title shows it
    band = sky(640, 96)
    band.alpha_composite(logo, (266, 18))
    sheet.alpha_composite(band, (12, 28))
    d.text((12, 126), "1x on the sky, where the title puts it (the tag goes under the reflection)", fill=P.rgb("PALE_SLATE"), font=small)
    # 4x over Abyss and Night 1
    y = 142
    for i, (bg, name) in enumerate((("ABYSS", "over Abyss"), ("NIGHT_1", "over Night 1"))):
        big = Image.new("RGBA", (W + 8, H + 8), P.rgba(bg))
        big.alpha_composite(logo, (4, 4))
        sheet.alpha_composite(zoom(big, 4), (12 + i * (W + 8) * 4 + i * 16, y))
        d.text((12 + i * (W + 8) * 4 + i * 16, y + (H + 8) * 4 + 2), name, fill=P.rgb("PALE_SLATE"), font=small)
    # the three ramps at 2x, the comparison the choice was made on
    y2 = y + (H + 8) * 4 + 18
    d.text((12, y2), "the three ramps tried for the letters, 2x: Bone ships (a nameplate's bleached paint); Stone sinks into the night; Salt turns the mark cold and takes the tide line with it",
           fill=P.rgb("PALE_SLATE"), font=small)
    y2 += 14
    for i, n in enumerate(("bone", "stone", "salt")):
        block = Image.new("RGBA", (W + 6, H + 6), P.rgba("ABYSS"))
        block.alpha_composite(build(n), (3, 3))
        sheet.alpha_composite(zoom(block, 2), (12 + i * ((W + 6) * 2 + 12), y2))
        d.text((12 + i * ((W + 6) * 2 + 12), y2 + (H + 6) * 2 + 2), n, fill=P.rgb("PALE_SLATE"), font=small)
    # the old logo as the title scaled it (88x30 at 2x), for the comparison only
    y3 = y2 + (H + 6) * 2 + 18
    old_path = os.path.join(REF, "logo_old.png")
    if os.path.exists(old_path):
        o = Image.open(old_path).convert("RGBA")
        ob = Image.new("RGBA", (o.width * 2 + 8, o.height * 2 + 8), P.rgba("ABYSS"))
        ob.alpha_composite(zoom(o, 2), (4, 4))
        sheet.alpha_composite(ob, (12, y3))
        d.text((12 + ob.width + 12, y3 + 10), "the old logo, at the 2x the title used to scale it to", fill=P.rgb("PALE_SLATE"), font=small)
    build("bone")
    sheet.save(os.path.join(REF, "logo_sheet.png"))
    print("wrote logo.png %dx%d and logo_sheet.png" % (W, H))


if __name__ == "__main__":
    main()
