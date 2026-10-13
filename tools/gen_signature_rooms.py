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


def _ellipse(p, cx, cy, rx, ry, ch, only=None):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                p.put(x, y, ch, only)


def hall_shop():
    """The Hall merchant, 40x23: the drowned merchant keeps shop in the crypt, a tomb slab for
    his counter, candles either side of it; the vault's columns in rows (one down in rubble),
    tomb slabs between them, a crypt grate sunk in the floor. You come in from the south of the
    vault and see him across the slabs. Exits west and east."""
    p = Plan(40, 23)
    p.rect(3, 4, 36, 18, ".")
    for b in [(3, 4, 6, 5), (33, 4, 36, 6), (3, 16, 5, 18), (31, 17, 36, 18), (18, 4, 20, 4)]:
        p.rect(*b, "#")
    # The vault's columns, in two rows; the east one of the south row is down.
    for (x, y) in [(8, 7), (14, 7), (25, 7), (31, 7), (8, 13), (14, 13), (25, 13)]:
        p.piece("column", x, y)
    for (x, y) in [(31, 13), (32, 14), (30, 15), (33, 12)]:
        p.put(x, y, "o", ".")
    # The slabs: his counter, and the tombs between the columns (one broken).
    p.rect(18, 9, 21, 10, "=")
    p.g[8][19] = "M"
    p.piece("candles", 17, 8)
    p.piece("candles", 22, 8)
    for (x0, y0) in [(9, 10), (27, 10), (9, 16)]:
        p.rect(x0, y0, x0 + 2, y0 + 1, "=")
    p.rect(28, 16, 29, 16, "=")
    # The crypt grate, and brine standing where the floor has sunk.
    p.rect(17, 13, 20, 14, "_")
    p.blob(6, 11, 2, 1.5, "_", 711, 0.3, only=".")
    p.piece("kelpglow", 18, 15)
    for (x, y) in [(12, 5), (23, 5), (35, 10), (24, 17)]:
        p.put(x, y, "o", ".")
    p.door(0, 11)
    p.door(39, 10)
    p.mark([(19, 17)], "P")
    return p


def hall_altar():
    """The Hall altar, 40x23: a side chapel. The altar on the dais in its apse, the apse wall
    behind it, two keeper statues at the dais steps, candles; columns down the nave's edges, one
    down; the west aisle's gutter has burst. You come in through the chapel's gate and walk up
    the nave to it. Exits west by the aisle and east."""
    p = Plan(40, 23)
    p.rect(12, 6, 27, 20, ".")
    p.rect(6, 8, 11, 19, ".")
    p.rect(28, 10, 34, 19, ".")
    p.rect(2, 12, 6, 14, ".")
    p.rect(34, 14, 37, 16, ".")
    _ellipse(p, 19.5, 7, 8, 5, ".")
    _ellipse(p, 19.5, 6.5, 5, 3, "=")
    p.rect(17, 9, 22, 10, "=")
    p.g[6][19] = "A"
    p.piece("apse", 17, 3)
    p.piece("statue", 13, 8)
    p.piece("statue", 25, 8)
    p.piece("candles", 16, 4)
    p.piece("candles", 23, 4)
    for (x, y) in [(12, 12), (12, 16), (26, 12)]:
        p.piece("column", x, y)
    for (x, y) in [(26, 16), (27, 17), (25, 18)]:
        p.put(x, y, "o", ".")
    # The west aisle's gutter has burst into a pool; the east aisle is dry and narrow.
    p.rect(7, 9, 7, 18, "_")
    p.blob(9, 15, 2.5, 2, "_", 721, 0.3, only=".")
    p.piece("kelpglow", 8, 16)
    p.piece("gate", 17, 18)
    for (x, y) in [(30, 11), (33, 18), (10, 9)]:
        p.put(x, y, "o", ".")
    p.door(0, 13)
    p.door(39, 15)
    p.mark([(19, 20)], "P")
    return p


