"""Stage 19 (categories 3, 4, 6): the post-brief enemies and the Chainmother, rebuilt.

The six enemies of M6/M7 were on the old 7-frame strips in the old palette.  They are redrawn
to STYLE.md 7 and 18 on the Stage 13 layout (idle 0-3, walk 4-7, windup 8-9, attack 10-11,
hurt 12, death 13-15): the Mooring, the Deckhand, the Barnacle swarm (Harbour), Tallow (Hall),
the Choir (Streets elite) and the Netted (Flats elite).  The drowned among them are people:
Drowned skin on the face and hands only, hair or a hat, calm eyes, a Sea pale rim on the crown,
one strand of kelp, and they go down like people.

The Chainmother is the Harbour's boss: the dock crane that kept the ships in, walking on its own
iron piles.  She was 24 px scaled by two; she is now a native 48x48 sheet on the boss layout
(idle 0-3, walk 4-7, windup 8-9, attack 10-11, hurt 12, phase 13, intro 14, death 15-17), with
the one warm lamp the Harbour allows in her two cab windows (STYLE.md 19).

Writes assets/sprites/: mooring, deckhand, barnacle, tallow, choir, netted (16 x 24x24),
chainmother (18 x 48x48), anchor_drop (24x24), wax (32x32), wisp_shot (4x4), shade_bolt (14x4),
and assets/reference/anchors/enemies_b_sheet.png.

Run:  python tools/gen_enemies_b.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
import gen_rim  # noqa: E402
from gen_anchors import LEG, grid, zoom  # noqa: E402
from gen_characters import part, stack, cell, recolour, LEGS_STAND, LEGS_W1, LEGS_W2, LEGS_W3, LEGS_W6  # noqa: E402
from gen_enemies import shift, lay  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
REF = os.path.join(P.ROOT, "assets", "reference", "anchors")
CELL = 24


def rgba(key, a=255):
    return P.rgb(key) + (a,)


def strip(frames, w=CELL, h=CELL):
    im = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.alpha_composite(f, (i * w, 0))
    return im


# The drowned wear the same cut as the living, in the Slate ramp: Tam's legs with Night 2 trousers.
_OIL = {P.rgb("OILSKIN_DARK"): P.rgb("NIGHT_2"), P.rgb("OILSKIN"): P.rgb("SLATE"), P.rgb("OILSKIN_LIGHT"): P.rgb("WET_GREY")}
LEGS = {k: recolour(v, _OIL) for k, v in (("stand", LEGS_STAND), ("w1", LEGS_W1), ("w2", LEGS_W2), ("w3", LEGS_W3),
                                          ("w6", LEGS_W6))}


def person_death(standing):
    """A person going down: the knee, lying still, sunk a pixel into the wet ground."""
    lying = lay(standing)
    return [shift(standing, 0, 3), lying, shift(lying, 0, 1)]


# =============================================================================
# THE MOORING (Harbour).  A harbour hand with the mooring chain still wrapped round his arm.
# =============================================================================
MO_HEAD = part("""
........................
........................
.........kkkkkk.........
........kPbbbbbk........
.......kbbbbbbbbk.......
.......kbbFFFFbbk.......
.......kbFFkFkFbk.......
........kmFFFFmk........
.........kFFFFk.........
""")
MO_TORSO = part("""
.......kP3333333k.......
......k33l33333233k.....
......k33233333233k.....
......k33233333iIik.....
......k33233333Iiik.....
......k33233333iIik.....
......kFF233333FFik.....
......kkk2333332kkk.....
""")
# the arm with the chain raised over the shoulder
MO_TORSO_UP = part("""
.......kP3333333k.......
......k33l333333k.......
......k332333333k.......
......k332333333k.......
......k332333333k.......
......k332333333k.......
......kFF2333333k.......
......kkk23333333k......
""")
MO_ARM_UP = grid("""
.kIk
kiIik
kIiIk
kiIik
.kkk.
""")
# the lash: arm straight out, the chain along the deck to the edge of the cell
MO_TORSO_LASH = part("""
.......kP3333333k.......
......k33l333333k.......
......k332333333kkkkkkkk
......k332333333iIiIiIiI
......k332333333kkkkkkkk
......k332333333k.......
......kFF2333333k.......
......kkk2333332kk......
""")
MO_CHAIN_HANG = grid("""
.i
.I
ki
kI
""")


def mooring_frames():
    def f(torso=MO_TORSO, legs="stand", dy=0, chain=True, arm_up=False):
        layers = [(LEGS[legs], 0, 17), (torso, 0, 9 + dy), (MO_HEAD, 0, dy)]
        if chain:
            layers.append((MO_CHAIN_HANG, 16, 16 + dy))
        if arm_up:
            layers.append((MO_ARM_UP, 15, 4 + dy))
        return stack(*layers)
    idle = [f(), f(dy=1), f(), f(dy=1)]
    walk = [f(legs="w1"), f(legs="w2", dy=1), f(legs="w3"), f(legs="w6", dy=1)]
    windup = [f(torso=MO_TORSO_UP, chain=False, arm_up=True), f(torso=MO_TORSO_UP, chain=False, arm_up=True, dy=-1)]
    attack = [f(torso=MO_TORSO_LASH, chain=False, dy=1), shift(f(torso=MO_TORSO_LASH, chain=False, dy=1), 1, 0)]
    hurt = [shift(f(), -2, 0)]
    return idle + walk + windup + attack + hurt + person_death(f())


# =============================================================================
# THE DECKHAND (Harbour).  Shield up, a cutlass behind; a kerchief on the head.
# =============================================================================
DH_HEAD = part("""
........................
........................
.........kkkkkk.........
........kPbbbbbkk.......
.......kbbbbbbbbbk......
.......kbbFFFFbbk.......
.......kbFFkFkFbk.......
........kmFFFFmk........
.........kFFFFk.........
""")
DH_TORSO = part("""
.......kP3333333k.......
......k22l222222k.......
......k22322222322k.....
......k22322222322k.....
......k22322222322k.....
......krrrrrrrrrrrk.....
......kFF2222222FFk.....
......kkk2222222kkk.....
""")
DH_SHIELD = grid("""
.kkkk.
kxXXxk
kXxxXk
kXxIxk
kXxxXk
kxXXxk
.kkkk.
""")
DH_BLADE_UP = grid("""
.kIk.
.kIk.
.kIk.
.kIk.
k%%%k
.kkk.
""")
DH_BLADE_OUT = grid("""
kkkkkkkk
%IIIIIII
kkkkkkkk
""")


def deckhand_frames():
    def f(legs="stand", dy=0, shield=(17, 10), blade=None):
        layers = [(LEGS[legs], 0, 17), (DH_TORSO, 0, 9 + dy), (DH_HEAD, 0, dy)]
        if blade == "up":
            layers.append((DH_BLADE_UP, 3, 3 + dy))
        if shield:
            layers.append((DH_SHIELD, shield[0], shield[1] + dy))
        if blade == "out":
            layers.append((DH_BLADE_OUT, 16, 10 + dy))
        return stack(*layers)
    idle = [f(), f(dy=1), f(), f(dy=1)]
    walk = [f(legs="w1"), f(legs="w2", dy=1), f(legs="w3"), f(legs="w6", dy=1)]
    windup = [f(blade="up", shield=(16, 11)), f(blade="up", shield=(15, 12), dy=-1)]
    attack = [f(blade="out", shield=(15, 14), dy=1), shift(f(blade="out", shield=(15, 14), dy=1), 1, 0)]
    hurt = [shift(f(shield=(16, 13)), -2, 0)]
    return idle + walk + windup + attack + hurt + person_death(f(shield=(16, 13)))


# =============================================================================
# THE BARNACLE SWARM (Harbour).  A crust that learned to move: Stone with Bone cones tipped in
# salt, two Sea pale points at the front.  Not a person.
# =============================================================================
BARN_MASS = grid("""
.....kkkkkkkkk.....
...kkTTTtTTTTTkkk..
..kTTtTTTTtTTTTTTk.
.kTtTTTTTTTTTtTTTTk
.ktTTTTtTTTTTTTtTTk
..kttTTTTTttTTTTTk.
...kkkkkkkkkkkkkk..
""")
BARN_CONE = grid("""
.kWk.
kvBvk
""")
BARN_MASS_SMALL = grid("""
....kkkkkkk....
..kkTTtTTTTkk..
.kTtTTTTTtTTTTk
.ktTTTtTTTTTTTk
..kkkkkkkkkkkk.
""")


def barnacle_frame(dy=0, wobble=0, gather=0, bite=False, hurt=False, spread=0, flat=False, small=False):
    layers = []
    body = BARN_MASS_SMALL if small else BARN_MASS
    if flat:
        body = body.crop((0, 2, body.width, body.height))
    mx = (4 if small else 2) + (2 if bite else 0)
    my = (17 if small else 15) + dy + gather
    if flat:
        my += 2
    layers.append((body, mx, my))
    cones = [(3, 13), (7, 12), (11, 13), (9, 15), (5, 16), (13, 16), (15, 14)]
    if small:
        cones = [(4, 15), (8, 14), (11, 16)]
    for i, (x, y) in enumerate(cones):
        ox = x + mx + (wobble if i % 2 else -wobble) - (gather if x < 9 else -gather) * (1 if gather else 0)
        sx = (spread if x > 9 else -spread)
        layers.append((BARN_CONE, ox + sx, y + dy + (2 if flat else 0) + (spread // 2)))
    im = stack(*layers)
    px = im.load()
    # two Sea pale points at the front, an Ink gap with bone teeth when it bites
    fx = mx + (12 if small else 16)
    if not flat:
        px[fx, 17 + dy + gather] = rgba("SEA_PALE")
        px[fx - 3, 18 + dy + gather] = rgba("SEA_PALE")
    if bite:
        for x in range(fx - 1, min(23, fx + 3)):
            px[x, 19 + dy] = rgba("INK")
            px[x, 20 + dy] = rgba("INK")
        px[fx, 19 + dy] = rgba("BONE")
        px[fx + 2, 20 + dy] = rgba("BONE")
    if hurt:
        px[mx + 8, 17 + dy] = rgba("SALT_WHITE")
    return im


def barnacle_frames(small=False):
    def f(**kw):
        return barnacle_frame(small=small, **kw)
    idle = [f(), f(wobble=1), f(), f(dy=-1)]
    walk = [f(wobble=1), f(dy=-1), f(wobble=-1), f(dy=-1, wobble=1)]
    windup = [f(gather=1, dy=-1), f(gather=1, dy=-2)]
    attack = [f(bite=True, dy=1), shift(f(bite=True, dy=1), 1, 0)]
    hurt = [f(hurt=True, dy=1, wobble=1)]
    death = [f(dy=1, spread=1), f(flat=True, spread=3), f(flat=True, spread=5)]
    return idle + walk + windup + attack + hurt + death


# =============================================================================
# TALLOW (Hall).  A keeper who stood so long the candle on his head ran down over him: a figure
# of Bone wax, the drowned face still in it, the candle still lit, a puddle of himself.
# =============================================================================
TA_FLAME = grid("""
.@.
@y@
kck
""")
TA_HEAD = part("""
........................
........................
...........kk...........
........kkkVVkkk........
.......kVVVVVVVVk.......
.......kVBFFFFBVk.......
.......kVBFkFkBVk.......
.......kVBFFFFBVk.......
........kVVVVVVk........
""")
TA_TORSO = part("""
.......kVVVVVVVVVk......
......kVVVBVVVVBVVk.....
......kVVVBVVVVBVVk.....
......kVBVBVVVVBVVk.....
......kVBVBVVBVBVVk.....
......kVBVBVVBVBVBk.....
......kBBVBVBBVBVBk.....
......kkkBBBBBBBkkk.....
""")
TA_TORSO_WIDE = part("""
.......kVVVVVVVVVk......
......kVVVBVVVVBVVk.....
.....kVVVVBVVVVBVVVk....
.....kVBVVBVVVVBVVVk....
....kVVBVBVVVBVBVVVVk...
....kVBVBVBVVBVBVBVVk...
....kBBBVBVBBVBVBVBBk...
....kkkkBBBBBBBBBkkkk...
""")
TA_LEGS = part("""
........kBBBkBBBk.......
........kBVBkBVBk.......
.......kvBBBkBBBvk......
......kvvvvvvvvvvvk.....
.....kkkkkkkkkkkkkkk....
""")
TA_POUR = grid("""
kkkkkkkk
kyVVVVVk
kVVVBVVk
kBVVVVBk
.kkBBBk.
""")
TA_SAG = part("""
........................
........................
........................
........................
........................
........................
........................
........................
........................
...........kk...........
........kkkVVkkk........
.......kVVVVVVVVk.......
......kVVBFFFFBVVk......
.....kVVVBFkFkBVVVk.....
....kVVBVBFFFFBVBVVk....
...kVVBVVBVVVVBVVBVVk...
...kVBVBVVBVVBVVBVBVk...
..kVBVBVVBVBBVBVVBVBVk..
..kBBBVBVBVBBVBVBVBBBk..
.kvvBBBBBBBBBBBBBBBvvvk.
.kvvvvvvvvvvvvvvvvvvvvk.
.kkkkkkkkkkkkkkkkkkkkkk.
........................
........................
""")
TA_SPREAD = part("""
........................
........................
........................
........................
........................
........................
........................
........................
........................
........................
........................
........................
........................
............kk..........
.........kkkVVkkk.......
.......kkVVBFFFFBVVkk...
.....kkVVVVBFkFkBVVVVkk.
...kkVVBVBVBFFFFBVBVBVVk
..kVBBVBVBVBVBVBVBVBBBVk
.kvvBBBBBBBBBBBBBBBBBvvk
.kvvvvvvvvvvvvvvvvvvvvvk
.kkkkkkkkkkkkkkkkkkkkkk.
........................
........................
""")
TA_PUDDLE = part("""
........................
........................
........................
........................
........................
........................
........................
........................
........................
........................
........................
........................
........................
........................
........................
............kk..........
.........kkkVVkkkk......
......kkVVVVVVVVVVVkk...
...kkVVBVBVBVVBVBVBVVkk.
.kkvvBBBBBBBBBBBBBBBvvvk
kvvvvvvvvvvvvvvvvvvvvvvk
kkkkkkkkkkkkkkkkkkkkkkkk
........................
........................
""")


def tallow_frames():
    def f(torso=TA_TORSO, dy=0, drip=0, lit=True, pour=False):
        im = stack((TA_LEGS, 0, 17), (torso, 0, 9 + dy), (TA_HEAD, 0, dy))
        px = im.load()
        if lit:
            im.alpha_composite(TA_FLAME, (10, max(0, dy - 1)))
        else:
            px[11, 1 + dy] = rgba("INK")
        # wax running down the body, further each frame
        for k, x in enumerate((8, 12, 16)):
            for j in range(1 + drip + (k % 2)):
                y = 17 + j + dy
                if y < 20:
                    px[x, y] = rgba("BONE_LIGHT")
        if pour:
            im.alpha_composite(TA_POUR, (16, 11 + dy))
        return im
    idle = [f(), f(drip=1), f(dy=1), f(drip=1, dy=1)]
    walk = [f(dy=-1), f(drip=1), f(dy=-1, drip=1), f()]
    windup = [f(torso=TA_TORSO_WIDE, dy=-1, drip=1), f(torso=TA_TORSO_WIDE, dy=-2, drip=2)]
    attack = [f(dy=1, drip=2, pour=True), f(dy=1, drip=2, pour=True)]
    hurt = [f(dy=1, drip=1, lit=False)]
    death = [grid_frame(TA_SAG), grid_frame(TA_SPREAD), grid_frame(TA_PUDDLE)]
    return idle + walk + windup + attack + hurt + death


def grid_frame(p):
    return stack((p, 0, 0))


# =============================================================================
# THE CHOIR (Streets elite).  One of the nine singers: a Slate hood lined Deep violet, hands
# folded, the mouth opening on the note, the hem drifting as if still under water.
# =============================================================================
def choir_head(mouth=0, glow=False):
    eye = "Q" if glow else "k"
    rows = [
        "........................",
        "........................",
        ".........kkkkkk.........",
        "........kP33333k........",
        ".......k33DDDDD3k.......",
        ".......k3DFFFFFD3k......",
        ".......k3DF%sF%sFD3k......" % (eye, eye),
        ".......k3DmFFFmD3k......",
        ".......k3DDFFFDD3k......",
    ]
    im = part("\n".join(rows))
    px = im.load()
    if mouth >= 1:
        px[12, 7] = rgba("INK")
    if mouth >= 2:
        px[11, 7] = rgba("INK")
        px[13, 7] = rgba("INK")
    if mouth >= 3:
        px[12, 8] = rgba("INK")
    return im


CH_ROBE = part("""
........k33333333k......
.......k3333333333k.....
......k33333333333k.....
......k33D33333D33k.....
......k33D33333D33k.....
......k33DkFFFkD33k.....
......k33DkFFFkD33k.....
......k333kkkkk333k.....
""")
CH_ROBE_ARMS_UP = part("""
........k33333333k......
.......k3333333333k.....
......k33333333333k.....
......k33D33333D33k.....
......k33D33333D33k.....
......k33D33333D33k.....
......k33D33333D33k.....
......k333333333333k....
""")
CH_ARM_L = grid("""
kFk
k3k
k3k
kDk
k3k
""")
CH_ARM_R = grid("""
kFk
k3k
k3k
kDk
k3k
""")
CH_HEM_A = part("""
......k33333333333k.....
......k33333333333k.....
......k3D3333333D3k.....
......k33k333k333lk.....
......kkk.kkk.kkkGk.....
""")
CH_HEM_B = part("""
......k33333333333k.....
......k33333333333k.....
......k3D3333333D3k.....
......kk333k333k3lk.....
.......kkk.kkk.kkGk.....
""")


def choir_frames():
    def f(hem=CH_HEM_A, dy=0, mouth=0, arms="down", glow=False):
        robe = CH_ROBE_ARMS_UP if arms == "up" else CH_ROBE
        layers = [(hem, 0, 17), (robe, 0, 9 + dy), (choir_head(mouth, glow), 0, dy)]
        if arms == "up":
            layers.append((CH_ARM_L, 4, 8 + dy))
            layers.append((CH_ARM_R, 18, 8 + dy))
        return stack(*layers)
    idle = [f(), f(dy=1), f(hem=CH_HEM_B), f(hem=CH_HEM_B, dy=1)]
    walk = [f(hem=CH_HEM_B, dy=-1), f(), f(hem=CH_HEM_B, dy=-1), f(dy=1)]
    windup = [f(mouth=1, arms="up", dy=-1), f(mouth=2, arms="up", dy=-1, glow=True)]
    attack = [f(mouth=3, arms="up", dy=1, glow=True), f(mouth=3, arms="up", dy=1, glow=True, hem=CH_HEM_B)]
    hurt = [shift(f(mouth=1), -2, 0)]
    return idle + walk + windup + attack + hurt + person_death(f())


# =============================================================================
# THE NETTED (Flats elite).  A fisherman who came back up inside his own net: the mesh over his
# head and shoulders, corks along its hem, a Slate fisher's coat.
# =============================================================================
NT_HEAD = part("""
........................
........................
.........kkkkkk.........
........kPbbbbbk........
.......kbbbbbbbbk.......
.......kbbFFFFbbk.......
.......kbFFkFkFbk.......
........kmFFFFmk........
.........kFFFFk.........
""")
NT_TORSO = part("""
.......kP3333333k.......
......k33l222222k.......
......k33222222233k.....
......k33222222233k.....
......k33222222233k.....
......k33222222233k.....
......kFF2222222FFk.....
......kkk2222222kkk.....
""")
NT_TORSO_UP = part("""
.......kP3333333k.......
......k33l222222k.......
......k33222222233k.....
......k33222222233k.....
......k33222222233k.....
......k33222222233k.....
......k332222222233k....
......kkk2222222kkk.....
""")
NT_ARM_UP = grid("""
kFk
k3k
k3k
k3k
""")


def net_mesh(w, h, corks=True):
    """A rope lattice, corks along the bottom edge."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y in range(h):
        for x in range(w):
            if (x + y) % 2 == 0 and ((x % 4 == y % 4) or (x % 4 == (4 - y % 4) % 4)):
                px[x, y] = rgba("ROPE")
    if corks:
        for x in range(1, w, 4):
            px[x, h - 1] = rgba("BONE")
    return im


