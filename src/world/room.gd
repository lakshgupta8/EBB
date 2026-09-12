class_name Room
extends Node2D
## A built room: ground tiles with collision, water overlay driven by the tide,
## doors, props, spawn points. Content (enemies, pickups) is added by the run.

const WATER_ANIM_PERIOD := 0.55
const DECOR := preload("res://assets/sprites/decor.png")
const DECOR_STREETS := preload("res://assets/sprites/decor2.png")
const DECOR_DEEP := preload("res://assets/sprites/decor3.png")
const DECOR_HARBOUR := preload("res://assets/sprites/decor4.png")
const DECOR_COUNT := 8
const DECOR_PUDDLE := 4
const TINTS := [Color(1, 1, 1), Color(0.97, 0.99, 1.0), Color(1.0, 0.97, 0.93), Color(0.95, 0.97, 0.95)]

var template: RoomTemplate
var theme: int = Tiles.Look.FLATS
var doors: Array[Door] = []
var props: Array[Prop] = []

var _ground: TileMapLayer
var _water: TileMapLayer
var _tide_level: float = -1.0
var tide_bonus: float = 0.0  # added to the run's tide here: wet ways, dives, the challenge
var _water_phase: int = 0
var _anim_t: float = 0.0
var _flooded: Array[Vector2i] = []
var _astar: AStarGrid2D


func build(t: RoomTemplate, decor_seed: int = 0, p_theme: int = Tiles.Look.FLATS) -> void:
	template = t
	theme = p_theme
	add_to_group("room")
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = Tiles.tileset()
	add_child(_ground)
	_scatter_decor(decor_seed)
	_water = TileMapLayer.new()
	_water.name = "Water"
	_water.tile_set = Tiles.tileset()
	_water.modulate = Color(1, 1, 1, 0.62)  # ground shows through shallow water; deep tile is darker
	_water.z_index = 1
	add_child(_water)
	for y in t.height:
		for x in t.width:
			_ground.set_cell(Vector2i(x, y), 0, Tiles.coords(t.tile_at(x, y, theme)))
	_build_nav()
	set_tide(0.0)


