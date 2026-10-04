class_name RoomGen
extends RefCounted
## Map Stage 08 (MAP_ROADMAP.md, B1; STYLE.md 22): fighting rooms made from a seed. Each biome
## has its grammar, the shapes a plan of it is built from (the Flats a coast and the sea, the
## Harbour a channel between quays, the Streets a square, streets and a canal, the Hall a nave),
## then its set pieces and world light by rule, then the doors and the keeper's spawn, then
## hand-authored chunks (data/chunks/<look>/*.txt, RoomChunks) stamped where the floor runs bare,
## then the spawns. The result is a RoomTemplate like any hand-made one, and `validate` holds it
## to the map rules; a plan that fails is made again from the next attempt's seed.

const C_WALL := 35   # '#'
const C_FLOOR := 46  # '.'
const C_LOW := 95    # '_'
const C_RAISED := 61 # '='
const C_ROCK := 111  # 'o'
const C_DOOR := 68   # 'D'
const C_PLAYER := 80 # 'P'
const C_ENEMY := 101 # 'e'
const TRIES := 12
const SIZE_L := Vector2i(80, 46)
const SIZE_M := Vector2i(60, 34)
const LOOK_NAME := {Tiles.Look.FLATS: "flats", Tiles.Look.HARBOUR: "harbour",
	Tiles.Look.STREETS: "streets", Tiles.Look.DEEP: "hall"}
## The measured limits (STYLE.md 22).
const MAX_HOLE := 8
const MAX_SYMMETRY := 0.80

static var last_attempts := 0  # how many attempts the last `generate` took (the preview reports it)


## A fighting room for a look and a seed: the same seed always gives the same room.
static func generate(look: int, seed_value: int) -> RoomTemplate:
	var t: RoomTemplate = null
	for attempt in TRIES:
		last_attempts = attempt + 1
		var g := build(look, hash([seed_value, attempt, look]))
		t = RoomTemplate.parse(g.text(), "gen_%s_%d" % [LOOK_NAME.get(look, "flats"), seed_value])
		if validate(t, look).is_empty():
			return t
	push_warning("RoomGen: %s seed %d failed %d attempts: %s" % [LOOK_NAME.get(look, "?"), seed_value, TRIES, validate(t, look)])
	return t


## One attempt, before validation (the preview tool shows these too).
static func build(look: int, seed_value: int) -> Grid:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var size := SIZE_L if rng.randf() < 0.7 else SIZE_M
	var g := Grid.new(size.x, size.y, rng)
	match look:
		Tiles.Look.HARBOUR: _harbour(g)
		Tiles.Look.STREETS: _streets(g)
		Tiles.Look.DEEP: _hall(g)
		_: _flats(g)
	_doors(g)
	_stamp_chunks(g, look)
	_connect(g)
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

	func _init(p_w: int, p_h: int, p_rng: RandomNumberGenerator) -> void:
		w = p_w
		h = p_h
		rng = p_rng
		c.resize(w * h)
		c.fill(C_WALL)

	func at(x: int, y: int) -> int:
		return c[y * w + x] if x >= 0 and y >= 0 and x < w and y < h else C_WALL

	func set_at(x: int, y: int, ch: int) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			c[y * w + x] = ch

	## Never into the outer two rings: the rim is a mass (doors cut it on their own).
	func put(x: int, y: int, ch: int, only: Array = []) -> void:
		if x >= 2 and y >= 2 and x < w - 2 and y < h - 2 and (only.is_empty() or c[y * w + x] in only) \
				and not solid.has(Vector2i(x, y)):
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
	var inward := (Vector2(g.w, g.h) * 0.5 - sea).normalized()
	var sea_c := sea + inward * g.h * 0.18
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
	var th := r.randi_range(6, 9)
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
	if r.randf() < 0.5:
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
	# Pieces: the warehouse against the north mass, the crane at the quay's edge (its lamp is
	# the room's one warm light, else a quay lamp), cargo, buoys cold in the channel.
	g.scatter("warehouse", "floor", func(px: int, py: int) -> bool: return g.against_north("warehouse", px, py) and py < y0)
	var crane := g.scatter("crane", "floor", func(px: int, py: int) -> bool: return py + 2 == y0 - 1 or py + 2 == y0)
	for id in _pick(r, ["netrack", "capstan", "crates", "crates"], r.randi_range(1, 3)):
		g.scatter(id)
	if not crane:
		g.scatter("lamppost", "floor", func(px: int, py: int) -> bool: return g.near(px, py, C_LOW, 2))
	for i in r.randi_range(1, 2):
		g.scatter("buoy", "water")


## The Streets: a square off centre, a street through it door to door with jogs, a cross street,
## alleys, blocks pushed into the square; often a canal across with a bridge where the street
## meets it; sometimes a terrace with steps, a sunken corner that floods first.
static func _streets(g: Grid) -> void:
	var r := g.rng
	var sw := r.randi_range(16, 22)
	var sh := r.randi_range(10, 13)
	var sx := r.randi_range(6, g.w - sw - 6)
	var sy := r.randi_range(5, g.h - sh - 5)
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


## The Deep Hall: a nave north to south, aisles behind column rows, the apse with its dais and the
## altar (or the organ), gutters down the aisles, often a transept of brine across; symmetric on
## its axis and broken: a column down, a gutter buried, a wall fallen into the dark, chapels
## that do not match.
static func _hall(g: Grid) -> void:
	var r := g.rng
	var nw := r.randi_range(10, 13) * 2
	# The aisles are of their own widths and the nave stands off the room's centre: the plan is
	# symmetric about the nave, not the room.
	var aw_w := r.randi_range(6, 11)
	var aw_e := r.randi_range(6, 11)
	while absi(aw_w - aw_e) < 3:
		aw_e = r.randi_range(5, 12)
	var nx0 := clampi(g.w / 2 - nw / 2 + r.randi_range(-6, 6) + (aw_w - aw_e) / 2, aw_w + 4, g.w - nw - aw_e - 4)
	var nx1 := nx0 + nw - 1
	var top := 8 if g.h >= 40 else 6
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
	if r.randf() < 0.65:
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
	for i in g.c.size():
		var cell := Vector2i(i % g.w, i / g.w)
		if (g.c[i] == C_FLOOR or g.c[i] == C_RAISED) and not seen.has(cell) and not g.taken.has(cell):
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
		if g.at(c.x, c.y) == C_FLOOR and maxi(absi(c.x - start.x), absi(c.y - start.y)) >= 8 and not g.taken.has(c):
			pool.append(c)
	if pool.is_empty():
		return
	pool.sort()
	var want := 10 if g.w >= 80 else 7
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
static func validate(t: RoomTemplate, look: int) -> PackedStringArray:
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
	if t.enemy_spawns.size() < (6 if t.width >= 80 else 4):
		out.append("%d spawns" % t.enemy_spawns.size())
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
	var hole := _hole(t)
	if hole > MAX_HOLE:
		out.append("bare square %d" % hole)
	var sym := symmetry(t)
	if sym > MAX_SYMMETRY:
		out.append("symmetry %.2f" % sym)
	var pockets := fight_pockets(t, reach)
	if pockets < (2 if t.width >= 80 else 1):
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
		Tiles.Look.STREETS:
			if l.WARM + l.FLAME > 0:
				out.append("a warm light in the Streets")
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