NT_MESH = net_mesh(13, 10)
NT_BUNDLE = grid("""
.krrrk.
krBrBrk
.krrrk.
""")
NT_FLUNG = net_mesh(8, 8)


def netted_frames():
    def f(legs="stand", dy=0, arms="down", mesh=True, bundle=False, flung=False):
        torso = NT_TORSO_UP if arms == "up" else NT_TORSO
        layers = [(LEGS[legs], 0, 17), (torso, 0, 9 + dy), (NT_HEAD, 0, dy)]
        if mesh:
            layers.append((NT_MESH, 6, 3 + dy))
        if arms == "up":
            layers.append((NT_ARM_UP, 5, 5 + dy))
            layers.append((NT_ARM_UP, 17, 5 + dy))
        if bundle:
            layers.append((NT_BUNDLE, 9, 1 + dy))
        if flung:
            layers.append((NT_FLUNG, 16, 8 + dy))
        return stack(*layers)
    idle = [f(), f(dy=1), f(), f(dy=1)]
    walk = [f(legs="w1"), f(legs="w2", dy=1), f(legs="w3"), f(legs="w6", dy=1)]
    windup = [f(arms="up", bundle=True), f(arms="up", bundle=True, dy=-1)]
    attack = [f(arms="up", flung=True, dy=1), shift(f(arms="up", flung=True, dy=1), 1, 0)]
    hurt = [shift(f(), -2, 0)]
    return idle + walk + windup + attack + hurt + person_death(f())


