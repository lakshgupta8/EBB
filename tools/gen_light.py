"""Stage 11: lighting.  The light textures and the check that the lantern pool stays inside
the palette (STYLE.md 11).

    assets/sprites/glow.png        48x48   PointLight2D texture: two-zone falloff, a flat 70 %
                                           core to 40 % of the radius, then a steep fall to zero.
                                           Pools read as lantern light with an edge, not fog.
    assets/sprites/glow_small.png  24x24   the same profile for candles, eyes and pickups
    assets/sprites/haze.png        128x128 a soft sprite (mist, the door and altar glow sprites,
                                           the title): a wide smooth falloff
    assets/reference/anchors/light_sheet.png   the three profiles, and the lantern over the four
                                           floors at the chosen energy under the run tint, with
                                           the brightest floor value against Bone light

Run:  python tools/gen_light.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
import gen_anchors as GA  # noqa: E402
from gen_anchors import zoom  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
REF = os.path.join(P.ROOT, "assets", "reference", "anchors")

CORE = 0.4        # of the radius
CORE_ALPHA = 0.7  # the flat core (0.4 read as fog on dark floors: cobbles and basalt got no pool)
LANTERN_SCALE = 3.2
LANTERN_ENERGY = 0.7
WARM = tuple(int(round(a + (b - a) * 0.6)) for a, b in zip(P.rgb("WARM_YELLOW"), P.rgb("PALE_CREAM")))


def two_zone(d):
    if d >= 1.0:
        return 0.0
    if d <= CORE:
        return CORE_ALPHA
    t = (d - CORE) / (1.0 - CORE)
    return CORE_ALPHA * (1.0 - t) ** 1.5


def glow(size):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = im.load()
    r = size / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - r, y + 0.5 - r) / r
            a = two_zone(d)
            if a > 0:
                px[x, y] = (255, 255, 255, int(round(255 * a)))
    return im


def haze(size=128):
    """A soft sprite: a wide smooth falloff. (Quantised steps banded into rings at the
    title's scale.)"""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = im.load()
    r = size / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - r, y + 0.5 - r) / r
            if d >= 1.0:
                continue
            a = (1.0 - d) ** 2
            if a > 0:
                px[x, y] = (255, 255, 255, int(round(255 * a)))
    return im


def lit(base, cx, cy, radius, colour, energy, tint):
    """Godot's additive 2D light on a pre-tinted item: base * tint * (1 + colour * energy * a)."""
    out = base.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a0 = px[x, y]
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / radius
            f = two_zone(d) * energy
            px[x, y] = (
                min(255, int(r * tint[0] * (1 + colour[0] / 255.0 * f))),
                min(255, int(g * tint[1] * (1 + colour[1] / 255.0 * f))),
                min(255, int(b * tint[2] * (1 + colour[2] / 255.0 * f))), a0)
    return out


