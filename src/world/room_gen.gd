class_name RoomGen
extends RefCounted
## Map Stage 08 (MAP_ROADMAP.md, B1; STYLE.md 22): fighting rooms made from a seed. Each biome
## has its grammar, the shapes a plan of it is built from (the Flats a coast and the sea, the
## Harbour a channel between quays, the Streets a square, streets and a canal, the Hall a nave),
## then its set pieces and world light by rule, then the doors and the keeper's spawn, then
## hand-authored chunks (data/chunks/<look>/*.txt, RoomChunks) stamped where the floor runs bare,
## then the spawns. The result is a RoomTemplate like any hand-made one, and `validate` holds it
## to the map rules; a plan that fails is made again from the next attempt's seed.
## Map Stage 10: a room may take a shape (SHAPES) besides the open plan. The corridor, the L and
## the ring are outlines the grammar draws inside; the split level raises one side behind a
## retaining wall with ramps; the flooded room goes under but for islands and causeways.

const C_WALL := 35   # '#'
const C_FLOOR := 46  # '.'
const C_LOW := 95    # '_'
const C_RAISED := 61 # '='
const C_ROCK := 111  # 'o'
const C_DOOR := 68   # 'D'
const C_PLAYER := 80 # 'P'
const C_ENEMY := 101 # 'e'
const C_CHEST := 84  # 'T'
const C_ALTAR := 65  # 'A'
const TRIES := 12
const SIZE_L := Vector2i(80, 46)
const SIZE_M := Vector2i(60, 34)
const SIZE_S := Vector2i(40, 23)
## Room kinds (map Stage 09): what the run puts in the room besides its plan.
## combat: the drowned's spawns. challenge: spawns and two chests on plinths. treasure: a hoard
## of chests, no fight. vault: one vault in a walled strongroom with one way in. dive: the room
## drowned, the altar and a chest on islands.
const KINDS := ["combat", "challenge", "treasure", "vault", "dive"]
## Room shapes (map Stage 10). "" is the open plan of Stages 08-09; "any" asks `pick_shape`.
const SHAPES := ["corridor", "ell", "ring", "split", "flooded"]
const SIZE_LONG := Vector2i(80, 23)  # a corridor east to west
const SIZE_TALL := Vector2i(40, 46)  # a corridor north to south
const OPEN_SHARE := 0.4  # the open plan's share when the shape is left to the seed
const LOOK_NAME := {Tiles.Look.FLATS: "flats", Tiles.Look.HARBOUR: "harbour",
	Tiles.Look.STREETS: "streets", Tiles.Look.DEEP: "hall", Tiles.Look.REEF: "reef"}
## The measured limits (STYLE.md 22).
const MAX_HOLE := 8
const MAX_SYMMETRY := 0.80

static var last_attempts := 0  # how many attempts the last `generate` took (the preview reports it)


## A room for a look and a seed: the same seed always gives the same room. `kind` is one of
## KINDS; `size` 40x23, 60x34 or 80x46, or zero for the fighting mix (seven large in ten).
## `shape` is one of SHAPES, "" for the open plan, or "any" for the seed's pick. A generated
## room's default name says how to make it again (`from_name`).
static func generate(look: int, seed_value: int, kind: String = "combat", size: Vector2i = Vector2i.ZERO,
		p_name: String = "", shape: String = "") -> RoomTemplate:
	var t: RoomTemplate = null
	var name := p_name
	if name == "":
		name = "gen_%s_%d" % [LOOK_NAME.get(look, "flats"), seed_value] + ("_" + shape if shape != "" else "")
	if shape == "any":
		shape = pick_shape(seed_value)
	for attempt in TRIES:
		last_attempts = attempt + 1
		var g := build(look, hash([seed_value, attempt, look]), kind, size, shape)
		t = RoomTemplate.parse(g.text(), name)
		if validate(t, look, kind).is_empty():
			return t
	push_warning("RoomGen: %s %s seed %d failed %d attempts: %s" % [LOOK_NAME.get(look, "?"), kind, seed_value, TRIES,
		validate(t, look, kind)])
	return t


## The shape a seed takes when it is left to it: the open plan four times in ten, else one of
## SHAPES (a stream of its own, so the plan's draws are the same whatever the shape).
static func pick_shape(seed_value: int) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, "shape"])
	if r.randf() < OPEN_SHARE:
		return ""
	return SHAPES[r.randi() % SHAPES.size()]


## The room a generated name stands for ("gen_<look>_<seed>[_<shape>]"), or null if the name is
## not one: a night left in a generated room is rebuilt from it.
static func from_name(p_name: String) -> RoomTemplate:
	var parts := p_name.split("_")
	if parts.size() < 3 or parts[0] != "gen" or not parts[2].is_valid_int():
		return null
	var look: Variant = LOOK_NAME.find_key(parts[1])
	if look == null:
		return null
	return generate(int(look), int(parts[2]), "combat", Vector2i.ZERO, p_name, parts[3] if parts.size() > 3 else "")


## One attempt, before validation (the preview tool shows these too).
static func build(look: int, seed_value: int, kind: String = "combat", size: Vector2i = Vector2i.ZERO,
		shape: String = "") -> Grid:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if size == Vector2i.ZERO:
		if shape == "corridor":
			size = SIZE_LONG if rng.randf() < 0.6 else SIZE_TALL
		else:
			size = SIZE_L if rng.randf() < 0.7 else SIZE_M
	var g := Grid.new(size.x, size.y, rng)
	_outline(g, shape)
	match look:
		Tiles.Look.HARBOUR: _harbour(g)
		Tiles.Look.STREETS: _streets(g)
		Tiles.Look.DEEP: _hall(g)
		Tiles.Look.REEF: _reef(g)
		_: _flats(g)
	g.clip()
	# A corridor's bays stay open ground whatever the grammar built there (the Streets' blocks).
	for b: Array in g.bays:
		var at: Vector2 = b[0]
		g.blob(at.x, at.y, b[1], b[2], C_FLOOR, 0.2, [C_WALL])
	if not g.shape_doors.is_empty():
		g.want_doors = g.shape_doors
	match kind:
		"challenge": _plinths(g, 2)
		"treasure": _hoard(g)
		"vault": _strongroom(g)
		"dive": _islands(g)
	_doors(g)
	if kind == "dive":
		_drown(g)
	else:
		_stamp_chunks(g, look)
	# After the chunks: the terrace keeps what they put on its floor.
	if shape == "split":
		_terrace(g)
	if shape == "flooded":
		_flood(g)
	_connect(g)
	if kind == "combat" or kind == "challenge":
		_spawns(g)
	return g


# --- the grid ------------------------------------------------------------------------------------