# =============================================================================
# THE CHAINMOTHER, 48x48.  Painted with rectangles, then outlined in Ink.
# =============================================================================
BW = 48


def canvas():
    return Image.new("RGBA", (BW, BW), (0, 0, 0, 0))


def rect(im, x0, y0, x1, y1, key):
    d = ImageDraw.Draw(im)
    d.rectangle([x0, y0, x1, y1], fill=rgba(key))


def pxs(im, key, *pts):
    px = im.load()
    for x, y in pts:
        if 0 <= x < im.width and 0 <= y < im.height:
            px[x, y] = rgba(key)


def outline(im):
    """A 1 px Ink outline around everything opaque (STYLE.md 3)."""
    out = im.copy()
    px = im.load()
    op = out.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < im.width and 0 <= ny < im.height and px[nx, ny][3]:
                    op[x, y] = rgba("INK")
                    break
    return out


def chain_v(im, x, y0, y1, hook=True):
    for y in range(y0, y1 + 1):
        pxs(im, "IRON" if (y - y0) % 2 == 0 else "IRON_LIGHT", (x, y))
    if hook:
        pxs(im, "IRON_LIGHT", (x, y1 + 1), (x + 1, y1 + 1), (x + 1, y1))


def chain_h(im, x0, x1, y):
    for x in range(x0, x1 + 1):
        pxs(im, "IRON" if (x - x0) % 2 == 0 else "IRON_LIGHT", (x, y))