def main():
    os.makedirs(REF, exist_ok=True)
    g48 = glow(48)
    g24 = glow(24)
    hz = haze()
    g48.save(os.path.join(SPRITES, "glow.png"))
    g24.save(os.path.join(SPRITES, "glow_small.png"))
    hz.save(os.path.join(SPRITES, "haze.png"))

    tiles = Image.open(os.path.join(SPRITES, "tiles.png")).convert("RGBA")
    try:
        font = ImageFont.load_default(size=11)
        small = ImageFont.load_default(size=9)
    except TypeError:
        font = small = ImageFont.load_default()
    W = 1180
    sheet = Image.new("RGBA", (W, 900), (30, 33, 42, 255))
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "EBB lighting  -  Stage 11  -  light textures and the lantern pool over the floors under the run tint %s" % (P.NIGHT_TINT_RUN,),
           fill=P.rgb("SALT_WHITE"), font=font)
    y = 30
    d.text((12, y), "glow.png 48 (two-zone, 4x), glow_small.png 24 (4x), haze.png 128 (1x), each over Night 1; and the alpha profile of glow.png", fill=P.rgb("PALE_SLATE"), font=small)
    y += 14
    x = 12
    for im, z in ((g48, 4), (g24, 4), (hz, 1)):
        bg = Image.new("RGBA", im.size, P.rgba("NIGHT_1"))
        bg.alpha_composite(im)
        sheet.alpha_composite(zoom(bg, z), (x, y))
        x += im.width * z + 12
    # profile graph
    gx, gy, gw, gh = x + 12, y, 200, 100
    d.rectangle([gx, gy, gx + gw, gy + gh], outline=P.rgb("PALE_SLATE"))
    for i in range(gw):
        a = two_zone(i / gw)
        d.point((gx + i, gy + gh - int(a * gh)), fill=P.rgb("WARM_YELLOW"))
    d.text((gx, gy + gh + 2), "alpha vs distance: flat %.1f to 40 %%, then (1-t)^1.5 to 0" % CORE_ALPHA, fill=P.rgb("PALE_SLATE"), font=small)
    y += 192 + 16

    # the lantern over the four floors
    radius = 24 * LANTERN_SCALE
    d.text((12, y), "Tam's lantern: scale %.1f (pool %d px, core %d px), energy %.2f, colour %s (Warm yellow 60 %% toward Pale cream), over Flats sand, cobbles, basalt, hub sand  (2x)"
           % (LANTERN_SCALE, radius * 2, radius * 2 * CORE, LANTERN_ENERGY, WARM), fill=P.rgb("PALE_SLATE"), font=small)
    y += 14
    bone = P.luminance(P.rgb("BONE_LIGHT"))
    x = 12
    report = []
    for name, idx, idx2 in (("sand", 0, 1), ("cobble", 14, 15), ("basalt", 20, 21), ("hub sand", 32, 33)):
        floor = Image.new("RGBA", (176, 176), (0, 0, 0, 0))
        for ty in range(11):
            for tx in range(11):
                i = idx2 if (tx * 7 + ty * 13) % 5 == 0 else idx
                floor.alpha_composite(tiles.crop((i * 16, 0, i * 16 + 16, 16)), (tx * 16, ty * 16))
        out = lit(floor, 88, 88, radius, WARM, LANTERN_ENERGY, P.NIGHT_TINT_RUN)
        tam = GA.build_assets()["tam_a"] if name == "sand" else None
        if tam is not None:
            out.alpha_composite(tam, (76, 66))
        # brightest floor pixel inside the core (sample the plain floor before Tam is drawn)
        plain = lit(floor, 88, 88, radius, WARM, LANTERN_ENERGY, P.NIGHT_TINT_RUN)
        px = plain.load()
        ls = sorted(P.luminance(px[xx, yy][:3]) for yy in range(176) for xx in range(176) if math.hypot(xx - 88, yy - 88) < radius * CORE)
        med = ls[len(ls) // 2]   # the floor body; 1 px salt grains and Bone ripples sit above it by design
        mx = ls[-1]
        report.append((name, med, mx))
        sheet.alpha_composite(zoom(out, 2), (x, y))
        d.text((x, y + 176 * 2 + 2), "%s: floor body in the core L=%.3f, brightest accent L=%.3f (Bone light L=%.3f) %s" % (name, med, mx, bone, "OK" if med <= bone else "TOO BRIGHT"),
               fill=P.rgb("PALE_SLATE"), font=small)
        x += 176 * 2 + 12
        if x + 352 > W:
            x = 12
            y += 176 * 2 + 30
    y += 176 * 2 + 40
    sheet = sheet.crop((0, 0, W, y))
    sheet.convert("RGB").save(os.path.join(REF, "light_sheet.png"))
    for name, med, mx in report:
        print("%-9s floor body in the lantern core L=%.3f, brightest accent L=%.3f  (Bone light L=%.3f)  %s" % (name, med, mx, bone, "ok" if med <= bone else "TOO BRIGHT"))
    print("wrote glow.png, glow_small.png, haze.png, light_sheet.png")


if __name__ == "__main__":
    main()
