"""Map Stage 06: one sample room per biome, built to STYLE.md 22 with Stages 02-05.

Each plan is composed from shapes, not typed: noisy blobs for natural ground (no straight run
longer than six tiles), broken straight runs for built edges (a notch, a step or a buttress at
least every ten tiles), thick polylines for streets and channels, and the set pieces from
data/set_pieces.json placed by `@ id x y` lines. The plans are written to data/rooms/test/ and
checked here: every door and enemy spawn reachable from the player's spawn, every footprint on
open ground and clear of the 3x3 before a door, the rim at least two cells thick.
Run:  python tools/gen_sample_rooms.py
Legend as tools/gen_rooms.py: # wall  . floor  _ low  = raised  o rock  D door  P player  e enemy
"""
import json
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "rooms", "test")
PIECES = json.load(open(os.path.join(ROOT, "data", "set_pieces.json"), encoding="utf-8"))
OPEN = set("._=")


class Plan:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [["#"] * w for _ in range(h)]
        self.pieces = []
        self.currents = []  # channels' lines, downstream (map Stage 11e): `~` lines
        self.doors = []
        self.bad = []

    def get(self, x, y):
        return self.g[y][x] if 0 <= x < self.w and 0 <= y < self.h else "#"

    def put(self, x, y, ch, only=None):
        # Never into the outer two rings: the rim is a mass (doors cut it on their own).
        if 2 <= x < self.w - 2 and 2 <= y < self.h - 2 and (only is None or self.g[y][x] in only):
            self.g[y][x] = ch

    def blob(self, cx, cy, rx, ry, ch, seed, rough=0.22, only=None):
        """A noisy ellipse: its radius wanders with the angle, so the edge never runs straight."""
        rng = random.Random(seed)
        waves = [(k, rough / (k - 1) * rng.uniform(0.6, 1.0), rng.uniform(0, 6.283)) for k in range(2, 7)]
        for y in range(int(cy - ry * 1.6) - 1, int(cy + ry * 1.6) + 2):
            for x in range(int(cx - rx * 1.6) - 1, int(cx + rx * 1.6) + 2):
                dx, dy = (x - cx) / rx, (y - cy) / ry
                a = math.atan2(dy, dx)
                r = 1.0 + sum(amp * math.sin(k * a + ph) for k, amp, ph in waves)
                if dx * dx + dy * dy <= r * r:
                    self.put(x, y, ch, only)

    def rect(self, x0, y0, x1, y1, ch, only=None):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, ch, only)

    def path(self, pts, half, ch, seed=0, wobble=0.0, only=None):
        """A thick polyline. With wobble its width wanders, for natural channels and tracks."""
        rng = random.Random(seed)
        ph = rng.uniform(0, 6.283)
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = max(abs(x1 - x0), abs(y1 - y0)) * 2 + 1
            for i in range(n + 1):
                t = i / n
                x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                r = half + wobble * math.sin((x + y) * 0.45 + ph)
                ri = int(math.ceil(r))
                for dy in range(-ri, ri + 1):
                    for dx in range(-ri, ri + 1):
                        if dx * dx + dy * dy <= r * r + 0.3:
                            self.put(int(round(x + dx)), int(round(y + dy)), ch, only)

    def door(self, x, y):
        """A door on the border with its cut through the mass to the first open cell."""
        dx = 1 if x == 0 else (-1 if x == self.w - 1 else 0)
        dy = 1 if y == 0 else (-1 if y == self.h - 1 else 0)
        self.g[y][x] = "D"
        self.doors.append((x, y))
        cx, cy = x + dx, y + dy
        while 0 < cx < self.w - 1 and 0 < cy < self.h - 1 and self.g[cy][cx] not in OPEN:
            self.g[cy][cx] = "."
            cx, cy = cx + dx, cy + dy

    def mark(self, cells, ch):
        """A spawn on open floor or low ground, moved to the nearest such cell: one on raised
        ground or a rock would cut a hole in it."""
        for x, y in cells:
            for r in range(6):
                ring = [(x + dx, y + dy) for dy in range(-r, r + 1) for dx in range(-r, r + 1)
                        if max(abs(dx), abs(dy)) == r and self.get(x + dx, y + dy) in "._"]
                if ring:
                    x, y = ring[0]
                    break
            else:
                self.bad.append(f"'{ch}' near {x},{y}: no open cell")
            self.g[y][x] = ch

    def piece(self, pid, x, y):
        """Place a piece; a pier or a bridge lays its deck, a tide pool its water (as
        RoomTemplate does on load), so the checks see the ground the room will have."""
        self.pieces.append((pid, x, y))
        for j, row in enumerate(PIECES[pid]["foot"]):
            for i, c in enumerate(row):
                if c in "=_" and self.get(x + i, y + j) not in "#D":
                    self.g[y + j][x + i] = c

    def footprint(self, pid, x, y):
        out = []
        for j, row in enumerate(PIECES[pid]["foot"]):
            for i, c in enumerate(row):
                if c == "#":
                    out.append((x + i, y + j))
        return out

    def text(self):
        rows = ["".join(r) for r in self.g]
        return "\n".join(rows + [f"@ {p} {x} {y}" for p, x, y in self.pieces]
                         + ["~ " + " ".join(f"{x} {y}" for x, y in c) for c in self.currents]) + "\n"

    # -- checks -----------------------------------------------------------------------------
    def check(self, name):
        solid = {c for p in self.pieces for c in self.footprint(*p)}
        errs = list(self.bad)
        for p in self.pieces:
            for (x, y) in self.footprint(*p):
                if self.g[y][x] not in OPEN:
                    errs.append(f"{p[0]} footprint on '{self.g[y][x]}' at {x},{y}")
            for (dx_, dy_) in self.doors:
                ix = dx_ + (1 if dx_ == 0 else -1 if dx_ == self.w - 1 else 0)
                iy = dy_ + (1 if dy_ == 0 else -1 if dy_ == self.h - 1 else 0)
                for (x, y) in self.footprint(*p):
                    if abs(x - ix) <= 1 and abs(y - iy) <= 1:
                        errs.append(f"{p[0]} in front of the door at {dx_},{dy_}")
        start = [(x, y) for y in range(self.h) for x in range(self.w) if self.g[y][x] == "P"]
        if len(start) != 1:
            errs.append("needs one P")
            return errs
        seen, stack = set(start), list(start)
        while stack:
            x, y = stack.pop()
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                c = self.get(nx, ny)
                if (nx, ny) in seen or c in "#o" or (nx, ny) in solid:
                    continue
                seen.add((nx, ny))
                if c != "D":
                    stack.append((nx, ny))
        for y in range(self.h):
            for x in range(self.w):
                c = self.g[y][x]
                if c in "De" and (x, y) not in seen:
                    errs.append(f"'{c}' at {x},{y} unreachable")
                if c in "eP" and (x, y) in solid:
                    errs.append(f"'{c}' at {x},{y} under a piece")
        for y in range(self.h):
            for x in range(self.w):
                if self.g[y][x] in OPEN and not (2 <= x < self.w - 2 and 2 <= y < self.h - 2):
                    if not any(abs(x - dx_) + abs(y - dy_) <= 2 for dx_, dy_ in self.doors):
                        errs.append(f"rim thinner than two at {x},{y}")
        return errs

    def holes(self, limit=8):
        """Bare squares larger than the limit (STYLE.md 22): (side, x, y) of each, top-left."""
        solid = {c for p in self.pieces for c in self.footprint(*p)}
        dp = [[0] * self.w for _ in range(self.h)]
        out = []
        for y in range(self.h):
            for x in range(self.w):
                if self.g[y][x] in ".Pe" and (x, y) not in solid:
                    dp[y][x] = 1 + (min(dp[y - 1][x], dp[y][x - 1], dp[y - 1][x - 1]) if x and y else 0)
                    if dp[y][x] > limit:
                        out.append((dp[y][x], x - dp[y][x] + 1, y - dp[y][x] + 1))
        out.sort(reverse=True)
        keep = []
        for o in out:
            if not any(abs(o[1] - k[1]) < 4 and abs(o[2] - k[2]) < 4 for k in keep):
                keep.append(o)
        return keep[:6]

    def symmetry(self):
        cells = [(x, y) for y in range(self.h) for x in range(self.w) if self.g[y][x] != "#"]
        k = lambda c: "o" if c in "o" else ("_" if c == "_" else ("=" if c == "=" else ("#" if c == "#" else ".")))
        solid = {c for p in self.pieces for c in self.footprint(*p)}
        g = [[("o" if (x, y) in solid else k(self.g[y][x])) for x in range(self.w)] for y in range(self.h)]
        lr = sum(g[y][x] == g[y][self.w - 1 - x] for x, y in cells) / len(cells)
        tb = sum(g[y][x] == g[self.h - 1 - y][x] for x, y in cells) / len(cells)
        return max(lr, tb)