class Grid:
	var w: int
	var h: int
	var c := PackedByteArray()
	var rng: RandomNumberGenerator
	var pieces: Array = []          # [id, x, y]
	var solid: Dictionary = {}      # the pieces' solid cells
	var taken: Dictionary = {}      # cells a piece or chunk owns (its footprint and a margin)
	var doors: Array[Vector2i] = []
	var entry := Vector2i(-1, -1)   # the door Tam comes in by (the first)
	var want_doors: Array = []      # [side, along] a builder asks for
	var shape_doors: Array = []     # the same, from the room's shape (they win)
	var bays: Array = []            # [centre, rx, ry] of a corridor's bays: kept open to fight in
	var mask := PackedByteArray()   # 1 outside the room's outline (map Stage 10); empty: no outline
	var currents: Array = []        # channels' lines, downstream (map Stage 11e): `~` lines

	func _init(p_w: int, p_h: int, p_rng: RandomNumberGenerator) -> void:
		w = p_w
		h = p_h
		rng = p_rng
		c.resize(w * h)
		c.fill(C_WALL)

	## Back to rock wherever the outline says there is no room (after a builder that writes the
	## plan directly, as the turned Harbour does).
	func clip() -> void:
		if mask.is_empty():
			return
		for i in c.size():
			if mask[i] != 0 and not solid.has(Vector2i(i % w, i / w)):
				c[i] = C_WALL

	func at(x: int, y: int) -> int:
		return c[y * w + x] if x >= 0 and y >= 0 and x < w and y < h else C_WALL

	func set_at(x: int, y: int, ch: int) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			c[y * w + x] = ch

	## Never into the outer two rings: the rim is a mass (doors cut it on their own).
	func put(x: int, y: int, ch: int, only: Array = []) -> void:
		if x >= 2 and y >= 2 and x < w - 2 and y < h - 2 and (only.is_empty() or c[y * w + x] in only) \
				and not solid.has(Vector2i(x, y)) and (mask.is_empty() or mask[y * w + x] == 0):
			c[y * w + x] = ch

	static func is_open(ch: int) -> bool:
		return ch == C_FLOOR or ch == C_LOW or ch == C_RAISED

	## A noisy ellipse: its radius wanders with the angle, so the edge never runs straight.
	func blob(cx: float, cy: float, rx: float, ry: float, ch: int, rough: float = 0.22, only: Array = []) -> void:
		var waves: Array = []
		for k in range(2, 7):
			waves.append([k, rough / (k - 1) * rng.randf_range(0.6, 1.0), rng.randf_range(0.0, TAU)])
		for y in range(int(cy - ry * 1.6) - 1, int(cy + ry * 1.6) + 2):
			for x in range(int(cx - rx * 1.6) - 1, int(cx + rx * 1.6) + 2):
				var dx := (x - cx) / rx
				var dy := (y - cy) / ry
				var a := atan2(dy, dx)
				var r := 1.0
				for wv in waves:
					r += float(wv[1]) * sin(float(wv[0]) * a + float(wv[2]))
				if dx * dx + dy * dy <= r * r:
					put(x, y, ch, only)

	func rect(x0: int, y0: int, x1: int, y1: int, ch: int, only: Array = []) -> void:
		for y in range(mini(y0, y1), maxi(y0, y1) + 1):
			for x in range(mini(x0, x1), maxi(x0, x1) + 1):
				put(x, y, ch, only)

	## A thick polyline; with wobble its width wanders (channels, canals, tracks).
	func path(pts: Array, half: float, ch: int, wobble: float = 0.0, only: Array = []) -> void:
		var ph := rng.randf_range(0.0, TAU)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)) * 2.0) + 1
			for k in n + 1:
				var p := a.lerp(b, float(k) / n)
				var r := half + wobble * sin((p.x + p.y) * 0.45 + ph)
				var ri := int(ceil(r))
				for dy in range(-ri, ri + 1):
					for dx in range(-ri, ri + 1):
						if dx * dx + dy * dy <= r * r + 0.3:
							put(int(round(p.x + dx)), int(round(p.y + dy)), ch, only)

	## Place a set piece if it fits: `need` says what each footprint cell must stand on.
	## "floor" every cell on bare floor; "water" every cell on low ground; "shelf" on raised;
	## "any" any open ground. A deck or water the footprint lays is written into the plan.
	func fits(id: String, x: int, y: int, need: String = "floor") -> bool:
		var rows: Array = SetPieces.info(id).get("foot", [])
		if rows.is_empty():
			return false
		var sz := Vector2i(str(rows[0]).length(), rows.size())
		if x < 3 or y < 3 or x + sz.x > w - 3 or y + sz.y > h - 3:
			return false
		for j in sz.y:
			for i in sz.x:
				var cell := Vector2i(x + i, y + j)
				var ch := at(cell.x, cell.y)
				var f: String = str(rows[j])[i]
				if taken.has(cell) or not is_open(ch):
					return false
				if need == "water" and ch != C_LOW:
					return false
				if need == "shelf" and ch != C_RAISED:
					return false
				# On floor, the open cells too: nothing stands in a gate's or an arch's gap.
				if need == "floor" and (f == "#" or f == ".") and ch != C_FLOOR:
					return false
		return true

	func place(id: String, x: int, y: int) -> void:
		pieces.append([id, x, y])
		var rows: Array = SetPieces.info(id).get("foot", [])
		for j in rows.size():
			var row: String = rows[j]
			for i in row.length():
				var cell := Vector2i(x + i, y + j)
				if row[i] == "#":
					solid[cell] = true
				elif row[i] == "=" or row[i] == "_":
					set_at(cell.x, cell.y, row[i].unicode_at(0))
		for j in range(-1, rows.size() + 1):
			for i in range(-1, str(rows[0]).length() + 1):
				taken[Vector2i(x + i, y + j)] = true

	## Try to place a piece at random spots that pass `test` (a Callable(x, y) -> bool).
	func scatter(id: String, need: String = "floor", test: Callable = Callable(), tries: int = 160) -> bool:
		var sz := SetPieces.size(id)
		for k in tries:
			var x := rng.randi_range(3, w - 3 - sz.x)
			var y := rng.randi_range(3, h - 3 - sz.y)
			if fits(id, x, y, need) and (not test.is_valid() or test.call(x, y)):
				place(id, x, y)
				return true
		return false

	## Whether any cell within r of (x, y) has the char.
	func near(x: int, y: int, ch: int, r: int) -> bool:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if at(x + dx, y + dy) == ch:
					return true
		return false

	## The row above a footprint is all wall: the piece stands against a mass (house, organ).
	func against_north(id: String, x: int, y: int) -> bool:
		for i in SetPieces.size(id).x:
			if at(x + i, y - 1) != C_WALL:
				return false
		return true

	func open_cells(ch: int = -1) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for y in h:
			for x in w:
				var v := c[y * w + x]
				if (ch < 0 and is_open(v)) or v == ch:
					out.append(Vector2i(x, y))
		return out

	func text() -> String:
		var lines := PackedStringArray()
		for y in h:
			lines.append(c.slice(y * w, (y + 1) * w).get_string_from_ascii())
		for p in pieces:
			lines.append("@ %s %d %d" % [p[0], p[1], p[2]])
		for line: Array in currents:
			var nums := PackedStringArray()
			for pt: Vector2 in line:
				nums.append("%d %d" % [roundi(pt.x), roundi(pt.y)])
			lines.append("~ " + " ".join(nums))
		return "\n".join(lines) + "\n"


# --- the biomes ----------------------------------------------------------------------------------

## The Flats: dunes crossing the room, the sea coming in from one side over them (it floods first),
## a sand bar into it, tide pools, sometimes a rock shelf (the last to flood) and a headland.
static func _flats(g: Grid) -> void:
	var r := g.rng
	var n := 5 if g.w >= 80 else 4
	for i in n:
		var cx := lerpf(g.w * 0.2, g.w * 0.8, (i + r.randf_range(-0.3, 0.3)) / float(n - 1))
		var cy := g.h * (0.5 + r.randf_range(-0.18, 0.18))
		g.blob(cx, cy, r.randf_range(g.w * 0.13, g.w * 0.19), r.randf_range(g.h * 0.24, g.h * 0.34), C_FLOOR, 0.2)
	for i in r.randi_range(1, 2):
		var p := _side_point(g, r.randi() % 4, 0.25, 0.75)
		g.blob(p.x, p.y, r.randf_range(3.0, 6.0), r.randf_range(4.0, 8.0), C_WALL, 0.3)
	var side := r.randi() % 4
	var sea := _side_point(g, side, 0.2, 0.8)
	if r.randf() < 0.25 and g.w >= 60:
		# The island: a moat of low ground round a dune, one spit across (it floods round you).
		var c := Vector2(g.w * r.randf_range(0.4, 0.6), g.h * r.randf_range(0.42, 0.58))
		g.blob(c.x, c.y, g.w * 0.2, g.h * 0.3, C_LOW, 0.2, [C_FLOOR])
		g.blob(c.x, c.y, g.w * 0.11, g.h * 0.16, C_FLOOR, 0.25, [C_LOW])
		var out := c + Vector2.from_angle(r.randf_range(0.0, TAU)) * g.w * 0.25
		g.path([c, out], 1.3, C_FLOOR, 0.4, [C_LOW])
		sea = Vector2(-100, -100)
	var sea_c := Vector2(g.w, g.h) * 0.5
	if sea.x > -50:
		var inward := (Vector2(g.w, g.h) * 0.5 - sea).normalized()
		sea_c = sea + inward * g.h * 0.18
		g.blob(sea_c.x, sea_c.y, g.w * r.randf_range(0.22, 0.3), g.h * r.randf_range(0.26, 0.34), C_LOW, 0.22, [C_FLOOR])
		var bar_a := sea_c - inward.orthogonal() * g.h * 0.2
		g.path([bar_a, bar_a.lerp(sea_c, 0.5) + inward * 3.0, sea_c + inward.orthogonal() * g.h * 0.15], 1.2, C_FLOOR, 0.5, [C_LOW])
	for i in r.randi_range(2, 4):
		var p := _random_cell(g, C_FLOOR)
		g.blob(p.x, p.y, r.randf_range(2.5, 4.5), r.randf_range(1.8, 3.0), C_LOW, 0.3, [C_FLOOR])
	var shelf := false
	if r.randf() < 0.55:
		var p := _far_from(g, sea_c, C_FLOOR)
		g.blob(p.x, p.y, r.randf_range(5.0, 7.5), r.randf_range(3.5, 5.0), C_RAISED, 0.22, [C_FLOOR, C_LOW])
		shelf = true
	for i in r.randi_range(1, 3):
		var p := _random_cell(g, C_FLOOR)
		g.blob(p.x, p.y, r.randf_range(1.5, 2.5), r.randf_range(1.3, 2.0), C_WALL, 0.3, [C_FLOOR])
	_rock_drifts(g, r.randi_range(3, 5))
	# Pieces: one major off the centre, one or two minors, the beacon on the shelf, kelp by water.
	var off_centre := func(x: int, y: int) -> bool: return absf(x - g.w * 0.5) + absf(y - g.h * 0.5) > g.w * 0.12
	g.scatter(["wreck", "arch", "whalebone", "stones"][r.randi() % 4], "floor", off_centre)
	for id in _pick(r, ["boat", "mast", "tidepool", "stones"], r.randi_range(1, 2)):
		g.scatter(id)
	if shelf:
		g.scatter("cairn", "shelf")
	for i in r.randi_range(1, 2):
		g.scatter("kelplight", "floor", func(x: int, y: int) -> bool: return g.near(x, y, C_LOW, 2))


## The Harbour: quays either side of a straight channel; the quay edges broken by steps, bites
## in the rim, basins cut in from the channel, a causeway or a pier across, cargo on the decks.
static func _harbour(g: Grid) -> void:
	var r := g.rng
	# Four in ten run north to south: the plan is laid on a turned grid and turned back, before
	# any piece goes down (the pieces only face one way).
	var vertical := r.randf() < 0.4 and g.w >= 60
	var y0: int
	if vertical:
		var tg := Grid.new(g.h, g.w, r)
		y0 = _harbour_plan(tg, false)
		for y in g.h:
			for x in g.w:
				g.c[y * g.w + x] = tg.c[x * tg.w + y]
	else:
		y0 = _harbour_plan(g, true)
	g.clip()
	# Pieces: the warehouse against the north mass, the crane at the quay's edge (its lamp is
	# the room's one warm light, else a quay lamp), cargo, buoys cold in the channel.
	g.scatter("warehouse", "floor", func(px: int, py: int) -> bool:
		return g.against_north("warehouse", px, py) and (vertical or py < y0))
	var crane := g.scatter("crane", "floor", func(px: int, py: int) -> bool: return g.near(px + 1, py + 1, C_LOW, 2))
	for id in _pick(r, ["netrack", "capstan", "crates", "crates"], r.randi_range(1, 3)):
		g.scatter(id)
	if not crane:
		g.scatter("lamppost", "floor", func(px: int, py: int) -> bool: return g.near(px, py, C_LOW, 2))
	for i in r.randi_range(1, 2):
		g.scatter("buoy", "water")