def hall_fountain():
    """The Hall fountain, 40x23: the baptistery, a round hall with the fountain on its round dais
    at the centre, a ring of columns round it (one down, its drums across the floor), the east
    wall breached into the dark, brine standing in the low ring by the walls. You come in by the
    west passage and see it across the floor. Exits west and north."""
    p = Plan(40, 23)
    _ellipse(p, 20, 11, 15, 8.5, ".")
    p.rect(2, 10, 6, 12, ".")
    p.rect(19, 2, 21, 4, ".")
    # The dais: round, one raised block, the fountain at its centre.
    _ellipse(p, 20, 11, 3.6, 2.4, "=")
    p.g[11][20] = "F"
    # The ring of columns; the south-east one is down.
    for (x, y) in [(29, 10), (24, 5), (14, 5), (9, 10), (14, 15)]:
        p.piece("column", x, y)
    for (x, y) in [(25, 16), (26, 17), (27, 16), (28, 18)]:
        p.put(x, y, "o", ".")
    # The low ring by the wall, brine in it; the breach in the east wall.
    p.blob(31, 15, 3, 2, "_", 731, 0.3, only=".")
    p.blob(9, 16, 2.5, 1.5, "_", 732, 0.3, only=".")
    p.blob(33, 7, 4, 3.5, ".", 733, 0.3)
    p.blob(36, 6, 1.5, 2, "#", 734, 0.3)
    for (x, y) in [(33, 5), (35, 9), (32, 8)]:
        p.put(x, y, "o", ".")
    p.piece("kelpglow", 31, 15)
    p.piece("candles", 18, 4)
    p.piece("statue", 26, 4)
    for (x, y) in [(12, 9), (33, 11), (7, 13)]:
        p.put(x, y, "o", ".")
    p.door(0, 11)
    p.door(20, 0)
    p.mark([(6, 11)], "P")
    return p


def hall_echo():
    """The Hall echo, 40x23: the drowned choir. The cage stands before the organ at its head,
    the choir stalls in raised rows either side, candles on the organ; a transept of brine
    crosses the hall below the choir, the first ground to go under; columns, a statue, rubble.
    The drowned among the stalls. You come in from the south-west. Exits north-east and east."""
    p = Plan(40, 23)
    p.rect(3, 3, 36, 19, ".")
    for b in [(3, 3, 6, 4), (32, 3, 36, 4), (3, 18, 6, 19), (33, 17, 36, 19), (14, 19, 18, 19)]:
        p.rect(*b, "#")
    p.piece("organ", 17, 3)
    p.g[7][20] = "E"
    p.piece("candles", 16, 4)
    p.piece("candles", 23, 4)
    # The stalls: raised rows facing across the choir, broken.
    for (x0, y0, x1, y1) in [(9, 6, 15, 7), (25, 6, 31, 7), (9, 10, 14, 11), (26, 10, 31, 11)]:
        p.rect(x0, y0, x1, y1, "=")
    p.put(12, 10, ".")
    # The transept, east to west across the hall, brine in it.
    p.path([(3, 14), (20, 15), (36, 13)], 1.1, "_", 741, 0.35)
    p.piece("kelpglow", 27, 14)
    for (x, y) in [(6, 7), (33, 7), (6, 16)]:
        p.piece("column", x, y)
    for (x, y) in [(31, 16), (30, 17), (32, 17)]:
        p.put(x, y, "o", ".")
    p.piece("statue", 22, 17)
    for (x, y) in [(18, 12), (24, 9), (10, 17), (36, 9)]:
        p.put(x, y, "o", ".")
    p.door(30, 0)
    p.door(39, 10)
    p.mark([(4, 17)], "P")
    p.mark([(18, 8), (23, 9), (12, 9), (28, 9), (14, 16), (27, 16)], "e")
    return p


