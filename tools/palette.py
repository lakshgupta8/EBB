"""EBB master palette: the single source of truth for every colour in the game.

STYLE.md section 9 is the human-readable spec; this file is the machine copy.  Sprite
generators import `PAL` / `rgb()` from here, and the engine copy `src/core/palette.gd`
is written by this script, never by hand.  Keep the three in step by editing STYLE.md
first, then this table, then running:

    python tools/palette.py            (writes src/core/palette.gd and assets/reference/palette.png)
    python tools/palette.py --check    (prints the luminance and contrast report only)
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GD_OUT = os.path.join(ROOT, "src", "core", "palette.gd")
PNG_OUT = os.path.join(ROOT, "assets", "reference", "palette.png")

# (key, display name, hex, group, use).  Order is the order in STYLE.md.
COLOURS = [
    # Ink and night (structure)
    ("INK", "Ink", "#10121c", "Ink and night", "outlines, eyes, deepest shadow, UI bevel"),
    ("ABYSS", "Abyss", "#151a2a", "Ink and night", "void beyond walls, deep water base, clear colour"),
    ("NIGHT_1", "Night 1", "#1f2536", "Ink and night", "wall shadow side, Hall walls, UI panel base"),
    ("NIGHT_2", "Night 2", "#2c3447", "Ink and night", "wall faces, UI rows"),
    ("SLATE", "Slate", "#414c62", "Ink and night", "Streets wall tops, cold cloth"),
    ("WET_GREY", "Wet grey", "#5d6b82", "Ink and night", "lit wall tops, hood light, UI muted text"),
    ("PALE_SLATE", "Pale slate", "#8494a8", "Ink and night", "distant stone, UI secondary text"),
    ("SALT_WHITE", "Salt white", "#d9e3e8", "Ink and night", "wet rims, salt crust, foam body, UI primary text"),
    ("FOAM_WHITE", "Foam white", "#f4f8f6", "Ink and night", "foam crests, glass glints; the brightest pixel"),
    # Sea
    ("DEEP_SEA", "Deep sea", "#1c3048", "Sea", "deep water body"),
    ("SEA", "Sea", "#26485e", "Sea", "shallow water body, unlit glass, cold light"),
    ("SHALLOW", "Shallow", "#357083", "Sea", "shallow ripples, sea-green cast"),
    ("SEA_PALE", "Sea pale", "#5f9c9f", "Sea", "cold highlight, drowned rim, Current family"),
    ("VERDIGRIS", "Verdigris", "#6a9f8a", "Sea", "bronze in water, Brine family"),
    # Stone and sand
    ("BASALT_DARK", "Basalt dark", "#20242d", "Stone and sand", "Hall floor shadow"),
    ("BASALT", "Basalt", "#2e333e", "Stone and sand", "Hall floor base"),
    ("BASALT_LIGHT", "Basalt light", "#414756", "Stone and sand", "Hall lit stones, dais"),
    ("STONE_DARK", "Stone dark", "#3a3e47", "Stone and sand", "mortar, cobble shadow"),
    ("STONE", "Stone", "#565b64", "Stone and sand", "cobbles, Streets walls, Flats rock"),
    ("STONE_LIGHT", "Stone light", "#7c818a", "Stone and sand", "lit stone tops"),
    ("SAND_DARK", "Sand dark", "#6a675b", "Stone and sand", "wet sand, low ground"),
    ("SAND", "Sand", "#948d7c", "Stone and sand", "Flats floor base"),
    ("SAND_LIGHT", "Sand light", "#b8b09b", "Stone and sand", "dry sand ripples, hub sand"),
    ("BONE_DARK", "Bone dark", "#8f887a", "Stone and sand", "shell ribs, barnacle base"),
    ("BONE", "Bone", "#c9c1ad", "Stone and sand", "shells, bone, bleached wood"),
    ("BONE_LIGHT", "Bone light", "#e6dfcb", "Stone and sand", "shell lip"),
    # Wood, rope, iron
    ("TAR", "Tar", "#221d1b", "Wood, rope, iron", "tarred wood, plank gaps, hull"),
    ("WOOD", "Wood", "#4a3a2e", "Wood, rope, iron", "planks, gaff shaft, benches"),
    ("WOOD_LIGHT", "Wood light", "#7a5e44", "Wood, rope, iron", "lit plank faces"),
    ("ROPE", "Rope", "#a68a5f", "Wood, rope, iron", "rope, net, hemp, ledger paper edge"),
    ("WEATHERED_BROWN", "Weathered brown", "#66574a", "Wood, rope, iron", "old wood, driftwood, Orla's shawl"),
    ("IRON_DARK", "Iron dark", "#2b2f37", "Wood, rope, iron", "iron shadow, chain links"),
    ("IRON", "Iron", "#4a515c", "Wood, rope, iron", "iron body"),
    ("IRON_LIGHT", "Iron light", "#7f8894", "Wood, rope, iron", "iron rim, rivets, UI frame"),
    ("RUST", "Rust", "#7a4a30", "Wood, rope, iron", "rust patches"),
    ("RUST_LIGHT", "Rust light", "#a8683c", "Wood, rope, iron", "lit rust, harbour accents"),
    ("BRONZE_DARK", "Bronze dark", "#6b4f2a", "Wood, rope, iron", "bell shadow"),
    ("BRONZE", "Bronze", "#a07c3e", "Wood, rope, iron", "bell, lamp fittings"),
    ("BRONZE_LIGHT", "Bronze light", "#cfa85a", "Wood, rope, iron", "bell rim, only when lit"),
    # Growth
    ("MOSS_DARK", "Moss dark", "#2b3b30", "Growth", "moss in shadow, kelp edge"),
    ("MOSS", "Moss", "#476246", "Growth", "moss, Still Citizen crust"),
    ("KELP", "Kelp", "#3d5e4f", "Growth", "kelp body"),
    ("KELP_LIGHT", "Kelp light", "#6b8a5f", "Growth", "kelp lit blade"),
    # Skin
    ("SKIN_SHADE", "Skin shade", "#a8735a", "Skin", "living skin shadow"),
    ("SKIN", "Skin", "#d9a98a", "Skin", "living skin"),
    ("DROWNED_SHADE", "Drowned shade", "#7e9694", "Skin", "drowned skin shadow"),
    ("DROWNED_SKIN", "Drowned skin", "#b7c8c3", "Skin", "drowned skin"),
    # Oilskin and wool
    ("OILSKIN_DARK", "Oilskin dark", "#2a3238", "Oilskin and wool", "Tam's coat shadow, hood interior"),
    ("OILSKIN", "Oilskin", "#3f4c52", "Oilskin and wool", "Tam's coat"),
    ("OILSKIN_LIGHT", "Oilskin light", "#5c6c70", "Oilskin and wool", "coat top faces"),
    ("WOOL_DARK", "Wool dark", "#4a3f3a", "Oilskin and wool", "villager cloth shadow"),
    ("WOOL", "Wool", "#6e6058", "Oilskin and wool", "villager cloth"),
    ("WOOL_LIGHT", "Wool light", "#8f8074", "Oilskin and wool", "villager cloth lit"),
    # Warm light (rare)
    ("AMBER_DEEP", "Amber deep", "#a8582a", "Warm light", "flame base, lit bronze shadow"),
    ("AMBER", "Amber", "#dc8f3c", "Warm light", "flame, lantern glow edge, Echo family"),
    ("WARM_YELLOW", "Warm yellow", "#f2c85c", "Warm light", "flame body, lantern core edge, UI accent"),
    ("PALE_CREAM", "Pale cream", "#fbeccb", "Warm light", "flame core, lantern core, glass catch-light"),
    # Accents
    ("SALT_RED", "Salt red", "#b5452f", "Accents", "the only red: claws, danger, health, Salt family"),
    ("DEEP_VIOLET", "Deep violet", "#4d4a72", "Accents", "Deep family base: icon ground, phase glow; never on the environment"),
    ("VIOLET_LIGHT", "Violet light", "#8c84be", "Accents", "Deep family highlight: icon marks, pickup glint, Deep text at display size"),
]

GROUPS = []
for _c in COLOURS:
    if _c[3] not in GROUPS:
        GROUPS.append(_c[3])

BY_KEY = {c[0]: c for c in COLOURS}
NAME_TO_KEY = {c[1]: c[0] for c in COLOURS}

# Biome subsets (STYLE.md section 10).  Roles map to a palette key; `growth` and `extra`
# list the biome's signature accents.  Everything else a biome needs (Tam, water, Ink,
# warm light) comes from SHARED.
BIOMES = {
    "hub": {
        "title": "Marrow Rock (hub)", "cast": "warm-neutral",
        "floor_base": "SAND_LIGHT", "floor_light": "BONE", "low": "SAND", "raised": "STONE_LIGHT",
        "wall_top": "STONE_LIGHT", "wall_face": "STONE",
        "growth": ["KELP", "ROPE", "WEATHERED_BROWN"],
        "warm": "lighthouse, Tam, one window per rescued echo, Fen's lamp",
    },
    "flats": {
        "title": "The Flats", "cast": "neutral cold, open",
        "floor_base": "SAND", "floor_light": "SAND_LIGHT", "low": "SAND_DARK", "raised": "STONE",
        "wall_top": "STONE_LIGHT", "wall_face": "STONE_DARK",
        "growth": ["KELP", "BONE", "ROPE", "SALT_WHITE"],
        "warm": "Tam only (plus lit enemies, the beacon)",
    },
    "harbour": {
        "title": "The Sunken Harbour", "cast": "tarred brown-iron",
        "floor_base": "WOOD", "floor_light": "WOOD_LIGHT", "low": "TAR", "raised": "STONE",
        "wall_top": "IRON_LIGHT", "wall_face": "IRON_DARK",
        "growth": ["RUST", "ROPE", "KELP", "SAND_DARK"],
        "warm": "Tam, one hanging lamp per room",
    },
    "streets": {
        "title": "The Drowned Streets", "cast": "blue-green, damp",
        "floor_base": "STONE", "floor_light": "STONE_LIGHT", "low": "STONE_DARK", "raised": "BASALT_LIGHT",
        "wall_top": "SLATE", "wall_face": "NIGHT_2",
        "growth": ["MOSS", "MOSS_DARK", "VERDIGRIS", "SALT_WHITE"],
        "warm": "Tam, Lamplighters, relit lampposts in story moments",
    },
    "hall": {
        "title": "The Deep Hall", "cast": "deep blue, near-black",
        "floor_base": "BASALT", "floor_light": "BASALT_LIGHT", "low": "DEEP_SEA", "raised": "BASALT_LIGHT",
        "wall_top": "NIGHT_1", "wall_face": "ABYSS",
        "growth": ["KELP", "IRON", "IRON_LIGHT"],
        "warm": "Tam, 2-4 tiny candle drifts per room, the Ebb's cold core",
    },
}
BIOME_ORDER = ["hub", "flats", "harbour", "streets", "hall"]
ROLES = ["floor_base", "floor_light", "low", "raised", "wall_top", "wall_face"]

# Colours every biome may use regardless of its subset.
SHARED = ["INK", "DEEP_SEA", "SEA", "SHALLOW", "SEA_PALE", "SALT_WHITE", "FOAM_WHITE",
          "OILSKIN_DARK", "OILSKIN", "OILSKIN_LIGHT", "SKIN_SHADE", "SKIN",
          "AMBER_DEEP", "AMBER", "WARM_YELLOW", "PALE_CREAM", "SALT_RED"]

# Tidemark families (STYLE.md section 9, engine colours).
FAMILIES = {"salt": "SALT_RED", "brine": "VERDIGRIS", "current": "SEA_PALE", "deep": "DEEP_VIOLET", "echo": "AMBER"}
# The mark drawn on each family icon (STYLE.md 15): the light colour that must read on the base.
FAMILY_MARK = {"salt": "SALT_WHITE", "brine": "SALT_WHITE", "current": "FOAM_WHITE", "deep": "VIOLET_LIGHT", "echo": "PALE_CREAM"}

# Engine colours.
NIGHT_TINT_RUN = (0.92, 0.95, 1.0)
NIGHT_TINT_HUB = (0.96, 0.97, 1.0)
OLD_NIGHT_TINT = (0.6, 0.68, 0.86)   # the placeholder build's run tint, for the tint check only
CLEAR_COLOUR = "ABYSS"

UI_TEXT = {"primary": "SALT_WHITE", "secondary": "PALE_SLATE", "muted": "WET_GREY",
           "accent": "WARM_YELLOW", "danger": "SALT_RED"}
UI_FACES = {"panel": "NIGHT_1", "row": "NIGHT_2", "hover": "SLATE"}


# --- helpers -----------------------------------------------------------------

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb(key):
    """RGB tuple for a palette key ("SAND") or display name ("Sand")."""
    key = NAME_TO_KEY.get(key, key)
    return hex_to_rgb(BY_KEY[key][2])


def rgba(key, a=255):
    return rgb(key) + (a,)


def floats(key):
    return tuple(round(v / 255.0, 4) for v in rgb(key))


def _lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def luminance(key_or_rgb):
    r, g, b = rgb(key_or_rgb) if isinstance(key_or_rgb, str) else key_or_rgb
    return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def tinted(key, tint):
    r, g, b = rgb(key)
    return (int(round(r * tint[0])), int(round(g * tint[1])), int(round(b * tint[2])))


# Generator-compatible dict: key -> RGB.  Generators build their own one-letter maps on
# top of this ("k": PAL["INK"]) so the letters stay local to each sheet.
PAL = {c[0]: hex_to_rgb(c[2]) for c in COLOURS}


# --- report -------------------------------------------------------------------

def check():
    print("%-16s %-8s %6s   %s" % ("colour", "hex", "lum", "group"))
    for k, name, hx, group, use in COLOURS:
        print("%-16s %-8s %6.3f   %s" % (name, hx, luminance(k), group))
    print()
    print("Biome floor bands (spec: floor tiles within a 15 % luminance band, walls darker):")
    for b in BIOME_ORDER:
        d = BIOMES[b]
        lf = [luminance(d[r]) for r in ("floor_base", "floor_light")]
        print("  %-24s floor %.3f-%.3f  low %.3f  raised %.3f  wall top %.3f  wall face %.3f" % (
            d["title"], min(lf), max(lf), luminance(d["low"]), luminance(d["raised"]),
            luminance(d["wall_top"]), luminance(d["wall_face"])))
    print()
    print("UI text on panel faces (WCAG ratio; >= 4.5 pass, >= 3 marginal, < 3 fail):")
    for face_name, face in UI_FACES.items():
        for role, key in list(UI_TEXT.items()) + [("fam " + f, k) for f, k in FAMILIES.items()] + [("deep text", "VIOLET_LIGHT")]:
            r = contrast(key, face)
            verdict = "pass" if r >= 4.5 else ("marginal" if r >= 3 else "FAIL")
            print("  %-6s %-12s %-14s %5.2f  %s" % (face_name, role, BY_KEY[key][1], r, verdict))
    print()
    print("Ink outline against biome floors (>= 3 keeps the outline law honest):")
    for b in BIOME_ORDER:
        d = BIOMES[b]
        print("  %-24s base %.2f  light %.2f  low %.2f" % (
            d["title"], contrast("INK", d["floor_base"]), contrast("INK", d["floor_light"]), contrast("INK", d["low"])))


# --- engine copy --------------------------------------------------------------

def write_gd():
    lines = [
        "class_name Palette",
        "extends RefCounted",
        "## GENERATED by tools/palette.py from STYLE.md section 9. Do not edit by hand.",
        "## Every colour the engine picks (lights, particles, UI, tints) comes from here.",
        "",
    ]
    for group in GROUPS:
        lines.append("# %s" % group)
        for k, name, hx, g, use in COLOURS:
            if g != group:
                continue
            f = floats(k)
            lines.append("const %s := Color(%.4f, %.4f, %.4f)  # %s %s" % (k, f[0], f[1], f[2], name, hx))
        lines.append("")
    lines.append("## Night CanvasModulate: near-neutral, because art is authored pre-tinted (STYLE.md 0.2).")
    lines.append("const NIGHT_TINT_RUN := Color(%.2f, %.2f, %.2f)" % NIGHT_TINT_RUN)
    lines.append("const NIGHT_TINT_HUB := Color(%.2f, %.2f, %.2f)" % NIGHT_TINT_HUB)
    lines.append("const CLEAR := %s" % CLEAR_COLOUR)
    lines.append("")
    lines.append("## Tidemark families (STYLE.md 9, engine colours).")
    lines.append("const FAMILY := {")
    for fam, key in FAMILIES.items():
        lines.append('\t"%s": %s,' % (fam, key))
    lines.append("}")
    lines.append("## The light mark drawn on each family icon (STYLE.md 15).")
    lines.append("const FAMILY_MARK := {")
    for fam, key in FAMILY_MARK.items():
        lines.append('\t"%s": %s,' % (fam, key))
    lines.append("}")
    lines.append("")
    lines.append("## UI text roles (STYLE.md 15).")
    lines.append("const TEXT := {")
    for role, key in UI_TEXT.items():
        lines.append('\t"%s": %s,' % (role, key))
    lines.append("}")
    lines.append("")
    lines.append("## Biome casts (STYLE.md 10): floor_base, floor_light, low, raised, wall_top, wall_face.")
    lines.append("const BIOME := {")
    for b in BIOME_ORDER:
        d = BIOMES[b]
        parts = ", ".join('"%s": %s' % (r, d[r]) for r in ROLES)
        lines.append('\t"%s": {%s},' % (b, parts))
    lines.append("}")
    lines.append("")
    lines.append("## Every colour by display name, for tools and debug overlays.")
    lines.append("const BY_NAME := {")
    for k, name, hx, g, use in COLOURS:
        lines.append('\t"%s": %s,' % (name, k))
    lines.append("}")
    lines.append("")
    with open(GD_OUT, "w", newline="\n") as f:
        f.write("\n".join(lines))
    print("wrote", os.path.relpath(GD_OUT, ROOT))


# --- reference sheet ------------------------------------------------------------

def write_png():
    from PIL import Image, ImageDraw, ImageFont

    W = 1120
    paper = (30, 33, 42)
    im = Image.new("RGB", (W, 1560), paper)
    d = ImageDraw.Draw(im)
    try:
        font = ImageFont.load_default(size=11)
        big = ImageFont.load_default(size=16)
        small = ImageFont.load_default(size=9)
    except TypeError:  # very old Pillow
        font = big = small = ImageFont.load_default()
    white = rgb("SALT_WHITE")
    grey = rgb("PALE_SLATE")

    def text(x, y, s, f=font, col=white):
        d.text((x, y), s, fill=col, font=f)

    def swatch(x, y, key, w=56, h=30, label=True, tint=None, caption=None):
        col = tinted(key, tint) if tint else rgb(key)
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=col)
        if label:
            name, hx = BY_KEY[key][1], BY_KEY[key][2]
            text(x, y + h + 2, name, small)
            text(x, y + h + 12, "%s %.2f" % (hx, luminance(key)), small, grey)
        if caption:
            text(x, y + h + 2, caption, small)

    y = 12
    text(12, y, "EBB master palette  -  STYLE.md section 9  -  %d colours, authored pre-tinted for night" % len(COLOURS), big)
    y += 24
    text(12, y, "Each swatch: name, hex, relative luminance. Engine copy: src/core/palette.gd. Generators: tools/palette.py.", font, grey)
    y += 26

    # A. groups
    for group in GROUPS:
        keys = [c[0] for c in COLOURS if c[3] == group]
        text(12, y, group.upper(), font, grey)
        y += 14
        x = 12
        for k in keys:
            swatch(x, y, k)
            x += 72
        y += 30 + 30

    # B. luminance ladder
    text(12, y, "LUMINANCE LADDER (all colours, darkest to brightest). Floor bands per biome drawn below it.", font, grey)
    y += 14
    order = sorted(COLOURS, key=lambda c: luminance(c[0]))
    lw = (W - 24) // len(order)
    for i, c in enumerate(order):
        d.rectangle([12 + i * lw, y, 12 + (i + 1) * lw - 1, y + 28], fill=rgb(c[0]))
    y += 30
    # band markers: position = luminance on a sqrt scale for legibility
    band_w = W - 24
    for j, b in enumerate(BIOME_ORDER):
        bd = BIOMES[b]
        lo = min(luminance(bd["floor_base"]), luminance(bd["floor_light"]))
        hi = max(luminance(bd["floor_base"]), luminance(bd["floor_light"]))
        x0 = 12 + int((lo ** 0.5) * band_w)
        x1 = 12 + int((hi ** 0.5) * band_w)
        yy = y + j * 12
        d.rectangle([x0, yy + 2, max(x1, x0 + 2), yy + 8], fill=rgb(bd["floor_base"]), outline=white)
        text(x1 + 6, yy, "%s floor  %.2f-%.2f" % (bd["title"], lo, hi), small)
    d.line([12, y + 62, W - 12, y + 62], fill=grey)
    text(12, y + 64, "0.00", small, grey)
    text(W - 40, y + 64, "1.00 (sqrt scale)", small, grey)
    y += 84

    # C. biome strips
    text(12, y, "BIOME SUBSETS (STYLE.md section 10). Roles left to right: floor base, floor light, low ground, raised, wall top, wall face | signature accents.", font, grey)
    y += 16
    for b in BIOME_ORDER:
        bd = BIOMES[b]
        text(12, y, "%s  -  %s" % (bd["title"], bd["cast"]), font)
        text(400, y, "warm allowed: " + bd["warm"], small, grey)
        y += 14
        x = 12
        for r in ROLES:
            swatch(x, y, bd[r], w=48, h=24, label=False, caption=r.replace("_", " "))
            text(x, y + 36, BY_KEY[bd[r]][1], small, grey)
            x += 54
        x += 12
        d.line([x - 6, y, x - 6, y + 24], fill=grey)
        for k in bd["growth"]:
            swatch(x, y, k, w=40, h=24, label=False, caption=BY_KEY[k][1])
            x += 46
        # a 3-tile floor mock: base with light ripple and a low tile, Ink outline test
        mx = 720
        d.rectangle([mx, y, mx + 95, y + 47], fill=rgb(bd["floor_base"]))
        d.rectangle([mx + 8, y + 6, mx + 20, y + 8], fill=rgb(bd["floor_light"]))
        d.rectangle([mx + 40, y + 20, mx + 60, y + 24], fill=rgb(bd["floor_light"]))
        d.rectangle([mx + 96, y, mx + 143, y + 47], fill=rgb(bd["low"]))
        d.rectangle([mx + 144, y, mx + 191, y + 47], fill=rgb(bd["wall_face"]))
        d.rectangle([mx + 144, y, mx + 191, y + 15], fill=rgb(bd["wall_top"]))
        # figure: outline + oilskin + skin + lantern
        fx, fy = mx + 24, y + 12
        d.rectangle([fx, fy, fx + 11, fy + 27], fill=rgb("INK"))
        d.rectangle([fx + 1, fy + 1, fx + 10, fy + 8], fill=rgb("SKIN"))
        d.rectangle([fx + 1, fy + 9, fx + 10, fy + 22], fill=rgb("OILSKIN"))
        d.rectangle([fx + 1, fy + 23, fx + 10, fy + 26], fill=rgb("OILSKIN_DARK"))
        d.rectangle([fx + 12, fy + 12, fx + 15, fy + 16], fill=rgb("WARM_YELLOW"))
        d.rectangle([fx + 13, fy + 13, fx + 14, fy + 15], fill=rgb("PALE_CREAM"))
        text(mx + 200, y + 2, "floor / low / wall + Tam mock", small, grey)
        text(mx + 200, y + 14, "Ink vs floor %.1f : 1" % contrast("INK", bd["floor_base"]), small, grey)
        text(mx + 200, y + 26, "Ink vs low   %.1f : 1" % contrast("INK", bd["low"]), small, grey)
        y += 62

    # D. night tint check
    y += 6
    text(12, y, "NIGHT TINT CHECK. Left: authored colour. Middle: under the new near-neutral tint %s. Right: under the old tint %s (why we author pre-tinted)." % (NIGHT_TINT_RUN, OLD_NIGHT_TINT), font, grey)
    y += 16
    samples = ["SAND", "SAND_LIGHT", "STONE", "BASALT", "WOOD", "MOSS", "SKIN", "DROWNED_SKIN", "OILSKIN", "AMBER", "PALE_CREAM", "SALT_WHITE", "SALT_RED", "DEEP_VIOLET", "SEA"]
    x = 12
    for k in samples:
        d.rectangle([x, y, x + 23, y + 23], fill=rgb(k))
        d.rectangle([x + 24, y, x + 47, y + 23], fill=tinted(k, NIGHT_TINT_RUN))
        d.rectangle([x + 48, y, x + 71, y + 23], fill=tinted(k, OLD_NIGHT_TINT))
        text(x, y + 26, BY_KEY[k][1], small)
        x += 74
    y += 44

    # E. UI text and family contrast
    text(12, y, "UI TEXT AND FAMILY COLOURS ON PANEL FACES (WCAG ratio; pass >= 4.5, marginal >= 3, fail < 3)", font, grey)
    y += 16
    x = 12
    for face_name, face in UI_FACES.items():
        d.rectangle([x, y, x + 330, y + 136], fill=rgb(face))
        text(x + 6, y + 4, face_name + " face  " + BY_KEY[face][1], small, grey)
        yy = y + 18
        entries = list(UI_TEXT.items()) + [("fam " + f, k) for f, k in FAMILIES.items()] + [("deep text", "VIOLET_LIGHT")]
        for i, (role, key) in enumerate(entries):
            cx = x + 6 + (i // 6) * 165
            cy = yy + (i % 6) * 19
            r = contrast(key, face)
            verdict = "pass" if r >= 4.5 else ("marginal" if r >= 3 else "FAIL")
            text(cx, cy, "%s  %s" % (role, BY_KEY[key][1]), small, rgb(key))
            text(cx, cy + 9, "%.1f:1 %s" % (r, verdict), small, rgb(key))
        x += 340
    y += 148

    # F. family icon bases: mark colour on base colour, base on the panel face
    text(12, y, "FAMILY ICON BASES: mark colour on base colour, then the base on Night 1 (icon vs panel).", font, grey)
    y += 16
    x = 12
    for fam, base in FAMILIES.items():
        mark = FAMILY_MARK[fam]
        d.rectangle([x, y, x + 59, y + 59], fill=rgb("NIGHT_1"))
        d.rectangle([x + 8, y + 8, x + 51, y + 51], fill=rgb(base))
        d.rectangle([x + 20, y + 20, x + 39, y + 39], fill=rgb(mark))
        text(x, y + 62, "%s  mark %.1f:1  base %.1f:1" % (fam, contrast(mark, base), contrast(base, "NIGHT_1")), small)
        x += 200
    y += 96

    im = im.crop((0, 0, W, y + 8))
    os.makedirs(os.path.dirname(PNG_OUT), exist_ok=True)
    im.save(PNG_OUT)
    print("wrote", os.path.relpath(PNG_OUT, ROOT), im.size)


if __name__ == "__main__":
    if "--check" in sys.argv:
        check()
    else:
        check()
        write_gd()
        write_png()