def flats():
    """The Flats, L: a coast crossing the room. Dry dunes and a rock headland in the north, the
    tidal flats in the south-west (they flood first), a rock shelf in the east (last to flood),
    the wreck beached off centre as the cover between them, the arch at the narrows."""
    p = Plan(80, 46)
    # The land: three overlapping dunes, a bay cut back into the north-west.
    p.blob(22, 15, 18, 10, ".", 11, 0.18)
    p.blob(44, 26, 26, 15, ".", 12, 0.16)
    p.blob(64, 18, 12, 11, ".", 13, 0.2)
    p.blob(20, 33, 17, 10, ".", 14, 0.18)
    p.blob(62, 36, 13, 7, ".", 15, 0.2)
    # The headland: rock running down from the north between the north-west and north-east.
    p.blob(41, 6, 6, 9, "#", 21, 0.28)
    for (x, y) in [(35, 11), (36, 12), (34, 13), (36, 14)]:
        p.put(x, y, "o", ".")
    # A spur of cliff into the south-east and a fallen block off it.
    p.blob(76, 30, 6, 5, "#", 23, 0.3)
    p.blob(45, 44, 9, 4, "#", 24, 0.3)
    # The tidal flats: the sea comes in from the south-west; a sand bar runs into it.
    p.blob(16, 36, 15, 8, "_", 31, 0.2, only=".")
    p.blob(28, 42, 8, 3, "_", 32, 0.25, only=".")
    p.path([(8, 30), (16, 34), (21, 39)], 1.2, ".", 33, 0.5, only="_")
    # Pools in the north-west and on the east beach.
    p.blob(14, 11, 4, 3, "_", 34, 0.3, only=".")
    p.blob(24, 19, 3, 2, "_", 35, 0.3, only=".")
    p.blob(50, 20, 3, 2, "_", 37, 0.35, only=".")
    p.blob(47, 34, 4, 2, "_", 38, 0.35, only=".")
    p.blob(23, 9, 3, 2, "_", 39, 0.35, only=".")
    # Outcrops: bare rock standing out of the sand.
    p.blob(55, 25, 2, 2, "#", 25, 0.3)
    p.blob(66, 8, 3, 2, "#", 26, 0.3)
    p.blob(48, 27, 1.5, 1.5, "#", 27, 0.3)
    p.blob(33, 21, 2, 1.5, "#", 28, 0.3)
    p.blob(14, 23, 3, 2, "_", 29, 0.35, only=".")
    p.blob(36, 37, 3, 2, "_", 30, 0.35, only=".")
    for (x, y) in [(41, 19), (42, 20), (40, 20), (27, 25), (63, 37), (64, 38), (64, 37)]:
        p.put(x, y, "o", ".")
    # The rock shelf in the east: raised, the last ground to flood.
    p.blob(66, 21, 7, 5, "=", 41, 0.22, only="._")
    p.blob(62, 25, 3, 2, "=", 42, 0.3, only="._")
    # Rocks in drifts at the foot of the cliffs.
    for (x, y) in [(31, 7), (32, 8), (49, 9), (50, 10), (72, 30), (71, 31), (8, 22), (55, 39)]:
        p.put(x, y, "o", ".")
    # Pieces: the wreck as the cover in the middle pocket, the arch where the north-east beach
    # narrows between the headland and the shelf, the boat on the edge of the flats.
    p.piece("wreck", 36, 27)
    p.piece("arch", 51, 13)
    p.piece("boat", 29, 31)
    # Second batch: the beacon lit on the shelf, standing stones on the north-west dune, a tide
    # pool in its rock ring on the east beach, a mast in the sand, the whalebone arch.
    p.piece("cairn", 66, 19)
    p.piece("stones", 17, 17)
    p.piece("tidepool", 56, 29)
    p.piece("mast", 66, 41)
    p.piece("whalebone", 24, 25)
    # World light (map Stage 07): the beacon is the only warm light; kelp glows cold on the
    # tidal flats (the pocket that floods first) and by the south door.
    p.piece("kelplight", 18, 36)
    p.piece("kelplight", 58, 41)
    p.door(0, 16)
    p.door(79, 14)
    p.door(56, 45)
    p.mark([(6, 16)], "P")
    p.mark([(18, 8), (26, 13), (44, 22), (34, 33), (12, 30), (22, 37), (60, 9), (66, 15),
            (70, 21), (64, 34), (50, 36)], "e")
    return p