## The Harbour's plan, west to east: returns the channel's first row. `pier` allows the pier
## (a piece, so never on a turned grid).
static func _harbour_plan(g: Grid, pier: bool) -> int:
	var r := g.rng
	g.rect(3, 3, g.w - 4, g.h - 4, C_FLOOR)
	for i in r.randi_range(4, 6):
		var side := r.randi() % 4
		var p := _side_point(g, side, 0.1, 0.9)
		var ln := r.randi_range(3, 8)
		var dp := r.randi_range(2, 4)
		if side < 2:
			g.rect(int(p.x) - ln / 2, int(p.y) - dp, int(p.x) + ln / 2, int(p.y) + dp, C_WALL)
		else:
			g.rect(int(p.x) - dp, int(p.y) - ln / 2, int(p.x) + dp, int(p.y) + ln / 2, C_WALL)
	# A block of sheds in one corner: the quays are never a mirror of each other.
	var bw0 := r.randi_range(g.w / 8, g.w / 5)
	var bh0 := r.randi_range(4, 7)
	var west := r.randf() < 0.5
	var north := r.randf() < 0.5
	var bx0 := 3 if west else g.w - 4 - bw0
	var by0 := 3 if north else g.h - 4 - bh0
	g.rect(bx0, by0, bx0 + bw0, by0 + bh0, C_WALL)
	var th := r.randi_range(4, 6) if g.h < 30 else r.randi_range(6, 9)
	var y0 := int(g.h * 0.5 + r.randf_range(-0.18, 0.18) * g.h) - th / 2
	# The channel runs out into the dark at one end and stops at a dock wall at the other.
	var dock := r.randi_range(8, g.w / 4)
	if r.randf() < 0.5:
		g.rect(dock, y0, g.w - 3, y0 + th - 1, C_LOW, [C_FLOOR])
	else:
		g.rect(3, y0, g.w - 1 - dock, y0 + th - 1, C_LOW, [C_FLOOR])
	var x := r.randi_range(6, 12)
	while x < g.w - 8:
		g.rect(x, y0 - 1, x + r.randi_range(2, 3), y0 - 1, C_LOW, [C_FLOOR])
		x += r.randi_range(10, 14)
	x = r.randi_range(10, 16)
	while x < g.w - 8:
		g.rect(x, y0 + th, x + r.randi_range(1, 3), y0 + th, C_LOW, [C_FLOOR])
		x += r.randi_range(10, 14)
	for i in r.randi_range(1, 2):
		var bw := r.randi_range(4, 7)
		var bx := r.randi_range(8, g.w - 10 - bw)
		if r.randf() < 0.5:
			g.rect(bx, y0 - r.randi_range(5, 8), bx + bw, y0, C_LOW, [C_FLOOR])
		else:
			g.rect(bx, y0 + th, bx + bw, y0 + th - 1 + r.randi_range(5, 8), C_LOW, [C_FLOOR])
	var cx := r.randi_range(g.w / 4, g.w * 3 / 4)
	var crossed := false
	if pier and r.randf() < 0.5:
		# A pier off a quay into the channel, a boat moored at it.
		var from_south := r.randf() < 0.5
		var py := y0 + th - 6 if from_south else y0
		if g.fits("pier", cx, py, "any"):
			g.place("pier", cx, py)
			if g.fits("moored", cx + 4, y0 + 1, "water"):
				g.place("moored", cx + 4, y0 + 1)
			crossed = true
	if not crossed:
		g.rect(cx, y0 - 1, cx + 2, y0 + th, C_RAISED)
		g.rect(cx - 2, y0 + th / 2 - 1, cx + 4, y0 + th / 2 + 1, C_RAISED, [C_LOW])
	for i in r.randi_range(3, 6):
		_drift(g, _random_cell(g, C_FLOOR), r.randi_range(2, 4))
	return y0


## The Streets: a square off centre, a street through it door to door with jogs, a cross street,
## alleys, blocks pushed into the square; often a canal across with a bridge where the street
## meets it; sometimes a terrace with steps, a sunken corner that floods first.
static func _streets(g: Grid) -> void:
	var r := g.rng
	var sw := r.randi_range(16, 22)
	var sh := r.randi_range(10, 13)
	var sx := r.randi_range(6, g.w - sw - 6)
	var sy := r.randi_range(5, g.h - sh - 5)
	# Inside the room's outline (map Stage 10): an L or a ring has no square in its dark.
	for k in 12:
		if g.mask.is_empty() or g.mask[(sy + sh / 2) * g.w + sx + sw / 2] == 0:
			break
		sx = r.randi_range(6, g.w - sw - 6)
		sy = r.randi_range(5, g.h - sh - 5)
	g.rect(sx, sy, sx + sw, sy + sh, C_FLOOR)
	if g.w >= 80:
		# A second, smaller square away from the first.
		var qw := r.randi_range(11, 14)
		var qh := r.randi_range(8, 10)
		var qx := r.randi_range(5, g.w - qw - 5)
		var qy := r.randi_range(5, g.h - qh - 5)
		for k in 8:
			if absi(qx + qw / 2 - (sx + sw / 2)) > (sw + qw) / 2 + 3:
				break
			qx = r.randi_range(5, g.w - qw - 5)
		g.rect(qx, qy, qx + qw, qy + qh, C_FLOOR)
		g.path([Vector2(qx + qw / 2, qy + qh / 2), Vector2(sx + sw / 2, qy + qh / 2), Vector2(sx + sw / 2, sy + sh / 2)], 2.2, C_FLOOR)
	var y1 := float(r.randi_range(6, g.h - 7))
	var y2 := float(sy + sh / 2 + r.randi_range(-2, 2))
	var jog := float(r.randi_range(sx + 2, sx + sw - 2))
	var half := r.randf_range(2.4, 3.2)
	g.path([Vector2(2, y1), Vector2(jog * 0.5, y1), Vector2(jog * 0.5, y2), Vector2(g.w - 3, y2)], half, C_FLOOR)
	var cx2 := float(r.randi_range(sx + 3, sx + sw - 3))
	if r.randf() < 0.5:
		g.path([Vector2(cx2, 2), Vector2(cx2, sy)], r.randf_range(1.5, 2.0), C_FLOOR)
	else:
		g.path([Vector2(cx2, sy + sh), Vector2(cx2, g.h - 3)], r.randf_range(1.5, 2.0), C_FLOOR)
	for i in r.randi_range(1, 3):
		var a := _random_cell(g, C_FLOOR)
		var horiz := r.randf() < 0.5
		var ln := r.randi_range(6, 14) * (1 if r.randf() < 0.5 else -1)
		var b := a + (Vector2(ln, 0) if horiz else Vector2(0, ln))
		g.path([a, b], 1.0, C_FLOOR)
	for i in r.randi_range(2, 3):
		var corner := Vector2i(sx if r.randf() < 0.5 else sx + sw - r.randi_range(3, 5), sy if r.randf() < 0.5 else sy + sh - r.randi_range(2, 3))
		g.rect(corner.x, corner.y, corner.x + r.randi_range(2, 4), corner.y + r.randi_range(1, 3), C_WALL)
	if r.randf() < 0.25:
		# The square is two courtyards under water either side of a causeway of raised flags.
		g.rect(sx + 1, sy + 1, sx + sw - 1, sy + sh - 1, C_LOW, [C_FLOOR])
		var cy := sy + sh / 2 + r.randi_range(-1, 1)
		g.rect(sx, cy - 1, sx + sw, cy + 1, C_RAISED, [C_FLOOR, C_LOW])
	var canal := r.randf() < 0.6
	if not canal or r.randf() < 0.4:
		# A sunken corner of the square: the first ground the tide takes.
		var p := Vector2(sx + r.randf_range(3, sw - 3), sy + r.randf_range(3, sh - 3))
		g.blob(p.x, p.y, r.randf_range(3.0, 4.5), r.randf_range(2.0, 3.0), C_LOW, 0.3, [C_FLOOR])
	if canal:
		# The canal: north to south away from the square, a bridge where the street crosses it.
		var kx := float(r.randi_range(sx + sw + 5, g.w - 6)) if sx + sw + 11 < g.w else float(r.randi_range(5, maxi(6, sx - 6)))
		g.path([Vector2(kx, 2), Vector2(kx + r.randf_range(-2, 2), g.h * 0.5), Vector2(kx + r.randf_range(-2, 2), g.h - 3)], 1.0, C_FLOOR, 0.0)
		g.path([Vector2(kx, 2), Vector2(kx, g.h * 0.5), Vector2(kx, g.h - 3)], 2.4, C_LOW, 0.5)
		var by := int(y2) - 2 if kx > jog * 0.5 else int(y1) - 2
		var bx := int(kx) - 3
		if g.fits("bridge", bx, by, "any"):
			g.place("bridge", bx, by)
	if r.randf() < 0.4:
		var tx := sx + 1
		var ty := sy + 1
		g.rect(tx, ty, tx + 6, ty + 3, C_RAISED)
		if g.fits("steps", tx + 1, ty + 4, "floor"):
			g.place("steps", tx + 1, ty + 4)
	_rock_drifts(g, r.randi_range(2, 4))
	var by_wall := func(x: int, y: int) -> bool: return g.against_north("house", x, y)
	if not g.scatter("house", "floor", by_wall):
		g.scatter("tower")
	for id in _pick(r, ["well", "stall", "fallen", "lamps", "tower"], r.randi_range(1, 3)):
		g.scatter(id)
	for i in r.randi_range(1, 2):
		g.scatter("coldlamp")
	if r.randf() < 0.5:
		g.scatter("shrine", "floor", func(x: int, y: int) -> bool: return g.against_north("shrine", x, y))


