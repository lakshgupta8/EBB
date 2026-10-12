"""Map Stage 11h: the Reef's own drowned (docs/BIOME5_CONCEPT.md, "Its people").

Three enemies on the production layout of art Stage 13 (STYLE.md 17), 16 x 24x24: idle 0-3,
walk 4-7, windup 8-9, attack 10-11, hurt 12, death 13-15. Feet on row 21. None of them is a
person, so none wears the drowned's wet crown; each has an elite costume that rides its top
(STYLE.md 1: an elite is a costume, never a scale).

- The Coral Crab: a crab that grew a dead coral head for a shell. Idle is the head alone,
  legs tucked: it is hiding. Walk is the head up on Bone legs; the claws are Salt red, the one
  red the style allows on a body. Living tips (Salt red, Violet light) where the water reached it.
- The Reef Ray: seen from above, a flat Oilskin diamond with pale spots and a Slate tail with
  a Bone barb. It does not touch the floor: its shadow sits apart under it. Idle and walk are
  the wings rippling; windup curls the wingtips; attack is the glide, flattened and stretched.
- The Polyp Swarm: a clutch of bleached stalks on a living-coral foot, each crowned with
  Violet tentacles. Walk is the clutch sinking into its coral and rising (it moves by going
  under); windup opens the crowns; attack puffs Sea pale spores.

Map Stage 11i adds the Reef's named elite:
- The Reefwarden: one of the divers who kept Saltmere's sea wall, still in his suit. A Bronze
  helmet crusted with coral, a Sea pale porthole with the drowned face behind it, a Slate suit
  with a belt of lead weights, lead boots (Iron dark), and a mason's maul (a Stone head on a Wood
  haft). He is a person, so he wears the wet crown and goes down like one. Windup raises the
  maul; attack brings it down on the floor (the slam, and the surge he sends out from it).

Writes assets/sprites/coral_crab.png, reef_ray.png, polyp_swarm.png, reefwarden.png, their
_elite sheets, polyp_spore.png (6x6), surge.png (16x16), and assets/reference/maps/
s11h_reef_enemies.png and s11i_reefwarden.png.

Run:  python tools/gen_reef_enemies.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
from gen_anchors import grid, zoom  # noqa: E402
from gen_characters import stack, cell  # noqa: E402
from gen_enemies import shift  # noqa: E402
from gen_enemies_b import outline, rgba, strip, LEGS, person_death  # noqa: E402
from gen_characters import part, recolour  # noqa: E402
import gen_enemies  # noqa: E402
import gen_rim  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
REF = os.path.join(P.ROOT, "assets", "reference", "maps")
CELL = 24


def put(im, key, *pts):
    px = im.load()
    for x, y in pts:
        if 0 <= x < im.width and 0 <= y < im.height:
            px[x, y] = rgba(key)


def ellipse(im, cx, cy, rx, ry, key):
    px = im.load()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if 0 <= x < im.width and 0 <= y < im.height:
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    px[x, y] = rgba(key)


def shade_lower(im, key, frac=0.6):
    """Every opaque pixel in the lower part of each column takes the shade colour."""
    px = im.load()
    for x in range(im.width):
        ys = [y for y in range(im.height) if px[x, y][3]]
        if not ys:
            continue
        top, bot = min(ys), max(ys)
        cut = top + int((bot - top + 1) * frac)
        for y in ys:
            if y >= cut:
                px[x, y] = rgba(key)


# =============================================================================
# THE CORAL CRAB.  A head of dead coral (Drowned skin, Drowned shade below, Pale slate
# knuckles) on a crab: Bone legs, Salt red claws, two Sea pale eyes on stalks.
# =============================================================================
def crab_head(dy=0, tips=True):
    im = cell()
    ellipse(im, 12, 13 + dy, 7.5, 5.5, "DROWNED_SKIN")
    shade_lower(im, "DROWNED_SHADE", 0.62)
    # the brain-coral grooves and knuckles
    put(im, "DROWNED_SHADE", (8, 11 + dy), (9, 12 + dy), (12, 10 + dy), (13, 11 + dy), (16, 12 + dy), (15, 13 + dy), (10, 14 + dy))
    put(im, "PALE_SLATE", (10, 9 + dy), (11, 9 + dy), (14, 9 + dy), (7, 12 + dy), (17, 11 + dy), (12, 12 + dy))
    if tips:
        # living tips where the water reached it
        put(im, "SALT_RED", (9, 8 + dy), (15, 8 + dy), (18, 10 + dy))
        put(im, "VIOLET_LIGHT", (12, 8 + dy), (6, 11 + dy))
    return im


def crab_legs(phase=0, out=True, dy=0):
    im = cell()
    if not out:
        put(im, "BONE_DARK", (6, 19 + dy), (17, 19 + dy))
        return im
    for i, x in enumerate((5, 8, 15, 18)):
        lift = 1 if (i + phase) % 2 else 0
        put(im, "BONE", (x, 18 + dy - lift), (x + (-1 if x < 12 else 1), 19 + dy - lift))
        put(im, "BONE_DARK", (x + (-1 if x < 12 else 1), 20 + dy - lift), (x + (-2 if x < 12 else 2), 21 - lift))
    return im


def crab_claws(open_=0, reach=0, dy=0):
    """Two Salt red claws at the front (the facing side is +x)."""
    im = cell()
    for k, (bx, by) in enumerate(((17, 15), (19, 13))):
        x, y = bx + reach, by + dy - (open_ if k else 0)
        put(im, "SALT_RED", (x, y), (x + 1, y), (x + 2, y), (x + 1, y + 1), (x + 2, y + 1))
        put(im, "BONE", (x + 2, y - 1 - open_))
        if open_:
            put(im, "SALT_RED", (x + 3, y - 1 - open_))
        put(im, "AMBER_DEEP", (x, y + 1))
    return im


def crab_eyes(dy=0, up=1):
    im = cell()
    put(im, "BONE", (14, 8 + dy - up), (16, 8 + dy - up))
    put(im, "SEA_PALE", (14, 7 + dy - up), (16, 7 + dy - up))
    return im


def crab_frame(state="hide", phase=0, dy=0, open_=0, reach=0, tips=True, flat=False, back=False):
    if state == "hide":
        im = stack((crab_legs(out=False), 0, 0), (crab_head(dy=4 + dy, tips=tips), 0, 0))
    else:
        layers = [(crab_legs(phase, dy=dy), 0, 0), (crab_head(dy=dy, tips=tips), 0, 0), (crab_eyes(dy), 0, 0)]
        if state != "dead":
            layers.append((crab_claws(open_, reach, dy), 0, 0))
        im = stack(*layers)
    if back:
        im = im.transpose(Image.FLIP_TOP_BOTTOM)
        bb = im.getbbox()
        im = shift(im, 0, 21 - bb[3] + 1)
    if flat:
        bb = im.getbbox()
        piece = im.crop(bb).resize((bb[2] - bb[0], max(3, (bb[3] - bb[1]) * 2 // 3)), Image.NEAREST)
        im = cell()
        im.alpha_composite(piece, (bb[0], 22 - piece.height))
    return outline(im)


def crab_frames():
    f = crab_frame
    # idle: hidden, the head only; a breath and a living tip flickering
    idle = [f(), f(dy=-1), f(), f(tips=False)]
    # walk: up on its legs, scuttling
    walk = [f("walk", 0), f("walk", 1, dy=-1), f("walk", 0), f("walk", 1, dy=-1)]
    # windup: rears with the claws open, then holds them high
    windup = [f("walk", 0, dy=-1, open_=1), f("walk", 0, dy=-2, open_=2)]
    # attack: the pinch, lunged forward, then the follow-through
    attack = [f("walk", 1, open_=0, reach=2), shift(f("walk", 0, open_=0, reach=1), 1, 0)]
    hurt = [shift(f("walk", 0, dy=1), -1, 0)]
    # death: it slumps, the head cracks down flat, and ends tipped on its back, legs up
    death = [f("walk", 0, dy=1), f("dead", flat=True), f("dead", back=True)]
    return idle + walk + windup + attack + hurt + death


# =============================================================================
# THE REEF RAY.  From above: an Oilskin diamond, darker at the wing edges, Oilskin light
# spots, a Pale slate belly rim on the trailing side, a Slate tail with a Bone barb.
# Flies a hand above the floor (no feet; the shadow is in the scene, apart).
# =============================================================================
def ray_body(cy=12, wing=0, stretch=0, curl=0):
    im = cell()
    px = im.load()
    # a diamond: half-width falls off from the shoulders (row cy) to nose and tail
    nose, tailroot = cy - 6, cy + 5
    for y in range(nose, tailroot + 1):
        t = (y - nose) / float(cy - nose) if y <= cy else 1.0 - (y - cy) / float(tailroot - cy + 1)
        hw = int(round((8 + stretch) * max(0.0, t))) + (1 if y == cy else 0)
        if y == cy or y == cy - 1:
            hw += wing
        for x in range(12 - hw, 12 + hw + 1):
            if 0 <= x < CELL and 0 <= y < CELL:
                edge = abs(x - 12) >= hw - 1
                px[x, y] = rgba("OILSKIN_DARK" if edge else "OILSKIN")
    # curled wingtips (the windup): the outermost pixels lift a row
    if curl:
        for sx in (-1, 1):
            x = 12 + sx * (8 + stretch + wing)
            put(im, "OILSKIN_DARK", (x, cy - 1 - curl), (x - sx, cy - 1 - curl))
    # the belly rim on the trailing side
    for y in range(cy + 1, tailroot + 1):
        t = 1.0 - (y - cy) / float(tailroot - cy + 1)
        hw = int(round((8 + stretch) * t))
        put(im, "PALE_SLATE", (12 - hw, y), (12 + hw, y))
    # spots, eyes
    put(im, "OILSKIN_LIGHT", (9, cy - 1), (15, cy - 1), (12, cy + 1), (7, cy), (17, cy))
    put(im, "SEA_PALE", (11, nose + 2), (13, nose + 2))
    # the tail and its barb
    for y in range(tailroot + 1, min(23, tailroot + 6)):
        put(im, "SLATE", (12, y))
    put(im, "BONE", (12, min(22, tailroot + 6)), (11, min(22, tailroot + 5)))
    return im


def ray_frame(cy=12, wing=0, stretch=0, curl=0, hurt=False, sunk=0, fade=False):
    im = ray_body(cy + sunk, wing, stretch, curl)
    if hurt:
        put(im, "SALT_WHITE", (12, cy))
    if fade:
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if a and (x + y) % 2:
                    px[x, y] = (r, g, b, 0)
    return outline(im)


def ray_frames():
    f = ray_frame
    idle = [f(wing=0), f(wing=1, cy=11), f(wing=0), f(wing=-1, cy=13)]
    walk = [f(wing=1), f(wing=0, cy=11), f(wing=-1), f(wing=0, cy=13)]
    windup = [f(curl=1, cy=13), f(curl=2, cy=14, wing=-1)]
    attack = [f(stretch=2, wing=1, cy=11), f(stretch=1, cy=12)]
    hurt = [shift(f(hurt=True, wing=-1), -1, 1)]
    death = [f(wing=-1, cy=14), f(wing=-2, cy=15, sunk=1), f(wing=-2, cy=15, sunk=2, fade=True)]
    return idle + walk + windup + attack + hurt + death


# =============================================================================
# THE POLYP SWARM.  A living-coral foot (Salt red, Amber deep), stalks of bleached Drowned
# skin, crowns of Violet light tentacles round a Deep violet mouth.
# =============================================================================
STALKS = [(6, -2, -1), (9, 2, 0), (13, -1, 1), (16, 1, 1)]   # x, extra height, its own lean: a clutch, not a row


def polyp_frame(h=6, open_=0, sink=0, puff=False, wilt=0, hurt=False, sway=0):
    im = cell()
    base_y = 20
    # the living-coral foot
    ellipse(im, 12, base_y + 0.5, 7.5, 2.0, "SALT_RED")
    put(im, "AMBER_DEEP", (7, 21), (10, 21), (14, 21), (17, 21), (12, 20))
    put(im, "VIOLET_LIGHT", (6, 20), (18, 20))
    for i, (x, extra, own) in enumerate(STALKS):
        top = base_y - max(0, h + extra - sink)
        if top >= base_y:
            continue
        lean = own + (sway if i % 2 else -sway) + (wilt * (1 if x > 12 else -1) if wilt else 0)
        for y in range(top, base_y):
            k = (base_y - y) / float(max(1, base_y - top))
            xx = x + int(round(lean * k))
            put(im, "DROWNED_SKIN" if y < base_y - 1 else "DROWNED_SHADE", (xx, y))
            if i != 0 and (y - top) > 1:   # the first is the thin one; the rest thicken toward the foot
                put(im, "DROWNED_SHADE", (xx + 1, y))
            if (y + i) % 4 == 0:
                put(im, "PALE_SLATE", (xx, y))
        cx = x + lean
        if wilt >= 2:
            put(im, "DEEP_VIOLET", (cx, top), (cx + 1, top))
            continue
        # the crown: a mouth and tentacles, wider as it opens
        put(im, "DEEP_VIOLET", (cx, top - 1), (cx + 1, top - 1))
        spread = 1 + open_
        put(im, "VIOLET_LIGHT", (cx - spread, top - 1 - (1 if open_ else 0)), (cx + 1 + spread, top - 1 - (1 if open_ else 0)),
            (cx, top - 2 - open_), (cx + 1, top - 2 - open_))
        if open_ >= 2:
            put(im, "VIOLET_LIGHT", (cx - spread, top - 3), (cx + 1 + spread, top - 3))
    if puff:
        for (x, y) in ((5, 7), (9, 5), (14, 4), (18, 6), (11, 8), (16, 9)):
            put(im, "SEA_PALE", (x, y))
        put(im, "FOAM_WHITE", (9, 4), (14, 3))
    if hurt:
        put(im, "SALT_WHITE", (11, 15), (14, 14))
    return outline(im)


def polyp_frames():
    f = polyp_frame
    idle = [f(), f(sway=1), f(h=7), f(sway=-1)]
    # walk: it goes under into its coral and comes up again
    walk = [f(sink=2), f(sink=5), f(sink=8), f(sink=4)]
    windup = [f(open_=1, h=7), f(open_=2, h=8)]
    attack = [f(open_=2, h=8, puff=True), f(open_=1, h=7)]
    hurt = [f(hurt=True, sway=1, h=5)]
    death = [f(wilt=1, h=5), f(wilt=2, h=3), f(wilt=2, h=1, sink=1)]
    return idle + walk + windup + attack + hurt + death


def spore():
    im = Image.new("RGBA", (6, 6), (0, 0, 0, 0))
    for (x, y) in ((2, 1), (3, 1), (1, 2), (4, 2), (1, 3), (4, 3), (2, 4), (3, 4)):
        put(im, "VIOLET_LIGHT", (x, y))
    put(im, "SEA_PALE", (2, 2), (3, 2), (2, 3))
    put(im, "FOAM_WHITE", (3, 3))
    return im


# =============================================================================
# THE REEFWARDEN (map Stage 11i).  A wall-diver of Saltmere: the helmet, the suit, the weights,
# the maul. Built of parts like the Netted (gen_enemies_b): head 0-8, torso 9-16, legs 17-21.
# =============================================================================
RW_HELMET = part("""
........................
.........kkkkkk.........
........k&&%%%%k........
.......k&%%%%%%~k.......
.......k%%kkkk%~k.......
.......k%kPFFPk~k.......
.......k%kFkkFk~k.......
.......k~kPFFPk~k.......
........k~kkkk~k........
""")
RW_CORAL = grid("""
#.F.
FFFF
""")                       # a little dead coral on the crown, one living tip
RW_TORSO = part("""
.......kiiiiiiiik.......
......k3333333333k......
......k3322222233k......
......k3322222233k......
......khIhIhIhIhhk......
......k3322222233k......
......kFF22222222Fk.....
......kkk22222222kk.....
""")
RW_TORSO_UP = part("""
.......kiiiiiiiik.......
......k3333333333k......
......k3322222233kk.....
......k33222222333k.....
......khIhIhIhIhhk......
......k3322222233k......
......kFF22222222k......
......kkk22222222k......
""")
RW_ARM_UP = grid("""
kFk
k3k
k3k
k3k
k3k
""")
RW_MAUL_DOWN = grid("""
..kXk..
..kXk..
..kXk..
..kXk..
kkkkkkk
k6LLLTk
k66LTtk
kkkkkkk
""")
RW_MAUL_UP = grid("""
kkkkkkk
k6LLLTk
k66LTtk
kkkkkkk
..kXk..
..kXk..
..kXk..
..kXk..
""")
RW_MAUL_SLAM = grid("""
.....kkkkkk
kkkkkk6LLTk
kXXXXk6LTtk
kkkkkk66Ttk
.....kkkkkk
""")
RW_SPLASH = grid("""
Z.....Z
.P.Z.P.
""")
# lead boots: the drowned's legs with the boots in Iron dark
RW_LEGS = {k: recolour(v, {P.rgb("WOOL_DARK"): P.rgb("IRON_DARK"), P.rgb("WOOL"): P.rgb("IRON")}) for k, v in LEGS.items()}


def reefwarden_frame(legs="stand", dy=0, maul="down", splash=False):
    torso = RW_TORSO_UP if maul == "up" else RW_TORSO
    layers = [(RW_LEGS[legs], 0, 17), (torso, 0, 9 + dy), (RW_HELMET, 0, dy), (RW_CORAL, 10, dy)]
    if maul == "down":
        layers.append((RW_MAUL_DOWN, 15, 11 + dy))
    elif maul == "up":
        layers.append((RW_MAUL_UP, 15, 0))
        layers.append((RW_ARM_UP, 17, 5 + dy))
    elif maul == "slam":
        layers.append((RW_MAUL_SLAM, 13, 15 + dy))
    if splash:
        layers.append((RW_SPLASH, 16, 13 + dy))
    return stack(*layers)


def reefwarden_frames():
    f = reefwarden_frame
    idle = [f(), f(dy=1), f(), f(dy=1)]
    walk = [f(legs="w1"), f(legs="w2", dy=1), f(legs="w3"), f(legs="w6", dy=1)]
    windup = [f(maul="up", dy=1), f(maul="up")]
    attack = [f(maul="slam", dy=1, splash=True), f(maul="slam", dy=1)]
    hurt = [shift(f(), -2, 0)]
    frames = idle + walk + windup + attack + hurt + person_death(f(maul="none"))
    gen_rim.crown(frames)   # a person: the wet crown on the helmet (STYLE.md 18)
    return frames


def surge():
    """The surge the maul sends out, 16x16: a swell with a foam crest. Seen from above and
    round, so it reads the same whichever way it rolls (pixel art is never turned)."""
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    ellipse(im, 8, 8, 7.5, 7.5, "SHALLOW")
    ellipse(im, 8, 8.5, 5.0, 5.0, "SEA")
    ellipse(im, 8, 9, 2.5, 2.5, "SEA_PALE")
    px = im.load()
    for y in range(16):
        for x in range(16):
            d = ((x + 0.5 - 8) ** 2 + (y + 0.5 - 8) ** 2) ** 0.5
            if 6.4 <= d <= 7.6 and (x + y) % 3:
                px[x, y] = rgba("FOAM_WHITE")
    put(im, "SALT_WHITE", (6, 4), (7, 3), (10, 4))
    return im


# =============================================================================
# THE TIDEWALL (map Stage 11j), 48x48 on the boss layout (idle 0-3, walk 4-7, windup 8-9,
# attack 10-11, hurt 12, phase 13, intro 14, death 15-17).  A slab of Saltmere's sea wall that
# stood up: dressed courses of Stone with Stone dark joints and Stone light arrises, dead coral
# along its crown with a few living tips, two buttresses for arms, and the breach in its chest
# where the sea comes through (Deep sea inside, two Sea pale glints, Sea and Shallow pouring
# down to foam at its foot). The second sheet (tidewall_breached.png) is the same wall after its
# second breach opens, high on the left: what it looks like once the boss's phase changes.
# =============================================================================
TW = 48


def tw_canvas():
    return Image.new("RGBA", (TW, TW), (0, 0, 0, 0))


def tw_rect(im, x0, y0, x1, y1, key):
    ImageDraw.Draw(im).rectangle([x0, y0, x1, y1], fill=rgba(key))


def tw_courses(im, x0, y0, x1, y1, seed=0, mask=None):
    """Dressed stone laid in blocks: courses four rows high, the joints staggered, a light
    arris only at each block's top-left corner (full-width light lines read as a radiator).
    With `mask` (a set of (x, y)) only those cells are laid: the wall's own silhouette."""
    for y in range(y0, y1 + 1):
        row = (y - y0) // 4
        off = (row * 4 + seed * 3) % 7
        for x in range(x0, x1 + 1):
            if mask is not None and (x, y) not in mask:
                continue
            ry = (y - y0) % 4
            bx = (x - x0 + off) % 7
            if ry == 3 or bx == 0:
                key = "STONE_DARK"                       # bed and cross joints
            elif ry == 0 and bx in (1, 2):
                key = "STONE_LIGHT"                      # the block's arris
            elif (x * 7 + y * 13 + seed) % 23 == 0:
                key = "WET_GREY"                         # weathering
            else:
                key = "STONE"
            put(im, key, (x, y))


