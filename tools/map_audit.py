"""Map Stage 01: measure every room template against the problems in MAP_ROADMAP.md.

Reads data/rooms/<biome>/*.txt and writes assets/reference/maps/audit.csv plus a markdown
table on stdout. Per room:
  plain   share of walkable cells that are bare floor ('.'): wallpaper when high
  hole    side of the largest square of bare floor (tiles): an empty field when large
  sym     best mirror match (left-right or top-bottom) of the room's plan, 0-1
  rect    share of the room's features (water, raised, solid blocks) that are plain
          rectangles or rectangle outlines
  twin    another biome's room with the same plan (cell for cell, ignoring markers)
  near    the most similar other room by feature cells (Jaccard), and its score
Scores, 0 fine / 1 weak / 2 failing, on the four problems a plan can show (MAP_ROADMAP.md
numbers): 2 wallpaper (plain, hole), 3 greybox (sym, rect), 7 no biome identity (twin, or no
biome feature at all), 9 repeats (near). Problems 1, 4, 5, 6 and 8 (one screen, hard edges,
no set pieces, the hidden rim, no world light) are in the renderer, not the plan: every room
scores 2 on them.
KEEP names the plans with an idea worth carrying into the chunk library (Stage 08).
With --shots=<dir> (the PNGs src/dev/room_sheet.tscn renders) it also writes one contact
sheet per biome, sheet_<biome>.png, five rooms across at half size, named.
Run:  godot --path . src/dev/room_sheet.tscn -- --out=<dir>
      python tools/map_audit.py [--shots=<dir>] [--with=test] [--tag=<prefix>]
"""
import csv
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOMS = os.path.join(ROOT, "data", "rooms")
OUT = os.path.join(ROOT, "assets", "reference", "maps")
BIOMES = ["biome1", "harbour", "biome2", "biome3"]
PIECES = json.load(open(os.path.join(ROOT, "data", "set_pieces.json"), encoding="utf-8"))
WALKABLE = set("._=PeDFTXAMOEBWCNKSILVYld")
# What a cell is for the plan, markers folded into the floor they stand on.
PLAN = {"#": "#", "o": "o", "h": "o", "_": "_", "=": "="}
# Plans with an idea worth keeping as a chunk, and what the idea is.
KEEP = {
    "biome1/flats_04": "moat ring round an island",
    "biome1/flats_06": "the coast cuts the room on a diagonal",
    "biome1/flats_07": "a winding channel, the one organic water shape",
    "harbour/harbour_03": "four warehouse bays opening on the deck",
    "harbour/harbour_06": "a dock basin with quay ends",
    "harbour/harbour_09": "a pier across a channel",
    "biome2/streets_01": "a raised terrace with shop fronts",
    "biome2/streets_08": "flooded courtyards either side of a causeway",
    "biome2/treasure_01": "the street collapses into the void",
    "biome3/hall_02": "stepped terraces down to a channel",
    "biome3/hall_06": "a colonnade standing in the channel",
    "biome3/treasure_01": "a nave aisle with the void either side",
}


def load(path):
    """The plan's rows, each set piece's footprint (`@ id x y`, map Stage 05) drawn in as rock."""
    lines = [r.rstrip() for r in open(path, encoding="utf-8").read().split("\n") if r.strip()]
    rows = [list(r) for r in lines if not r.startswith("@")]
    for r in lines:
        if r.startswith("@"):
            pid, x, y = r[1:].split()
            for j, foot in enumerate(PIECES[pid]["foot"]):
                for i, c in enumerate(foot):
                    if c == "#":
                        rows[int(y) + j][int(x) + i] = "o"
                    elif c in "=_" and rows[int(y) + j][int(x) + i] not in "#D":
                        rows[int(y) + j][int(x) + i] = c  # a deck or water the piece lays
    return ["".join(r) for r in rows]


def plan(rows):
    return ["".join(PLAN.get(c, ".") for c in r) for r in rows]


def interior(p):
    """Cells inside the rim: anything that is not wall connected to the room's edge."""
    h, w = len(p), len(p[0])
    outside = set()
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in outside or not (0 <= x < w and 0 <= y < h) or p[y][x] != "#":
            continue
        outside.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return {(x, y) for y in range(h) for x in range(w) if (x, y) not in outside}


def features(p, inside):
    """Connected groups of non-floor cells inside the room, by kind."""
    seen, groups = set(), []
    for (x, y) in sorted(inside):
        k = p[y][x]
        if k == "." or (x, y) in seen:
            continue
        group, stack = set(), [(x, y)]
        while stack:
            c = stack.pop()
            if c in seen or c not in inside or p[c[1]][c[0]] != k:
                continue
            seen.add(c)
            group.add(c)
            stack += [(c[0] + 1, c[1]), (c[0] - 1, c[1]), (c[0], c[1] + 1), (c[0], c[1] - 1)]
        groups.append(group)
    return groups


def is_rectish(g):
    xs, ys = [c[0] for c in g], [c[1] for c in g]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    box = (x1 - x0 + 1) * (y1 - y0 + 1)
    if len(g) == box:
        return True
    ring = box - max(0, (x1 - x0 - 1)) * max(0, (y1 - y0 - 1))
    # A rectangle outline, allowing a gap or two for a doorway.
    return len(g) >= ring - 4 and all(x in (x0, x1) or y in (y0, y1) for x, y in g)


