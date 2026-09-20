class_name Room
extends Node2D
## A built room: ground tiles with collision, water overlay driven by the tide,
## doors, props, spawn points. Content (enemies, pickups) is added by the run.

## Shallow water and foam step at 3 fps; the deep bodies at half that (STYLE.md 12).
const WATER_TICK := 1.0 / 3.0
const DECOR := preload("res://assets/sprites/decor.png")
const DECOR_STREETS := preload("res://assets/sprites/decor2.png")
const DECOR_DEEP := preload("res://assets/sprites/decor3.png")
const DECOR_HARBOUR := preload("res://assets/sprites/decor4.png")
const DECOR_COUNT := 8
const DECOR_PUDDLE := 4
const WATER_SHADER := preload("res://src/world/water.gdshader")
## Neighbour order for the water autotiles: the bit for each is 1 << index (N E S W).
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Water body kinds, in atlas order (Tiles.water_tileset): shallow A, shallow B, deep ring A,
## deep ring B, deep, abyss ring, abyss.
enum Body { SHALLOW_A, SHALLOW_B, RING_A, RING_B, DEEP, ABYSS_RING, ABYSS }
const BODY_COL := {Body.SHALLOW_A: 0, Body.SHALLOW_B: 3, Body.RING_A: 6, Body.RING_B: 8, Body.DEEP: 10,
	Body.ABYSS_RING: 12, Body.ABYSS: 14}

var template: RoomTemplate
var theme: int = Tiles.Look.FLATS
var doors: Array[Door] = []
var props: Array[Prop] = []

var _ground: TileMapLayer
var _shade: TileMapLayer   # the walls' cast shadow on the floor (art Stage 09)
var _edge: TileMapLayer    # the dry side of the shore: wet band, and the tide line round low ground
var _water: TileMapLayer   # shallow and deep bodies
var _foam: TileMapLayer    # foam on the shore side of every flooded cell
var _tide_level: float = -1.0
var tide_bonus: float = 0.0  # added to the run's tide here: wet ways, dives, the challenge
var _tick: int = 0
var _anim_t: float = 0.0
var _flooded: Array[Vector2i] = []
var _deep_cells: Array[Vector2i] = []
var _body: Dictionary = {}       # flooded cell -> Body
var _foam_case: Dictionary = {}  # flooded cell -> dry-neighbour bits
var _bubble_t: float = 0.0
var _bubble_rng := RandomNumberGenerator.new()
var _astar: AStarGrid2D


func build(t: RoomTemplate, decor_seed: int = 0, p_theme: int = Tiles.Look.FLATS) -> void:
	template = t
	theme = p_theme
	add_to_group("room")
	_bubble_rng.seed = decor_seed if decor_seed != 0 else hash(t.name)
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = Tiles.tileset()
	add_child(_ground)
	_shade = TileMapLayer.new()
	_shade.name = "Shade"
	_shade.tile_set = Tiles.tileset()
	add_child(_shade)
	_edge = TileMapLayer.new()
	_edge.name = "Edge"
	_edge.tile_set = Tiles.water_tileset()
	add_child(_edge)
	_scatter_decor(decor_seed)
	# Water sits under everything that walks (bodies draw their own wet edge): all at z 0,
	# so tree order decides, and the room is built before its content.
	_water = TileMapLayer.new()
	_water.name = "Water"
	_water.tile_set = Tiles.water_tileset()
	_water.modulate = Settings.water_tint()
	# Reflections: the shader adds glints of each light's colour (STYLE.md 11).
	_water.material = ShaderMaterial.new()
	_water.material.shader = WATER_SHADER
	Settings.changed.connect(func(k): if k == "water_tint" and is_instance_valid(_water): _water.modulate = Settings.water_tint())
	add_child(_water)
	_foam = TileMapLayer.new()
	_foam.name = "Foam"
	_foam.tile_set = Tiles.water_tileset()
	add_child(_foam)
	for y in t.height:
		for x in t.width:
			_ground.set_cell(Vector2i(x, y), 0, Tiles.coords(t.tile_at(x, y, theme)))
	_cast_wall_shadows()
	_build_nav()
	set_tide(0.0)


