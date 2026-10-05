class_name Current
extends Node2D
## Map Stage 11e, the Reef's tide rule (docs/BIOME5_CONCEPT.md): the water in a channel runs.
## A room's `~ x0 y0 x1 y1 ...` lines (RoomTemplate.currents) are its channels' lines in cells,
## read downstream; every open cell within REACH of one takes that line's direction, weaker away
## from it. Where the cell is flooded the current carries what stands in it: gently in shallow
## water, hard in deep, harder as the tide rises over it. On the Reef, living coral (its first
## patch, laid by the water) cuts a body the current is carrying across it. Foam flecks drift
## with the water so the current can be seen before it is felt.

const REACH := 3.0
const SHALLOW_PUSH := 20.0   # px/s on the line, the cell just flooded (Tam walks 96)
const DEEP_PUSH := 44.0      # px/s on the line in deep water
const RISE_PUSH := 16.0      # px/s more as the tide climbs a further level over the cell
const CUT_MIN := 12.0        # px/s of carry before living coral cuts
const FLECKS := 70
const FLECK_LIFE := 2.4
const FLECK_DRIFT := 1.5     # flecks run a little faster than they carry, so the eye reads them

var room: Room
var flow: Dictionary = {}    # cell -> Vector2: direction times weight (0..1]
var _cells: Array = []
var _flecks: Array = []      # [position, age]
var _rng := RandomNumberGenerator.new()
var show_arrows := false     # dev aid: the flow drawn as arrows where it runs (room_sheet --flow)


func setup(p_room: Room) -> void:
	room = p_room
	name = "Current"
	z_index = 4  # on the water, under the spray
	var t := room.template
	for line: PackedVector2Array in t.currents:
		for i in line.size() - 1:
			_lay(t, line[i], line[i + 1])
	_cells = flow.keys()
	_rng.seed = hash(t.name) + 11


## Every open cell near the segment a..b takes its direction, the nearer the stronger.
func _lay(t: RoomTemplate, a: Vector2, b: Vector2) -> void:
	var dir := (b - a).normalized()
	if dir == Vector2.ZERO:
		return
	var r := int(ceil(REACH)) + 1
	for y in range(int(minf(a.y, b.y)) - r, int(maxf(a.y, b.y)) + r + 1):
		for x in range(int(minf(a.x, b.x)) - r, int(maxf(a.x, b.x)) + r + 1):
			if t.is_solid(x, y) or x < 0 or y < 0 or x >= t.width or y >= t.height:
				continue
			var p := Vector2(x, y)
			var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
			if d > REACH + 0.5:
				continue
			var w := 1.0 - d / (REACH + 1.0)
			var c := Vector2i(x, y)
			if not flow.has(c) or (flow[c] as Vector2).length() < w:
				flow[c] = dir * w


## How fast the water carries a body standing at `pos` (px/s), or zero where it is dry or still.
func push_at(pos: Vector2) -> Vector2:
	var c := room.world_to_cell(pos)
	if not flow.has(c) or not room.is_flooded_at(pos):
		return Vector2.ZERO
	var over := room.tide_level() - float(room.template.height_at(c.x, c.y))
	var s := SHALLOW_PUSH
	if over > 1.0:
		s = DEEP_PUSH + RISE_PUSH * clampf(over - 1.0, 0.0, 1.0)
	return (flow[c] as Vector2) * s


## Whether the water is carrying a body over living coral at `pos` (the Reef only).
func cuts_at(pos: Vector2) -> bool:
	if room.theme != Tiles.Look.REEF:
		return false
	return int(room.patches.get(room.world_to_cell(pos), -1)) == 0 and push_at(pos).length() >= CUT_MIN


func _process(delta: float) -> void:
	if _cells.is_empty():
		return
	while _flecks.size() < FLECKS:
		_flecks.append([Vector2.ZERO, FLECK_LIFE + 1.0])
	for f: Array in _flecks:
		f[1] += delta
		var p: Vector2 = f[0]
		var push := push_at(p)
		if f[1] > FLECK_LIFE or push == Vector2.ZERO:
			_respawn(f)
			continue
		f[0] = p + push * FLECK_DRIFT * delta
	queue_redraw()


func _respawn(f: Array) -> void:
	for k in 4:
		var c: Vector2i = _cells[_rng.randi() % _cells.size()]
		var p := room.cell_to_world(c) + Vector2(_rng.randf_range(-7, 7), _rng.randf_range(-7, 7))
		if push_at(p) != Vector2.ZERO:
			f[0] = p
			f[1] = _rng.randf_range(0.0, FLECK_LIFE * 0.5)
			return
	f[0] = Vector2(-999, -999)
	f[1] = FLECK_LIFE + 1.0


func _draw() -> void:
	if show_arrows:
		for c: Vector2i in _cells:
			if (c.x + c.y) % 3 != 0:
				continue
			var p := room.cell_to_world(c)
			var v := push_at(p)
			if v == Vector2.ZERO:
				continue
			var a := to_local(p)
			var tip := a + v.normalized() * (3.0 + v.length() * 0.12)
			var col := Color(Palette.SALT_RED, 0.9)
			draw_line(a, tip, col, 1.0)
			draw_line(tip, tip - v.normalized().rotated(0.6) * 3.0, col, 1.0)
			draw_line(tip, tip - v.normalized().rotated(-0.6) * 3.0, col, 1.0)
	for f: Array in _flecks:
		var p: Vector2 = f[0]
		if p.x < -900:
			continue
		var a := clampf(1.0 - absf(float(f[1]) / FLECK_LIFE - 0.5) * 2.0, 0.0, 1.0) * 0.8
		var at := to_local(p).round()
		draw_rect(Rect2(at, Vector2(2, 1)), Color(Palette.FOAM_WHITE, a))
