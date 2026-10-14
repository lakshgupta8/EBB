"""Map Stage 11k: the Reef's echo, Hale the Mason, drawn the way tools/gen_people.py draws the
people of Marrow Rock (STYLE.md 7, 18).

Hale laid stone on Saltmere's sea wall. Drowned: Drowned skin on the face and hands only, a
Wool cap with the Sea pale rim of the wet crown, one strand of kelp at the collar, calm eyes;
a Weathered brown leather apron over a Slate shirt, Iron dark boots, a trowel in the right hand.
Two frames: the drowned drip (a Sea pale drop from the hem).

Writes assets/sprites/npc_mason.png (2 x 24x24) and Hale's portrait into
assets/sprites/portraits.png as cell 12 (Prop.PORTRAIT "mason"): appended once, replaced on
every run after, so the other twelve portraits are never touched. Review sheet
assets/reference/maps/s11k_mason.png.

Run:  python tools/gen_reef_people.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
from gen_anchors import grid, zoom  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")
REF = os.path.join(P.ROOT, "assets", "reference", "maps")
CELL = 24
PORTRAIT_INDEX = 12   # after the merchant (Prop.PORTRAIT)

HALE = """
........................
........................
.........kkkkkk.........
........kPwwwwwk........
.......kwwwwwwwwk.......
.......kbbFFFFbbk.......
.......kbFFkFkFbk.......
........kmFFFFmk........
.........kFFFFk.........
.......kl33333333k......
......k3333333333k......
......k33RRRRRR33k......
......k3RRRRRRRR3kkk....
......kFRRrRRrRRFkIk....
......kkRRRRRRRRkkIk....
.......kRRRRRRRRkkiik...
.......kRRRRRRRRk.kk....
.......k333k333k........
.......k333k333k........
.......khhhkhhhk........
.......khhhkhhhk........
.......kkkkkkkkk........
........................
........................
"""

HALE_PORTRAIT = """
.....kkkkkk.....
....kPwwwwwk....
...kwwwwwwwwk...
..kwwwwwwwwwwk..
..kbbFFFFFFbbk..
..kbFFFFFFFFbk..
..kbFFkFFkFFbk..
..kbmFFFFFFmbk..
...kmFFFFFFmk...
....kFFFFFFk....
...kl3FFFF33k...
..k33RRRRRR33k..
.k333RrRRrR333k.
.k333RRRRRR333k.
k3333RRRRRR3333k
kkkkkkkkkkkkkkkk
"""


def g(text, w, h):
    rows = text.strip("\n").split("\n")
    assert len(rows) == h, "%d rows" % len(rows)
    for i, r in enumerate(rows):
        assert len(r) == w, "row %d is %d wide" % (i, len(r))
    return grid(text, w, h)


def main():
    f1 = g(HALE, 24, 24)
    f2 = f1.copy()
    f2.putpixel((16, 22), P.rgb("SEA_PALE") + (255,))   # the drowned drip
    sheet = Image.new("RGBA", (48, 24), (0, 0, 0, 0))
    sheet.alpha_composite(f1, (0, 0))
    sheet.alpha_composite(f2, (24, 0))
    sheet.save(os.path.join(SPRITES, "npc_mason.png"))

    portrait = g(HALE_PORTRAIT, 16, 16)
    path = os.path.join(SPRITES, "portraits.png")
    old = Image.open(path).convert("RGBA")
    width = max(old.width, (PORTRAIT_INDEX + 1) * 16)
    out = Image.new("RGBA", (width, 16), (0, 0, 0, 0))
    out.alpha_composite(old.crop((0, 0, min(old.width, PORTRAIT_INDEX * 16), 16)), (0, 0))
    out.alpha_composite(portrait, (PORTRAIT_INDEX * 16, 0))
    if old.width > (PORTRAIT_INDEX + 1) * 16:
        out.alpha_composite(old.crop(((PORTRAIT_INDEX + 1) * 16, 0, old.width, 16)), ((PORTRAIT_INDEX + 1) * 16, 0))
    out.save(path)

    try:
        font = ImageFont.load_default(size=11)
    except TypeError:
        font = ImageFont.load_default()
    ref = Image.new("RGBA", (12 + 3 * (24 * 6 + 12), 24 * 6 + 40), (30, 33, 42, 255))
    d = ImageDraw.Draw(ref)
    d.text((12, 8), "EBB - map Stage 11k - Hale the Mason, the Reef's echo: two frames and the portrait at 6x",
           fill=P.rgb("SALT_WHITE"), font=font)
    for i, im in enumerate((f1, f2, portrait)):
        bg = Image.new("RGBA", (24, 24), P.rgba("STONE"))
        bg.alpha_composite(im, ((24 - im.width) // 2, (24 - im.height) // 2))
        ref.alpha_composite(zoom(bg, 6), (12 + i * (24 * 6 + 12), 28))
    os.makedirs(REF, exist_ok=True)
    ref.convert("RGB").save(os.path.join(REF, "s11k_mason.png"))
    print("wrote npc_mason.png, portraits.png cell %d, s11k_mason.png" % PORTRAIT_INDEX)


if __name__ == "__main__":
    main()
