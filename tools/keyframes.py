"""Stage 21: the four biome keyframes, the final visual references for the project.

Each is a frame of the real game at 640x360 (the screenshots come out at the window's
integer scale and are reduced by exact block sampling; the script checks that every block
was uniform, so the reference is the game's own pixels). They come from the run scene's
`--keyframe` dev aid (Tam mid-room, a full wave closing in, the fight's effects) and the
hub as it stands.

    assets/reference/keyframes/marrow_rock.png    the hub at dusk: the people, the beam, the tide
    assets/reference/keyframes/flats.png          a wet Flats room at a moderate tide: sand, pools, foam
    assets/reference/keyframes/streets.png        the Streets flooded to the doors (the flooding keyframe)
    assets/reference/keyframes/hall.png           the Hall's channels lit, a Tallow and his wax
    assets/reference/anchors/keyframes_sheet.png  the four at 1x on one sheet

To retake one: run the command in SHOTS below, then `python tools/keyframes.py`.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402

SHOTS = os.path.join(P.ROOT, ".shots")
OUT = os.path.join(P.ROOT, "assets", "reference", "keyframes")
REF = os.path.join(P.ROOT, "assets", "reference", "anchors")

# name -> (screenshot in .shots, the command that made it, one line on what it shows)
FRAMES = [
    ("marrow_rock", "k21_hub.png",
     "hub.tscn -- --screenshot --sim-save --wait=200",
     "Marrow Rock: the twelve people, the lighthouse beam across the sand, the tide at the dock, Tam's lantern"),
    ("flats", "k21_flats_t08_21.png",
     "run.tscn -- --screenshot --sim-save --biome=0 --first=combat --keyframe --wet --tide=0.8 --seed=21 --wait=30",
     "The Flats: warm-grey sand, four foam-edged pools and a wet strip, a wave of crabs, shellbacks and gulls, the arc and the cue"),
    ("streets", "k21_streets_a.png",
     "run.tscn -- --screenshot --sim-save --biome=2 --first=combat --keyframe --wet --seed=21 --wait=30",
     "The Drowned Streets flooded to the doors: shallow water over cobbles, a lit lamplighter, citizens, Tam's arc (the flooding keyframe)"),
    ("hall", "k21_hall_a.png",
     "run.tscn -- --screenshot --sim-save --biome=3 --first=combat --keyframe --seed=21 --wait=30",
     "The Deep Hall: basalt, the lit channels, a Tallow on the walk with his wax pool, still citizens in the water"),
]


def reduce_exact(im):
    """Reduce a screenshot taken at an integer window scale to 640x360 by sampling one
    pixel per block, and report how many blocks were not uniform (0 when the window was
    an exact integer scale)."""
    s = im.width // 640
    assert im.width == 640 * s and im.height == 360 * s, im.size
    if s == 1:
        return im, 0
    px = im.load()
    out = Image.new("RGB", (640, 360))
    op = out.load()
    bad = 0
    for y in range(360):
        for x in range(640):
            c = px[x * s, y * s]
            op[x, y] = c
            if px[x * s + s - 1, y * s + s - 1] != c or px[x * s + s // 2, y * s + s // 2] != c:
                bad += 1
    return out, bad


def main():
    os.makedirs(OUT, exist_ok=True)
    frames = []
    for name, shot, cmd, blurb in FRAMES:
        im = Image.open(os.path.join(SHOTS, shot)).convert("RGB")
        small, bad = reduce_exact(im)
        small.save(os.path.join(OUT, name + ".png"))
        frames.append((name, small, blurb))
        print("%-12s <- %-22s  %d/230400 blocks not uniform" % (name, shot, bad))
    try:
        font = ImageFont.load_default(size=11)
        small = ImageFont.load_default(size=9)
    except TypeError:
        font = small = ImageFont.load_default()
    sheet = Image.new("RGB", (640 * 2 + 36, 360 * 2 + 80), (30, 33, 42))
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "EBB keyframes  -  Stage 21  -  the four places at 1x, frames of the real game (HUD, Tam, a wave, water, light, effects)",
           fill=P.rgb("SALT_WHITE"), font=font)
    for i, (name, im, blurb) in enumerate(frames):
        x = 12 + (i % 2) * (640 + 12)
        y = 28 + (i // 2) * (360 + 26)
        sheet.paste(im, (x, y))
        d.text((x, y + 362), blurb, fill=P.rgb("PALE_SLATE"), font=small)
    sheet.save(os.path.join(REF, "keyframes_sheet.png"))
    print("wrote keyframes/ and keyframes_sheet.png")


if __name__ == "__main__":
    main()