def hall_boss():
    """The Ebb's crossing, 40x23: the crossing of the Deep Hall, where the Ebb waits on the
    raised floor between the four piers; the high altar behind it under the north wall with the
    keepers' statues standing either side (every keeper before you is standing in it), the
    transept's arms flooded east and west, the gate at the south where you come in. The crossing
    is the dry ground at the Ebb; it floods further as it rises. One way out, south."""
    p = Plan(40, 23)
    p.rect(3, 3, 36, 19, ".")
    for b in [(3, 3, 6, 4), (33, 3, 36, 4), (3, 18, 8, 19), (31, 18, 36, 19)]:
        p.rect(*b, "#")
    # The transept's arms, flooded, broken at their edges.
    p.blob(6, 11, 3.5, 5.5, "_", 751, 0.25, only=".")
    # The east arm: its wall fallen into the dark, rubble across it, brine in the hollow.
    p.blob(33, 13, 2.5, 3, "_", 752, 0.3, only=".")
    p.blob(37, 7, 3, 2.5, "#", 753, 0.3)
    for (x, y) in [(32, 6), (34, 8), (31, 9), (33, 5)]:
        p.put(x, y, "o", ".")
    # The crossing: raised, round; the piers at its corners.
    _ellipse(p, 19.5, 10.5, 7.5, 4.2, "=")
    for (x, y) in [(10, 5), (28, 5), (10, 14)]:
        p.piece("column", x, y)
    # The south-east pier is down, its drums across the floor toward the gate.
    for (x, y) in [(28, 15), (27, 16), (25, 16), (24, 17)]:
        p.put(x, y, "o", ".")
    p.piece("altar", 18, 3)
    for (x, y) in [(8, 3), (13, 3), (24, 3), (30, 3)]:
        p.piece("statue", x, y)
    p.piece("gate", 17, 17)
    p.rect(16, 19, 23, 20, ".")
    p.piece("kelpglow", 5, 12)
    p.piece("kelpglow", 33, 14)
    p.piece("candles", 23, 6)
    for (x, y) in [(13, 16), (35, 16), (4, 6), (16, 15)]:
        p.put(x, y, "o", ".")
    p.door(19, 22)
    p.g[10][20] = "e"
    p.mark([(19, 20)], "P")
    return p


def _reef_floor(p, bites):
    """A Reef room's ground: sand inside the sea wall, the rim bitten back (the reef's edge is
    never straight; only the wall is)."""
    p.rect(3, 3, p.w - 4, p.h - 4, ".")
    for (x, y, rx, ry, sd) in bites:
        p.blob(x, y, rx, ry, "#", sd, 0.3)


def reef_shop():
    """The Reef merchant, 40x23: the drowned merchant trades on a coral head inside the ribs of
    a wreck the reef has grown over, glowing coral beside him; a slow channel runs past the
    head's foot west to east, its water moving; fans and a clam by it. You come in on the sand
    from the south and see him up on the head. Exits west and east."""
    p = Plan(40, 23)
    _reef_floor(p, [(3, 4, 3, 2, 801), (36, 18, 3, 2.5, 802), (24, 19, 4, 1.5, 803), (36, 4, 2, 2, 804)])
    # The coral head, the ribs grown over it, the merchant inside them.
    p.blob(19, 7, 6, 3, "=", 811, 0.3, only=".")
    p.piece("ribcoral", 15, 4)
    p.g[7][18] = "M"
    p.piece("glowcoral", 22, 7)
    p.piece("wallsteps", 17, 10)
    # The channel past its foot, the water running east.
    p.path([(3, 13), (12, 12), (26, 13), (36, 12)], 0.8, "_", 812, 0.3, only=".")
    p.currents.append([(3, 13), (12, 12), (26, 13), (36, 12)])
    p.piece("fans", 8, 10)
    p.piece("clam", 29, 9)
    p.piece("jelly", 31, 12)
    p.piece("brainhead", 7, 16)
    p.blob(31, 16, 2.5, 1.5, "=", 813, 0.3, only=".")
    for (x, y) in [(13, 16), (14, 17), (27, 6), (5, 9), (34, 15), (21, 17)]:
        p.put(x, y, "o", ".")
    p.door(0, 9)
    p.door(39, 15)
    p.mark([(19, 18)], "P")
    return p


def reef_altar():
    """The Reef altar, 40x23: Saltmere's sea wall across the north; a bastion built out from it,
    raised, the altar on it lit cold, the wall's stair up to it; west of it the wall is breached
    and the sea comes through and runs south down a channel. An anchor driven into the sand by
    the wall. You come in from the east and see it up on the bastion. Exits west and east."""
    p = Plan(40, 23)
    _reef_floor(p, [(4, 18, 3, 2.5, 821), (35, 19, 3, 2, 822), (20, 20, 4, 1.2, 823)])
    # The wall: straight, three courses thick; a breach in it to the west.
    p.rect(3, 3, 36, 5, "#")
    p.rect(9, 3, 12, 5, ".")
    # The bastion: raised, built out from the wall, its corners square (it is built), notched.
    p.rect(20, 6, 30, 10, "=")
    p.rect(20, 10, 21, 10, ".")
    p.g[8][25] = "A"
    p.piece("wallsteps", 22, 11)
    p.piece("glowcoral", 29, 7)
    # The sea through the breach, south down its channel.
    p.path([(10, 4), (10, 9), (7, 14), (9, 19)], 1.4, "_", 824, 0.4, only=".")
    p.currents.append([(10, 3), (10, 9), (7, 14), (9, 19)])
    p.piece("breach", 7, 6)
    p.piece("anchor", 16, 7)
    p.piece("staghorn", 14, 14)
    p.piece("fans", 31, 15)
    p.piece("jelly", 8, 12)
    p.blob(27, 16, 2.5, 1.5, "_", 825, 0.3, only=".")
    for (x, y) in [(18, 6), (19, 7), (15, 9), (33, 7), (34, 8), (24, 17), (5, 11)]:
        p.put(x, y, "o", ".")
    p.door(0, 12)
    p.door(39, 12)
    p.mark([(35, 12)], "P")
    return p