def crane(dy=0, legs="stand", chains="hang", windows="lit", jib_dy=0, cab_dy=0, phase=False, crumple=0):
    im = canvas()
    cy = dy + cab_dy
    # --- the jib: an iron beam with a raised arm at each end and a hook chain under each arm
    jy = 3 + dy + jib_dy
    rect(im, 7, jy, 40, jy + 1, "IRON")
    pxs(im, "IRON_LIGHT", *[(x, jy) for x in range(7, 41, 3)])
    rect(im, 5, jy - 2, 8, jy + 1, "IRON_DARK")     # the arms
    rect(im, 39, jy - 2, 42, jy + 1, "IRON_DARK")
    pxs(im, "IRON_LIGHT", (5, jy - 2), (6, jy - 2), (41, jy - 2), (42, jy - 2))
    rect(im, 13, jy + 2, 14, jy + 6, "IRON_DARK")   # posts down into the cab
    rect(im, 33, jy + 2, 34, jy + 6, "IRON_DARK")
    pxs(im, "IRON", (13, jy + 2), (33, jy + 2))
    if chains == "hang":
        chain_v(im, 5, jy + 2, jy + 9)
        chain_v(im, 42, jy + 2, jy + 9)
    elif chains == "up":
        chain_v(im, 5, jy + 2, jy + 4)
        chain_v(im, 42, jy + 2, jy + 4)
    elif chains == "out":
        chain_h(im, 0, 6, jy)
        chain_h(im, 41, 47, jy)
        pxs(im, "IRON_LIGHT", (0, jy + 1), (1, jy + 1), (46, jy + 1), (47, jy + 1))
    # --- the cab: a tarred housing with wood strakes, iron bands, rust under the rivets
    top, bot = 10 + cy, 27 + cy
    rect(im, 9, top, 38, bot, "TAR")
    for y in (top + 3, top + 7, top + 11, top + 15):
        rect(im, 10, y, 37, y, "WOOD")
        pxs(im, "WOOD_LIGHT", *[(x, y) for x in range(11, 37, 5)])
    rect(im, 9, top + 1, 38, top + 1, "IRON_DARK")
    rect(im, 9, bot - 1, 38, bot - 1, "IRON_DARK")
    for x in range(11, 38, 4):
        pxs(im, "IRON_LIGHT", (x, top + 1), (x, bot - 1))
    for x in (11, 23, 35):
        pxs(im, "RUST", (x, top + 2), (x, top + 3))
        pxs(im, "RUST_LIGHT", (x, top + 2))
    pxs(im, "RUST", (15, bot - 2), (16, bot - 2), (30, bot - 3), (30, bot - 2))
    # a rope fender on the near corner
    pxs(im, "ROPE", (9, bot - 4), (10, bot - 4), (9, bot - 3), (10, bot - 3), (11, bot - 3))
    # --- the windows: the one warm lamp the Harbour allows, her eyes
    for wx in (14, 28):
        rect(im, wx, top + 5, wx + 5, top + 10, "IRON_DARK")
        if windows == "lit":
            rect(im, wx + 1, top + 6, wx + 4, top + 9, "AMBER_DEEP")
            rect(im, wx + 1, top + 7, wx + 4, top + 8, "WARM_YELLOW")
            pxs(im, "WARM_YELLOW", (wx + 2, top + 6), (wx + 3, top + 6), (wx + 2, top + 9), (wx + 3, top + 9))
            pxs(im, "PALE_CREAM", (wx + 2, top + 7), (wx + 3, top + 7))
            if phase:
                rect(im, wx + 2, top + 7, wx + 3, top + 8, "PALE_CREAM")
                pxs(im, "AMBER", (wx, top + 5), (wx + 5, top + 5), (wx, top + 10), (wx + 5, top + 10))
        else:
            rect(im, wx + 1, top + 6, wx + 4, top + 9, "NIGHT_2")
            pxs(im, "SLATE", (wx + 2, top + 7))
    # --- the chassis
    rect(im, 11, bot + 1, 36, bot + 2, "IRON_DARK")
    pxs(im, "IRON", *[(x, bot + 1) for x in range(12, 36, 4)])
    # --- four iron piles, feet on row 45
    lift = {"stand": (0, 0), "a": (2, 0), "b": (0, 2)}[legs]
    for i, lx in enumerate((11, 19, 27, 35)):
        up = lift[i % 2] - (crumple if i in (0, 3) else 0)
        y0 = bot + 3
        y1 = 45 - up
        if crumple:
            y1 = 45
            y0 = min(45, y0 + crumple)
        rect(im, lx, y0, lx + 2, y1, "IRON_DARK")
        rect(im, lx, y0, lx, y1, "IRON")
        pxs(im, "IRON_LIGHT", (lx, y0 + 2), (lx, y0 + 6))
        rect(im, lx - 1, y1, lx + 3, y1, "IRON_DARK")
        pxs(im, "RUST", (lx + 1, y1 - 2), (lx + 2, y1 - 3))
    return outline(im)


