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
const DECOR_REEF := preload("res://assets/sprites/decor5.png")
const WATER_SHADER := preload("res://src/world/water.gdshader")
const GROUND_DECALS := preload("res://assets/sprites/ground_decals.png")
## One-cell obstacles per look (map Stage 06, tools/gen_obstacles.py): 16x24, the cell and 8 px
## rising above it; rows in Tiles.Look order, three variants across.
const OBSTACLES := preload("res://assets/sprites/obstacles.png")
const OBSTACLE_RISE := 8
## World light's pools (map Stage 07): the haze sprite at this scale per unit of light scale,
## and its alpha at energy 0.5.
const POOL_SCALE := 0.5
const POOL_ALPHA := 0.2
## Neighbour order for the water autotiles: the bit for each is 1 << index (N E S W).
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Water body kinds per cell (the deep ones pick the full deep tiles): shallow A, shallow B, deep ring A,
## deep ring B, deep, abyss ring, abyss.
enum Body { SHALLOW_A, SHALLOW_B, RING_A, RING_B, DEEP, ABYSS_RING, ABYSS }
const BODY_COL := {Body.SHALLOW_A: 0, Body.SHALLOW_B: 3, Body.RING_A: 6, Body.RING_B: 8, Body.DEEP: 10,
	Body.ABYSS_RING: 12, Body.ABYSS: 14}

var template: RoomTemplate
var theme: int = Tiles.Look.FLATS
var doors: Array[Door] = []
var props: Array[Prop] = []

var _beyond: Node2D      # the void beyond the walls and the far scenery on it (art Stage 12)
var _fore: Node2D        # foreground silhouettes on the south rim, above everything that walks
var _ground: TileMapLayer  # collision only since map Stage 03: the terrain layers draw the ground
var _terrain: Array[TileMapLayer] = []  # dual grid: low, floor, raised, wall (STYLE.md 22, Edges)
var _patch_layers: Array[TileMapLayer] = []  # dual grid: the look's three ground patches (map Stage 04)
var patches: Dictionary = {}  # floor cell -> patch index (GroundPatches.plan)
var current: Current = null   # the water that runs (map Stage 11e), if the room has `~` lines
var _cells: TileMapLayer   # what is drawn per cell over the terrain: rocks and doors
var _water: TileMapLayer   # shallow water on the dual grid, its foam and the wet band beside it
var _deep: TileMapLayer    # deep water over it
var _water_cells: Array = []  # [vertex, case, variant, full kind] for the shallow layer
var _deep_vertices: Array = []  # [vertex, case, variant, ring] for the deep layer
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
var _spray: CPUParticles2D              # Salt white specks along the shore (art Stage 15)
var _drip_points: PackedVector2Array = []  # wall tops that drip (the Streets, the Hall)
var _drip_t: float = 0.0
var _astar: AStarGrid2D
## Per cell, on a grid one wider than the room on every side (map Stage 13b): the terrain height
## the layers draw, solid or not, and the ground height the water floods. A template does not
## change once built; asking it per corner made an 80x46 room's water cost 150 ms a rebuild.
var _pw: int = 0
var _ter := PackedInt32Array()
var _sol := PackedByteArray()
var _hgt := PackedInt32Array()