def harbour():
    """The Sunken Harbour, L: the dock basin. A straight channel crosses the room between hard
    quays, a pier carries the route over it, a slipway runs down into it from the south; the
    warehouse fronts the north quay, the crane stands at its edge, nets dry on the south quay.
    The channel runs out east into the dark: the beyond."""
    p = Plan(80, 46)
    # The quays: north and south decks, straight but broken.
    p.rect(3, 4, 76, 18, ".")
    p.rect(3, 28, 76, 42, ".")
    # Bites in the decks: a collapsed corner, a bay, buttresses.
    p.rect(3, 4, 9, 7, "#")
    p.rect(66, 4, 76, 6, "#")
    p.rect(30, 4, 32, 5, "#")
    p.rect(52, 4, 53, 5, "#")
    p.rect(3, 38, 6, 42, "#")
    p.rect(40, 40, 52, 42, "#")
    p.rect(70, 39, 76, 42, "#")
    p.blob(20, 41, 4, 2, "#", 51, 0.3)
    # The channel: straight, two quay steps on each side, and it runs out east.
    p.rect(3, 19, 77, 27, "_")
    for x0 in (14, 38, 62):
        p.rect(x0, 18, x0 + 3, 18, "_")
    for x0 in (26, 50, 70):
        p.rect(x0, 28, x0 + 2, 28, "_")
    p.rect(3, 19, 4, 27, "#")
    # The slipway: low ground running down from the channel through the south quay.
    p.rect(22, 28, 27, 36, "_")
    p.rect(23, 37, 26, 38, "_")
    # The pier: raised timber across the channel, three wide, with a landing.
    p.rect(44, 17, 46, 29, "=")
    p.rect(42, 22, 48, 24, "=")
    # A dock basin cut into the north quay; a second basin in the east of the south quay.
    p.rect(56, 9, 61, 18, "_")
    p.rect(61, 37, 67, 42, "_")
    p.rect(61, 28, 67, 30, "_")
    # Crate stacks on the decks, cargo waiting in rows by the warehouse and the slipway.
    for (x, y) in [(34, 5), (35, 5), (36, 5), (34, 6), (44, 5), (45, 5), (45, 6), (25, 5), (26, 5),
                   (41, 34), (42, 34), (33, 34), (34, 34), (34, 35), (37, 37), (38, 37), (38, 36), (36, 31),
                   (40, 9), (41, 9), (40, 10), (66, 10), (67, 10), (67, 11), (24, 13), (25, 13),
                   (48, 31), (49, 31), (49, 32), (12, 35), (13, 35), (72, 33), (72, 34),
                   (16, 11), (17, 11), (16, 12), (30, 10), (31, 10), (46, 11), (47, 11), (47, 12),
                   (8, 15), (9, 15), (70, 13), (71, 13), (6, 33), (7, 33)]:
        p.put(x, y, "o", ".")
    # Bollards, a mooring post in the channel.
    for (x, y) in [(12, 18), (35, 18), (58, 18), (16, 28), (60, 28)]:
        p.put(x, y, "o")
    p.piece("warehouse", 12, 6)
    p.piece("crane", 36, 15)
    p.piece("netrack", 56, 34)
    # Second batch: a timber pier off the south quay with a boat moored beside it, the capstan
    # at its root, the slipway's rails down into the slip, cargo by the warehouse.
    p.piece("pier", 30, 22)
    p.piece("moored", 34, 23)
    p.piece("capstan", 28, 30)
    p.piece("slipway", 23, 30)
    p.piece("crates", 20, 8)
    # World light: the crane's lamp is the room's one warm light; buoys burn cold in the channel,
    # one off the pier's end, one at the east bend.
    p.piece("buoy", 40, 21)
    p.piece("buoy", 66, 24)
    p.door(0, 12)
    p.door(60, 0)
    p.door(10, 45)
    p.door(79, 35)
    p.mark([(6, 13)], "P")
    p.mark([(24, 11), (40, 9), (56, 12), (68, 14), (30, 33), (14, 32), (52, 37), (66, 31),
            (46, 20), (58, 23), (18, 24)], "e")
    return p