def crane_fallen(stage):
    """Death: the piles buckle, the cab drops onto them, the jib falls across the top."""
    im = canvas()
    drop = (6, 12, 14)[stage]
    top = 10 + drop
    bot = min(44, 27 + drop)
    # legs splayed under it
    for lx, tilt in ((6, -1), (17, 0), (29, 0), (40, 1)):
        for y in range(bot - 2, 46):
            x = lx + (y - bot) * tilt // 3
            pxs(im, "IRON_DARK", (x, y), (x + 1, y), (x + 2, y))
            pxs(im, "IRON", (x, y))
    rect(im, 9, top, 38, bot, "TAR")
    for y in range(top + 3, bot - 1, 4):
        rect(im, 10, y, 37, y, "WOOD")
    rect(im, 9, top + 1, 38, top + 1, "IRON_DARK")
    for x in range(11, 38, 4):
        pxs(im, "IRON_LIGHT", (x, top + 1))
    for wx in (14, 28):
        rect(im, wx, top + 5, wx + 5, top + 10, "IRON_DARK")
        rect(im, wx + 1, top + 6, wx + 4, top + 9, "NIGHT_2")
        if stage == 0:
            pxs(im, "AMBER_DEEP", (wx + 2, top + 7), (wx + 3, top + 8))
    # the jib slides off to the side and down
    jx = 4 + stage * 3
    jy = top - 4 + stage * 2
    for i in range(34):
        x = jx + i
        y = jy + i * (stage + 1) // 12
        pxs(im, "IRON", (x, y), (x, y + 1))
    chain_v(im, jx + 1, jy + 2, jy + 6, hook=False)
    return outline(im)