func build(t: RoomTemplate, decor_seed: int = 0, p_theme: int = Tiles.Look.FLATS) -> void:
	template = t
	theme = p_theme
	add_to_group("room")
	_bubble_rng.seed = decor_seed if decor_seed != 0 else hash(t.name)
	var rng := RandomNumberGenerator.new()
	rng.seed = _bubble_rng.seed
	_cache_cells()
	_build_beyond(rng)
	# The cell grid keeps the collision; it is not drawn (the terrain draws the ground).
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = Tiles.tileset()
	_ground.self_modulate = Color(1, 1, 1, 0)
	add_child(_ground)
	for i in 2:
		_terrain.append(_dual_layer("Terrain%d" % i, Tiles.terrain_tileset()))
	# Patches lie on the floor, under raised ground and walls, which draw their edges over them.
	for i in 3:
		_patch_layers.append(_dual_layer("Patch%d" % i, Tiles.patch_tileset()))
	patches = GroundPatches.plan(t, theme, _bubble_rng.seed)
	_lay_decals()
	_terrain.append(_dual_layer("Terrain2", Tiles.terrain_tileset()))
	_scatter_decor(decor_seed)
	# Water sits under everything that walks (bodies draw their own wet edge): all at z 0,
	# so tree order decides, and the room is built before its content.
	_water = _dual_layer("Water", Tiles.water_edge_tileset())
	_deep = _dual_layer("Deep", Tiles.water_edge_tileset())
	for layer in [_water, _deep]:
		layer.modulate = Settings.water_tint()
		# Reflections: the shader adds glints of each light's colour (STYLE.md 11).
		layer.material = ShaderMaterial.new()
		layer.material.shader = WATER_SHADER
	Settings.changed.connect(func(k): if k == "water_tint" and is_instance_valid(_water):
		_water.modulate = Settings.water_tint()
		_deep.modulate = Settings.water_tint())
	# Walls stand over the water that laps them, and over the decor at their feet.
	_terrain.append(_dual_layer("Terrain3", Tiles.terrain_tileset()))
	_cells = TileMapLayer.new()
	_cells.name = "Cells"
	_cells.tile_set = Tiles.cells_tileset()
	add_child(_cells)
	for y in t.height:
		for x in t.width:
			# The inside of a wall mass is left to the void layer beneath.
			if t.is_beyond(x, y):
				continue
			var idx := t.tile_at(x, y, theme)
			_ground.set_cell(Vector2i(x, y), 0, Tiles.coords(idx))
			# Rocks are drawn as obstacles with the set pieces (map Stage 06); doors per cell.
			if idx in [Tiles.DOOR, Tiles.DOOR_OPEN]:
				_cells.set_cell(Vector2i(x, y), 0, Tiles.coords(idx))
	# Set pieces stand on the floor: their footprints collide (an undrawn solid cell).
	for c: Vector2i in t.piece_cells:
		_ground.set_cell(c, 0, Tiles.coords(Tiles.ROCK))
	_paint_terrain()
	_build_pieces()
	_build_foreground(rng)
	_build_nav()
	_build_spray()
	if not t.currents.is_empty():
		current = Current.new()
		add_child(current)
		current.setup(self)
	_find_drips()
	set_tide(0.0)


## The void beyond the walls (STYLE.md 11: Abyss with a faint Night 1 texture, unlit) with the
## far scenery standing in it, on one node so it can shift a little with Tam (Scenery.PARALLAX).
func _build_beyond(rng: RandomNumberGenerator) -> void:
	_beyond = Node2D.new()
	_beyond.name = "Beyond"
	add_child(_beyond)
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var void_layer := TileMapLayer.new()
	void_layer.name = "Void"
	void_layer.tile_set = Tiles.beyond_tileset()
	void_layer.material = unlit
	var row := Scenery.void_row(theme)
	# Every wall cell and two cells past the room on each side: the rim walls draw over it, and
	# the shift never shows the clear colour (an L room shifts it up to 20 px, map Stage 02).
	for y in range(-2, template.height + 2):
		for x in range(-2, template.width + 2):
			if template.char_at(x, y) == "#":
				var c := Vector2i(x, y)
				void_layer.set_cell(c, 0, Vector2i(Scenery.void_variant(c), row))
	_beyond.add_child(void_layer)
	for p in Scenery.place_scenery(template, theme, rng):
		var s := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = Scenery.SCENERY
		at.region = Rect2(int(p.kind) * Scenery.CELL, 0, Scenery.CELL, Scenery.CELL)
		s.texture = at
		s.centered = false
		s.position = p.pos - Vector2(Scenery.CELL / 2.0, Scenery.CELL)
		s.material = unlit
		_beyond.add_child(s)


## Foreground silhouettes on the south rim (STYLE.md 20: the strongest shapes on screen, so two
## or three, and never near a door). They overhang the last floor row by 8 px, above the content.
func _build_foreground(rng: RandomNumberGenerator) -> void:
	_fore = Node2D.new()
	_fore.name = "Foreground"
	_fore.z_index = 3
	add_child(_fore)
	for p in Scenery.place_foreground(template, theme, rng):
		var s := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = Scenery.FOREGROUND
		at.region = Rect2(int(p.kind) * Scenery.FG_W, 0, Scenery.FG_W, Scenery.FG_H)
		s.texture = at
		s.centered = false
		s.position = p.pos - Vector2(Scenery.FG_W / 2.0, Scenery.FG_H)
		_fore.add_child(s)


