"""M6e sprites: the Tidewisp (flats), the Netted and the Choir (named elites), Tallow
(the hall), and the wax pool Tallow leaves. Imported by gen_sprites.py.
"""
import math
import os

from PIL import Image

import gen_sprites as G
from gen_sprites import Canvas, PAL, sheet, OUT

PAL["%"] = (140, 220, 230)   # wisp core
PAL["<"] = (70, 150, 180)    # wisp edge
PAL[">"] = (40, 90, 120)     # wisp dark
PAL["{"] = (196, 178, 140)   # tallow wax
PAL["}"] = (232, 220, 186)   # tallow wax light
PAL["["] = (150, 126, 92)    # tallow wax dark
PAL["]"] = (255, 170, 70)    # tallow flame
PAL["/"] = (108, 84, 120)    # choir robe
PAL["\\"] = (150, 122, 166)  # choir robe light
PAL["|"] = (198, 186, 210)   # choir pale skin


# ----------------------------------------------------------------------------- tidewisp (a light over the water)
def wisp_frame(bob=0, squash=0, cast=False, hurt=False):
    c = Canvas()
    cx, cy = 12, 10 + bob
    # core: a soft diamond of light
    r = 4 + squash
    for y in range(-r - 1, r + 2):
        for x in range(-r - 2, r + 3):
            d = abs(x) * 0.7 + abs(y)
            if d <= r - 1.5:
                c.px(cx + x, cy + y, "1" if not hurt else "2")
            elif d <= r:
                c.px(cx + x, cy + y, "%")
            elif d <= r + 1.2:
                c.px(cx + x, cy + y, "<")
            elif d <= r + 2.0 and (x + y) % 2 == 0:
                c.px(cx + x, cy + y, ">")
    # two dark eye-slits: it is looking at you
    c.px(cx - 2, cy - 1, "e")
    c.px(cx + 2, cy - 1, "e")
    # tendrils trailing below, drifting
    for k in range(3):
        tx = cx - 3 + k * 3
        for j in range(4 + (k % 2)):
            wob = int(math.sin((j + bob * 2 + k) * 0.9) * 1.5)
            c.px(tx + wob, cy + r + 1 + j, "<" if j < 2 else ">")
    if cast:
        # a bead of light thrown forward
        c.blit("k%k\n%1%\nk%k", 18, cy - 1)
    return c


def build_tidewisp():
    frames = [
        wisp_frame(0),
        wisp_frame(-1),
        wisp_frame(0, 1),
        wisp_frame(-1, -1),
        wisp_frame(-2, 1),          # windup: swells
        wisp_frame(0, -1, cast=True),
        wisp_frame(1, -1, hurt=True),
    ]
    return sheet(frames, "tidewisp.png")


# ----------------------------------------------------------------------------- the Netted (flats elite)
NET_HEAD = """
..kkkkk..
.kfffffk.
kfnnnnnfk
kfnenenfk
kfnnnnnfk
.kfffffk.
..kkkkk..
"""
NET_BODY = """
..kkkkkkk..
.kccccccck.
kcCCCCCCCck
kcCcccccCck
kcCCCCCCCck
.kbbbbbbbk.
"""
NET_MESH = """
.k.k.k.k.k.
k.k.k.k.k.k
.k.k.k.k.k.
k.k.k.k.k.k
.k.k.k.k.k.
"""
NET_ARM = """
kck
kCk
kck
kbk
"""


def netted_frame(legs, dy=0, arm="down", throw=False, hurt=False):
    c = Canvas()
    c.blit(legs, 6, 19)
    c.blit(NET_BODY, 6, 13 + dy)
    c.blit(NET_HEAD, 7, 7 + dy)
    # the net he never got out of, draped over the shoulders
    c.blit(NET_MESH, 6, 12 + dy)
    if arm == "down":
        c.blit(NET_ARM, 4, 14 + dy)
        c.blit(NET_ARM, 17, 14 + dy)
    elif arm == "up":
        c.blit("kck\nkCk\nkck", 17, 9 + dy)
        c.blit(NET_ARM, 4, 14 + dy)
        # a folded net held over the head
        c.blit(".kkkk.\nk.k.k.\n.k.k.k", 15, 5 + dy)
    if throw:
        c.blit("k.k.k.k\n.k.k.k.\nk.k.k.k", 15, 10 + dy)
    for (x, y) in ((9, 9), (13, 16), (8, 18)):
        c.px(x, y + dy, "s")
    if hurt:
        c.px(9, 10 + dy, "r")
        c.px(11, 10 + dy, "r")
    return c


LEGS_A = """
.kbbk.kbbk.
.kbbk.kbbk.
.kkkk.kkkk.
"""
LEGS_B = """
kbbk...kbbk
.kbbk.kbbk.
..kkk.kkk..
"""


def build_netted():
    frames = [
        netted_frame(LEGS_A, 0),
        netted_frame(LEGS_A, -1),
        netted_frame(LEGS_A, 0),
        netted_frame(LEGS_B, -1),
        netted_frame(LEGS_A, -1, arm="up"),
        netted_frame(LEGS_B, 1, arm="up", throw=True),
        netted_frame(LEGS_B, 1, hurt=True),
    ]
    return sheet(frames, "netted.png")