## Scatter shells, kelp, driftwood... on open sand so rooms do not look identical.
func _scatter_decor(decor_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = decor_seed if decor_seed != 0 else hash(template.name)
	_ground.modulate = TINTS[rng.randi() % TINTS.size()]
	var layer := Node2D.new()
	layer.name = "Decor"
	layer.z_index = 0
	add_child(layer)
	var candidates: Array[Vector2i] = []
	for y in range(1, template.height - 1):
		for x in range(1, template.width - 1):
			var ch := template.char_at(x, y)
			if ch == "." or ch == "_":
				candidates.append(Vector2i(x, y))
	var count := mini(candidates.size(), rng.randi_range(16, 28))
	for i in count:
		var idx := rng.randi() % candidates.size()
		var cell := candidates[idx]
		candidates.remove_at(idx)
		var kind := rng.randi() % DECOR_COUNT
		if theme == Tiles.Look.FLATS and template.char_at(cell.x, cell.y) == "_" and rng.randf() < 0.5:
			kind = DECOR_PUDDLE
		var s := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = DECOR
		match theme:
			Tiles.Look.DEEP: at.atlas = DECOR_DEEP
			Tiles.Look.STREETS: at.atlas = DECOR_STREETS
			Tiles.Look.HARBOUR: at.atlas = DECOR_HARBOUR
		at.region = Rect2(kind * 16, 0, 16, 16)
		s.texture = at
		s.position = cell_to_world(cell) + Vector2(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
		s.flip_h = rng.randf() < 0.5
		layer.add_child(s)


func _build_nav() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, template.width, template.height)
	_astar.cell_size = Vector2(Tiles.SIZE, Tiles.SIZE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in template.height:
		for x in template.width:
			if template.is_solid(x, y):
				_astar.set_point_solid(Vector2i(x, y), true)


## Cell-centre waypoints from `from` to `to` (both world positions). Empty if unreachable.
func nav_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := world_to_cell(from).clamp(Vector2i.ZERO, Vector2i(template.width - 1, template.height - 1))
	var b := world_to_cell(to).clamp(Vector2i.ZERO, Vector2i(template.width - 1, template.height - 1))
	if _astar.is_point_solid(a) or _astar.is_point_solid(b):
		return PackedVector2Array()
	var pts := _astar.get_point_path(a, b)
	for i in pts.size():
		pts[i] += Vector2(Tiles.SIZE, Tiles.SIZE) * 0.5
	return pts


func size_px() -> Vector2:
	return Vector2(template.width, template.height) * Tiles.SIZE


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * Tiles.SIZE + Vector2(Tiles.SIZE, Tiles.SIZE) * 0.5


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i((pos / Tiles.SIZE).floor())


## Keep a point on walkable ground: inside the outer walls and off solid cells.
func clamp_inside(pos: Vector2) -> Vector2:
	var margin := Tiles.SIZE + 5.0
	var p := Vector2(
		clampf(pos.x, margin, size_px().x - margin),
		clampf(pos.y, margin, size_px().y - margin))
	var c := world_to_cell(p)
	if template.is_solid(c.x, c.y):
		# Push toward the nearest open neighbour cell.
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + off
			if not template.is_solid(n.x, n.y):
				return cell_to_world(n)
	return p


func height_at(pos: Vector2) -> int:
	var c := world_to_cell(pos)
	return template.height_at(c.x, c.y)


func is_flooded_at(pos: Vector2) -> bool:
	return _tide_level > height_at(pos)


func is_deep_at(pos: Vector2) -> bool:
	return _tide_level > height_at(pos) + 1.0


## Any flooded tile at all (the drowned come up out of the water).
func has_water() -> bool:
	return not _flooded.is_empty()


func set_ground_tile(cell: Vector2i, index: int) -> void:
	_ground.set_cell(cell, 0, Tiles.coords(index))


## Direction from a wall cell toward the room interior (for door icons).
func interior_dir(cell: Vector2i) -> Vector2:
	if cell.y == 0: return Vector2.DOWN
	if cell.y == template.height - 1: return Vector2.UP
	if cell.x == 0: return Vector2.RIGHT
	return Vector2.LEFT


## Assign exit types to door slots. Extra slots become wall.
func place_doors(types: Array) -> void:
	for i in template.doors.size():
		var cell: Vector2i = template.doors[i]
		if i < types.size():
			var d := Door.new()
			add_child(d)
			d.setup(self, cell, types[i])
			doors.append(d)
		else:
			set_ground_tile(cell, Tiles.WALL)


func open_doors() -> void:
	for d in doors:
		d.open()


func add_prop(kind: Prop.Kind, cell: Vector2i) -> Prop:
	var p := Prop.new()
	add_child(p)
	p.setup(kind, cell_to_world(cell))
	props.append(p)
	return p


## Rebuild the water overlay when the tide crosses a new quarter-level.
func set_tide(level: float) -> void:
	level += tide_bonus
	if int(level * 8.0) == int(_tide_level * 8.0) and _tide_level >= 0.0:
		_tide_level = level
		return
	_tide_level = level
	_refresh_water()


func _refresh_water() -> void:
	_water.clear()
	_flooded.clear()
	for y in template.height:
		for x in template.width:
			var h := template.height_at(x, y)
			if template.is_solid(x, y) or _tide_level <= h:
				continue
			var cell := Vector2i(x, y)
			_flooded.append(cell)
			_water.set_cell(cell, 0, Tiles.coords(_water_tile(cell, h)))


## Deep, foam (touching dry ground) or plain water, in the current animation phase.
func _water_tile(cell: Vector2i, h: int) -> int:
	if _tide_level > h + 1.0:
		return Tiles.DEEP
	var shore := false
	for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + off
		if template.is_solid(n.x, n.y):
			continue
		if _tide_level <= template.height_at(n.x, n.y):
			shore = true
			break
	if shore:
		return Tiles.FOAM2 if _water_phase == 1 else Tiles.FOAM
	return Tiles.WATER2 if _water_phase == 1 else Tiles.WATER


func _process(delta: float) -> void:
	if _flooded.is_empty():
		return
	_anim_t += delta
	if _anim_t >= WATER_ANIM_PERIOD:
		_anim_t = 0.0
		_water_phase = 1 - _water_phase
		for cell in _flooded:
			var h := template.height_at(cell.x, cell.y)
			if _tide_level > h + 1.0:
				continue
			_water.set_cell(cell, 0, Tiles.coords(_water_tile(cell, h)))