## Set pieces (map Stage 05, SetPieces): each sprite split at its footprint's north edge. The
## part on the footprint and its shadow draws with the ground; the part that rises above it
## draws over the keeper and the drowned (z 3), who can stand behind it. A piece may carry a light.
func _build_pieces() -> void:
	# World light's pools (map Stage 07): additive light cannot lift a near-black floor (STYLE.md
	# 11), so each piece's light also lays a faint disc of its colour on the ground at its foot,
	# under the pieces and the bodies, breathing with it.
	var pools := Node2D.new()
	pools.name = "LightPools"
	add_child(pools)
	var under := Node2D.new()
	under.name = "Pieces"
	add_child(under)
	var over := Node2D.new()
	over.name = "PiecesAbove"
	over.z_index = 3
	add_child(over)
	# The one-cell obstacles, split as the pieces are: the 8 px above the cell over the bodies.
	for y in template.height:
		for x in template.width:
			if template.char_at(x, y) != "o":
				continue
			var v := vertex_pick(Vector2i(x, y), 3, 5)
			# On the quays a bollard stands at the water's edge, crates everywhere else.
			if theme == Tiles.Look.HARBOUR:
				var by_water := false
				for d in DIRS:
					by_water = by_water or template.height_at(x + d.x, y + d.y) == 0
				v = 2 if by_water else posmod(hash(Vector2i(x, y)), 2)
			var at := Vector2(x, y) * Tiles.SIZE
			var row := clampi(theme, 0, Tiles.LAST_LOOK) * 24
			for part in [[under, OBSTACLE_RISE, Tiles.SIZE, at], [over, 0, OBSTACLE_RISE, at - Vector2(0, OBSTACLE_RISE)]]:
				var s := Sprite2D.new()
				s.texture = OBSTACLES
				s.region_enabled = true
				s.region_rect = Rect2(v * 16, row + int(part[1]), 16, part[2])
				s.centered = false
				s.position = part[3]
				s.flip_h = posmod(hash(Vector2i(x, y)), 2) == 1
				part[0].add_child(s)
	for p in template.pieces:
		var info := SetPieces.info(str(p.id))
		var r: Array = info.region
		var o: Array = info.origin
		var top_left := Vector2(p.cell) * Tiles.SIZE - Vector2(o[0], o[1])
		for part in [[under, int(o[1]), int(r[3]) - int(o[1])], [over, 0, int(o[1])]]:
			if int(part[2]) <= 0:
				continue
			var s := Sprite2D.new()
			s.texture = SetPieces.TEXTURE
			s.region_enabled = true
			s.region_rect = Rect2(r[0], int(r[1]) + int(part[1]), r[2], part[2])
			s.centered = false
			s.position = top_left + Vector2(0, int(part[1]))
			part[0].add_child(s)
		if info.has("light"):
			var l: Dictionary = info.light
			var col: Color = {"WARM": Atmosphere.WARM, "FLAME": Atmosphere.FLAME}.get(str(l.color), Atmosphere.COLD)
			var e := float(l.energy)
			var pl := Atmosphere.light(under, col, float(l.scale), e, top_left + Vector2(l.at[0], l.at[1]))
			# World light breathes (map Stage 07): a flame quick and shallow, a lamp slow, the cold
			# glows slower and deeper, each out of step with the others.
			var beat: Array = {"FLAME": [0.12, 1.3], "WARM": [0.08, 3.0]}.get(str(l.color), [0.15, 3.4])
			var period: float = beat[1] * (0.85 + 0.3 * vertex_pick(p.cell, 10, 3) / 10.0)
			Atmosphere.breathe(pl, e * (1.0 - beat[0]), e * (1.0 + beat[0]), period)
			var size := SetPieces.size(str(p.id))
			var pool := Sprite2D.new()
			pool.texture = Atmosphere.HAZE
			pool.position = Vector2(p.cell) * Tiles.SIZE + Vector2(size.x * Tiles.SIZE * 0.5, size.y * Tiles.SIZE)
			pool.scale = Vector2(1.0, 0.7) * float(l.scale) * POOL_SCALE
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			pool.material = add
			var a: float = POOL_ALPHA * e / 0.5
			pool.modulate = Color(col, a)
			pools.add_child(pool)
			var tw := pool.create_tween().set_loops()
			tw.tween_property(pool, "modulate:a", a * (1.0 + beat[0]), period * 0.5).set_trans(Tween.TRANS_SINE)
			tw.tween_property(pool, "modulate:a", a * (1.0 - beat[0]), period * 0.5).set_trans(Tween.TRANS_SINE)


