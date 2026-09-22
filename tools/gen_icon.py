"""The icon (art Stage 23, the user's call): the logo's lighthouse on the tide line as a
pixel mark, at every size Windows asks for.

    installer/ebb.ico   16, 24, 32, 48, 64, 128, 256 (the installer, the shortcut, inside EBB.exe)
    icon.png            256x256, the project icon (the window and the editor)

Two grids, 16 and 24, drawn on the palette (STYLE.md 9): a Night 1 plate with its corners
cut, the whitewashed tower on its rock, the lamp lit, the sea at the foot with a foam line,
the lamp's road on the water. Every other size is one of the two at an integer scale, so
nothing is smoothed. Run:  python tools/gen_icon.py
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
from gen_anchors import grid, zoom  # noqa: E402

ROOT = P.ROOT
OUT = os.path.join(ROOT, "installer", "ebb.ico")
SIZES = [256, 128, 64, 48, 32, 24, 16]

# 1 Night 1, 2 Night 2, E Deep sea, e Sea, S Shallow, Z Foam white, W Salt white,
# 6 Pale slate, 5 Wet grey, 3 Slate, h Iron dark, i Iron, y Warm yellow, c Pale cream,
# @ Amber deep, a Amber, t Stone dark, T Stone, k Ink.
MARK16 = """
.11111111111111.
1111111111111111
111111hyyh111111
111111hcyh111111
111111h33h111111
1111111W61111111
1111111W65111111
111111W6651111ZW
11111W66651111Z1
11111W66651111Z1
1111tW666511Z111
111tTTTTTt1Z1111
ZZZZZZZZZZZZZZZZ
eeeee@eeeeeeeeee
EEEEEEEEEEEEEEEE
.EEEEEEEEEEEEEE.
"""

MARK24 = """
..11111111111111111111..
.1111111111111111111111.
111111111111111111111111
111111111hhhh11111111111
111111111hyyh11111111111
111111111hccyh1111111111
111111111hyyyh1111111111
1111111111hhhh1111111111
11111111113333111111111Z
1111111111W66511111111Z1
1111111111W665111111Z111
111111111W66651111111Z11
111111111W6665111111Z111
111111111W66651111111Z11
11111111W666651111Z11111
11111111W66665111111Z111
1111111W6666651111Z11111
111111tTTTTTTTt1111Z1111
11111ttTTTTTTTtt11Z11111
ZZZZZZZZZZZZZZZZZZZZZZZZ
eeeeeeeeee@eeeeeeeeeeeee
eeeeeeeeeeeeeeeeeeeeeeee
.EEEEEEEEEE@EEEEEEEEEEE.
..EEEEEEEEEEEEEEEEEEEE..
"""


def build(px):
    """A frame at `px` pixels: the 24 grid for 24, else the 16 grid at an integer scale."""
    if px == 24:
        return grid(MARK24, 24, 24)
    assert px % 16 == 0, px
    return zoom(grid(MARK16, 16, 16), px // 16)


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    frames = [build(s) for s in SIZES]
    frames[0].save(OUT, format="ICO", sizes=[(s, s) for s in SIZES], append_images=frames[1:])
    build(256).save(os.path.join(ROOT, "icon.png"))
    print("wrote %s (%d sizes, %d bytes) and icon.png" % (OUT, len(SIZES), os.path.getsize(OUT)))


if __name__ == "__main__":
    main()
