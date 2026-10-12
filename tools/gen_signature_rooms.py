"""Map Stage 12: the signature rooms (shop, altar, fountain, echo, the boss arenas, the hub),
composed by hand in code the way tools/gen_sample_rooms.py composed Stage 06's samples, and
written over data/rooms/<biome>/<kind>_01.txt.

The rules every signature room keeps (STYLE.md 22, map Stage 12a):
- It is a place, not a box: one focal thing (the merchant's stall, the altar, the fountain, the
  cage, the boss's ground), raised or framed so the eye goes to it, lit by the room's one light.
- The way in is a path to it: the player's spawn faces the focus across open ground.
- Its biome's set pieces dress it, chosen for what the place is, not scattered.
- At least two exits: the run offers up to two rooms next, and doors are filled in order, so a
  room with one door silently dropped the second (the wet way at the fork among them).
- No bare square over 8, no rim thinner than two, every door and spawn reachable (Plan.check).
- Calm rooms (shop, altar, fountain) stay near one screen; the camera follows anyway.

Run:  python tools/gen_signature_rooms.py [name ...]     (no names: every room it knows)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_sample_rooms import Plan, ROOT  # noqa: E402

ROOMS = os.path.join(ROOT, "data", "rooms")


def flats_shop():
    """The Flats merchant, 44x26: the drowned merchant trades from a sandbar out on the tidal
    flats, beside an upturned keeper's boat, under the warm beacon (the Flats' one warm light).
    The flats run round the bar on the west and south; a sand spit is the way out to it from
    where you come in; kelp glows cold on the flats' edge. Exits west and east."""
    p = Plan(44, 26)
    # The beach: dry sand, wide in the middle, rock all round.
    p.blob(22, 12, 18, 8, ".", 101, 0.16)
    p.blob(33, 17, 8, 6, ".", 102, 0.2)
    p.blob(11, 17, 8, 6, ".", 103, 0.2)
    p.blob(22, 20, 10, 3.5, ".", 104, 0.2)
    # Behind the stall: a low rough shelf of rock (raised, the last ground to flood) with the
    # beacon on it; a headland of cliff in the north-east.
    p.blob(23, 6.5, 6, 2.2, "=", 131, 0.3, only=".")
    p.blob(37, 5, 4, 3, "#", 111, 0.3)
    # The tidal flats, two arms of them: west, and south-east under the cliff. They flood first.
    p.blob(9, 13, 5, 4, "_", 121, 0.3, only=".")
    p.blob(13, 18, 4, 2.5, "_", 122, 0.35, only=".")
    p.blob(33, 18, 5, 3, "_", 123, 0.32, only=".")
    p.blob(29, 21, 3, 1.5, "_", 124, 0.35, only=".")
    # A dune between where you come in and the stall: the stall is seen across it.
    for (x, y) in [(31, 9), (32, 10), (34, 11), (6, 8), (7, 9), (16, 21), (35, 22), (18, 14), (26, 15), (27, 16), (15, 10), (19, 17), (18, 18)]:
        p.put(x, y, "o", ".")
    # The stall on the sand in front of the shelf: the merchant, the boat upturned beside him
    # as his counter, the mast laid along the shelf with the nets, the beacon lighting both.
    # Set, not marked, so it stays where it is put (Plan.mark moves a spawn to the nearest
    # floor; a marker takes its neighbours' ground: RoomTemplate.ground_char).
    p.g[10][22] = "M"
    p.piece("boat", 24, 10)
    p.piece("mast", 18, 7)
    p.piece("cairn", 25, 5)
    # Out on the beach: a tide pool in its ring, standing stones by the south-east flats, kelp
    # glowing cold on the flats' edges, the whalebone where the west exit opens.
    p.piece("tidepool", 30, 12)
    p.piece("stones", 36, 15)
    p.piece("whalebone", 5, 17)
    p.piece("kelplight", 10, 12)
    p.piece("kelplight", 32, 19)
    p.door(0, 12)
    p.door(43, 14)
    p.mark([(22, 21)], "P")
    return p