## Large decals flat on the floor (map Stage 04): ribs in the sand, a drain, the tide sigil.
func _lay_decals() -> void:
	var layer := Node2D.new()
	layer.name = "GroundDecals"
	add_child(layer)
	for d in GroundPatches.decals(template, patches, _bubble_rng.seed):
		var s := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = GROUND_DECALS
		at.region = Rect2(int(d.kind) * 32, clampi(theme, 0, Tiles.LAST_LOOK) * 32, 32, 32)
		s.texture = at
		s.position = Vector2(d.cell + Vector2i.ONE) * Tiles.SIZE
		s.flip_h = posmod(hash(d.cell), 2) == 1
		layer.add_child(s)


## The small things (shells, kelp, driftwood, benches, candles...), placed by rule
## (DecorRules, art Stage 12) so rooms differ without clutter in doorways or under props.
func _scatter_decor(decor_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = decor_seed if decor_seed != 0 else hash(template.name)
	var layer := Node2D.new()
	layer.name = "Decor"
	layer.z_index = 0
	add_child(layer)
	var atlas: Texture2D = DECOR
	match theme:
		Tiles.Look.DEEP: atlas = DECOR_DEEP
		Tiles.Look.STREETS: atlas = DECOR_STREETS
		Tiles.Look.HARBOUR: atlas = DECOR_HARBOUR
		Tiles.Look.REEF: atlas = DECOR_REEF
	for d in DecorRules.plan(template, theme, rng):
		var s := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = atlas
		at.region = Rect2(int(d.kind) * 16, 0, 16, 16)
		s.texture = at
		s.position = cell_to_world(d.cell) + Vector2(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
		s.flip_h = rng.randf() < 0.5
		layer.add_child(s)


## A layer drawn on the dual grid: offset half a tile so each of its tiles sits on the corner
## where four cells meet (map Stage 03).
func _dual_layer(p_name: String, ts: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = p_name
	layer.tile_set = ts
	layer.position = -Vector2(Tiles.SIZE, Tiles.SIZE) * 0.5
	add_child(layer)
	return layer


## The terrain height of a cell for the layers: 0 low, 1 floor, 2 raised, 3 wall, -1 the void.
## Rocks stand on floor and doors in the wall (both drawn per cell over it).
func terrain_height(x: int, y: int) -> int:
	if template.is_beyond(x, y):
		return -1
	match template.char_at(x, y):
		"#", "D": return 3
		"=", "h": return 2
		"_", "X": return 0
		_: return template.height_at(x, y)  # a marker stands on its neighbours' ground


func _cache_cells() -> void:
	_pw = template.width + 2
	var n := _pw * (template.height + 2)
	_ter.resize(n)
	_sol.resize(n)
	_hgt.resize(n)
	for y in range(-1, template.height + 1):
		for x in range(-1, template.width + 1):
			var k := (y + 1) * _pw + x + 1
			_ter[k] = terrain_height(x, y)
			_sol[k] = 1 if template.is_solid(x, y) else 0
			_hgt[k] = template.height_at(x, y)


## dual_case over a per-cell grid laid out as _ter is: cell (x, y) at (y + 1) * _pw + x + 1.
func _corner(a: PackedByteArray, i: int, j: int) -> int:
	var k := j * _pw + i
	return a[k] | a[k + 1] << 1 | a[k + _pw] << 2 | a[k + _pw + 1] << 3


## Corner case for the tile at vertex (i, j): which of its four cells pass. TL=1 TR=2 BL=4 BR=8.
static func dual_case(i: int, j: int, holds: Callable) -> int:
	return int(holds.call(i - 1, j - 1)) | int(holds.call(i, j - 1)) << 1 		| int(holds.call(i - 1, j)) << 2 | int(holds.call(i, j)) << 3


## A variant from 0..n-1 for a vertex, stable for the room.
static func vertex_pick(v: Vector2i, n: int, salt: int = 0) -> int:
	return posmod(hash(v * 31 + Vector2i(salt, salt * 7)), n)


## Every layer: a vertex gets its layer's tile when any of its four cells reach that height. Walls
## show their face where their edge runs south, steps and banks a smaller one, and each throws
## its shadow (STYLE.md 22, Edges; tools/gen_terrain.py).
func _paint_terrain() -> void:
	var look := clampi(theme, 0, Tiles.LAST_LOOK)
	var holds := PackedByteArray()
	holds.resize(_ter.size())
	for la in Tiles.TERRAIN_LAYERS:
		var layer := _terrain[la]
		layer.clear()
		var row := look * Tiles.TERRAIN_LAYERS + la
		for k in _ter.size():
			holds[k] = 1 if _ter[k] >= la else 0
		for j in template.height + 1:
			for i in template.width + 1:
				var v := Vector2i(i, j)
				var c := _corner(holds, i, j)
				if c == 0:
					continue
				var col := c * Tiles.TERRAIN_VARIANTS + vertex_pick(v, Tiles.TERRAIN_VARIANTS)
				if c == 15:
					# The clean fill, the tile as drawn one in five, the floor's second tile one in five.
					var pick := vertex_pick(v, 5, 3)
					col = Tiles.TERRAIN_FILL + (1 if pick == 0 else 2 if pick == 1 and la == 1 else 0)
				layer.set_cell(v, 0, Vector2i(col, row))
	var patch := PackedInt32Array()
	patch.resize(_ter.size())
	for y in range(-1, template.height + 1):
		for x in range(-1, template.width + 1):
			patch[(y + 1) * _pw + x + 1] = int(patches.get(Vector2i(x, y), -1))
	for p in _patch_layers.size():
		var layer := _patch_layers[p]
		layer.clear()
		var row := look * 3 + p
		for k in patch.size():
			holds[k] = 1 if patch[k] == p else 0
		for j in template.height + 1:
			for i in template.width + 1:
				var v := Vector2i(i, j)
				var c := _corner(holds, i, j)
				if c == 0:
					continue
				var col := c * Tiles.TERRAIN_VARIANTS + vertex_pick(v, Tiles.TERRAIN_VARIANTS, 5)
				if c == 15:
					col = Tiles.TERRAIN_FILL + vertex_pick(v, 3, 9)
				layer.set_cell(v, 0, Vector2i(col, row))


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
		# Deep in a mass (rims are thick since map Stage 06): the nearest floor anyone can reach.
		if _reach_cache.is_empty():
			_reach_cache = template.reachable_cells()
		var best := Vector2i(-1, -1)
		var bd := INF
		for n: Vector2i in _reach_cache:
			var d := Vector2(n - c).length_squared()
			if d < bd:
				bd = d
				best = n
		if best.x >= 0:
			return cell_to_world(best)
	return p


var _reach_cache: Dictionary = {}


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


func tide_level() -> float:
	return _tide_level


## The current carries a body standing in it (map Stage 11e); walls stop it as they stop walking.
func carry(body: CharacterBody2D, delta: float) -> void:
	if current == null:
		return
	var p := current.push_at(body.global_position)
	if p != Vector2.ZERO:
		body.move_and_collide(p * delta)


func is_flooded_at(pos: Vector2) -> bool:
	return _tide_level > height_at(pos)


func is_deep_at(pos: Vector2) -> bool:
	return _tide_level > height_at(pos) + 1.0


## Any flooded tile at all (the drowned come up out of the water).
func has_water() -> bool:
	return not _flooded.is_empty()


func set_ground_tile(cell: Vector2i, index: int) -> void:
	_ground.set_cell(cell, 0, Tiles.coords(index))
	if index in [Tiles.ROCK, Tiles.DOOR, Tiles.DOOR_OPEN]:
		_cells.set_cell(cell, 0, Tiles.coords(index))
	else:
		_cells.erase_cell(cell)


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


## The water language, from the height map (STYLE.md 12; map Stage 03). Per cell: which cells
## are flooded and deep, the body each one gets (shallow alternating, deep dithered two tiles in
## from shallow, Abyss at the centre of a large pool) and which sides face dry floor (the spray
## follows them). Drawn on the dual grid: the shallow layer's tiles carry the foam on their wet
## side and the wet band on their dry side, and the deep layer lies over it. Water runs under
## any wall or rock it touches, so it meets them with no foam and the wall draws over it.
## Worked on the per-cell grids of _cache_cells (map Stage 13b).
func _refresh_water() -> void:
	_water.clear()
	_deep.clear()
	_flooded.clear()
	_deep_cells.clear()
	_body.clear()
	_foam_case.clear()
	_water_cells.clear()
	_deep_vertices.clear()
	var w := template.width
	var h := template.height
	var pw := _pw
	var n := _hgt.size()
	# Flooded and deep (nothing outside the room is: it counts as solid).
	var fl := PackedByteArray()
	var dp := PackedByteArray()
	fl.resize(n)
	dp.resize(n)
	for k in n:
		if _sol[k] == 0 and _tide_level > _hgt[k]:
			fl[k] = 1
			if _tide_level > _hgt[k] + 1.0:
				dp[k] = 1
	# Distance from anything that is not deep water (shallow, dry, wall) picks the dither rings.
	# -1: not reached, -2: outside the room.
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var queue := PackedInt32Array()
	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			var k := (y + 1) * pw + x + 1
			if x < 0 or y < 0 or x >= w or y >= h:
				dist[k] = -2
			elif dp[k] == 0:
				dist[k] = 0
				queue.append(k)
	var steps := PackedInt32Array()
	for d in DIRS:
		steps.append(d.y * pw + d.x)
	var qi := 0
	while qi < queue.size():
		var k := queue[qi]
		qi += 1
		for st in steps:
			if dist[k + st] == -1:
				dist[k + st] = dist[k] + 1
				queue.append(k + st)
	for y in h:
		for x in w:
			var k := (y + 1) * pw + x + 1
			if fl[k] == 0:
				continue
			var c := Vector2i(x, y)
			_flooded.append(c)
			if dp[k] == 1:
				_deep_cells.append(c)
				var d := dist[k] if dist[k] >= 0 else 99
				_body[c] = Body.RING_A if d == 1 else Body.RING_B if d == 2 else Body.DEEP if d <= 4 \
					else Body.ABYSS_RING if d == 5 else Body.ABYSS
			else:
				_body[c] = Body.SHALLOW_A if (x + y) % 2 == 0 else Body.SHALLOW_B
			var bits := 0
			for i in 4:
				if _sol[k + steps[i]] == 0 and fl[k + steps[i]] == 0:
					bits |= 1 << i
			if bits:
				_foam_case[c] = bits
	if _flooded.is_empty():
		_refresh_spray()
		return
	# Flooded (or deep), or a wall or rock with such water beside it: the water runs under it.
	# The void beyond the walls takes none.
	var wet := PackedByteArray()
	var under := PackedByteArray()
	wet.resize(n)
	under.resize(n)
	for y in h:
		for x in w:
			var k := (y + 1) * pw + x + 1
			if _sol[k] == 0:
				wet[k] = fl[k]
				under[k] = dp[k]
			elif _ter[k] != -1:
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nk := k + dy * pw + dx
						wet[k] |= fl[nk]
						under[k] |= dp[nk]
	for j in h + 1:
		for i in w + 1:
			var v := Vector2i(i, j)
			var c := _corner(wet, i, j)
			if c != 0:
				_water_cells.append([v, c, vertex_pick(v, Tiles.TERRAIN_VARIANTS), (i + j) % 2])
			var dc := _corner(under, i, j)
			if dc == 0:
				continue
			# A full deep tile takes its body from the nearest of its four cells to the shallows.
			var ring := 99
			var k := j * pw + i
			for kk in [k, k + 1, k + pw, k + pw + 1]:
				ring = mini(ring, maxi(dist[kk], 0))
			_deep_vertices.append([v, dc, vertex_pick(v, Tiles.TERRAIN_VARIANTS), ring])
	_paint_water()
	_refresh_spray()


## Spray (STYLE.md 13, art Stage 15): 1 px Salt white specks rising off the water just inside
## the foam line, 6 px over 1.5 s and fading; the count follows the length of the foam line.
func _build_spray() -> void:
	_spray = CPUParticles2D.new()
	_spray.name = "Spray"
	_spray.emitting = false
	_spray.lifetime = 1.5
	_spray.preprocess = 1.5
	_spray.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	_spray.direction = Vector2(0, -1)
	_spray.spread = 8.0
	_spray.gravity = Vector2.ZERO
	_spray.initial_velocity_min = 3.0
	_spray.initial_velocity_max = 5.0
	_spray.scale_amount_min = 1.0
	_spray.scale_amount_max = 1.0
	# Bright at birth and gone by the end of its rise: a 1 px speck is invisible at 25 %.
	_spray.color = Color(Palette.SALT_WHITE, 0.9)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	_spray.color_ramp = fade
	_spray.z_index = 5
	add_child(_spray)


func _refresh_spray() -> void:
	if _spray == null:
		return
	var pts := PackedVector2Array()
	for c in _foam_case:
		var bits: int = _foam_case[c]
		var at := cell_to_world(c)
		# just inside the foam, over the water, where a Salt white speck reads
		for i in 4:
			if bits & (1 << i):
				pts.append(at + Vector2(DIRS[i]) * 2.0)
	if pts.is_empty():
		_spray.emitting = false
		return
	_spray.emission_points = pts
	_spray.amount = clampi(pts.size() / 2, 4, 32)
	_spray.emitting = true


## Drips (STYLE.md 13): in the Streets and the Hall an occasional 1 px Sea pale drop falls
## down a wall face, about one every 4 s per room and more in a long one.
func _find_drips() -> void:
	_drip_points = PackedVector2Array()
	if theme != Tiles.Look.STREETS and theme != Tiles.Look.DEEP:
		return
	for y in range(1, template.height):
		for x in template.width:
			if not template.is_solid(x, y) and template.is_solid(x, y - 1) and not template.is_beyond(x, y - 1):
				_drip_points.append(cell_to_world(Vector2i(x, y - 1)) + Vector2(0, -6))


func _tick_drips(delta: float) -> void:
	if _drip_points.is_empty():
		return
	_drip_t += delta * (1.0 + float(_drip_points.size()) / 40.0)
	if _drip_t >= 4.0:
		_drip_t -= 4.0
		var p: Vector2 = _drip_points[_bubble_rng.randi() % _drip_points.size()]
		FX.drip(p + Vector2(_bubble_rng.randi_range(-6, 6), 0), self)


## Water tiles for the current animation tick: shallow in three frames, deep in two.
func _paint_water() -> void:
	var f3 := _tick % 3
	var f2 := (_tick / 2) % 2
	for e in _water_cells:
		var c: int = e[1]
		var col: int = c * Tiles.TERRAIN_VARIANTS + int(e[2])
		if c == 15 and int(e[3]) == 1:
			col = Tiles.TERRAIN_FILL  # the second shallow body, alternating as the cells did
		_water.set_cell(e[0], 0, Vector2i(col, f3))
	for e in _deep_vertices:
		var c: int = e[1]
		if c != 15:
			_deep.set_cell(e[0], 0, Vector2i(c * Tiles.TERRAIN_VARIANTS + int(e[2]), Tiles.WATER_EDGE_DEEP_ROW + f2))
			continue
		var d: int = e[3]
		var body := 0 if d <= 1 else 2 if d == 2 else 4 if d <= 4 else 6 if d == 5 else 8
		_deep.set_cell(e[0], 0, Vector2i(body + f2, Tiles.WATER_EDGE_BODY_ROW))


func _process(delta: float) -> void:
	# The void slides a few pixels with Tam: the rim is near, what stands beyond it is far.
	if _beyond != null:
		var tam := get_tree().get_first_node_in_group("player") as Node2D
		if tam != null:
			_beyond.position = ((to_local(tam.global_position) - size_px() * 0.5) * Scenery.PARALLAX).round()
	_tick_drips(delta)
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