## The Reef (map Stage 11d): Saltmere's sea wall laid straight across the room (or down it), three
## courses thick, a length of it slid out of line, broken through in one or two breaches where
## the breach's stubs stand; outside it a channel along its foot, inside the current running away
## from each breach in a channel; coral heads (raised, the last to flood) between, pools in the
## hollows, the wall's rubble at its foot. Two rooms in ten are the reef flat with the wall gone.
static func _reef(g: Grid) -> void:
	var r := g.rng
	g.rect(3, 3, g.w - 4, g.h - 4, C_FLOOR)
	# The reef's edge is never straight: only the wall is.
	for i in r.randi_range(7, 11):
		var p := _side_point(g, r.randi() % 4, 0.05, 0.95)
		g.blob(p.x, p.y, r.randf_range(3.0, 7.0), r.randf_range(2.5, 5.0), C_WALL, 0.32)
	# A corner or two worn right back.
	for i in r.randi_range(1, 2):
		var c := Vector2(3 if r.randf() < 0.5 else g.w - 4, 3 if r.randf() < 0.5 else g.h - 4)
		g.blob(c.x, c.y, r.randf_range(5.0, 9.0), r.randf_range(4.0, 7.0), C_WALL, 0.3)
	var breaches: Array[Vector2] = []
	var inward := Vector2(0, 1)
	var plan := r.randf()
	if plan < 0.5 or (plan < 0.8 and g.w < 60):
		# Across: the sea to the north or the south.
		var north := r.randf() < 0.5
		var y0 := int(g.h * r.randf_range(0.2, 0.32))
		if not north:
			y0 = g.h - 3 - y0
		inward = Vector2(0, 1) if north else Vector2(0, -1)
		g.rect(2, y0, g.w - 3, y0 + 2, C_WALL)
		var jx := r.randi_range(g.w / 4, g.w * 3 / 5)
		var jl := r.randi_range(5, 9)
		var dy := 1 if r.randf() < 0.5 else -1
		g.rect(jx, y0, jx + jl, y0 + 2, C_FLOOR)
		g.rect(jx, y0 + dy, jx + jl, y0 + 2 + dy, C_WALL)
		var n := 2 if g.w >= 60 else 1
		for k in n:
			var bx := int(lerpf(g.w * 0.12, g.w * 0.8, (k + r.randf_range(0.15, 0.85)) / n))
			if absi(bx + 3 - (jx + jl / 2)) < jl / 2 + 5:
				bx = clampi(bx + jl + 6, 4, g.w - 11)
			g.rect(bx, y0 - 1, bx + 6, y0 + 3, C_FLOOR)
			if g.fits("breach", bx, y0, "floor"):
				g.place("breach", bx, y0)
			breaches.append(Vector2(bx + 3, y0 + 1))
		var yc := y0 - 4 if north else y0 + 6
		if yc >= 4 and yc <= g.h - 5:
			var line := [Vector2(2, yc), Vector2(g.w * 0.35, yc + r.randf_range(-1.5, 1.5)), Vector2(g.w * 0.7, yc + r.randf_range(-1.5, 1.5)),
				Vector2(g.w - 3, yc)]
			g.path(line, r.randf_range(1.3, 1.8), C_LOW, 0.5, [C_FLOOR])
			# Along the wall's outer foot the water runs one way or the other.
			if r.randf() < 0.5:
				line.reverse()
			g.currents.append(line)
	elif plan < 0.8:
		# Down the room: the sea to the west or the east; the breaches are plain gaps.
		var west := r.randf() < 0.5
		var x0 := int(g.w * r.randf_range(0.2, 0.3))
		if not west:
			x0 = g.w - 3 - x0
		inward = Vector2(1, 0) if west else Vector2(-1, 0)
		g.rect(x0, 2, x0 + 2, g.h - 3, C_WALL)
		for k in r.randi_range(1, 2):
			var by := int(lerpf(g.h * 0.2, g.h * 0.75, (k + r.randf_range(0.2, 0.8)) / 2.0))
			g.rect(x0 - 1, by, x0 + 3, by + r.randi_range(4, 5), C_FLOOR)
			_drift(g, Vector2(x0 + 1 + inward.x * 3, by - 1), 3)
			breaches.append(Vector2(x0 + 1, by + 2))
		var xc := x0 - 4 if west else x0 + 6
		if xc >= 4 and xc <= g.w - 5:
			var line := [Vector2(xc, 2), Vector2(xc + r.randf_range(-1.5, 1.5), g.h * 0.5), Vector2(xc, g.h - 3)]
			g.path(line, r.randf_range(1.3, 1.7), C_LOW, 0.5, [C_FLOOR])
			if r.randf() < 0.5:
				line.reverse()
			g.currents.append(line)
	else:
		# The reef flat: no wall; the current crosses the room in two channels.
		for k in 2:
			var a := _side_point(g, k * 2, 0.2, 0.8)
			var b := _side_point(g, 1 + k * 2, 0.2, 0.8)
			breaches.append(a)
			var line := [a, a.lerp(b, 0.5) + Vector2(r.randf_range(-6, 6), r.randf_range(-4, 4)), b]
			g.path(line, r.randf_range(1.4, 1.9), C_LOW, 0.6, [C_FLOOR])
			g.currents.append(line)
	# The current from each breach runs away from the wall and bends toward the far side.
	for b in breaches:
		if plan >= 0.8:
			break
		var side := Vector2(inward.y, inward.x) * r.randf_range(-0.3, 0.3)
		var far := b + (inward + side) * maxf(g.w, g.h)
		far = Vector2(clampf(far.x, 3, g.w - 4), clampf(far.y, 3, g.h - 4))
		var mid := b.lerp(far, 0.5) + Vector2(inward.y, inward.x) * r.randf_range(-5, 5)
		g.path([b + inward * 2, mid, far], r.randf_range(1.4, 1.9), C_LOW, 0.6, [C_FLOOR])
		# The sea comes in through the breach: the water runs away from the wall.
		g.currents.append([b - inward, b + inward * 2, mid, far])
	# Coral heads between the channels, pools in the hollows, the wall's rubble at its foot.
	for i in r.randi_range(3, 5) + (2 if plan >= 0.8 else 0):
		var p := _random_cell(g, C_FLOOR)
		g.blob(p.x, p.y, r.randf_range(3.0, 6.5), r.randf_range(2.0, 4.0), C_RAISED, 0.28, [C_FLOOR])
	for i in r.randi_range(1, 3):
		var p := _random_cell(g, C_FLOOR)
		g.blob(p.x, p.y, r.randf_range(2.0, 3.5), r.randf_range(1.4, 2.2), C_LOW, 0.35, [C_FLOOR])
	_rock_drifts(g, r.randi_range(3, 5))
	# Pieces: one or two great things off the centre as cover, the living ones by the water, the
	# anchor by the wall, the wall's stair up onto a coral head; the light all cold.
	var off_centre := func(x: int, y: int) -> bool: return absf(x - g.w * 0.5) + absf(y - g.h * 0.5) > g.w * 0.1
	for id in _pick(r, ["brainhead", "ribcoral", "staghorn"], r.randi_range(1, 2)):
		g.scatter(id, "floor", off_centre)
	for id in _pick(r, ["clam", "fans"], r.randi_range(1, 2)):
		g.scatter(id, "floor", func(x: int, y: int) -> bool: return g.near(x, y, C_LOW, 2))
	if r.randf() < 0.6:
		g.scatter("anchor", "floor", func(x: int, y: int) -> bool: return g.near(x, y, C_WALL, 1))
	if r.randf() < 0.4:
		g.scatter("wallsteps", "floor", func(x: int, y: int) -> bool: return g.near(x + 1, y - 1, C_RAISED, 1))
	for i in r.randi_range(1, 2):
		g.scatter("glowcoral", "floor", func(x: int, y: int) -> bool: return g.near(x, y, C_LOW, 2))
	if r.randf() < 0.4:
		g.scatter("jelly", "water")


## The Deep Hall: a nave north to south, aisles behind column rows, the apse with its dais and the
## altar (or the organ), gutters down the aisles, often a transept of brine across; symmetric on
## its axis and broken: a column down, a gutter buried, a wall fallen into the dark, chapels
## that do not match.
static func _hall(g: Grid) -> void:
	# Three plans (map Stage 09): the nave (half the rooms), the crossing and the crypt, so a
	# Hall room is not always the same building broken differently.
	var pick := g.rng.randf()
	if g.w >= 60 and pick < 0.25:
		_hall_cross(g)
	elif g.w >= 60 and pick < 0.5:
		_hall_crypt(g)
	else:
		_hall_nave(g)


## The crossing: a nave met by a transept that runs the room's width, each arm ending in a
## half-round apse; columns at the crossing's four corners, the altar where the arms meet or at
## the nave's head, gutters along the arms, one arm fallen in.
static func _hall_cross(g: Grid) -> void:
	var r := g.rng
	var nw := r.randi_range(7, 9) * 2
	var tw := r.randi_range(9, 12)
	var cx := g.w / 2 + r.randi_range(-8, 8)
	var cy := g.h / 2 + r.randi_range(-4, 4)
	var nx0 := cx - nw / 2
	var ty0 := cy - tw / 2
	g.rect(nx0, 4, nx0 + nw - 1, g.h - 5, C_FLOOR)
	g.rect(5, ty0, g.w - 6, ty0 + tw - 1, C_FLOOR)
	for end in [5, g.w - 6]:
		g.blob(end, cy, 4.0, tw * 0.5, C_FLOOR, 0.1)
	g.blob(cx, 5, nw * 0.5, 3.5, C_FLOOR, 0.1)
	for gy in [ty0 + 1, ty0 + tw - 2]:
		g.rect(8, gy, nx0 - 3, gy, C_LOW, [C_FLOOR])
		g.rect(nx0 + nw + 2, gy, g.w - 9, gy, C_LOW, [C_FLOOR])
	# One arm has fallen in: its end a rubble field under water.
	var west := r.randf() < 0.5
	var fx := 9 if west else g.w - 10
	g.blob(fx, cy, 5.0, tw * 0.45, C_LOW, 0.3, [C_FLOOR])
	_drift(g, Vector2(fx + (4 if west else -4), cy), 4)
	for c in [Vector2i(nx0 - 2, ty0 - 2), Vector2i(nx0 + nw, ty0 - 2), Vector2i(nx0 - 2, ty0 + tw), Vector2i(nx0 + nw, ty0 + tw)]:
		if g.fits("column", c.x, c.y, "any"):
			g.place("column", c.x, c.y)
	g.rect(cx - 5, 6, cx + 4, 9, C_RAISED, [C_FLOOR])
	if not g.scatter("altar", "shelf"):
		g.scatter("altar", "floor", func(x: int, y: int) -> bool: return absi(y - cy) < tw / 2)
	g.want_doors = [[1, (cx + 0.5) / g.w]]
	_hall_furnish(g)


