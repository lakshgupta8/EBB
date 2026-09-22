"""Stage 22: point every entity scene's Shadow node at its cell of shadow.png (STYLE.md 4)
and drop the node scale. Measures the body width from frame 0 of each sheet.

Run:  python tools/patch_shadows.py
"""
import io
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
from gen_shadow import CELL_W, CELL_H, WIDTHS, cell_for  # noqa: E402

SPRITES = os.path.join(P.ROOT, "assets", "sprites")

# scene -> (sheet, cell size, boss)
SCENES = {
    "src/player/player.tscn": ("player", 24, False),
    "src/enemies/anchor.tscn": ("anchor", 24, False),
    "src/enemies/barnacle.tscn": ("barnacle", 24, False),
    "src/enemies/bell_ringer.tscn": ("bell_ringer", 24, False),
    "src/enemies/choir.tscn": ("choir", 24, False),
    "src/enemies/deckhand.tscn": ("deckhand", 24, False),
    "src/enemies/deep_maw.tscn": ("deep_maw", 24, False),
    "src/enemies/gull.tscn": ("gull", 24, False),
    "src/enemies/keeper_shade.tscn": ("keeper_shade", 24, False),
    "src/enemies/lamplighter.tscn": ("lamplighter", 24, False),
    "src/enemies/mooring.tscn": ("mooring", 24, False),
    "src/enemies/netted.tscn": ("netted", 24, False),
    "src/enemies/shellback.tscn": ("shellback", 24, False),
    "src/enemies/still_citizen.tscn": ("still_citizen", 24, False),
    "src/enemies/swimmer.tscn": ("swimmer", 24, False),
    "src/enemies/tallow.tscn": ("tallow", 24, False),
    "src/enemies/tidewisp.tscn": ("tidewisp", 24, False),
    "src/enemies/wrack_crab.tscn": ("wrack_crab", 24, False),
    "src/enemies/wreck.tscn": ("wreck", 72, True),
    "src/enemies/bell.tscn": ("bell", 48, True),
    "src/enemies/ebb.tscn": ("ebb", 72, True),
    "src/enemies/chainmother.tscn": ("chainmother", 48, True),
}


def body_width(sheet, cell):
    im = Image.open(os.path.join(SPRITES, sheet + ".png")).convert("RGBA")
    bb = im.crop((0, 0, cell, im.height)).getbbox()
    return bb[2] - bb[0]


def main():
    for scene, (sheet, cell, boss) in SCENES.items():
        p = os.path.join(P.ROOT, scene)
        s = io.open(p, encoding="utf-8").read()
        m = re.search(r'\[node name="Shadow" type="Sprite2D" parent="\."\]\n(.*?)(?=\n\[|\Z)', s, re.S)
        assert m, scene
        block = m.group(1)
        lines = [l for l in block.split("\n") if l and not l.startswith("scale = ") and not l.startswith("region_")
                 and not l.startswith("light_mask")]
        w = body_width(sheet, cell)
        i = cell_for(w, boss)
        # The blob sits under the feet (the root is at the feet): rows 1-4, or 2-7 on a boss.
        # The gull and the wisp keep their own offsets (a flyer's shadow is on the floor below).
        if sheet not in ("gull", "tidewisp"):
            lines = [("position = Vector2(0, %d)" % (5 if boss else 3)) if l.startswith("position = ") else l for l in lines]
        # No light reaches it: a shadow is the absence of light, so the lantern must not
        # add to it the way it adds to the floor around it.
        lines.append("light_mask = 0")
        lines.append("region_enabled = true")
        lines.append("region_rect = Rect2(%d, 0, %d, %d)" % (i * CELL_W, CELL_W, CELL_H))
        new_block = "\n".join(lines) + "\n"   # the blank line before the next node stays
        s = s[:m.start(1)] + new_block + s[m.end(1):]
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("%-34s body %2d -> cell %d (%dx%d)" % (scene, w, i, WIDTHS[i][0], WIDTHS[i][1]))


if __name__ == "__main__":
    main()