def reef_fountain():
    """The Reef fountain, 40x23: a coral table in a ring of water, the fountain on the table;
    the ring's water circles it (a current that goes round), living coral grown into the ring on its
    south-east, staghorn and a brain-coral head out on the sand, a jellyfish bloom over the ring.
    You come in from the west and see it across the sand. Exits west and south."""
    p = Plan(40, 23)
    _reef_floor(p, [(3, 4, 2.5, 2, 831), (36, 19, 3, 2, 832), (36, 5, 2, 2, 833), (5, 19, 3, 1.5, 834)])
    # The ring, the table in it: one raised region, nothing raised touching it.
    _ellipse(p, 24, 9, 7, 4.6, "_")
    _ellipse(p, 24, 9, 3.6, 2.2, "=")
    p.g[9][24] = "F"
    p.currents.append([(24, 4), (30, 6), (31, 9), (30, 12), (24, 13), (18, 12), (17, 9), (18, 6), (24, 4)])
    # Living coral has grown into the ring on its south-east side.
    for (x, y) in [(28, 13), (29, 12), (30, 11)]:
        p.put(x, y, "o", "_")
    p.piece("fans", 31, 15)
    p.piece("glowcoral", 18, 11)
    p.piece("jelly", 29, 7)
    p.piece("staghorn", 13, 9)
    p.piece("brainhead", 8, 6)
    p.piece("clam", 33, 16)
    p.blob(9, 15, 2.5, 1.5, "=", 835, 0.3, only=".")
    for (x, y) in [(12, 5), (30, 4), (35, 11), (18, 18), (25, 18), (6, 12)]:
        p.put(x, y, "o", ".")
    p.door(0, 11)
    p.door(24, 22)
    p.mark([(5, 11)], "P")
    return p


def reef_echo():
    """The Reef echo, 40x23: the sea wall across the north, breached; the sea pours through the
    breach and runs south down a channel; the cage stands on the wall's rubble at the breach's
    foot, the water going past it. The drowned on the coral either side. You come in from the
    south-west. Exits east and south."""
    p = Plan(40, 23)
    _reef_floor(p, [(3, 19, 2.5, 1.5, 841), (36, 3, 2, 1.5, 842), (36, 19, 2, 1.5, 843)])
    p.rect(3, 3, 36, 5, "#")
    p.rect(18, 3, 22, 5, ".")
    p.piece("breach", 17, 6)
    # The channel from the breach, south and east, the current down it.
    p.path([(20, 4), (20, 9), (24, 14), (30, 19)], 1.6, "_", 851, 0.4, only=".")
    p.currents.append([(20, 3), (20, 9), (24, 14), (30, 19)])
    # The rubble heap at the breach's foot, raised, the cage on it.
    p.blob(14, 10, 3, 2, "=", 852, 0.3, only=".")
    p.g[10][14] = "E"
    p.piece("glowcoral", 16, 9)
    p.piece("brainhead", 28, 7)
    p.piece("staghorn", 7, 13)
    p.piece("fans", 25, 17)
    p.piece("anchor", 10, 7)
    p.piece("jelly", 22, 11)
    p.blob(32, 12, 3, 2, "=", 853, 0.3, only=".")
    for (x, y) in [(16, 7), (24, 7), (25, 8), (12, 16), (13, 17), (34, 8), (5, 9)]:
        p.put(x, y, "o", ".")
    p.door(39, 11)
    p.door(9, 22)
    p.mark([(5, 17)], "P")
    p.mark([(11, 11), (18, 12), (27, 10), (31, 15), (15, 15), (33, 9)], "e")
    return p