## The crypt: a low hall on a grid of piers, vaults of brine sunk between some of them, a dais at
## one end with the altar, the keepers' statues among the piers.
static func _hall_crypt(g: Grid) -> void:
	var r := g.rng
	var x0 := 5
	var y0 := 5
	var x1 := g.w - 6
	var y1 := g.h - 6
	g.rect(x0, y0, x1, y1, C_FLOOR)
	# Bays knocked through the outer wall, never two alike.
	for i in r.randi_range(2, 4):
		var p := _side_point(g, r.randi() % 4, 0.2, 0.8)
		g.blob(p.x + signf(g.w * 0.5 - p.x) * 3.0, p.y + signf(g.h * 0.5 - p.y) * 3.0, r.randf_range(3.0, 5.0), r.randf_range(2.5, 4.0), C_FLOOR, 0.25)
	var sx := r.randi_range(7, 9)
	var sy := r.randi_range(6, 7)
	var ox := x0 + r.randi_range(3, 5)
	var oy := y0 + r.randi_range(3, 4)
	var gap_x := ox + sx * r.randi_range(1, 3)
	var y := oy
	while y < y1 - 3:
		var x := ox
		while x < x1 - 3:
			# A row of piers with one lane left clear down the crypt.
			if x != gap_x:
				if r.randf() < 0.15:
					_drift(g, Vector2(x + 1, y + 1), 3)
				elif g.fits("column", x, y, "any"):
					g.place("column", x, y)
			if r.randf() < 0.18:
				g.rect(x + 3, y + 2, x + sx - 2, y + sy - 3, C_LOW, [C_FLOOR])
			x += sx
		y += sy
	var top := r.randf() < 0.5
	var dy := y0 + 1 if top else y1 - 3
	g.rect(g.w / 2 - 5, dy, g.w / 2 + 4, dy + 2, C_RAISED, [C_FLOOR])
	g.scatter("altar", "shelf")
	g.want_doors = [[1 if top else 0, r.randf_range(0.3, 0.7)]]
	for i in 2:
		g.scatter("statue")
	_hall_furnish(g)


## What any Hall plan gets after its shape: the furniture, the clutter and the light.
static func _hall_furnish(g: Grid) -> void:
	var r := g.rng
	for id in _pick(r, ["rose", "organ", "apse", "font"], r.randi_range(1, 2)):
		var test := Callable()
		if id == "organ" or id == "apse":
			test = func(x: int, y: int) -> bool: return g.against_north(id, x, y)
		g.scatter(id, "floor", test)
	_rock_drifts(g, r.randi_range(2, 4))
	for i in r.randi_range(1, 2):
		g.scatter("candles", "floor", func(x: int, y: int) -> bool: return g.near(x, y, C_WALL, 1))
	if r.randf() < 0.6:
		g.scatter("kelpglow", "floor", func(x: int, y: int) -> bool: return g.near(x, y, C_LOW, 2))


static func _hall_nave(g: Grid) -> void:
	var r := g.rng
	var small := g.w < 60
	var nw := r.randi_range(6, 8) * 2 if small else r.randi_range(10, 13) * 2
	# The aisles are of their own widths and the nave stands off the room's centre: the plan is
	# symmetric about the nave, not the room.
	var aw_w := r.randi_range(3, 6) if small else r.randi_range(6, 11)
	var aw_e := r.randi_range(3, 6) if small else r.randi_range(6, 11)
	while absi(aw_w - aw_e) < (2 if small else 3):
		aw_e = r.randi_range(2, 7) if small else r.randi_range(5, 12)
	var nx0 := clampi(g.w / 2 - nw / 2 + r.randi_range(-6, 6) + (aw_w - aw_e) / 2, aw_w + 4, g.w - nw - aw_e - 4)
	var nx1 := nx0 + nw - 1
	var top := 8 if g.h >= 40 else (6 if g.h >= 30 else 4)
	g.rect(nx0, top + 2, nx1, g.h - 5, C_FLOOR)
	g.rect(nx0 - aw_w, top + 6, nx0 - 1, g.h - 5, C_FLOOR)
	g.rect(nx1 + 1, top + 6, nx1 + aw_e, g.h - 5, C_FLOOR)
	var cx := (nx0 + nx1) * 0.5
	var rad := nw * 0.5 + 0.5
	for y in range(2, top + 3):
		for x in range(nx0 - 1, nx1 + 2):
			if pow((x - cx) / rad, 2) + pow((y - (top + 2)) / float(top), 2) <= 1.0:
				g.put(x, y, C_FLOOR)
	var dr := nw * 0.5 - 3.0
	for y in range(3, top + 5):
		for x in range(nx0, nx1 + 1):
			if pow((x - cx) / dr, 2) + pow((y - (top + 3)) / float(top - 2), 2) <= 1.0:
				g.put(x, y, C_RAISED)
	for side in [-1, 1]:
		for i in r.randi_range(1, 2):
			var cy := r.randi_range(top + 10, g.h - 10)
			var ox := nx0 - aw_w - 4 if side < 0 else nx1 + aw_e + 1
			g.rect(ox, cy, ox + 3, cy + r.randi_range(3, 5), C_FLOOR)
	var gx := [nx0 - aw_w + 1, nx1 + aw_e - 2]
	var buried := r.randi() % 3  # 0: west buried in part, 1: east, 2: neither
	for k in 2:
		var gy0 := top + 8
		if buried == k:
			gy0 = r.randi_range(g.h / 2, g.h - 12)
		g.rect(gx[k], gy0, gx[k] + 1, g.h - 7, C_LOW, [C_FLOOR])
	var flooded := r.randf() < 0.33
	if flooded:
		# The nave has drowned: brine down its middle, the columns either side of it.
		var half := r.randi_range(2, 3) if not small else 1
		g.rect(int(cx) - half, top + 9, int(cx) + half + 1, g.h - 8, C_LOW, [C_FLOOR, C_RAISED])
	elif r.randf() < 0.65:
		var ty := float(r.randi_range(g.h / 2 - 4, g.h / 2 + 4))
		g.path([Vector2(nx0 - aw_w + 1, ty), Vector2(cx, ty + r.randf_range(-1.5, 1.5)), Vector2(nx1 + aw_e - 1, ty + r.randf_range(-1, 1))], 1.1, C_LOW, 0.35, [C_FLOOR, C_RAISED])
	if r.randf() < 0.6:
		var side := -1 if r.randf() < 0.5 else 1
		var bx := float(nx0 - aw_w - 2) if side < 0 else float(nx1 + aw_e + 3)
		var byy := r.randf_range(top + 10.0, g.h - 12.0)
		g.blob(bx, byy, r.randf_range(4.0, 6.0), r.randf_range(3.0, 5.0), C_FLOOR, 0.3)
		_drift(g, Vector2(bx - side * 3, byy), 4)
	# The altar on the dais, statues at its foot, the column rows with one down.
	if not g.scatter("altar", "shelf", func(x: int, y: int) -> bool: return absf(x + 2 - cx) < 3.0):
		g.scatter("altar", "floor", func(x: int, y: int) -> bool: return y < g.h / 2)
	var foot := top + 6
	for sx in [nx0 + 3, nx1 - 4]:
		if g.fits("statue", sx, foot, "any"):
			g.place("statue", sx, foot)
	var down := r.randi_range(0, 3)
	var row := 0
	var y := top + 10
	while y < g.h - 8:
		for k in 2:
			var colx := nx0 if k == 0 else nx1 - 1
			if row == down and k == (down % 2):
				_drift(g, Vector2(colx + (3 if k == 0 else -3), y + 1), 4)
				continue
			if g.fits("column", colx, y, "any"):
				g.place("column", colx, y)
		row += 1
		y += 6
	for i in r.randi_range(0, 2):
		var p := _random_cell(g, C_FLOOR)
		g.rect(int(p.x), int(p.y), int(p.x) + 2, int(p.y) + 1, C_RAISED, [C_FLOOR])
	if r.randf() < 0.5:
		var p := _random_cell(g, C_FLOOR)
		g.rect(int(p.x), int(p.y), int(p.x) + 3, int(p.y) + 2, C_LOW, [C_FLOOR])
	g.want_doors = [[1, (cx + 0.5) / g.w]]  # the entrance at the foot of the nave (side 1 is south)
	if g.fits("gate", int(cx) - 2, g.h - 9, "floor"):
		g.place("gate", int(cx) - 2, g.h - 9)
	_hall_furnish(g)


# --- room shapes (map Stage 10) ------------------------------------------------------------------

