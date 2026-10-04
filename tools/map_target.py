"""Map Stage 01: the target schematic. One large Flats combat room (80x46 tiles, two screens
by two) drawn as a labelled plan, to show the shape language STYLE.md 22 asks for: an organic
coast, edges with transition bands, set pieces, clustered decor, world lights, fight pockets
and a route. A plan, not art: flat fills by material, 8 px a tile.
Run:  python tools/map_target.py   -> assets/reference/maps/target_flats_L.png
"""
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "reference", "maps", "target_flats_L.png")
W, H, C = 80, 46, 8
COL = {
    "void": (11, 14, 22), "sea": (38, 72, 94), "deep": (24, 46, 66), "foam": (214, 222, 222),
    "rock": (86, 86, 92), "rockface": (58, 58, 66), "shelf": (122, 118, 112),
    "sand": (176, 160, 128), "sand2": (162, 146, 116), "wet": (128, 116, 96), "pool": (52, 92, 110),
    "wreck": (96, 70, 48), "wreckdk": (58, 40, 30), "kelp": (61, 94, 79), "drift": (120, 96, 72),
    "door": (210, 200, 160), "light": (240, 200, 110), "cold": (150, 200, 210), "text": (240, 236, 220),
    "screen": (240, 236, 220),
}


def blob(cx, cy, r, wob, seed):
    rnd = random.Random(seed)
    ph = [rnd.uniform(0, 6.28) for _ in range(3)]
    def inside(x, y):
        a = math.atan2(y - cy, x - cx)
        rr = r * (1 + wob * (math.sin(3 * a + ph[0]) * 0.5 + math.sin(5 * a + ph[1]) * 0.3 + math.sin(7 * a + ph[2]) * 0.2))
        return math.hypot((x - cx) / 1.35, y - cy) < rr
    return inside