def chainmother_frames():
    idle = [crane(), crane(dy=1), crane(), crane(dy=1, chains="hang")]
    walk = [crane(legs="a"), crane(legs="a", dy=1), crane(legs="b"), crane(legs="b", dy=1)]
    windup = [crane(chains="up", jib_dy=-1), crane(chains="up", jib_dy=-2, cab_dy=-1)]
    attack = [crane(chains="out", cab_dy=1), crane(chains="out", cab_dy=1, dy=1)]
    hurt = [crane(windows="dark", cab_dy=1)]
    phase = [crane(phase=True, jib_dy=1)]
    intro = [crane(windows="dark")]
    death = [crane(windows="dark", crumple=4, cab_dy=4), crane_fallen(1), crane_fallen(2)]
    return idle + walk + windup + attack + hurt + phase + intro + death


# =============================================================================
# The small things: the dropped anchor, the wax pool, the wisp's shot, the Shade's bolt.
# =============================================================================
ANCHOR_DROP = """
..........kkkk..........
.........krrrrk.........
.........kr..rk.........
.........krrrrk.........
..........khhk..........
..........kIik..........
.......kkkkIikkkk.......
.......kiiiIiiiik.......
.......kkkkIikkkk.......
..........kIik..........
..........kIik..........
..........kIik..........
..........kIik..........
..kkk.....kIik.....kkk..
.kIIhk....kIik....khIIk.
.kIhhk....kIik....khhIk.
..kIhk....kIik....khIk..
..kIhhk...kIik...khhIk..
...kIhhkkkkIikkkkhhIk...
....kIhhhhhIiihhhhIk....
.....kkIIIIIiiIIIkk.....
.......kkkkkkkkkkk......
........................
........................
"""
WISP_SHOT = """
.PP.
PWWP
PWWP
.PP.
"""