## The outline of a corridor, an L or a ring, drawn on a scratch grid and kept as the mask: the
## biome's grammar then draws only inside it. The open plan, the split level and the flooded
## room keep the whole box.
static func _outline(g: Grid, shape: String) -> void:
	if not shape in ["corridor", "ell", "ring"]:
		return
	var r := g.rng
	var m := Grid.new(g.w, g.h, r)
	match shape:
		"corridor":
			# A long way through, its line wandering, two or three bays opening off it to fight in.
			var long := g.w >= g.h
			var ln := g.w if long else g.h
			var across := g.h if long else g.w
			var pts: Array = []
			for k in 5:
				var a := lerpf(2.0, ln - 3.0, k / 4.0)
				var b := across * 0.5 + r.randf_range(-0.14, 0.14) * across
				pts.append(Vector2(a, b) if long else Vector2(b, a))
			m.path(pts, r.randf_range(3.6, 4.6), C_FLOOR, 0.8)
			for k in r.randi_range(2, 3):
				var p: Vector2 = pts[1 + k]
				p = p.lerp(pts[k], r.randf_range(0.0, 0.5))
				var off := r.randf_range(2.0, 4.0) * (1.0 if r.randf() < 0.5 else -1.0)
				p += Vector2(0, off) if long else Vector2(off, 0)
				var rx := r.randf_range(6.0, 8.0) if long else r.randf_range(5.0, 7.0)
				var ry := r.randf_range(5.0, 7.0) if long else r.randf_range(6.0, 8.0)
				m.blob(p.x, p.y, rx, ry, C_FLOOR, 0.25)
				g.bays.append([p, rx * 0.7, ry * 0.7])
			var a0: Vector2 = pts[0]
			var a1: Vector2 = pts[4]
			g.shape_doors = [[2, a0.y / g.h], [3, a1.y / g.h]] if long else [[0, a0.x / g.w], [1, a1.x / g.w]]
		"ell":
			# One corner of the box is the dark: an L, the inner corner worn round.
			m.rect(2, 2, g.w - 3, g.h - 3, C_FLOOR)
			var cw := int(g.w * r.randf_range(0.4, 0.5))
			var chh := int(g.h * r.randf_range(0.42, 0.52))
			var west := r.randf() < 0.5
			var north := r.randf() < 0.5
			var x0 := 0 if west else g.w - cw
			var y0 := 0 if north else g.h - chh
			m.rect(x0, y0, x0 + cw - 1, y0 + chh - 1, C_WALL)
			var ix := x0 + cw if west else x0
			var iy := y0 + chh if north else y0
			m.blob(ix, iy, r.randf_range(3.0, 5.0), r.randf_range(2.5, 4.0), C_WALL, 0.3)
			for k in r.randi_range(2, 3):
				var e := Vector2(x0 + r.randf_range(0.2, 0.8) * cw, iy) if r.randf() < 0.5 else Vector2(ix, y0 + r.randf_range(0.2, 0.8) * chh)
				m.blob(e.x, e.y, r.randf_range(2.0, 3.5), r.randf_range(1.5, 2.5), C_WALL if r.randf() < 0.5 else C_FLOOR, 0.3)
		"ring":
			# A loop round a pit: the middle of the room has fallen into the dark.
			m.rect(2, 2, g.w - 3, g.h - 3, C_FLOOR)
			var cx := g.w * 0.5 + r.randi_range(-4, 4)
			var cy := g.h * 0.5 + r.randi_range(-2, 2)
			m.blob(cx, cy, g.w * r.randf_range(0.16, 0.2), g.h * r.randf_range(0.19, 0.23), C_WALL, 0.2)
	g.mask.resize(g.w * g.h)
	for i in g.c.size():
		g.mask[i] = 0 if m.c[i] == C_FLOOR else 1


## The split level: one side of the room raised (it floods last) behind a retaining wall two cells
## thick, broken by two or three ramps. The pieces, chunks and doors already down keep their ground.
static func _terrace(g: Grid) -> void:
	var r := g.rng
	var side := r.randi() % 4  # the terrace's side: 0 north, 1 south, 2 west, 3 east
	var deep := g.h if side < 2 else g.w
	var span := g.w if side < 2 else g.h
	var base := deep * r.randf_range(0.34, 0.44)
	var amp := r.randf_range(1.0, 2.5)
	var ph := r.randf_range(0.0, TAU)
	var edge := PackedInt32Array()
	edge.resize(span)
	for a in span:
		edge[a] = int(base + amp * sin(a * 0.22 + ph))
	# depth from the terrace's own side
	var cell := func(a: int, d: int) -> Vector2i:
		match side:
			0: return Vector2i(a, d)
			1: return Vector2i(a, g.h - 1 - d)
			2: return Vector2i(d, a)
			_: return Vector2i(g.w - 1 - d, a)
	for a in span:
		for d in edge[a]:
			var p: Vector2i = cell.call(a, d)
			if g.at(p.x, p.y) == C_FLOOR and not g.solid.has(p):
				g.set_at(p.x, p.y, C_RAISED)
	# Where a ramp can go: open ground both above and below the wall.
	var ramps: Array = []
	var cands: Array = []
	for a in range(4, span - 5):
		var up: Vector2i = cell.call(a, edge[a] - 2)
		var down: Vector2i = cell.call(a, edge[a] + 1)
		if Grid.is_open(g.at(up.x, up.y)) and Grid.is_open(g.at(down.x, down.y)):
			cands.append(a)
	if cands.is_empty():
		return
	for k in r.randi_range(2, 3):
		var best := -1
		var bd := -1
		for t in 20:
			var a: int = cands[r.randi() % cands.size()]
			var d := 999
			for o: int in ramps:
				d = mini(d, absi(o - a))
			if d > bd:
				bd = d
				best = a
		if bd >= 8 or ramps.is_empty():
			ramps.append(best)
	for a in span:
		var ramp := false
		for o: int in ramps:
			ramp = ramp or absi(a - o) <= 1
		for d in [edge[a] - 1, edge[a]]:
			var p: Vector2i = cell.call(a, d)
			if not Grid.is_open(g.at(p.x, p.y)) or g.solid.has(p) or g.taken.has(p):
				continue
			if ramp:
				g.set_at(p.x, p.y, C_RAISED if d < edge[a] else C_FLOOR)
			else:
				g.set_at(p.x, p.y, C_WALL)


## The flooded room: islands of ground and the causeways between them stand; the rest of the floor
## is low, the first the tide takes. The keeper's landing and the causeways from the doors stay
## dry; the pieces and the chunks' rocks stand in the water.
static func _flood(g: Grid) -> void:
	var r := g.rng
	var start := Vector2i(-1, -1)
	for i in g.c.size():
		if g.c[i] == C_PLAYER:
			start = Vector2i(i % g.w, i / g.w)
	if start.x < 0:
		return
	var keep := Grid.new(g.w, g.h, r)
	var isles: Array[Vector2] = [Vector2(start)]
	for k in (r.randi_range(4, 6) if g.w >= 80 else r.randi_range(3, 4)):
		var p := _far_from_all(g, isles)
		isles.append(p)
		keep.blob(p.x, p.y, r.randf_range(3.5, 5.0), r.randf_range(2.8, 3.8), C_FLOOR, 0.3)
	# Each island tied by a causeway to the nearest one before it, the doors to the landing.
	for k in range(1, isles.size()):
		var near := isles[0]
		for j in k:
			if isles[j].distance_to(isles[k]) < near.distance_to(isles[k]):
				near = isles[j]
		keep.path([near, isles[k]], 1.0, C_FLOOR, 0.3)
	for d in g.doors:
		keep.path([Vector2(d + _inward(g, d)), Vector2(start)], 1.0, C_FLOOR, 0.3)
	for i in g.c.size():
		var c := Vector2i(i % g.w, i / g.w)
		if g.c[i] != C_FLOOR or keep.c[i] == C_FLOOR or g.solid.has(c):
			continue
		if maxi(absi(c.x - start.x), absi(c.y - start.y)) <= 3:
			continue
		g.c[i] = C_LOW


## A floor cell as far as can be found from all of the points.
static func _far_from_all(g: Grid, pts: Array[Vector2]) -> Vector2:
	var best := Vector2(g.w * 0.5, g.h * 0.5)
	var bd := -1.0
	var cells := g.open_cells(C_FLOOR)
	if cells.is_empty():
		return best
	for k in 60:
		var c := Vector2(cells[g.rng.randi() % cells.size()])
		var d := INF
		for p in pts:
			d = minf(d, c.distance_to(p))
		if d > bd:
			bd = d
			best = c
	return best


# --- room kinds (map Stage 09) -------------------------------------------------------------------

## A spot of bare floor for a w x h block, clear of pieces and anything taken, `gap` cells clear
## round it too; (-1, -1) if there is none.
static func _clear_spot(g: Grid, w: int, h: int, gap: int = 1) -> Vector2i:
	for k in 300:
		var x := g.rng.randi_range(4, g.w - 5 - w)
		var y := g.rng.randi_range(4, g.h - 5 - h)
		var ok := true
		for j in range(-gap, h + gap):
			for i in range(-gap, w + gap):
				var c := Vector2i(x + i, y + j)
				if g.at(c.x, c.y) != C_FLOOR or g.taken.has(c) or g.solid.has(c):
					ok = false
					break
			if not ok:
				break
		if ok:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _own(g: Grid, at: Vector2i, w: int, h: int, gap: int = 1) -> void:
	for j in range(-gap, h + gap):
		for i in range(-gap, w + gap):
			g.taken[at + Vector2i(i, j)] = true


## Chests on raised plinths (a challenge's reward), as far apart as they can be.
static func _plinths(g: Grid, n: int) -> void:
	var placed: Array[Vector2i] = []
	for i in n:
		var best := Vector2i(-1, -1)
		var bd := -1
		for k in 8:
			var at := _clear_spot(g, 3, 3)
			if at.x < 0:
				continue
			var d := 999
			for o in placed:
				d = mini(d, absi(o.x - at.x) + absi(o.y - at.y))
			if d > bd:
				bd = d
				best = at
		if best.x < 0:
			return
		g.rect(best.x, best.y, best.x + 2, best.y + 2, C_RAISED)
		g.set_at(best.x + 1, best.y + 1, C_CHEST)
		_own(g, best, 3, 3)
		placed.append(best)


## A hoard: one chest (two in a large room) on a raised step, a drift of the look's clutter by it.
static func _hoard(g: Grid) -> void:
	for i in (2 if g.w >= 80 else 1):
		var at := _clear_spot(g, 5, 3)
		if at.x < 0:
			return
		g.rect(at.x, at.y, at.x + 4, at.y + 2, C_RAISED)
		g.set_at(at.x + 2, at.y + 1, C_CHEST)
		_own(g, at, 5, 3)
		_drift(g, Vector2(at.x + (7 if g.rng.randf() < 0.5 else -3), at.y + 1), 3)