def flats_altar():
    """The Flats altar, 40x23: a ring of standing stones on a low rise of rock above the beach,
    the altar inside it, lit cold. You come in from the south-west and walk up to it through the
    whalebone arch; the ring is open on that side. Tidal flats west and south-east, kelp glowing
    in them. Exits west and east."""
    p = Plan(40, 23)
    p.blob(20, 11, 16, 8, ".", 201, 0.16)
    p.blob(10, 15, 8, 5, ".", 202, 0.2)
    p.blob(30, 15, 8, 5, ".", 203, 0.2)
    p.blob(19, 18, 9, 3, ".", 204, 0.2)
    p.blob(21, 6, 12, 3.5, ".", 205, 0.2)
    # The rise: raised rock, the last ground to flood; the altar at its heart.
    p.blob(25, 8, 5, 2.6, "=", 211, 0.3, only=".")
    p.g[8][25] = "A"
    # The ring: a row of standing stones behind the altar, single stones round it, open to the
    # south-west where the way up comes in.
    p.piece("stones", 23, 5)
    for (x, y) in [(20, 8), (30, 7), (29, 10)]:
        p.put(x, y, "o", "=")
    # The tidal flats, west and south-east; a pool below the rise.
    p.blob(7, 8, 4, 3, "_", 221, 0.3, only=".")
    p.blob(33, 16, 4, 2.5, "_", 222, 0.3, only=".")
    p.blob(24, 19, 4, 1.5, "_", 223, 0.35, only=".")
    p.blob(5, 17, 2, 1.5, "_", 224, 0.35, only=".")
    # The way up: through the whalebone, the altar seen across the sand.
    p.piece("whalebone", 14, 14)
    p.piece("kelplight", 6, 9)
    p.piece("kelplight", 34, 17)
    p.piece("mast", 30, 12)
    for (x, y) in [(5, 13), (6, 14), (15, 6), (16, 5), (35, 7), (34, 8), (19, 12), (21, 16), (4, 6), (29, 19)]:
        p.put(x, y, "o", ".")
    p.door(0, 11)
    p.door(39, 10)
    p.mark([(9, 18)], "P")
    return p