def tw_mask(top, bot, cx=24, half_top=13, half_bot=16, seed=0):
    """The wall's silhouette: battered (wider at its foot), the top course broken."""
    cells = set()
    for y in range(top, bot + 1):
        k = (y - top) / float(max(1, bot - top))
        hw = int(round(half_top + (half_bot - half_top) * k))
        for x in range(cx - hw, cx + hw):
            # the broken top: some columns lose one to three rows
            loss = ((x * 7 + seed) % 5 == 0) + ((x * 3 + seed) % 7 == 0) + (x in (cx - hw, cx + hw - 1))
            if y < top + loss:
                continue
            cells.add((x, y))
    return cells


def tw_breach(im, cx, cy, w, h, glow=False, glints=True):
    """A ragged hole through the wall with the sea behind it."""
    for y in range(cy - h // 2, cy + h // 2 + 1):
        k = 1.0 - abs(y - cy) / float(h // 2 + 1)
        hw = max(1, int(round(w / 2.0 * (0.55 + 0.45 * k))) + ((y * 7) % 3 == 0))
        tw_rect(im, cx - hw, y, cx + hw - 1, y, "DEEP_SEA")
        put(im, "STONE_DARK", (cx - hw - 1, y), (cx + hw, y))
    tw_rect(im, cx - w // 4, cy - 1, cx + w // 4 - 1, cy + 1, "SEA_PALE" if glow else "SEA")
    if glints:
        put(im, "FOAM_WHITE" if glow else "SEA_PALE", (cx - 3, cy - 2), (cx + 2, cy - 2))


def tw_pour(im, cx, top, bottom, w, phase_off=0):
    """The sea pouring from the breach's sill down the wall's face to foam at its foot."""
    for y in range(top, bottom + 1):
        for x in range(cx - w // 2, cx + w // 2):
            put(im, "SEA" if (x + y + phase_off) % 4 else "SHALLOW", (x, y))
        if (y + phase_off) % 3 == 0:
            put(im, "FOAM_WHITE", (cx - w // 2 + (y % max(1, w)), y))
    for x in range(cx - w // 2 - 3, cx + w // 2 + 3):
        put(im, "FOAM_WHITE" if (x + phase_off) % 2 else "SEA_PALE", (x, bottom))


def tw_crown(im, y, flicker=0):
    """Dead coral heaped on the broken top in clumps, spilling down the left shoulder; a few
    living tips (Salt red, Violet light) where the water still reaches."""
    for (cx, r) in ((13, 3.2), (19, 2.4), (25, 3.6), (31, 2.6), (35, 2.0)):
        ellipse(im, cx, y, r, r * 0.8, "DROWNED_SKIN")
        put(im, "DROWNED_SHADE", (cx - 1, y + 1), (cx + 1, y + 1), (cx, y))
        put(im, "PALE_SLATE", (cx - 1, y - int(r * 0.6)))
    for k in range(6):                       # spilling down the left shoulder
        ellipse(im, 11 - (k % 2), y + 3 + k * 2, 1.6, 1.2, "DROWNED_SKIN")
    tips = [(12, -3, "SALT_RED"), (19, -2, "VIOLET_LIGHT"), (25, -4, "SALT_RED"), (31, -3, "SALT_RED"),
            (35, -2, "VIOLET_LIGHT"), (10, 8, "SALT_RED")]
    for i, (x, dy, key) in enumerate(tips):
        if (i + flicker) % 6:
            put(im, key, (x, y + dy))


def tw_buttress(im, x0, y0, lift=0, down=0, side=1):
    """An arm: a stepped buttress, broad at its foot like a fist on the floor."""
    y = y0 - lift + down
    mask = set()
    for yy in range(y, y + 16):
        k = (yy - y) / 15.0
        w = 4 + int(round(3 * k))
        xs = range(x0, x0 + w) if side > 0 else range(x0 + 7 - w, x0 + 7)
        for xx in xs:
            mask.add((xx, yy))
    tw_courses(im, x0, y, x0 + 7, y + 15, seed=2, mask=mask)
    put(im, "DROWNED_SKIN", (x0 + 2, y - 1), (x0 + 3, y - 1), (x0 + 3, y - 2))


def tidewall(dy=0, lift=0, down=0, glow=False, pour=0, chips=False, second=False, sunk=0, burst=False, bob=0):
    im = tw_canvas()
    top, bot = 9 + dy + bob, 42 + dy
    tw_buttress(im, 1, top + 12, lift, down, side=-1)
    tw_buttress(im, 39, top + 12, lift, down, side=1)
    tw_courses(im, 7, top, 40, bot, mask=tw_mask(top, bot))
    tw_crown(im, top, flicker=pour)
    tw_breach(im, 24, top + 14, 12, 12, glow=glow)
    if second:
        tw_breach(im, 15, top + 6, 7, 7, glow=glow, glints=False)
        tw_pour(im, 15, top + 10, bot + 2, 2, pour)
    tw_pour(im, 24, top + 20, bot + 3, 6, pour)
    if burst:
        for (x, y) in ((17, top + 12), (31, top + 12), (14, top + 16), (34, top + 17), (20, top + 9), (28, top + 9)):
            put(im, "FOAM_WHITE", (x, y), (x + 1, y))
            put(im, "SEA_PALE", (x, y + 1))
    if chips:
        put(im, "SALT_WHITE", (13, top + 4), (33, top + 7), (22, top + 2))
    for x in range(8, 40, 3):          # its foot: rubble on row 44-45
        put(im, "STONE_DARK", (x, 44), (x + 1, 44))
        put(im, "STONE", (x, 43))
    im = outline(im)
    if sunk:
        # the intro: rising out of the water, the lower part still under it
        px = im.load()
        line = 45 - sunk
        for y in range(line, TW):
            for x in range(TW):
                if px[x, y][3]:
                    px[x, y] = rgba("SEA") if (x + y) % 3 else rgba("SHALLOW")
        for x in range(TW):
            if px[x, line][3]:
                px[x, line] = rgba("FOAM_WHITE")
    return im


def tidewall_fallen(stage):
    """Death: the slab drops in on itself and leaves a heap the sea runs through."""
    im = tw_canvas()
    top = 9 + (8, 16, 22)[stage]
    tw_courses(im, 4, top, 44, 42, mask=tw_mask(top, 42, half_top=13 + stage * 2, half_bot=17 + stage * 2, seed=stage + 1))
    for i in range(stage * 4 + 3):     # stones knocked loose
        x = 6 + (i * 11) % 36
        y = 36 + (i * 5) % 8
        tw_rect(im, x, y, x + 3, y + 2, "STONE")
        put(im, "STONE_LIGHT", (x, y), (x + 1, y))
    tw_crown(im, top, flicker=stage)
    tw_breach(im, 24, top + 6, 12 - stage * 2, 6, glints=False)
    tw_pour(im, 24, top + 9, 44, 8 + stage * 4, stage)
    return outline(im)


def tidewall_frames(second=False):
    def f(**kw):
        return tidewall(second=second, **kw)
    idle = [f(pour=0), f(pour=1, dy=1), f(pour=2), f(pour=3, dy=1)]
    walk = [f(pour=0, bob=1), f(pour=1), f(pour=2, bob=1), f(pour=3)]
    windup = [f(lift=3, glow=True), f(lift=6, glow=True, dy=-1)]
    attack = [f(down=2, burst=True, dy=1), f(down=2, dy=1, pour=1)]
    hurt = [f(chips=True, dy=1)]
    phase = [tidewall(second=True, glow=True, burst=True)]
    intro = [f(sunk=18)]
    death = [tidewall_fallen(0), tidewall_fallen(1), tidewall_fallen(2)]
    return idle + walk + windup + attack + hurt + phase + intro + death


def wall_stone():
    """A dressed stone off the wall, 16x16, thrown: square from above, so it reads unturned."""
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    tw_courses(im, 3, 4, 12, 11)
    put(im, "DROWNED_SKIN", (4, 3), (5, 3), (9, 3))
    put(im, "SALT_RED", (10, 3))
    return outline(im)


# --- elite costumes: ride the top of the body (gen_enemies.elite_sheet) -------------------
CC_CROWN = grid("""
#.Q.#
#Q#Q#
""")                       # the coral crab: a crown of living coral on the head
RR_BARBS = grid("""
W.....W
.WW.WW.
...W...
""")                       # the ray: a salt crest along the shoulders
PS_BLOOM = grid("""
.Q.Q.
QyQyQ
""")                       # the polyp: a bloom of lit tips (a little warmth is a costume only)
RW_CROWN = grid("""
#.Q.#.#
#Q#Q#Q#
""")                       # the reefwarden: the living coral has grown over his whole helmet
ELITE_COSTUMES = {
    "coral_crab": (CC_CROWN, "top", (0, 1)),
    "reef_ray": (RR_BARBS, "top", (0, 3)),
    "polyp_swarm": (PS_BLOOM, "top", (0, 1)),
    "reefwarden": (RW_CROWN, "top", (0, 2)),
}


def main():
    os.makedirs(SPRITES, exist_ok=True)
    os.makedirs(REF, exist_ok=True)
    built = {"coral_crab": crab_frames(), "reef_ray": ray_frames(), "polyp_swarm": polyp_frames()}
    gen_enemies.COSTUMES.update(ELITE_COSTUMES)
    elites = {}
    for name, frames in built.items():
        assert len(frames) == 16, (name, len(frames))
        strip(frames).save(os.path.join(SPRITES, name + ".png"))
        elites[name] = gen_enemies.elite_sheet(name, frames)
        strip(elites[name]).save(os.path.join(SPRITES, name + "_elite.png"))
    spore().save(os.path.join(SPRITES, "polyp_spore.png"))
    surge().save(os.path.join(SPRITES, "surge.png"))
    wall = tidewall_frames()
    breached = tidewall_frames(second=True)
    assert len(wall) == 18 and len(breached) == 18
    strip(wall, TW, TW).save(os.path.join(SPRITES, "tidewall.png"))
    strip(breached, TW, TW).save(os.path.join(SPRITES, "tidewall_breached.png"))
    wall_stone().save(os.path.join(SPRITES, "wall_stone.png"))
    warden = reefwarden_frames()
    assert len(warden) == 16
    strip(warden).save(os.path.join(SPRITES, "reefwarden.png"))
    warden_elite = gen_enemies.elite_sheet("reefwarden", warden)
    strip(warden_elite).save(os.path.join(SPRITES, "reefwarden_elite.png"))

    # review sheet: each over the Reef floor at 4x, then its elite, then the spore
    try:
        font = ImageFont.load_default(size=11)
        small = ImageFont.load_default(size=9)
    except TypeError:
        font = small = ImageFont.load_default()
    labels = ["idle"] * 4 + ["walk"] * 4 + ["windup", "windup", "attack", "attack", "hurt", "death", "death", "death"]
    names = {"coral_crab": ["hidden"] * 4 + labels[4:], "reef_ray": labels, "polyp_swarm": labels[:4] + ["under"] * 4 + labels[8:]}
    Z = 4
    rows = list(built.items()) + [(n + "_elite", elites[n]) for n in built]
    W = 12 + 16 * (CELL * Z + 4) + 12
    sheet = Image.new("RGBA", (W, 40 + len(rows) * (CELL * Z + 40) + 60), (30, 33, 42, 255))
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "EBB - map Stage 11h - the Reef's drowned on the 16-frame layout, 4x over the Reef floor (Drowned shade)",
           fill=P.rgb("SALT_WHITE"), font=font)
    y = 28
    for name, frames in rows:
        d.text((12, y), name, fill=P.rgb("SALT_WHITE"), font=font)
        y += 14
        labs = names[name.replace("_elite", "")]
        for i, fr in enumerate(frames):
            bg = Image.new("RGBA", (CELL, CELL), P.rgba("DROWNED_SHADE"))
            if name.startswith("reef_ray"):
                sh = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
                ImageDraw.Draw(sh).ellipse((6, 19, 17, 22), fill=(0, 0, 0, 70))
                bg.alpha_composite(sh)
            bg.alpha_composite(fr)
            sheet.alpha_composite(zoom(bg, Z), (12 + i * (CELL * Z + 4), y))
            d.text((12 + i * (CELL * Z + 4), y + CELL * Z + 2), "%d %s" % (i, labs[i]), fill=P.rgb("PALE_SLATE"), font=small)
        y += CELL * Z + 26
    bg = Image.new("RGBA", (10, 10), P.rgba("DROWNED_SHADE"))
    bg.alpha_composite(spore(), (2, 2))
    sheet.alpha_composite(zoom(bg, 6), (12, y))
    d.text((80, y + 20), "polyp_spore 6x6 (6x)", fill=P.rgb("PALE_SLATE"), font=small)
    sheet.convert("RGB").save(os.path.join(REF, "s11h_reef_enemies.png"))

    # map Stage 11i: the Reefwarden, its elite sheet (how it is met: named), and the surge
    labs = labels
    sheet = Image.new("RGBA", (W, 40 + 2 * (CELL * Z + 40) + 120), (30, 33, 42, 255))
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "EBB - map Stage 11i - the Reefwarden, the Reef's named elite, 4x over the Reef floor; the named one wears the elite sheet",
           fill=P.rgb("SALT_WHITE"), font=font)
    y = 28
    for name, frames in (("reefwarden", warden), ("reefwarden_elite (as met)", warden_elite)):
        d.text((12, y), name, fill=P.rgb("SALT_WHITE"), font=font)
        y += 14
        for i, fr in enumerate(frames):
            bg = Image.new("RGBA", (CELL, CELL), P.rgba("DROWNED_SHADE"))
            bg.alpha_composite(fr)
            sheet.alpha_composite(zoom(bg, Z), (12 + i * (CELL * Z + 4), y))
            d.text((12 + i * (CELL * Z + 4), y + CELL * Z + 2), "%d %s" % (i, labs[i]), fill=P.rgb("PALE_SLATE"), font=small)
        y += CELL * Z + 26
    bg = Image.new("RGBA", (20, 20), P.rgba("DROWNED_SHADE"))
    bg.alpha_composite(surge(), (2, 2))
    sheet.alpha_composite(zoom(bg, 5), (12, y))
    d.text((120, y + 40), "surge 16x16 (5x): what the maul sends rolling", fill=P.rgb("PALE_SLATE"), font=small)
    sheet.convert("RGB").save(os.path.join(REF, "s11i_reefwarden.png"))

    # map Stage 11j: the Tidewall at 3x over the Reef floor, before and after its second breach
    blabels = labels[:13] + ["phase", "intro", "death", "death", "death"]
    Z3 = 3
    sheet = Image.new("RGBA", (12 + 18 * (TW * Z3 + 4) + 12, 40 + 2 * (TW * Z3 + 40) + 110), (30, 33, 42, 255))
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "EBB - map Stage 11j - the Tidewall, the Reef's boss, 48 px on the boss layout at 3x; below, after its second breach",
           fill=P.rgb("SALT_WHITE"), font=font)
    y = 28
    for name, frames in (("tidewall", wall), ("tidewall_breached (phase 2)", breached)):
        d.text((12, y), name, fill=P.rgb("SALT_WHITE"), font=font)
        y += 14
        for i, fr in enumerate(frames):
            bg = Image.new("RGBA", (TW, TW), P.rgba("DROWNED_SHADE"))
            bg.alpha_composite(fr)
            sheet.alpha_composite(zoom(bg, Z3), (12 + i * (TW * Z3 + 4), y))
            d.text((12 + i * (TW * Z3 + 4), y + TW * Z3 + 2), "%d %s" % (i, blabels[i]), fill=P.rgb("PALE_SLATE"), font=small)
        y += TW * Z3 + 26
    bg = Image.new("RGBA", (20, 20), P.rgba("DROWNED_SHADE"))
    bg.alpha_composite(wall_stone(), (2, 2))
    sheet.alpha_composite(zoom(bg, 5), (12, y))
    d.text((120, y + 40), "wall_stone 16x16 (5x): what it throws", fill=P.rgb("PALE_SLATE"), font=small)
    sheet.convert("RGB").save(os.path.join(REF, "s11j_tidewall.png"))
    print("wrote", ", ".join(built), "+ elites, polyp_spore; s11h_reef_enemies.png")


if __name__ == "__main__":
    main()