## A strongroom: walls round a room with the vault in it and one way in, facing the room's middle.
static func _strongroom(g: Grid) -> void:
	var w := 12 if g.w >= 60 else 10
	var h := 8 if g.h >= 30 else 7
	var at := _clear_spot(g, w, h, 1)
	if at.x < 0:
		# No room for it as the plan stands: clear a place near the middle.
		at = Vector2i(g.w / 2 - w / 2 + g.rng.randi_range(-4, 4), g.h / 2 - h / 2 + g.rng.randi_range(-2, 2))
		g.rect(at.x - 1, at.y - 1, at.x + w, at.y + h, C_FLOOR)
	g.rect(at.x, at.y, at.x + w - 1, at.y + h - 1, C_WALL)
	g.rect(at.x + 1, at.y + 1, at.x + w - 2, at.y + h - 2, C_FLOOR)
	# The way in, on the side that faces the room's middle.
	var mid := Vector2(g.w, g.h) * 0.5
	var c := Vector2(at) + Vector2(w, h) * 0.5
	if absf(mid.x - c.x) / g.w > absf(mid.y - c.y) / g.h:
		var x := at.x + w - 1 if mid.x > c.x else at.x
		g.rect(x, at.y + h / 2 - 1, x, at.y + h / 2, C_FLOOR)
	else:
		var y := at.y + h - 1 if mid.y > c.y else at.y
		g.rect(at.x + w / 2 - 1, y, at.x + w / 2, y, C_FLOOR)
	g.set_at(at.x + w / 2, at.y + h / 2, C_CHEST)
	_own(g, at, w, h, 1)


## The dive's islands: the altar on one, a chest on another, before the room is drowned.
static func _islands(g: Grid) -> void:
	for mark: int in [C_ALTAR, C_CHEST]:
		var at := _clear_spot(g, 5, 4, 0)
		if at.x < 0:
			at = Vector2i(g.w / 2 + (-8 if mark == C_ALTAR else 6), g.h / 2 - 2)
			g.rect(at.x, at.y, at.x + 4, at.y + 3, C_FLOOR)
		g.blob(at.x + 2.0, at.y + 1.5, 3.2, 2.4, C_RAISED, 0.25)
		g.set_at(at.x + 2, at.y + 2, mark)
		_own(g, at, 5, 4, 1)


## The dive: every bit of floor more than three cells from the keeper's landing goes under.
static func _drown(g: Grid) -> void:
	var start := Vector2i(-1, -1)
	for i in g.c.size():
		if g.c[i] == C_PLAYER:
			start = Vector2i(i % g.w, i / g.w)
	for i in g.c.size():
		var cell := Vector2i(i % g.w, i / g.w)
		if g.c[i] == C_FLOOR and not g.taken.has(cell) and maxi(absi(cell.x - start.x), absi(cell.y - start.y)) > 3:
			var near_door := false
			for d in g.doors:
				if absi(cell.x - d.x) + absi(cell.y - d.y) <= 2:
					near_door = true
			if not near_door:
				g.c[i] = C_LOW


# --- doors, chunks, reach, spawns ----------------------------------------------------------------

## A point on a side (0 north, 1 south, 2 west, 3 east), two cells in.
static func _side_point(g: Grid, side: int, lo: float, hi: float) -> Vector2:
	var t := g.rng.randf_range(lo, hi)
	match side:
		0: return Vector2(g.w * t, 2)
		1: return Vector2(g.w * t, g.h - 3)
		2: return Vector2(2, g.h * t)
		_: return Vector2(g.w - 3, g.h * t)


static func _random_cell(g: Grid, ch: int) -> Vector2:
	var cells := g.open_cells(ch)
	if cells.is_empty():
		return Vector2(g.w * 0.5, g.h * 0.5)
	return Vector2(cells[g.rng.randi() % cells.size()])


static func _far_from(g: Grid, p: Vector2, ch: int) -> Vector2:
	var best := Vector2(g.w * 0.5, g.h * 0.5)
	var d := -1.0
	for k in 40:
		var c := _random_cell(g, ch)
		if c.distance_to(p) > d:
			d = c.distance_to(p)
			best = c
	return best