def biggest_hole(p, inside):
    h, w = len(p), len(p[0])
    best, dp = 0, [[0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if (x, y) in inside and p[y][x] == ".":
                dp[y][x] = 1 + (min(dp[y - 1][x], dp[y][x - 1], dp[y - 1][x - 1]) if x and y else 0)
                best = max(best, dp[y][x])
    return best


def symmetry(p, inside):
    h, w = len(p), len(p[0])
    cells = list(inside)
    lr = sum(p[y][x] == p[y][w - 1 - x] for x, y in cells) / len(cells)
    tb = sum(p[y][x] == p[h - 1 - y][x] for x, y in cells) / len(cells)
    return max(lr, tb)


def sheets(shots, tag=""):
    from PIL import Image, ImageDraw
    names = {"biome1": "flats", "harbour": "harbour", "biome2": "streets", "biome3": "hall"}
    for b in BIOMES:
        files = sorted(f for f in os.listdir(shots) if f.startswith(b + "__"))
        cols, w, h, lab = 5, 320, 180, 14
        rows = (len(files) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * w, rows * (h + lab)), (20, 20, 24))
        d = ImageDraw.Draw(sheet)
        for i, f in enumerate(files):
            im = Image.open(os.path.join(shots, f)).convert("RGB").resize((w, h), Image.NEAREST)
            x, y = (i % cols) * w, (i // cols) * (h + lab)
            sheet.paste(im, (x, y + lab))
            d.text((x + 4, y + 1), f.split("__")[1][:-4], fill=(230, 220, 180))
        sheet.save(os.path.join(OUT, f"{tag}sheet_{names[b]}.png"))


def main(extra=(), tag=""):
    rooms = {}
    for b in BIOMES + list(extra):
        for f in sorted(os.listdir(os.path.join(ROOMS, b))):
            if f.endswith(".txt"):
                rows = load(os.path.join(ROOMS, b, f))
                rooms[f"{b}/{f[:-4]}"] = rows
    data = {}
    for name, rows in rooms.items():
        p = plan(rows)
        inside = interior(p)
        walk = [c for c in inside if rows[c[1]][c[0]] in WALKABLE]
        plain = sum(rows[y][x] == "." for x, y in walk) / max(1, len(walk))
        groups = features(p, inside)
        rect = sum(is_rectish(g) for g in groups) / len(groups) if groups else 1.0
        feat = {(x, y, p[y][x]) for x, y in inside if p[y][x] != "."}
        data[name] = dict(p=p, plain=plain, hole=biggest_hole(p, inside), sym=symmetry(p, inside),
                          rect=rect, nfeat=len(groups), feat=feat)
    for name, d in data.items():
        twin, near, near_s = "", "", 0.0
        for other, o in data.items():
            if other == name:
                continue
            if o["p"] == d["p"] and other.split("/")[0] != name.split("/")[0]:
                twin = twin or other
            union = len(d["feat"] | o["feat"])
            s = len(d["feat"] & o["feat"]) / union if union else 1.0
            if s > near_s:
                near, near_s = other, s
        d.update(twin=twin, near=near, near_s=near_s)
        d["s2"] = 2 if d["plain"] >= 0.9 or d["hole"] >= 14 else (1 if d["plain"] >= 0.8 or d["hole"] >= 11 else 0)
        d["s3"] = (d["sym"] >= 0.9) + (d["rect"] >= 0.8)
        d["s7"] = 2 if twin else 1
        d["s9"] = 2 if near_s >= 0.5 else (1 if near_s >= 0.3 else 0)
        d["total"] = d["s2"] + d["s3"] + d["s7"] + d["s9"] + 10
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, f"{tag}audit.csv"), "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["room", "plain", "hole", "sym", "rect", "features", "twin", "near", "near_score",
                    "p2", "p3", "p7", "p9", "of18", "keep"])
        for name, d in data.items():
            w.writerow([name, f"{d['plain']:.2f}", d["hole"], f"{d['sym']:.2f}", f"{d['rect']:.2f}",
                        d["nfeat"], d["twin"], d["near"], f"{d['near_s']:.2f}",
                        d["s2"], d["s3"], d["s7"], d["s9"], d["total"], KEEP.get(name, "")])
    print("| room | plain | hole | sym | rect | twin | nearest | 2 | 3 | 7 | 9 | /18 | keep |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for name, d in data.items():
        print(f"| {name} | {d['plain']:.2f} | {d['hole']} | {d['sym']:.2f} | {d['rect']:.2f} | "
              f"{d['twin'] or '-'} | {d['near'] or '-'} {d['near_s']:.2f} | {d['s2']} | {d['s3']} | "
              f"{d['s7']} | {d['s9']} | {d['total']} | {KEEP.get(name, '')} |")


if __name__ == "__main__":
    # --with=test also measures data/rooms/test/ (the map samples) against the rest.
    # --tag=s09_ writes s09_audit.csv and s09_sheet_*.png, keeping Stage 01's as the "before".
    tag = next((a[len("--tag="):] for a in sys.argv[1:] if a.startswith("--tag=")), "")
    main([a[len("--with="):] for a in sys.argv[1:] if a.startswith("--with=")], tag)
    for a in sys.argv[1:]:
        if a.startswith("--shots="):
            sheets(a[len("--shots="):], tag)