def streets():
    """The Drowned Streets, M: a street from the west door opens into a square; a canal cuts
    the east side, crossed by one causeway; house blocks crowd every edge with alleys between
    them; a terrace with steps in the north-east. The house front faces the square, the well
    stands off its centre, the stall at its corner."""
    p = Plan(60, 34)
    # The street and the square.
    p.rect(2, 13, 24, 18, ".")
    p.rect(14, 7, 40, 27, ".")
    # Alleys off the square.
    p.rect(20, 2, 22, 7, ".")
    p.rect(28, 27, 30, 31, ".")
    p.rect(6, 19, 8, 27, ".")
    p.rect(6, 25, 14, 27, ".")
    # Blocks pushed into the square: broken fronts.
    p.rect(14, 7, 18, 10, "#")
    p.rect(14, 22, 19, 27, "#")
    p.rect(34, 7, 40, 9, "#")
    p.rect(36, 24, 40, 27, "#")
    p.rect(26, 7, 27, 8, "#")
    # The canal: north to south, a moss bank either side.
    p.path([(46, 1), (45, 10), (47, 20), (46, 33)], 2.6, "_", 61, 0.6)
    p.rect(41, 10, 52, 27, ".", only="#")
    p.path([(46, 1), (45, 10), (47, 20), (46, 33)], 2.4, "_", 61, 0.6)
    # The east bank and the terrace with its steps.
    p.rect(50, 6, 57, 28, ".", only="#")
    p.rect(50, 6, 57, 13, "=")
    p.rect(56, 22, 57, 28, "#")
    # Low ground in a sunken corner of the square floods before the street.
    p.blob(32, 22, 4, 3, "_", 62, 0.3, only=".")
    for (x, y) in [(24, 9), (13, 18), (8, 24), (19, 14), (20, 14), (19, 15)]:
        p.put(x, y, "o", ".")
    p.piece("house", 26, 9)
    p.piece("well", 24, 18)
    p.piece("stall", 33, 12)
    # Second batch: the bridge over the canal, steps up to the terrace, the tower's stump against
    # the south block, lamps along the street, a statue fallen in the square.
    p.piece("bridge", 43, 15)
    p.piece("steps", 51, 14)
    p.piece("tower", 36, 20)
    p.piece("lamps", 8, 13)
    p.piece("fallen", 22, 21)
    # World light, all cold: a shrine on the street from the west door, a lamp lit by the sea at
    # the bridge's west end, another by the south alley.
    p.piece("shrine", 15, 11)
    p.piece("coldlamp", 41, 14)
    p.piece("coldlamp", 31, 26)
    p.door(0, 15)
    p.door(21, 0)
    p.door(29, 33)
    p.door(59, 20)
    p.mark([(3, 15)], "P")
    p.mark([(17, 12), (30, 16), (36, 19), (22, 24), (10, 26), (53, 9), (54, 24), (44, 13)], "e")
    return p


