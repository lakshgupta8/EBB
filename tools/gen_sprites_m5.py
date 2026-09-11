"""M5 sprites: Fen (village kid) appended to props.png as frame 13.
Imported and run by gen_sprites.py.
"""
import os

from PIL import Image

from gen_sprites import Canvas, PAL, OUT

# Fen: small, brown mop of hair, a coat too big for them.
FEN = """
................
................
.....kkkkkk.....
....kwwwwwwk....
....kwwwwwwk....
....kWffffWk....
....kwfeffek....
....kwFfFFwk....
.....kkkkkk.....
....kCCCCCCk....
...kfCCcCCCfk...
...kkCCcCCCkk...
....kCCcCCCk....
....kbbkkbbk....
....kkk..kkk....
................
"""


def build_props_m5(base):
    n0 = base.width // 16
    im = Image.new("RGBA", (16 * (n0 + 1), 16), (0, 0, 0, 0))
    im.alpha_composite(base, (0, 0))
    c = Canvas(16, 16)
    c.blit(FEN, 0, 0)
    im.alpha_composite(c.im, (16 * n0, 0))
    im.save(os.path.join(OUT, "props.png"))
    return im


# The title logo: EBB in heavy letters with a water line through the lower third,
# and foam breaking on it. 88x30, shown at 2x.
LOGO_LETTERS = """
kkkkkkkkkk...kkkkkkkkk....kkkkkkkkk...
kGGGGGGGGk...kGGGGGGGGk...kGGGGGGGGk..
kGGGGGGGGk...kGGGGGGGGGk..kGGGGGGGGGk.
kGGGkkkkkk...kGGGkkkkGGk..kGGGkkkkGGk.
kGGGk........kGGGk..kGGk..kGGGk..kGGk.
kGGGk........kGGGk..kGGk..kGGGk..kGGk.
kGGGkkkkk....kGGGkkkGGk...kGGGkkkGGk..
kGGGGGGGGk...kGGGGGGGGk...kGGGGGGGGk..
kGGGGGGGGk...kGGGGGGGGGk..kGGGGGGGGGk.
kGGGkkkkk....kGGGkkkkkGGk.kGGGkkkkkGGk
kOOOk........kOOOk...kOOk.kOOOk...kOOk
kOOOk........kOOOk...kOOk.kOOOk...kOOk
kOOOkkkkkk...kOOOkkkkkOOk.kOOOkkkkkOOk
kQQQQQQQQQk..kQQQQQQQQQk..kQQQQQQQQQk.
kQQQQQQQQQk..kQQQQQQQQk...kQQQQQQQQk..
kkkkkkkkkkk..kkkkkkkkkk...kkkkkkkkkk..
"""


def build_logo():
    import gen_sprites_m4b  # noqa: F401  (registers O and Q in the palette)
    PAL.setdefault("O", (120, 170, 210))
    PAL.setdefault("Q", (60, 90, 130))
    w, h = 88, 30
    c = Canvas(w, h)
    c.blit(LOGO_LETTERS, 25, 4)
    # water line with foam under the letters
    for x in range(w):
        y = 22 + (1 if (x // 6) % 2 == 0 else 0)
        c.px(x, y, "u", 170)
        if x % 9 in (2, 3):
            c.px(x, y - 1, "U", 200)
        c.px(x, y + 1, "O", 120)
    c.im.save(os.path.join(OUT, "logo.png"))
    return c.im


def build_all(built):
    built["props"] = build_props_m5(built["props"])
    built["logo"] = build_logo()
