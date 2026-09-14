"""Draws the Windows icon: the lighthouse from icon.svg, at every size Windows asks for.

The .ico goes on the installer, on the desktop shortcut, and inside EBB.exe itself.
Run:  python tools/gen_icon.py
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "installer", "ebb.ico")
SIZES = [256, 128, 64, 48, 32, 24, 16]
SS = 8  # supersample: draw big, shrink down, so the curves stay smooth

NIGHT = (24, 20, 37)
DEEP = (60, 100, 130)
SHALLOW = (90, 150, 180)
STONE = (230, 220, 200)
CAP = (196, 76, 60)
LAMP = (250, 210, 90)


def draw(px: int) -> Image.Image:
    """One frame at `px` pixels, drawn in the 128-unit space icon.svg uses."""
    n = px * SS
    u = n / 128.0  # one SVG unit in pixels
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Night sky, corners rounded the way the svg rounds them.
    d.rounded_rectangle([0, 0, n - 1, n - 1], radius=16 * u, fill=NIGHT)

    # Two waves across the bottom. The svg draws them as a chain of quadratics that
    # reflect their control points, which is a sine: period 64 units, crest 6 then 5.
    for mid, amp, colour in ((84.0, 6.0, DEEP), (100.0, 5.0, SHALLOW)):
        pts = []
        for i in range(n + 1):
            x = i / u
            pts.append((i, (mid - amp * math.sin(x * math.pi / 32.0)) * u))
        d.polygon(pts + [(n, n), (0, n)], fill=colour)

    # The tower, its cap, and the light.
    d.rectangle([52 * u, 24 * u, 76 * u - 1, 84 * u], fill=STONE)
    d.rectangle([48 * u, 16 * u, 80 * u - 1, 28 * u], fill=CAP)
    d.ellipse([(64 - 5) * u, (22 - 5) * u, (64 + 5) * u, (22 + 5) * u], fill=LAMP)

    # Mask the corners back out: the waves and the tower were drawn over them.
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, n - 1, n - 1], radius=16 * u, fill=255)
    img.putalpha(mask)
    return img.resize((px, px), Image.LANCZOS)


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    frames = [draw(s) for s in SIZES]
    frames[0].save(OUT, format="ICO", sizes=[(s, s) for s in SIZES], append_images=frames[1:])
    print("wrote %s (%d sizes, %d bytes)" % (OUT, len(SIZES), os.path.getsize(OUT)))


if __name__ == "__main__":
    main()