def hall():
    """The Deep Hall, L: the nave. A nave runs north to the apse with the altar on its dais,
    column rows divide it from the aisles, gutters of water run down the aisles' outer edges,
    keeper statues flank the steps. Symmetric on one axis with the breaks that make it a ruin:
    the east wall has fallen into the dark, a column is down, the west gutter has burst."""
    p = Plan(80, 46)
    # The nave and the aisles.
    p.rect(26, 10, 53, 41, ".")
    p.rect(12, 14, 25, 41, ".")
    p.rect(54, 14, 67, 41, ".")
    # The apse: a half disc at the head of the nave, the dais in it.
    for y in range(3, 14):
        for x in range(26, 54):
            if ((x - 39.5) / 13.5) ** 2 + ((y - 13) / 10.0) ** 2 <= 1.0:
                p.put(x, y, ".")
    for y in range(4, 14):
        for x in range(30, 50):
            if ((x - 39.5) / 9.0) ** 2 + ((y - 13) / 7.5) ** 2 <= 1.0:
                p.put(x, y, "=")
    p.rect(37, 14, 42, 15, "=")
    # Side chapels off the aisles (buttresses between).
    p.rect(8, 20, 11, 25, ".")
    p.rect(8, 29, 11, 33, ".")
    p.rect(68, 31, 71, 36, ".")
    # The north-west chapel has drowned.
    p.rect(8, 20, 12, 25, "_")
    # The gutters down the aisles' outer edges.
    p.rect(13, 16, 14, 39, "_")
    p.rect(65, 29, 66, 39, "_")  # the east one buried under the fallen wall to the north
    p.blob(59, 22, 5, 3, "_", 81, 0.3, only=".")  # where it backs up behind the fall
    # The burst gutter: the west one spills into a pool in the aisle.
    p.blob(18, 29, 5, 3, "_", 71, 0.3, only=".")
    # The east wall has fallen: the aisle breaks open, rubble spills, the floor gives out.
    p.blob(71, 21, 7, 6, ".", 72, 0.3)
    p.blob(74, 17, 3, 3, "#", 73, 0.3)
    for (x, y) in [(64, 22), (66, 24), (69, 25), (61, 19), (72, 23)]:
        p.put(x, y, "o", "._")
    # The west aisle's floor has sunk: brine stands in the broken flags, masonry lies in it.
    p.blob(20, 20, 3, 3, "_", 79, 0.35, only=".")
    for (x, y) in [(17, 24), (22, 25), (23, 33), (16, 33), (19, 40), (21, 37), (22, 36)]:
        p.put(x, y, "o", ".")
    # The transept: a gutter of brine across the hall, the first ground to flood.
    p.path([(13, 26), (40, 27), (66, 26)], 1.1, "_", 74, 0.35, only=".=")
    # The east column at the fourth bay has fallen across the nave.
    for (x, y) in [(50, 31), (48, 31), (47, 32), (45, 32), (44, 33), (42, 33)]:
        p.put(x, y, "o", ".")
    # Built things in the nave, not puddles: a crypt grate sunk in the floor, tomb slabs in
    # pairs (one pair broken), a font of brine in the east aisle.
    p.rect(38, 30, 41, 32, "_")
    for (x0, y0) in [(31, 19), (31, 37), (46, 37)]:
        p.rect(x0, y0, x0 + 2, y0 + 1, "=")
    p.rect(47, 19, 48, 19, "=")
    # The east chapel goes deeper, into a second bay.
    p.rect(68, 37, 73, 40, ".")
    for (x, y) in [(58, 35), (40, 18), (57, 21), (47, 20), (48, 21), (49, 38),
                   (33, 31), (35, 24), (44, 24)]:
        p.put(x, y, "o", ".")
    # The dais runs down into wide steps.
    p.rect(34, 14, 45, 16, "=", only=".")
    # The narthex steps at the south.
    p.rect(30, 42, 49, 43, ".")
    p.piece("altar", 38, 8)
    p.piece("statue", 31, 14)
    p.piece("statue", 47, 14)
    # Second batch: the organ at the head of the west aisle, an apse wall closing the east one,
    # the rose window fallen in the nave, a font in the east aisle, the gate at the entrance.
    p.piece("organ", 16, 15)
    p.piece("apse", 56, 14)
    p.piece("rose", 37, 22)
    p.piece("font", 58, 31)
    p.piece("gate", 36, 39)
    # World light: the altar's candles and the font as before; two candle drifts, by the organ and
    # in the east chapel by its door; kelp glowing cold where the west gutter burst.
    p.piece("candles", 22, 17)
    p.piece("candles", 70, 33)
    p.piece("kelpglow", 22, 29)
    # Column rows, two cells in from the nave's edge; the fourth on the east is down.
    for y in (18, 24, 30, 36):
        p.piece("column", 26, y)
        if y != 30:
            p.piece("column", 52, y)
    for (x, y) in [(53, 30), (54, 32)]:
        p.put(x, y, "o", ".")
    p.door(39, 45)
    p.door(0, 22)
    p.door(79, 34)
    p.mark([(39, 41)], "P")
    p.mark([(36, 21), (46, 22), (39, 28), (34, 34), (18, 19), (20, 35), (60, 17), (59, 38),
            (70, 21), (44, 34)], "e")
    return p