## Scatter shells, kelp, driftwood... on open sand so rooms do not look identical.
func _scatter_decor(decor_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = decor_seed if decor_seed != 0 else hash(template.name)
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
	var count := mini(candidates.size(), rng.randi_range(10, 18))
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


## Walls read as height by the shadow they throw: 3 px south, 1 px east and west (STYLE.md 4).
func _cast_wall_shadows() -> void:
	_shade.clear()
	for y in template.height:
		for x in template.width:
			if template.char_at(x, y) in ["#", "o"]:
				continue
			var s := y > 0 and template.char_at(x, y - 1) == "#"
			var w := x > 0 and template.char_at(x - 1, y) == "#"
			var e := x + 1 < template.width and template.char_at(x + 1, y) == "#"
			var idx := -1
			if s and w and e: idx = Tiles.SHADE_SWE
			elif s and w: idx = Tiles.SHADE_SW
			elif s and e: idx = Tiles.SHADE_SE
			elif w and e: idx = Tiles.SHADE_WE
			elif s: idx = Tiles.SHADE_S
			elif w: idx = Tiles.SHADE_W
			elif e: idx = Tiles.SHADE_E
			if idx >= 0:
				_shade.set_cell(Vector2i(x, y), 0, Tiles.coords(idx))


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
		# Push to the nearest open floor cell (never a door).
		for off in _RINGS:
			var n: Vector2i = c + off
			if not template.is_solid(n.x, n.y) and template.char_at(n.x, n.y) != "D":
				return cell_to_world(n)
	return p


## Cell offsets out to three tiles, nearest first.
static var _RINGS: Array[Vector2i] = _rings(3)


static func _rings(radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx != 0 or dy != 0:
				out.append(Vector2i(dx, dy))
	out.sort_custom(func(a, b): return Vector2(a).length_squared() < Vector2(b).length_squared())
	return out


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


## Rebuild the water overlay when the tide crosses a new eighth-level.
func set_tide(level: float) -> void:
	level += tide_bonus
	if int(level * 8.0) == int(_tide_level * 8.0) and _tide_level >= 0.0:
		_tide_level = level
		return
	_tide_level = level
	_refresh_water()


func _cell_flooded(c: Vector2i) -> bool:
	return not template.is_solid(c.x, c.y) and _tide_level > template.height_at(c.x, c.y)


func _cell_deep(c: Vector2i) -> bool:
	return not template.is_solid(c.x, c.y) and _tide_level > template.height_at(c.x, c.y) + 1.0


## The water language, from the height map (STYLE.md 12). Shallow water shows the floor
## through it; foam sits on the water tile along every edge that touches dry floor; the dry
## side gets a wet band; low ground that is still dry keeps a tide line where it meets the
## floor. Deep water is opaque, dithered two tiles wide where it meets shallow water, and
## Abyss at the centre of a large pool.
func _refresh_water() -> void:
	_water.clear()
	_foam.clear()
	_edge.clear()
	_flooded.clear()
	_deep_cells.clear()
	_body.clear()
	_foam_case.clear()
	var w := template.width
	var h := template.height
	# Distance from anything that is not deep water (shallow, dry, wall) picks the dither rings.
	var dist: Dictionary = {}
	var queue: Array[Vector2i] = []
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not _cell_deep(c):
				dist[c] = 0
				queue.append(c)
	var qi := 0
	while qi < queue.size():
		var c: Vector2i = queue[qi]
		qi += 1
		for off in DIRS:
			var n: Vector2i = c + off
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or dist.has(n):
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if template.is_solid(x, y):
				continue
			if _cell_flooded(c):
				_flooded.append(c)
				if _cell_deep(c):
					_deep_cells.append(c)
					var d := int(dist.get(c, 99))
					_body[c] = Body.RING_A if d == 1 else Body.RING_B if d == 2 else Body.DEEP if d <= 4 \
						else Body.ABYSS_RING if d == 5 else Body.ABYSS
				else:
					_body[c] = Body.SHALLOW_A if (x + y) % 2 == 0 else Body.SHALLOW_B
				var bits := 0
				for i in 4:
					var n: Vector2i = c + DIRS[i]
					if not template.is_solid(n.x, n.y) and not _cell_flooded(n):
						bits |= 1 << i
				if bits:
					_foam_case[c] = bits
			else:
				var bits := 0
				for i in 4:
					if _cell_flooded(c + DIRS[i]):
						bits |= 1 << i
				if bits:
					_edge.set_cell(c, 0, Vector2i(bits, Tiles.WATER_WET_ROW))
				elif template.height_at(x, y) == 0:
					for i in 4:
						var n: Vector2i = c + DIRS[i]
						if not template.is_solid(n.x, n.y) and template.height_at(n.x, n.y) >= 1:
							bits |= 1 << i
					if bits:
						_edge.set_cell(c, 0, Vector2i(bits, Tiles.WATER_LINE_ROW))
	_paint_water()


## Body and foam cells for the current animation tick.
func _paint_water() -> void:
	var f3 := _tick % 3
	var f2 := (_tick / 2) % 2
	for c in _body:
		var kind: int = _body[c]
		var col: int = BODY_COL[kind] + (f3 if kind <= Body.SHALLOW_B else f2)
		_water.set_cell(c, 0, Vector2i(col, 0))
	for c in _foam_case:
		_foam.set_cell(c, 0, Vector2i(int(_foam_case[c]), Tiles.WATER_FOAM_ROW + f3))


func _process(delta: float) -> void:
	if _flooded.is_empty():
		return
	_anim_t += delta
	if _anim_t >= WATER_TICK:
		_anim_t -= WATER_TICK
		_tick += 1
		_paint_water()
	# A bubble every ~4 s per 6 deep tiles.
	if not _deep_cells.is_empty():
		_bubble_t += delta * float(_deep_cells.size()) / 24.0
		var n := 0
		while _bubble_t >= 1.0 and n < 4:
			_bubble_t -= 1.0
			n += 1
			var c: Vector2i = _deep_cells[_bubble_rng.randi() % _deep_cells.size()]
			FX.bubble(cell_to_world(c) + Vector2(_bubble_rng.randi_range(-5, 5), _bubble_rng.randi_range(-5, 5)), self)