def wax_pool():
    """40x28: a pool of burning wax on the floor. Bone light body, a Bone rim, a darker south
    edge, and a few Warm yellow points where it still burns."""
    im = Image.new("RGBA", (40, 28), (0, 0, 0, 0))
    px = im.load()
    cx, cy, rx, ry = 19.5, 13.5, 19.0, 12.0
    for y in range(28):
        for x in range(40):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d <= 1.0:
                if d > 0.78:
                    px[x, y] = rgba("BONE_DARK") if y > cy else rgba("BONE")
                else:
                    px[x, y] = rgba("BONE_LIGHT")
    for x, y in ((9, 12), (18, 8), (28, 13), (13, 19), (24, 20), (33, 16)):
        px[x, y] = rgba("WARM_YELLOW")
        px[x + 1, y] = rgba("AMBER")
        px[x, y - 1] = rgba("PALE_CREAM")
    return im


SHADE_BOLT_MAP = {
    "IRON_DARK": "NIGHT_1", "IRON": "NIGHT_2", "IRON_LIGHT": "SLATE", "BONE_DARK": "SLATE", "BONE": "PALE_SLATE",
    "BONE_LIGHT": "PALE_SLATE", "ROPE": "NIGHT_2", "WEATHERED_BROWN": "NIGHT_1", "WOOD": "NIGHT_2", "WOOD_LIGHT": "SLATE",
}


def shade_bolt():
    """Tam's bolt in the Night ramp: what the Keeper's Shade fires (STYLE.md 14, Stage 19)."""
    bolt = Image.open(os.path.join(SPRITES, "harpoon_bolt.png")).convert("RGBA")
    swap = {P.rgb(a): P.rgb(b) for a, b in SHADE_BOLT_MAP.items()}
    return recolour(bolt, swap)