static func _pick(r: RandomNumberGenerator, list: Array, n: int) -> Array:
	var l := list.duplicate()
	for i in range(l.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = l[i]
		l[i] = l[j]
		l[j] = t
	return l.slice(0, n)


## A drift of rocks round a point: two to four obstacles, never a lone one in the open.
static func _drift(g: Grid, at: Vector2, n: int) -> void:
	for k in n:
		var p := Vector2i(int(at.x) + g.rng.randi_range(-2, 2), int(at.y) + g.rng.randi_range(-1, 1))
		if g.at(p.x, p.y) == C_FLOOR and not g.taken.has(p):
			g.put(p.x, p.y, C_ROCK)


## Drifts at the foot of walls (STYLE.md 22: decor and rocks gather with reason).
static func _rock_drifts(g: Grid, n: int) -> void:
	for k in n:
		for t in 30:
			var p := _random_cell(g, C_FLOOR)
			if g.near(int(p.x), int(p.y), C_WALL, 1):
				_drift(g, p, g.rng.randi_range(2, 3))
				break


## Two or three doors on different sides, each cut through the mass to the floor, none before a
## piece; the first is the entry and the keeper's spawn is a few steps inside it.
static func _doors(g: Grid) -> void:
	var sides := [0, 1, 2, 3]
	sides = _pick(g.rng, sides, 4)
	var want: Array = g.want_doors.duplicate()
	var n := 3 if g.w >= 80 or g.rng.randf() < 0.5 else 2
	var used: Array = []
	for w in want:
		sides.erase(w[0])
		sides.push_front(w[0])
	for side: int in sides:
		if g.doors.size() >= n:
			break
		var along_fixed := -1.0
		for w in want:
			if w[0] == side:
				along_fixed = w[1]
		for k in 30:
			var t := along_fixed if along_fixed >= 0.0 and k < 3 else g.rng.randf_range(0.18, 0.82)
			if _try_door(g, side, t):
				break
	if g.doors.is_empty():
		return
	var d := g.doors[0]
	g.entry = d
	var inward := _inward(g, d)
	var p := d + inward
	var steps := 0
	while steps < 6 and Grid.is_open(g.at(p.x + inward.x, p.y + inward.y)) and not g.solid.has(p + inward):
		p += inward
		steps += 1
	if g.at(p.x, p.y) != C_FLOOR:
		for rr in 4:
			for c in [p + Vector2i(rr, 0), p + Vector2i(-rr, 0), p + Vector2i(0, rr), p + Vector2i(0, -rr)]:
				if g.at(c.x, c.y) == C_FLOOR and not g.solid.has(c):
					p = c
					break
	g.set_at(p.x, p.y, C_PLAYER)


static func _inward(g: Grid, d: Vector2i) -> Vector2i:
	if d.y == 0:
		return Vector2i(0, 1)
	if d.y == g.h - 1:
		return Vector2i(0, -1)
	if d.x == 0:
		return Vector2i(1, 0)
	return Vector2i(-1, 0)


static func _try_door(g: Grid, side: int, t: float) -> bool:
	var d: Vector2i
	match side:
		0: d = Vector2i(int(g.w * t), 0)
		1: d = Vector2i(int(g.w * t), g.h - 1)
		2: d = Vector2i(0, int(g.h * t))
		_: d = Vector2i(g.w - 1, int(g.h * t))
	var inward := _inward(g, d)
	var p := d + inward
	var cut: Array[Vector2i] = []
	while not Grid.is_open(g.at(p.x, p.y)):
		if cut.size() > 14 or g.solid.has(p) or p.x <= 0 or p.y <= 0 or p.x >= g.w - 1 or p.y >= g.h - 1:
			return false
		cut.append(p)
		p += inward
	# Nothing drawn stands in the 3x3 before the door, and doors keep apart.
	var first := d + inward
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if g.solid.has(first + Vector2i(dx, dy)) or g.solid.has(p + Vector2i(dx, dy)):
				return false
	for o in g.doors:
		if absi(o.x - d.x) + absi(o.y - d.y) < 12:
			return false
	for c in cut:
		g.set_at(c.x, c.y, C_FLOOR)
	g.set_at(d.x, d.y, C_DOOR)
	g.doors.append(d)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			g.taken[first + Vector2i(dx, dy)] = true
	return true


## The largest square of bare floor (no piece, no feature): [side, x, y] of its top-left.
static func bare_square(g: Grid) -> Array:
	var dp := PackedInt32Array()
	dp.resize(g.w * g.h)
	var best := [0, 0, 0]
	for y in g.h:
		for x in g.w:
			var i := y * g.w + x
			if g.c[i] == C_FLOOR and not g.solid.has(Vector2i(x, y)):
				var v := 1
				if x > 0 and y > 0:
					v += mini(dp[i - g.w], mini(dp[i - 1], dp[i - g.w - 1]))
				dp[i] = v
				if v > best[0]:
					best = [v, x - v + 1, y - v + 1]
	return best


## Where the floor runs bare (a square wider than MAX_HOLE), stamp a hand-made chunk of the look
## (RoomChunks), or failing that a drift of the look's obstacles, until it does not.
static func _stamp_chunks(g: Grid, look: int) -> void:
	var chunks := RoomChunks.for_look(look)
	for k in 40:
		var hole := bare_square(g)
		if int(hole[0]) <= MAX_HOLE:
			return
		var side: int = hole[0]
		var corner := Vector2i(int(hole[1]), int(hole[2]))
		var done := false
		# A chunk anywhere it fits over the square, the centre first.
		for ch: Dictionary in _pick(g.rng, chunks, chunks.size()):
			var rows: PackedStringArray = ch.rows
			var size := Vector2i(rows[0].length(), rows.size())
			var mid := corner + Vector2i(side, side) / 2 - size / 2
			var spots: Array[Vector2i] = [mid]
			for dy in range(-side / 2, side / 2 + 1, 2):
				for dx in range(-side / 2, side / 2 + 1, 2):
					spots.append(mid + Vector2i(dx, dy))
			for at in spots:
				if RoomChunks.fits(g, ch, at):
					RoomChunks.stamp(g, ch, at, g.rng.randf() < 0.5 and bool(ch.mirror))
					done = true
					break
			if done:
				break
		if not done:
			# A drift of the look's obstacles on a cell of the square nothing owns.
			for k2 in 30:
				var p := corner + Vector2i(g.rng.randi_range(1, side - 2), g.rng.randi_range(1, side - 2))
				if not g.taken.has(p) and g.at(p.x, p.y) == C_FLOOR:
					g.put(p.x, p.y, C_ROCK)
					_drift(g, Vector2(p), 3)
					g.taken[p] = true
					break


## Every door and the spawn joined: a door whose cut does not reach the keeper's ground is dug
## through to it; open ground no one can reach is filled back to rock.
static func _connect(g: Grid) -> void:
	var start := Vector2i(-1, -1)
	for i in g.c.size():
		if g.c[i] == C_PLAYER:
			start = Vector2i(i % g.w, i / g.w)
	if start.x < 0:
		return
	var seen := _reach(g, start)
	for d in g.doors:
		var p := d + _inward(g, d)
		if seen.has(p):
			continue
		# Dig toward the spawn, along x then y, through anything but a piece.
		var q := p
		while not seen.has(q) and q != start:
			if q.x != start.x:
				q.x += signi(start.x - q.x)
			else:
				q.y += signi(start.y - q.y)
			if not g.solid.has(q) and not Grid.is_open(g.at(q.x, q.y)) and g.at(q.x, q.y) != C_PLAYER:
				g.set_at(q.x, q.y, C_FLOOR)
		seen = _reach(g, start)
	# Ground no one can reach (a pool behind a piece, a corner cut off) goes back to rock. The
	# pieces' own open cells are left: a gap in an arch is walked through from either side.
	for i in g.c.size():
		var cell := Vector2i(i % g.w, i / g.w)
		if Grid.is_open(g.c[i]) and not seen.has(cell) and not g.solid.has(cell):
			g.c[i] = C_WALL


static func _reach(g: Grid, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + off
			var ch := g.at(n.x, n.y)
			if seen.has(n) or g.solid.has(n) or not (Grid.is_open(ch) or ch == C_ENEMY):
				continue
			seen[n] = true
			stack.append(n)
	return seen


## Walkable cells in the 5x5 round a cell: a spawn stands in a pocket, never in a door's cut or
## a one-wide gap (map Stage 09: the bot spent its time hunting crabs down corridors).
static func _openness(g: Grid, c: Vector2i) -> int:
	var n := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var p := c + Vector2i(dx, dy)
			if Grid.is_open(g.at(p.x, p.y)) and not g.solid.has(p):
				n += 1
	return n


## The drowned's spawns: spread over the reachable floor by farthest-point picking, ten in a
## large room and seven in a medium one, none within eight cells of the keeper.
static func _spawns(g: Grid) -> void:
	var start := Vector2i(-1, -1)
	for i in g.c.size():
		if g.c[i] == C_PLAYER:
			start = Vector2i(i % g.w, i / g.w)
	if start.x < 0:
		return
	var seen := _reach(g, start)
	var pool: Array[Vector2i] = []
	for c: Vector2i in seen:
		if g.at(c.x, c.y) == C_FLOOR and maxi(absi(c.x - start.x), absi(c.y - start.y)) >= 8 and not g.taken.has(c) \
				and _openness(g, c) >= 15:
			pool.append(c)
	if pool.is_empty():
		return
	pool.sort()
	var want := 10 if g.w >= 80 else (7 if g.w >= 60 else 5)
	var chosen: Array[Vector2i] = [pool[g.rng.randi() % pool.size()]]
	while chosen.size() < want:
		var best := Vector2i(-1, -1)
		var bd := -1
		for k in 60:
			var c := pool[g.rng.randi() % pool.size()]
			var d := 99999
			for o in chosen:
				d = mini(d, absi(o.x - c.x) + absi(o.y - c.y))
			if d > bd:
				bd = d
				best = c
		if bd < 4:
			break
		chosen.append(best)
	for c in chosen:
		g.set_at(c.x, c.y, C_ENEMY)


# --- the validator -------------------------------------------------------------------------------

## The map rules a fighting room must keep (STYLE.md 22): an empty list when it does.
static func validate(t: RoomTemplate, look: int, kind: String = "combat") -> PackedStringArray:
	var out := PackedStringArray()
	if t.width < 40 or t.width > 80 or t.height < 23 or t.height > 46:
		out.append("size %dx%d" % [t.width, t.height])
	if t.player_spawn.x < 0:
		out.append("no spawn")
		return out
	if t.doors.size() < 2:
		out.append("%d doors" % t.doors.size())
	var reach := t.reachable_cells()
	for d in t.doors:
		var ok := false
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if reach.has(d + off):
				ok = true
		if not ok:
			out.append("door %s unreachable" % d)
	var fights := kind == "combat" or kind == "challenge"
	if fights and t.enemy_spawns.size() < (6 if t.width >= 80 else 4):
		out.append("%d spawns" % t.enemy_spawns.size())
	var chests := t.marker_cells("T").size()
	if (kind == "challenge" or kind == "treasure") and chests < 1:
		out.append("no chest")
	if kind == "vault" and chests != 1:
		out.append("%d vaults" % chests)
	if kind == "dive" and (chests != 1 or t.marker_cells("A").size() != 1):
		out.append("no altar and chest")
	for ch in t.markers:
		for c: Vector2i in t.markers[ch]:
			var by := false
			for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				by = by or reach.has(c + off)
			if not by:
				out.append("marker %s unreachable" % ch)
	for e in t.enemy_spawns:
		if not reach.has(e):
			out.append("spawn %s unreachable" % e)
	for p in t.pieces:
		for c in SetPieces.footprint(str(p.id), p.cell):
			if t.char_at(c.x, c.y) in ["#", "D"]:
				out.append("%s on a wall" % p.id)
				break
			for d in t.doors:
				var first := d + _inward_t(t, d)
				if absi(c.x - first.x) <= 1 and absi(c.y - first.y) <= 1:
					out.append("%s before a door" % p.id)
	var cut := 0
	for y in t.height:
		for x in t.width:
			var c := Vector2i(x, y)
			if not t.is_solid(x, y) and not t.char_at(x, y) in ["D", "T", "A"] and not reach.has(c) and c != t.player_spawn:
				cut += 1
	if cut > 0:
		out.append("%d cells cut off" % cut)
	var hole := _hole(t)
	if hole > MAX_HOLE:
		out.append("bare square %d" % hole)
	var sym := symmetry(t)
	if sym > MAX_SYMMETRY:
		out.append("symmetry %.2f" % sym)
	var pockets := fight_pockets(t, reach)
	if pockets < (2 if t.width >= 80 and fights else 1):
		out.append("%d fight pockets" % pockets)
	var low := 0
	for c: Vector2i in reach:
		if t.height_at(c.x, c.y) == 0:
			low += 1
	if low < reach.size() * 0.02:
		out.append("no low ground for the tide")
	var l := SetPieces.lights(t)
	var n: int = l.WARM + l.FLAME + l.COLD
	if n < 1 or n > 3:
		out.append("%d world lights" % n)
	if l.WARM + l.FLAME + l.candles > 3:
		out.append("too many warm lights")
	match look:
		Tiles.Look.STREETS, Tiles.Look.REEF:
			# The Streets' lamps burn cold; on the Reef only Tam's lantern is warm (map Stage 11c).
			if l.WARM + l.FLAME > 0:
				out.append("a warm light in the Streets or the Reef")
		Tiles.Look.FLATS, Tiles.Look.HARBOUR:
			if l.WARM > 1 or l.FLAME > 0:
				out.append("more than one warm light")
	return out


static func _inward_t(t: RoomTemplate, d: Vector2i) -> Vector2i:
	if d.y == 0:
		return Vector2i(0, 1)
	if d.y == t.height - 1:
		return Vector2i(0, -1)
	if d.x == 0:
		return Vector2i(1, 0)
	return Vector2i(-1, 0)


static func _hole(t: RoomTemplate) -> int:
	var dp := PackedInt32Array()
	dp.resize(t.width * t.height)
	var best := 0
	for y in t.height:
		for x in t.width:
			var ch := t.char_at(x, y)
			if (ch == "." or ch == "P" or ch == "e") and not t.piece_cells.has(Vector2i(x, y)):
				var i := y * t.width + x
				var v := 1
				if x > 0 and y > 0:
					v += mini(dp[i - t.width], mini(dp[i - 1], dp[i - t.width - 1]))
				dp[i] = v
				best = maxi(best, v)
	return best


## The best mirror match (left-right or top-bottom) of the plan, pieces as rock (map_audit.py).
static func symmetry(t: RoomTemplate) -> float:
	var kind := func(x: int, y: int) -> String:
		if t.piece_cells.has(Vector2i(x, y)):
			return "o"
		var ch := t.char_at(x, y)
		return ch if ch in ["#", "o", "_", "="] else "."
	var n := 0
	var lr := 0
	var tb := 0
	for y in t.height:
		for x in t.width:
			if t.char_at(x, y) == "#":
				continue
			n += 1
			var k: String = kind.call(x, y)
			if k == kind.call(t.width - 1 - x, y):
				lr += 1
			if k == kind.call(x, t.height - 1 - y):
				tb += 1
	return float(maxi(lr, tb)) / maxf(1.0, n)


## Fight pockets (STYLE.md 22): non-overlapping 10x7 (or 7x10) windows of ground a body can stand
## on and reach, counted greedily.
static func fight_pockets(t: RoomTemplate, reach: Dictionary) -> int:
	var used: Dictionary = {}
	var n := 0
	for dims: Vector2i in [Vector2i(10, 7), Vector2i(7, 10)]:
		var y := 0
		while y <= t.height - dims.y:
			var x := 0
			while x <= t.width - dims.x:
				var ok := true
				for j in dims.y:
					for i in dims.x:
						var c := Vector2i(x + i, y + j)
						if used.has(c) or not (reach.has(c) or t.char_at(c.x, c.y) in ["P", "e"]):
							ok = false
							break
					if not ok:
						break
				if ok:
					n += 1
					for j in dims.y:
						for i in dims.x:
							used[Vector2i(x + i, y + j)] = true
					x += dims.x
				else:
					x += 1
			y += 1
	return n