# ----------------------------------------------------------------------------- the Choir (streets elite)
CH_HOOD = """
..kkkkkkk..
.k///////k.
k//|||||//k
k//|e|e|//k
k//|||||//k
.k//|||//k.
..k/////k..
"""
CH_ROBE = """
.kkkkkkkkk.
k/////////k
k/\\\\\\\\\\\\\\/k
k/\\\\\\\\\\\\\\/k
k//////////k
k/////////k
.kkkkkkkkk.
"""


def choir_frame(dy=0, mouth=0, arms="down", hurt=False):
    c = Canvas()
    c.blit(CH_ROBE, 6, 12 + dy)
    c.blit(CH_HOOD, 6, 5 + dy)
    # the mouth: open wider as it sings
    if mouth > 0:
        for j in range(mouth):
            for i in range(3 - j // 2):
                c.px(11 + i, 11 + j + dy, "k")
        c.px(12, 11 + dy, "e")
    if arms == "up":
        c.blit("k/k\nk\\k\nk/k", 3, 11 + dy)
        c.blit("k/k\nk\\k\nk/k", 19, 11 + dy)
    else:
        c.blit("k/k\nk/k\nk\\k\nk/k", 4, 14 + dy)
        c.blit("k/k\nk/k\nk\\k\nk/k", 18, 14 + dy)
    # the hem drifts: it has been underwater three hundred years
    c.blit(".k/k.k/k.", 7, 19 + dy)
    if hurt:
        c.px(10, 9 + dy, "r")
        c.px(14, 9 + dy, "r")
    return c


def build_choir():
    frames = [
        choir_frame(0),
        choir_frame(-1),
        choir_frame(0, 1),
        choir_frame(-1, 1),
        choir_frame(-1, 2, arms="up"),      # windup: the breath before
        choir_frame(1, 4, arms="up"),       # the note
        choir_frame(1, 0, hurt=True),
    ]
    return sheet(frames, "choir.png")


# ----------------------------------------------------------------------------- Tallow (the hall)
TA_HEAD = """
.kkkkkkk.
k{{{{{{{k
k{}}}}}{k
k{}e}e}{k
k{}}}}}{k
.k{{{{{k.
..kkkkk..
"""
TA_BODY = """
..kkkkkkk..
.k{{{{{{{k.
k{}}}}}}}{k
k{}}}}}}}{k
k{{{{{{{{{k
.k[[[[[[[k.
"""


def tallow_frame(dy=0, drip=0, lit=True, pour=False, hurt=False):
    c = Canvas()
    # a puddle of itself, always
    c.blit(".k[[[[[[[k.\nk[[[[[[[[[k\n.kkkkkkkkk.", 6, 19)
    c.blit(TA_BODY, 6, 13 + dy)
    c.blit(TA_HEAD, 7, 7 + dy)
    if lit:
        # the candle still burning on its head
        c.blit("k]k\nk2k\nkYk", 11, 3 + dy)
        c.px(12, 2 + dy, "1")
    # wax running down, further each frame
    for k in range(3):
        x = 8 + k * 4
        for j in range(1 + drip + (k % 2)):
            c.px(x, 18 + j + dy, "[" if j else "{")
    if pour:
        # a sheet of hot wax thrown forward
        c.blit("k]]]]k\nk}}}}k\nk[[[[k", 16, 14 + dy)
    if hurt:
        c.px(10, 10 + dy, "r")
        c.px(14, 10 + dy, "r")
    return c


def build_tallow():
    frames = [
        tallow_frame(0, 0),
        tallow_frame(0, 1),
        tallow_frame(-1, 0),
        tallow_frame(-1, 1),
        tallow_frame(-1, 2),            # windup: it swells
        tallow_frame(1, 2, pour=True),
        tallow_frame(1, 1, lit=False, hurt=True),
    ]
    return sheet(frames, "tallow.png")


WAX_POOL = """
................
................
....kkkkkkk.....
..kk[[[[[[[kk...
.k[[{{{{{{{[[k..
.k[{}}}}}}}{[k..
.k[{}}]]]}}{[k..
.k[{}}]]]}}{[k..
.k[{}}}}}}}{[k..
.k[[{{{{{{{[[k..
..kk[[[[[[[kk...
....kkkkkkk.....
................
................
................
................
"""


def build_wax():
    c = Canvas(16, 16)
    c.blit(WAX_POOL, 0, 0)
    c.im.save(os.path.join(OUT, "wax.png"))
    return c.im


WISP_SHOT = """
.kk.
k%1k
k1%k
.kk.
"""


def build_wisp_shot():
    c = Canvas(4, 4)
    c.blit(WISP_SHOT, 0, 0)
    c.im.save(os.path.join(OUT, "wisp_shot.png"))
    return c.im


def build_all(built):
    built["tidewisp"] = Image.open(os.path.join(OUT, "tidewisp.png")).convert("RGBA")  # art Stage 07 sheet
    built["netted"] = build_netted()
    built["choir"] = build_choir()
    built["tallow"] = build_tallow()
    built["wax"] = build_wax()
    built["wisp_shot"] = build_wisp_shot()
    return built