# =============================================================================
def main():
    os.makedirs(SPRITES, exist_ok=True)
    os.makedirs(REF, exist_ok=True)
    built = {
        "mooring": mooring_frames(),
        "deckhand": deckhand_frames(),
        "barnacle": barnacle_frames(),
        "barnacle_small": barnacle_frames(small=True),
        "tallow": tallow_frames(),
        "choir": choir_frames(),
        "netted": netted_frames(),
    }
    for name, frames in built.items():
        assert len(frames) == 16, (name, len(frames))
        if name in gen_rim.DROWNED:       # the wet crown (STYLE.md 18, Stage 20)
            gen_rim.crown(frames)
        strip(frames).save(os.path.join(SPRITES, name + ".png"))
    boss = chainmother_frames()
    assert len(boss) == 18
    strip(boss, BW, BW).save(os.path.join(SPRITES, "chainmother.png"))
    grid(ANCHOR_DROP, 24, 24).save(os.path.join(SPRITES, "anchor_drop.png"))
    grid(WISP_SHOT, 4, 4).save(os.path.join(SPRITES, "wisp_shot.png"))
    wax_pool().save(os.path.join(SPRITES, "wax.png"))
    shade_bolt().save(os.path.join(SPRITES, "shade_bolt.png"))

    # review sheet
    try:
        font = ImageFont.load_default(size=11)
        small = ImageFont.load_default(size=9)
    except TypeError:
        font = small = ImageFont.load_default()
    floors = {"mooring": "WOOD", "deckhand": "WOOD", "barnacle": "SAND_DARK", "barnacle_small": "SAND_DARK",
              "tallow": "BASALT", "choir": "STONE", "netted": "SAND"}
    labels = ["idle"] * 4 + ["walk"] * 4 + ["windup", "windup", "attack", "attack", "hurt", "death", "death", "death"]
    Z = 4
    W = 12 + 18 * (BW * 3 + 4) + 12
    sheet = Image.new("RGBA", (W, 12 + 7 * (CELL * Z + 40) + (BW * 3 + 60) + 160), (30, 33, 42, 255))
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "EBB enemies B  -  Stage 19  -  the post-brief six on the 16-frame layout at 4x, the Chainmother at 48 px (3x), the small things",
           fill=P.rgb("SALT_WHITE"), font=font)
    y = 26
    for name, frames in built.items():
        d.text((12, y), name, fill=P.rgb("SALT_WHITE"), font=font)
        y += 14
        for i, f in enumerate(frames):
            bg = Image.new("RGBA", (CELL, CELL), P.rgba(floors[name]))
            bg.alpha_composite(f)
            sheet.alpha_composite(zoom(bg, Z), (12 + i * (CELL * Z + 4), y))
            d.text((12 + i * (CELL * Z + 4), y + CELL * Z + 2), "%d %s" % (i, labels[i]), fill=P.rgb("PALE_SLATE"), font=small)
        y += CELL * Z + 26
    d.text((12, y), "chainmother.png 48x48 x 18 over deck (3x)", fill=P.rgb("SALT_WHITE"), font=font)
    y += 14
    blabels = labels[:13] + ["phase", "intro", "death", "death", "death"]
    for i, f in enumerate(boss):
        bg = Image.new("RGBA", (BW, BW), P.rgba("WOOD"))
        bg.alpha_composite(f)
        sheet.alpha_composite(zoom(bg, 3), (12 + i * (BW * 3 + 4), y))
        d.text((12 + i * (BW * 3 + 4), y + BW * 3 + 2), "%d %s" % (i, blabels[i]), fill=P.rgb("PALE_SLATE"), font=small)
    y += BW * 3 + 30
    x = 12
    for name, im, bgk in (("anchor_drop 24", grid(ANCHOR_DROP, 24, 24), "WOOD"), ("wax 40x28", wax_pool(), "BASALT"),
                          ("wisp_shot 4", grid(WISP_SHOT, 4, 4), "SAND"), ("shade_bolt 14x4", shade_bolt(), "BASALT"),
                          ("the harpoon bolt, for the difference", Image.open(os.path.join(SPRITES, "harpoon_bolt.png")).convert("RGBA"), "BASALT")):
        bg = Image.new("RGBA", (im.width + 4, im.height + 4), P.rgba(bgk))
        bg.alpha_composite(im, (2, 2))
        sheet.alpha_composite(zoom(bg, 4), (x, y))
        d.text((x, y + bg.height * 4 + 2), name, fill=P.rgb("PALE_SLATE"), font=small)
        x += bg.width * 4 + 24
    sheet.convert("RGB").save(os.path.join(REF, "enemies_b_sheet.png"))
    print("wrote", ", ".join(built), "chainmother, anchor_drop, wax, wisp_shot, shade_bolt; enemies_b_sheet.png")


if __name__ == "__main__":
    main()