def reef_boss():
    """The Tidewall's breach, 40x23 (map Stage 11j's arena, dressed): the wall's top raised along
    the north (the Tidewall slides along it; the dry ground to fight at it, 11l), the two
    channels across the arena with their currents (the second running back; the Tidewall turns
    them), coral heads, fans and glowing coral between them, the wall's rubble at its foot, the
    jellies over the water. The shelf, the channels and their lines are kept as 11j-11l made
    them. One way out, south."""
    p = Plan(40, 23)
    p.rect(2, 4, 37, 21, ".")
    for (x, y, rx, ry, sd) in [(3, 20, 2, 1.5, 861), (36, 20, 2, 1.5, 862)]:
        p.blob(x, y, rx, ry, "#", sd, 0.3)
    # The wall's top: raised, straight (it is the wall), stepped where it was rebuilt.
    p.rect(2, 4, 37, 7, "=")
    p.rect(9, 2, 30, 3, "=")
    p.rect(11, 2, 12, 2, "#")
    p.rect(27, 2, 30, 2, "#")
    # The channels, as 11j laid them, and their lines.
    p.rect(3, 9, 36, 11, "_")
    p.rect(3, 15, 36, 16, "_")
    # Their banks ragged where the sea has worked at them: a bay off each, a coral spur into one.
    p.blob(28, 12, 4, 1.4, "_", 863, 0.35, only=".")
    p.blob(10, 17, 4, 1.3, "_", 864, 0.35, only=".")
    p.blob(17, 8, 3, 1, "_", 865, 0.4, only=".")
    p.rect(6, 11, 8, 11, ".")
    p.rect(31, 15, 33, 15, ".")
    # The shelf's front broken: stones fallen off it.
    p.rect(13, 7, 15, 7, ".")
    p.rect(30, 7, 31, 7, ".")
    # A coral head standing between the channels in the west.
    p.blob(9, 13, 3, 1.1, "=", 866, 0.3, only=".")
    p.currents.append([(3, 10), (36, 10)])
    p.currents.append([(36, 15), (3, 15)])
    # Between and below them: coral heads and their growth, the wall's rubble, the light.
    p.piece("brainhead", 6, 12)
    p.piece("staghorn", 30, 12)
    p.piece("fans", 18, 13)
    p.piece("clam", 11, 18)
    p.piece("ribcoral", 25, 18)
    p.piece("glowcoral", 14, 13)
    p.piece("glowcoral", 34, 18)
    p.piece("jelly", 22, 10)
    p.piece("anchor", 3, 8)
    for (x, y) in [(10, 8), (11, 8), (26, 8), (33, 8), (24, 13), (5, 17), (17, 19), (32, 17)]:
        p.put(x, y, "o", ".")
    p.door(20, 22)
    p.g[5][20] = "e"
    p.mark([(20, 20)], "P")
    return p


## The hub's markers (src/hub/hub.gd): the descent, the tower, a spot for each person, the dock,
## the lantern posts. Each must be reachable from the keeper's spawn (checked in `hub_reach`).
HUB_PEOPLE = "OKBWCNSILVYG"