def reef():
    """The Reef, L (map Stage 11b): Saltmere's sea wall runs straight across the north, broken
    in two breaches. Outside it the outer reef and a channel along the wall's foot; inside, the
    current comes through the breaches and runs south in two channels between the coral heads
    (raised, the last ground to flood), rubble from the wall at its foot."""
    p = Plan(80, 46)
    p.rect(3, 3, 76, 42, ".")
    # The rim bitten back: the reef's edge is never a straight line, only the wall is.
    for (x, y, rx, ry, sd) in [(3, 22, 3, 5, 51), (76, 36, 3, 4, 52), (30, 43, 6, 2, 53), (60, 3, 7, 2, 54),
                               (3, 40, 4, 3, 55), (76, 8, 3, 3, 56), (16, 3, 5, 2, 57)]:
        p.blob(x, y, rx, ry, "#", sd, 0.3)
    # The sea wall: three courses thick, straight, a jog where a length of it slid, two breaches.
    p.rect(3, 13, 76, 15, "#")
    p.rect(35, 12, 42, 12, "#")
    p.rect(35, 15, 42, 15, ".")
    p.rect(19, 13, 25, 15, ".")
    p.rect(53, 13, 57, 15, ".")
    # Outside: the channel at the wall's foot, the outer reef's coral heads.
    p.path([(4, 9), (20, 10), (40, 8), (60, 10), (75, 9)], 1.6, "_", 61, 0.5, only=".")
    p.blob(11, 6, 4, 2, "=", 62, 0.3, only=".")
    p.blob(45, 5, 4, 1.5, "=", 63, 0.3, only=".")
    p.blob(68, 6, 3, 1.5, "=", 64, 0.3, only=".")
    # Inside: the current through each breach and away south.
    p.path([(22, 16), (17, 25), (13, 33), (9, 41)], 1.8, "_", 65, 0.6, only=".")
    p.path([(55, 16), (59, 25), (64, 33), (71, 41)], 1.6, "_", 66, 0.6, only=".")
    # The coral heads: one great head mid-room, smaller ones by the channels.
    p.blob(37, 26, 6.5, 4, "=", 71, 0.28, only=".")
    p.blob(48, 36, 5, 3.2, "=", 72, 0.3, only="._")
    p.blob(26, 37, 4, 2.6, "=", 73, 0.3, only=".")
    p.blob(68, 22, 3.5, 2.4, "=", 74, 0.3, only=".")
    p.blob(8, 19, 2.5, 2, "=", 75, 0.3, only=".")
    # Pools left in the hollows, and the wall's rubble at its foot.
    p.blob(44, 21, 3, 1.6, "_", 76, 0.35, only=".")
    p.blob(32, 33, 2.5, 1.5, "_", 77, 0.35, only=".")
    p.blob(58, 40, 3, 1.5, "_", 78, 0.35, only=".")
    for (x, y) in [(29, 16), (30, 16), (30, 17), (46, 16), (47, 16), (66, 16), (67, 17), (11, 16), (12, 17),
                   (50, 28), (51, 28), (20, 31), (21, 30), (60, 34), (40, 40), (41, 40)]:
        p.put(x, y, "o", ".")
    # The Reef's pieces (map Stage 11c): the breach's broken stubs standing in the west gap, a
    # great brain-coral head and a staghorn thicket as cover mid-room, the clam and the living fans
    # by the water, an anchor driven in by the wall, a ship's ribs grown over in the south-west,
    # the wall's stair up onto the great coral head. Light, all cold: glowing coral by both
    # channels and a jellyfish bloom over the pool under the wall.
    p.piece("breach", 19, 13)
    p.piece("brainhead", 26, 24)
    p.piece("staghorn", 44, 27)
    p.piece("clam", 51, 33)
    p.piece("fans", 60, 37)
    p.piece("anchor", 72, 18)
    p.piece("ribcoral", 15, 38)
    p.piece("wallsteps", 35, 31)
    p.piece("glowcoral", 15, 28)
    p.piece("glowcoral", 62, 29)
    p.piece("jelly", 44, 21)
    # The currents (map Stage 11e): along the wall's outer foot to the east; through each breach
    # and away south down its channel.
    p.currents.append([(4, 9), (20, 10), (40, 8), (60, 10), (75, 9)])
    p.currents.append([(22, 13), (22, 16), (17, 25), (13, 33), (9, 41)])
    p.currents.append([(55, 13), (55, 16), (59, 25), (64, 33), (71, 41)])
    p.door(0, 30)
    p.door(79, 26)
    p.door(30, 0)
    p.mark([(5, 30)], "P")
    p.mark([(12, 24), (28, 29), (45, 26), (36, 35), (20, 40), (52, 22), (60, 19), (72, 28), (66, 38), (48, 6),
            (24, 7)], "e")
    return p


def main():
    os.makedirs(OUT, exist_ok=True)
    bad = False
    for name, fn in [("sample_flats", flats), ("sample_harbour", harbour),
                     ("sample_streets", streets), ("sample_hall", hall), ("sample_reef", reef)]:
        p = fn()
        errs = p.check(name)
        for e in errs:
            print(f"{name}: {e}")
        bad = bad or bool(errs)
        with open(os.path.join(OUT, name + ".txt"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(p.text())
        print(f"{name}: {p.w}x{p.h}, {len(p.pieces)} pieces, {len(errs)} problems, "
              f"symmetry {p.symmetry():.2f}, bare squares over 8: {p.holes()}")
    raise SystemExit(1 if bad else 0)


if __name__ == "__main__":
    main()