def flats_fountain():
    """The Flats fountain, 40x23: a spring of sweet water rising on a table of rock in the lee
    of a beached hull. The hull is the backdrop, the spring lit cold in front of it; a tide pool
    and the flats either side. You come in from the south and see it across the sand. Exits
    west and east."""
    p = Plan(40, 23)
    p.blob(20, 11, 16, 8, ".", 301, 0.16)
    p.blob(9, 14, 7, 6, ".", 302, 0.2)
    p.blob(31, 14, 7, 6, ".", 303, 0.2)
    p.blob(22, 18, 9, 3, ".", 304, 0.2)
    # The hull, beached along the north; the spring's table of rock in front of it (one dais,
    # nothing raised touching it, so the fountain is centred on it: Run._dais_centre).
    p.piece("wreck", 15, 4)
    p.blob(19, 8.5, 4, 2.2, "=", 311, 0.15, only=".")
    xs = [x for y in range(p.h) for x in range(p.w) if p.g[y][x] == "="]
    ys = [y for y in range(p.h) for x in range(p.w) if p.g[y][x] == "="]
    p.g[(min(ys) + max(ys)) // 2][(min(xs) + max(xs)) // 2] = "F"
    # The flats: west and east, kelp glowing in them; a tide pool off the hull's stern.
    p.blob(8, 11, 3, 2.6, "_", 321, 0.3, only=".")
    p.blob(32, 17, 5, 3, "_", 322, 0.3, only=".")
    p.blob(14, 18, 3, 1.5, "_", 323, 0.35, only=".")
    p.piece("tidepool", 28, 6)
    p.piece("kelplight", 8, 12)
    p.piece("kelplight", 31, 17)
    # The hull's spilled gear: the mast fallen west, the boat drawn up east.
    p.piece("mast", 8, 6)
    p.piece("boat", 26, 12)
    for (x, y) in [(12, 4), (13, 5), (25, 4), (35, 9), (34, 10), (17, 14), (24, 15), (5, 17), (27, 19), (11, 8)]:
        p.put(x, y, "o", ".")
    p.door(0, 14)
    p.door(39, 12)
    p.mark([(21, 19)], "P")
    return p


def flats_echo():
    """The Flats echo, 40x23: the cage stands on a bar of sand out in the tidal flats, where the
    tide comes in first, and the drowned keep it. A causeway of sand runs out to it from the
    shore; the nets and the mast of whoever was taken lie by the bar. A fight, then the cage.
    Exits north and east."""
    p = Plan(40, 23)
    p.blob(20, 11, 17, 8, ".", 401, 0.15)
    p.blob(9, 16, 8, 5, ".", 402, 0.2)
    p.blob(31, 7, 7, 5, ".", 403, 0.2)
    p.blob(19, 4, 6, 3, ".", 404, 0.25)
    # The flats: a wide basin in the middle-east, the bar in it, the causeway out from the shore.
    p.blob(26, 11, 9, 5, "_", 411, 0.14, only=".")
    p.blob(12, 5, 3, 2, "_", 412, 0.3, only=".")
    p.blob(27, 11, 3, 1.8, ".", 413, 0.2, only="_")
    p.path([(17, 14), (21, 13), (25, 12)], 0.7, ".", 414, 0.0, only="_")
    p.g[11][27] = "E"
    p.piece("mast", 25, 9)
    p.piece("kelplight", 21, 9)
    p.piece("kelplight", 32, 14)
    # The shore: the boat drawn up, standing stones, a cliff spur, rocks.
    p.piece("boat", 7, 11)
    p.piece("stones", 6, 8)
    p.blob(36, 19, 3, 2, "#", 421, 0.3)
    for (x, y) in [(16, 10), (15, 11), (33, 5), (34, 4), (10, 19), (11, 20), (22, 19), (4, 15), (35, 12)]:
        p.put(x, y, "o", ".")
    p.door(19, 0)
    p.door(39, 9)
    p.mark([(7, 17)], "P")
    p.mark([(26, 12), (29, 11), (19, 7), (33, 6), (21, 18), (14, 13)], "e")
    return p


def flats_boss():
    """The Wreck's beach, 40x23: where the Wreck came ashore. Wide dry sand to fight on, the
    broken hull it shed half sunk in the flats along the north (the sea it came out of), shallow
    pools across the sand that its stirring fills. The two roads leave by the south: the harbour
    road west, by a mast and a boat; the reef road east, by a tide pool and kelp light. The
    harbour door comes first in the file, as Run.BIOMES's `next` lists it."""
    p = Plan(40, 23)
    p.blob(20, 11, 17, 9, ".", 501, 0.12)
    p.blob(10, 17, 8, 4, ".", 502, 0.2)
    p.blob(30, 17, 8, 4, ".", 503, 0.2)
    # The flats along the north, the hull in them.
    p.blob(13, 5, 7, 2, "_", 511, 0.3, only=".")
    p.blob(28, 5, 6, 2, "_", 512, 0.3, only=".")
    p.piece("wreck", 12, 5)
    p.piece("kelplight", 27, 5)
    # Pools across the sand: the tide's way in when the Wreck stirs.
    for (cx, cy, rx, ry, s) in [(9, 10, 2.5, 1.5, 521), (29, 9, 3, 1.5, 522), (18, 13.5, 2.6, 1.3, 523),
                                (33, 13, 2, 1.4, 524), (14, 13, 2, 1.2, 525), (25, 13, 1.6, 1.1, 526)]:
        p.blob(cx, cy, rx, ry, "_", s, 0.35, only=".")
    # The harbour road: a mast and a boat by it. The reef road: a tide pool and kelp by it.
    p.piece("mast", 3, 18)
    p.piece("boat", 14, 19)
    p.piece("tidepool", 32, 16)
    p.piece("kelplight", 25, 19)
    p.piece("cairn", 32, 8)
    for (x, y) in [(3, 7), (4, 8), (36, 10), (35, 11), (2, 14), (37, 16), (21, 6), (20, 20), (19, 20)]:
        p.put(x, y, "o", ".")
    p.door(10, 22)
    p.door(29, 22)
    p.mark([(20, 18)], "P")
    p.mark([(20, 8)], "e")
    return p


def _quay(p, bites):
    """A Harbour room's ground: one deck of quay, the rim bitten into (built edges are straight
    but broken: a notch, a step or a buttress at least every ten tiles)."""
    p.rect(2, 2, p.w - 3, p.h - 3, ".")
    for b in bites:
        p.rect(*b, "#")


def harbour_shop():
    """The Harbour merchant, 40x23: the drowned merchant trades at the end of a timber pier out
    over the channel, a boat moored alongside for his stock, the lamppost at the pier's root the
    one warm light. You come in on the south quay and see him out on the water. Exits west and
    east along the quay."""
    p = Plan(40, 23)
    _quay(p, [(2, 2, 5, 3), (31, 2, 37, 2), (2, 18, 4, 20), (25, 20, 32, 20), (36, 11, 37, 13), (14, 2, 16, 2)])
    # The channel across the north, quay steps down into it.
    p.rect(2, 4, 37, 9, "_")
    p.rect(7, 10, 9, 10, "_")
    p.rect(29, 10, 31, 10, "_")
    # The pier: raised timber out from the quay, a landing at its end, the merchant on it.
    p.rect(11, 4, 17, 6, "=")
    p.piece("pier", 13, 6)
    p.g[5][14] = "M"
    p.piece("moored", 18, 5)
    p.piece("lamppost", 12, 12)
    p.piece("capstan", 17, 12)
    p.piece("buoy", 27, 6)
    p.piece("buoy", 5, 7)
    # Cargo on the quay: crate stacks, a net rack, bollards along the edge.
    p.piece("crates", 4, 13)
    p.piece("netrack", 26, 16)
    p.piece("crates", 31, 12)
    for (x, y) in [(10, 10), (24, 10), (34, 10), (21, 14), (22, 14), (9, 17), (10, 17), (34, 17), (17, 19), (6, 11)]:
        p.put(x, y, "o", ".")
    p.door(0, 15)
    p.door(39, 16)
    p.mark([(22, 18)], "P")
    return p


def harbour_altar():
    """The Harbour altar, 40x23: an emptied dry dock cut into the quay, the altar on the stone
    sill at its head where the dock gate was, lit cold; the slipway runs down into it from the south quay, the
    crane stands over it with its lamp. The dock floods first; the sill stays dry longest. You
    come in at the slipway's foot. Exits west and east."""
    p = Plan(40, 23)
    _quay(p, [(2, 2, 4, 4), (33, 2, 37, 3), (2, 19, 6, 20), (30, 20, 37, 20), (36, 9, 37, 10), (19, 2, 21, 2)])
    # The dock: a straight basin, stepped at its head, the ramp down from the south.
    p.rect(10, 4, 22, 12, "_")
    p.rect(9, 7, 9, 9, "_")
    p.rect(23, 9, 23, 11, "_")
    p.rect(13, 13, 18, 16, "_")
    # The dock gate's sill: raised stone across the dock's head, the altar on it.
    p.rect(12, 4, 20, 6, "=")
    p.g[6][12] = "_"
    p.g[6][20] = "_"
    p.g[5][16] = "A"
    p.piece("slipway", 14, 12)
    p.piece("crane", 24, 5)
    p.piece("capstan", 6, 4)
    p.piece("capstan", 24, 2)
    # East of the dock: the dock master's shed and its yard, cargo in rows.
    p.rect(30, 3, 37, 8, "#")
    p.rect(33, 9, 37, 9, "#")
    # The quays round it: crates waiting, a net rack, bollards along the dock's edge.
    p.piece("crates", 4, 10)
    p.piece("crates", 31, 14)
    p.piece("netrack", 7, 17)
    for (x, y) in [(8, 6), (8, 11), (24, 12), (27, 16), (28, 16), (28, 9), (29, 10), (4, 6), (10, 19), (33, 18), (22, 18)]:
        p.put(x, y, "o", ".")
    p.door(0, 12)
    p.door(39, 13)
    p.mark([(12, 19)], "P")
    return p


def harbour_fountain():
    """The Harbour fountain, 40x23: the market quay's pump on its stone dais, the warehouse
    behind it, the lamppost by it; the channel runs along the south with a boat tied up. You
    come in from the south-west and see it across the market. Exits west and east."""
    p = Plan(40, 23)
    _quay(p, [(2, 2, 6, 3), (30, 2, 37, 2), (2, 13, 3, 15), (36, 18, 37, 20), (17, 2, 18, 2)])
    p.rect(2, 16, 26, 20, "_")
    p.rect(27, 18, 37, 20, "_")
    p.rect(11, 15, 13, 15, "_")
    p.rect(30, 17, 32, 17, "_")
    # The dais: one raised block with its corners cut, the pump at its centre.
    p.rect(20, 6, 28, 10, "=")
    for (x, y) in [(20, 6), (28, 6), (20, 10), (28, 10)]:
        p.g[y][x] = "."
    p.g[8][24] = "F"
    p.piece("warehouse", 21, 2)
    p.piece("lamppost", 30, 6)
    # West of the market: a block of sheds against the mass.
    p.rect(2, 4, 7, 8, "#")
    p.rect(8, 4, 9, 5, "#")
    p.piece("crates", 11, 3)
    p.piece("crates", 33, 3)
    p.piece("netrack", 6, 11)
    p.piece("moored", 15, 17)
    p.piece("buoy", 8, 18)
    p.piece("buoy", 33, 18)
    for (x, y) in [(14, 8), (15, 8), (32, 11), (33, 11), (17, 13), (27, 14), (35, 15), (4, 13)]:
        p.put(x, y, "o", ".")
    p.door(0, 9)
    p.door(39, 8)
    p.mark([(8, 13)], "P")
    return p


def harbour_echo():
    """The Harbour echo, 40x23: the cage stands on the stone footing of the old harbour light,
    out in the basin, a timber pier out to it from the south quay; the lamppost at the pier's
    root, a hull tied up by the footing, buoys in the basin. The drowned on the footing and the
    quays. You come in on the west quay and see it out on the water. Exits north and south."""
    p = Plan(40, 23)
    _quay(p, [(2, 2, 4, 3), (2, 19, 5, 20), (12, 2, 14, 2), (12, 20, 15, 20)])
    p.rect(16, 3, 37, 18, "_")
    p.rect(30, 19, 37, 20, "_")
    p.rect(15, 7, 15, 8, "_")
    p.rect(15, 14, 15, 15, "_")
    # The footing: raised stone, its corners broken; the pier out to it from the south quay.
    p.rect(22, 7, 32, 12, "=")
    for (x, y) in [(22, 7), (32, 7), (32, 12), (23, 7)]:
        p.g[y][x] = "_"
    p.piece("pier", 25, 13)
    p.g[9][28] = "E"
    p.piece("capstan", 30, 10)
    for (x, y) in [(23, 11), (24, 11), (31, 8)]:
        p.put(x, y, "o", "=")
    p.piece("lamppost", 23, 19)
    p.piece("warehouse", 5, 4)
    p.piece("netrack", 6, 15)
    p.piece("buoy", 19, 15)
    p.piece("buoy", 35, 4)
    p.piece("moored", 30, 15)
    for (x, y) in [(9, 9), (10, 9), (9, 10), (12, 17), (3, 12), (14, 5)]:
        p.put(x, y, "o", ".")
    p.door(8, 0)
    p.door(9, 22)
    p.mark([(4, 9)], "P")
    p.mark([(26, 9), (29, 12), (19, 5), (11, 6), (12, 14), (20, 19)], "e")
    return p


def harbour_boss():
    """The Chainmother's basin, 40x23: the dock where every ship that tried to leave is still
    tied up. The basin in the middle, where she rises; two hulls moored at its corners, the
    capstans and bollards that hold them round it; the crane's lamp over the north-east. The
    old harbour wall's raised coping all round, the dry ring to fight on when the tide is deep.
    One way out, north, to the Streets."""
    p = Plan(40, 23)
    _quay(p, [(2, 2, 5, 3), (34, 18, 37, 20), (2, 17, 3, 20), (13, 20, 17, 20), (36, 7, 37, 9)])
    p.rect(10, 6, 29, 15, "_")
    for (x, y) in [(10, 6), (11, 6), (10, 7), (29, 15), (28, 15), (29, 14)]:
        p.g[y][x] = "."
    p.rect(15, 16, 17, 16, "_")
    p.rect(24, 5, 26, 5, "_")
    p.rect(9, 11, 9, 12, "_")
    # The old harbour wall's coping all round: raised stone, the dry place to fight when the
    # night's tide is deep (STYLE.md 1.45), stepped down to the quay where it would run long.
    for (x0, y0, x1, y1) in [(2, 2, 37, 4), (2, 17, 37, 20), (2, 2, 5, 20), (34, 2, 37, 20)]:
        p.rect(x0, y0, x1, y1, "=", only=".")
    for (x0, y0, x1, y1) in [(19, 17, 21, 17), (5, 9, 5, 10), (34, 12, 34, 13), (12, 4, 13, 4), (28, 17, 29, 17)]:
        p.rect(x0, y0, x1, y1, ".")
    p.piece("moored", 12, 6)
    p.piece("moored", 24, 14)
    p.piece("capstan", 6, 5)
    p.piece("capstan", 32, 15)
    p.piece("crane", 31, 2)
    p.piece("crates", 3, 13)
    p.piece("buoy", 14, 11)
    p.piece("buoy", 26, 9)
    for (x, y) in [(9, 8), (30, 11), (13, 17), (27, 4), (21, 4), (6, 18), (33, 7), (20, 17)]:
        p.put(x, y, "o", ".")
    p.door(20, 0)
    p.g[18][20] = "P"
    p.mark([(20, 10)], "e")
    return p


def streets_shop():
    """The Streets merchant, 40x23: his stall in a small market square hemmed by houses, a cold
    lamp over it; a well off the square's centre, a statue fallen by the east street, a corner
    the sea has sunk. You come in up the south alley and see him across the square. Exits by
    the west street and the east street."""
    p = Plan(40, 23)
    p.rect(5, 5, 33, 17, ".")
    p.rect(2, 10, 5, 13, ".")
    p.rect(33, 7, 37, 10, ".")
    p.rect(16, 17, 20, 20, ".")
    # The blocks: broken fronts pushed into the square.
    for b in [(5, 5, 8, 7), (5, 15, 9, 17), (29, 14, 33, 17), (28, 5, 29, 6), (13, 17, 15, 17)]:
        p.rect(*b, "#")
    p.piece("house", 9, 5)
    p.piece("house", 21, 5)
    p.piece("stall", 16, 6)
    p.g[8][18] = "M"
    p.piece("coldlamp", 20, 8)
    p.piece("well", 11, 11)
    p.piece("fallen", 26, 11)
    p.piece("lamps", 33, 10)
    p.blob(24, 15, 3, 1.6, "_", 611, 0.3, only=".")
    for (x, y) in [(15, 12), (30, 8), (8, 9), (21, 13), (13, 15), (4, 11)]:
        p.put(x, y, "o", ".")
    p.door(0, 12)
    p.door(39, 8)
    p.mark([(18, 19)], "P")
    return p


def streets_altar():
    """The Streets altar, 40x23: a wayside chapel open on a little square, its floor raised, a
    flight of steps up to it, the altar inside lit cold between two shrines. A canal cuts the
    west of the room and a bridge carries the street over it, so you cross the water and climb
    to it. Exits west over the canal's street and east."""
    p = Plan(40, 23)
    p.rect(2, 5, 36, 19, ".")
    p.rect(14, 2, 18, 5, ".")
    for b in [(2, 5, 5, 7), (2, 17, 6, 19), (32, 16, 36, 19), (34, 5, 36, 8), (14, 2, 15, 3)]:
        p.rect(*b, "#")
    # The canal, north to south, the bridge over it on the street.
    p.path([(10, 4), (9, 11), (10, 20)], 1.6, "_", 621, 0.4)
    p.piece("bridge", 6, 10)
    # The chapel: walls round three sides, its raised floor, the steps up from the square.
    p.rect(22, 3, 33, 10, "#")
    p.rect(24, 4, 31, 10, "=")
    p.rect(27, 10, 28, 10, "=")
    p.g[6][27] = "A"
    p.piece("steps", 25, 11)
    p.piece("shrine", 24, 4)
    p.piece("shrine", 31, 4)
    # The square before it: a house block, a well, rubble, a lamp lit by the sea at the bridge.
    p.piece("house", 16, 14)
    p.piece("well", 33, 12)
    p.piece("coldlamp", 13, 9)
    for (x, y) in [(19, 8), (20, 8), (15, 6), (35, 15), (13, 18), (22, 18), (4, 15)]:
        p.put(x, y, "o", ".")
    p.door(0, 12)
    p.door(39, 11)
    p.mark([(4, 9)], "P")
    return p


def streets_fountain():
    """The Streets fountain, 40x23: the city's fountain on its dais in a sunken court, the
    paving round it gone under the sea's level (it floods first; the dais last); house fronts
    round the court, cold lamps at its corners, a statue's plinth. You come in from the south-
    west street and look across the court to it. Exits west and north."""
    p = Plan(40, 23)
    p.rect(4, 4, 35, 18, ".")
    p.rect(2, 13, 4, 16, ".")
    p.rect(22, 2, 25, 4, ".")
    for b in [(4, 4, 8, 6), (30, 4, 35, 5), (4, 17, 10, 18), (31, 15, 35, 18), (35, 9, 35, 11)]:
        p.rect(*b, "#")
    # The court: low, its corners cut; the dais in it, one raised block.
    p.rect(11, 7, 29, 15, "_")
    for (x, y) in [(11, 7), (29, 7), (11, 15), (29, 15), (12, 7), (11, 8)]:
        p.g[y][x] = "."
    p.rect(17, 9, 23, 13, "=")
    for (x, y) in [(17, 9), (23, 9), (17, 13), (23, 13)]:
        p.g[y][x] = "_"
    p.g[11][20] = "F"
    p.piece("house", 10, 4)
    p.piece("house", 23, 16)
    p.piece("coldlamp", 10, 8)
    p.piece("coldlamp", 30, 14)
    p.piece("lamps", 26, 5)
    p.piece("fallen", 31, 10)
    for (x, y) in [(6, 9), (7, 9), (33, 7), (14, 17), (19, 17), (21, 6), (5, 12)]:
        p.put(x, y, "o", ".")
    p.door(0, 15)
    p.door(23, 0)
    p.mark([(6, 15)], "P")
    return p


def streets_echo():
    """The Streets echo (1), 40x23: the cage in the churchyard before the tower's stump, the
    fallen church's stones lying in rows where its nave stood, a shrine at the yard's gate in a
    broken wall; the drowned among the stones. You come in at the gate and see the cage by the
    tower. Exits north and east."""
    p = Plan(40, 23)
    p.rect(3, 3, 36, 19, ".")
    p.rect(2, 9, 3, 12, ".")
    for b in [(3, 3, 7, 5), (31, 3, 36, 4), (3, 17, 8, 19), (30, 18, 36, 19), (17, 19, 21, 19)]:
        p.rect(*b, "#")
    # The churchyard wall, broken; the tower's stump, the cage before it.
    p.rect(10, 6, 10, 15, "#")
    p.rect(10, 9, 10, 11, ".")
    p.piece("tower", 22, 4)
    p.g[8][24] = "E"
    p.piece("shrine", 11, 8)
    # The nave's stones in rows, some gone; a fallen statue; a sunken corner.
    for y in (11, 14, 16):
        for x in range(13, 34, 3):
            if (x * 7 + y) % 5 != 0:
                p.put(x, y, "o", ".")
    p.piece("fallen", 29, 7)
    p.piece("coldlamp", 19, 6)
    p.blob(33, 13, 2.5, 2, "_", 641, 0.3, only=".")
    p.blob(6, 15, 2, 1.5, "_", 642, 0.3, only=".")
    p.piece("house", 13, 3)
    for (x, y) in [(5, 7), (7, 13), (34, 6)]:
        p.put(x, y, "o", ".")
    p.door(27, 0)
    p.door(39, 10)
    p.mark([(4, 10)], "P")
    p.mark([(21, 9), (27, 10), (15, 13), (25, 15), (31, 16), (17, 17)], "e")
    return p


def streets_echo_2():
    """The Streets echo (2), 40x23: the cage on a bridge in the middle of a canal, the street
    gone under on both banks; the drowned on the banks and coming up out of the water. You come
    in on the west bank and see it out on the bridge. Exits north on the east bank, south on
    the west."""
    p = Plan(40, 23)
    p.rect(3, 3, 36, 19, ".")
    for b in [(3, 3, 6, 4), (31, 3, 36, 5), (3, 18, 7, 19), (32, 17, 36, 19)]:
        p.rect(*b, "#")
    # The canal, wide and deep through the middle; low street at its banks.
    p.path([(19, 2), (18, 10), (18, 11), (20, 20)], 2.3, "_", 651, 0.3)
    p.blob(9, 14, 4, 2.5, "_", 652, 0.3, only=".")
    p.blob(29, 7, 4, 2, "_", 653, 0.3, only=".")
    p.piece("bridge", 15, 9)
    p.g[10][18] = "E"
    # The banks: house fronts, a lamp lit by the sea at each end of the bridge, rubble.
    p.piece("house", 7, 5)
    p.piece("house", 26, 14)
    p.piece("coldlamp", 13, 9)
    p.piece("coldlamp", 22, 12)
    p.piece("well", 31, 10)
    p.piece("stall", 5, 9)
    for (x, y) in [(10, 17), (11, 17), (28, 4), (34, 13), (4, 13), (25, 9)]:
        p.put(x, y, "o", ".")
    p.door(29, 0)
    p.door(10, 22)
    p.mark([(4, 11)], "P")
    p.mark([(12, 7), (16, 15), (24, 7), (29, 12), (33, 16), (9, 15)], "e")
    return p


def streets_boss():
    """The Bell's square, 40x23: Saltmere's square under the bell tower. The tower on the north,
    the church terrace raised before it where the Bell rises (the first spawn, so the boss's),
    the square's statues on their spots round it (the later spawns: dormant until the bell
    cracks), the well and a fallen statue, low corners the sea comes in by, the house fronts
    round it. One way out, by the alley beside the tower."""
    p = Plan(40, 23)
    p.rect(3, 3, 36, 19, ".")
    for b in [(3, 3, 7, 5), (32, 3, 36, 5), (3, 17, 5, 19), (34, 17, 36, 19), (16, 19, 23, 19)]:
        p.rect(*b, "#")
    p.piece("tower", 18, 3)
    # The church terrace: raised, the dry ground at the Bell; its corners cut, steps down.
    p.rect(12, 6, 27, 9, "=")
    for (x, y) in [(12, 6), (27, 6), (12, 9), (27, 9)]:
        p.g[y][x] = "."
    p.piece("steps", 14, 10)
    p.piece("steps", 21, 10)
    # Low corners the sea comes in by.
    p.blob(6, 9, 2.5, 2.5, "_", 661, 0.3, only=".")
    p.blob(33, 13, 2.5, 2.5, "_", 662, 0.3, only=".")
    p.blob(10, 18, 3, 1.2, "_", 663, 0.3, only=".")
    p.piece("well", 25, 14)
    p.piece("fallen", 9, 13)
    p.piece("house", 8, 3)
    p.piece("house", 25, 3)
    p.piece("coldlamp", 11, 7)
    p.piece("coldlamp", 30, 8)
    p.piece("lamps", 27, 18)
    for (x, y) in [(17, 15), (29, 11), (4, 13), (35, 9)]:
        p.put(x, y, "o", ".")
    p.door(31, 0)
    p.g[8][20] = "e"
    p.mark([(8, 11), (31, 11), (13, 16), (28, 16)], "e")
    p.mark([(20, 18)], "P")
    return p


ALL = {
    "biome2/shop_01": streets_shop,
    "biome2/altar_01": streets_altar,
    "biome2/fountain_01": streets_fountain,
    "biome2/echo_01": streets_echo,
    "biome2/echo_02": streets_echo_2,
    "biome2/boss_01": streets_boss,
    "harbour/shop_01": harbour_shop,
    "harbour/altar_01": harbour_altar,
    "harbour/fountain_01": harbour_fountain,
    "harbour/echo_01": harbour_echo,
    "harbour/boss_01": harbour_boss,
    "biome1/shop_01": flats_shop,
    "biome1/altar_01": flats_altar,
    "biome1/fountain_01": flats_fountain,
    "biome1/echo_01": flats_echo,
    "biome1/boss_01": flats_boss,
}


def main():
    names = sys.argv[1:] or list(ALL)
    bad = 0
    for name in names:
        p = ALL[name]()
        errs = p.check(name)
        holes = p.holes()
        sym = p.symmetry()
        path = os.path.join(ROOMS, name + ".txt")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(p.text())
        print("%s %dx%d: %s; bare squares %s; symmetry %.2f" % (name, p.w, p.h, "ok" if not errs else "; ".join(errs),
                                                               [h[0] for h in holes] or "none", sym))
        bad += len(errs)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