def main():
    rnd = random.Random(4)
    g = [["sand"] * W for _ in range(H)]
    # Coast: the north-west is open sea, the shore a slow curve with a spit.
    for y in range(H):
        for x in range(W):
            coast = 13 + 7 * math.sin(x / 11.0) + 3 * math.sin(x / 4.3 + 1) - (6 if 30 < x < 38 else 0) * (1 - abs(x - 34) / 4)
            if y < coast - 6 + x * 0.05:
                g[y][x] = "deep"
            elif y < coast - 2 + x * 0.05:
                g[y][x] = "sea"
            elif y < coast + x * 0.05:
                g[y][x] = "wet"
    # The rock mass in the east: the room's wall is a cliff, not a rim.
    for y in range(H):
        for x in range(W):
            edge = 66 + 4 * math.sin(y / 5.0) + 2 * math.sin(y / 2.1)
            if x > edge:
                g[y][x] = "rock" if x > edge + 2 else "rockface"
            if y > 41 + 2 * math.sin(x / 6.0):
                g[y][x] = "rock" if y > 43 else "rockface"
    # A raised rock shelf (the dry ground the tide reaches last), with its own wet foot.
    shelf = blob(56, 30, 6.5, 0.25, 2)
    pools = [blob(22, 33, 4.2, 0.35, 5), blob(31, 38, 2.6, 0.4, 6), blob(45, 19, 3.0, 0.3, 7)]
    for y in range(H):
        for x in range(W):
            if g[y][x] != "sand":
                continue
            if shelf(x, y):
                g[y][x] = "shelf"
            elif any(p(x, y) for p in pools):
                g[y][x] = "pool"
    # Transition bands: wet sand around every pool and the sea, two tiles wide, broken.
    src = [row[:] for row in g]
    for y in range(H):
        for x in range(W):
            if src[y][x] != "sand":
                continue
            near = any(src[yy][xx] in ("pool", "sea", "wet")
                       for yy in range(max(0, y - 2), min(H, y + 3)) for xx in range(max(0, x - 2), min(W, x + 3)))
            if near:
                g[y][x] = "wet"
            elif rnd.random() < 0.06:
                g[y][x] = "sand2"
    # Ground patches at large scale: a drier ripple field in the south-west.
    for y in range(30, 42):
        for x in range(4, 16):
            if g[y][x] == "sand" and (x + y) % 3 == 0:
                g[y][x] = "sand2"
    img = Image.new("RGB", (W * C, H * C), COL["void"])
    d = ImageDraw.Draw(img)
    for y in range(H):
        for x in range(W):
            d.rectangle([x * C, y * C, x * C + C - 1, y * C + C - 1], fill=COL[g[y][x]])
    # Foam on the shore and round the pools.
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if g[y][x] in ("sea", "pool") and any(g[y + dy][x + dx] in ("wet", "sand") for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1))):
                d.rectangle([x * C, y * C + 5, x * C + C - 1, y * C + 7], fill=COL["foam"])
    # Set piece: the wreck, a broken hull on its side, stern in the shallows (solid, cover).
    hull = [(30, 22), (44, 18), (47, 21), (46, 25), (33, 28), (29, 26)]
    d.polygon([(x * C, y * C) for x, y in hull], fill=COL["wreck"], outline=COL["wreckdk"])
    for i in range(5):
        x0 = 32 + i * 3
        d.line([(x0 * C, (27 - i) * C), ((x0 + 1) * C, (21 - i * 0.6) * C)], fill=COL["wreckdk"], width=3)
    d.rectangle([40 * C, 16 * C, 41 * C, 19 * C], fill=COL["wreckdk"])  # the broken mast
    # Decor in clusters, never sprinkled: kelp on the tide line, driftwood by the wreck.
    for cx, cy, kind, n in ((14, 21, "kelp", 7), (52, 20, "kelp", 5), (27, 30, "drift", 4), (48, 27, "drift", 3), (9, 36, "kelp", 4)):
        for _ in range(n):
            x, y = cx + rnd.randint(-3, 3), cy + rnd.randint(-2, 2)
            d.rectangle([x * C + 2, y * C + 2, x * C + 6, y * C + 6], fill=COL[kind])
    # World lights: a beacon brazier on the shelf (warm), glowing kelp in the pool (cold).
    for (x, y, col, r) in ((57, 28, "light", 7), (22, 33, "cold", 4)):
        d.ellipse([(x - r) * C, (y - r) * C, (x + r) * C, (y + r) * C], outline=COL[col], width=1)
        d.ellipse([x * C - 4, y * C - 4, x * C + 4, y * C + 4], fill=COL[col])
    # Doors: west on the spit, south through the rocks, east through the cliff (a cut).
    for (x, y) in ((0, 27), (52, 44), (75, 12)):
        d.rectangle([x * C - 2, y * C - 6, x * C + 10, y * C + 14], fill=COL["door"])
    # Fight pockets (A-C) and the route between them.
    route = [(4, 27), (16, 27), (24, 25), (38, 31), (52, 34), (56, 30), (74, 12)]
    d.line([(x * C, y * C) for x, y in route], fill=COL["text"], width=1)
    d.line([(38 * C, 31 * C), (52 * C, 43 * C)], fill=COL["text"], width=1)
    for (x, y, lab) in ((15, 27, "A open beach"), (38, 33, "B wreck cover"), (56, 31, "C the shelf")):
        d.ellipse([(x - 5) * C, (y - 4) * C, (x + 5) * C, (y + 4) * C], outline=COL["text"], width=1)
        d.text((x * C - 18, y * C - 4), lab, fill=COL["text"])
    # One screen, for scale: the camera shows a quarter of the room.
    d.rectangle([20 * C, 16 * C, 60 * C - 1, 39 * C - 1], outline=COL["screen"], width=1)
    d.text((20 * C + 3, 16 * C + 3), "one screen", fill=COL["screen"])
    for (x, y, t) in ((6, 4, "open sea, beyond"), (69, 4, "cliff"), (45, 9, "the coast, a curve with a spit"),
                      (29, 15, "wreck (set piece)"), (5, 40, "dry ripple field")):
        d.text((x * C, y * C), t, fill=COL["text"])
    big = img.resize((W * C * 2, H * C * 2), Image.NEAREST)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    big.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