def hub():
    """Marrow Rock, 40x23 (the hub): the rock in the sea, the lighthouse on its summit in a flagged
    court (Orla at its door, Maren at its foot), a path from the descent at the waterline up to
    it through the whalebone, lined with the lantern posts that light as the Log fills. Each of
    the people has a place that says who they are, made of what came home from where they were
    found: Bram at his forge fire, Wren at her shrine by the standing stones with the Choir,
    Aldous by a keeper's statue under the summit, the Cartographer on a lookout over the sea,
    Hale at the sea wall he is building, Nessa by her boat and nets, Fen at the tide pool, Idris
    by his cargo at the dock's root, Pell out on the dock."""
    p = Plan(40, 23)
    # The rock: its body, the summit's shoulder, a west and an east shore.
    p.blob(20, 11, 17, 8, ".", 901, 0.16)
    p.blob(24, 5, 8, 3.4, ".", 902, 0.2)
    p.blob(9, 15, 8, 5.5, ".", 903, 0.2)
    p.blob(31, 15, 8, 5.5, ".", 904, 0.2)
    p.blob(33, 7, 4, 3, ".", 905, 0.25)
    # The sea: in along the whole south, up to the shore; a cove in the south-west.
    p.rect(3, 16, 36, 20, ".")
    p.blob(20, 23, 24, 5, "_", 911, 0.18, only=".")
    p.blob(5, 19, 3.5, 2, "_", 912, 0.3, only=".")
    # The summit court: flagged, raised, its corners cut, the tower on it.
    p.rect(18, 3, 29, 7, "=")
    for (x, y) in [(18, 3), (29, 3), (18, 7), (29, 7), (19, 3), (28, 3)]:
        p.g[y][x] = "."
    for (x, y) in [(23, 3), (24, 3), (23, 4), (24, 4)]:
        p.g[y][x] = "h"
    p.g[6][21] = "O"
    p.g[6][27] = "N"
    # The way up: the whalebone over the path, the lantern posts along it.
    p.piece("whalebone", 20, 10)
    for (x, y) in [(17, 16), (21, 15), (18, 13), (25, 12), (16, 8), (28, 9)]:
        p.g[y][x] = "l"
    # West: Bram's forge fire; Wren's shrine and the standing stones, the Choir with her.
    p.piece("cairn", 6, 7)
    p.g[9][9] = "B"
    p.piece("stones", 3, 13)
    p.piece("shrine", 5, 11)
    p.g[12][7] = "W"
    p.g[14][10] = "Y"
    # Under the summit: Aldous by an old keeper's statue.
    p.piece("statue", 11, 5)
    p.g[7][14] = "L"
    # East: the Cartographer's lookout (flagged, raised), Hale's half-built sea wall.
    p.rect(31, 5, 35, 8, "=")
    p.g[5][31] = "."
    p.g[7][33] = "C"
    p.rect(34, 12, 36, 16, "=")
    p.rect(34, 12, 34, 13, ".")
    p.piece("anchor", 30, 12)
    p.g[14][32] = "G"
    # The shore: Nessa's boat and nets, Fen's tide pool, Idris's cargo, the dock with Pell on it.
    p.piece("boat", 6, 17)
    p.piece("netrack", 4, 15)
    p.g[16][10] = "S"
    p.piece("tidepool", 12, 13)
    p.g[15][16] = "K"
    p.piece("crates", 21, 13)
    p.g[15][25] = "I"
    p.blob(31, 21, 8, 3, "_", 913, 0.25, only=".")
    p.g[18][23] = "d"
    p.g[17][24] = "V"
    p.piece("kelplight", 30, 19)
    p.piece("kelplight", 9, 20)
    for (x, y) in [(16, 4), (17, 5), (4, 10), (12, 11), (27, 12), (36, 10), (13, 19), (31, 9)]:
        p.put(x, y, "o", ".")
    p.g[20][19] = "X"
    p.g[16][19] = "P"
    return p


def hub_reach(p):
    """Every hub marker reachable from the keeper's spawn (Plan.check knows doors and spawns)."""
    solid = {c for q in p.pieces for c in p.footprint(*q)}
    start = [(x, y) for y in range(p.h) for x in range(p.w) if p.g[y][x] == "P"]
    seen, stack = set(start), list(start)
    while stack:
        x, y = stack.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            c = p.get(nx, ny)
            if (nx, ny) in seen or c in "#oh" or (nx, ny) in solid:
                continue
            seen.add((nx, ny))
            stack.append((nx, ny))
    errs = []
    for y in range(p.h):
        for x in range(p.w):
            c = p.g[y][x]
            if c in HUB_PEOPLE + "Xdl" and (x, y) not in seen:
                errs.append(f"'{c}' at {x},{y} unreachable")
            if c in HUB_PEOPLE + "Xdl" and (x, y) in solid:
                errs.append(f"'{c}' at {x},{y} under a piece")
    return errs


ALL = {
    "hub": hub,
    "reef/shop_01": reef_shop,
    "reef/altar_01": reef_altar,
    "reef/fountain_01": reef_fountain,
    "reef/echo_01": reef_echo,
    "reef/boss_01": reef_boss,
    "biome3/shop_01": hall_shop,
    "biome3/altar_01": hall_altar,
    "biome3/fountain_01": hall_fountain,
    "biome3/echo_01": hall_echo,
    "biome3/boss_01": hall_boss,
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
        errs = p.check(name) + (hub_reach(p) if name == "hub" else [])
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
