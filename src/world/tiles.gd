class_name Tiles
extends RefCounted
## Tile indices into assets/sprites/tiles.png (mirrors TILE_NAMES in tools/gen_sprites.py)
## and a code-built TileSet with collision on the solid ones.

const TEXTURE := preload("res://assets/sprites/tiles.png")
## The void beyond the walls (tools/gen_scenery.py): 3 rows by look (Scenery.Void), 3 variants.
const BEYOND_TEXTURE := preload("res://assets/sprites/beyond.png")
const SIZE := 16

## The water atlas (tools/gen_water.py) is now only the source tools/gen_terrain.py draws the
## dual-grid water from (water_edge.png, map Stage 03).
enum { SAND, SAND2, WALL, WALL2, WATER, WATER2, DEEP, LOW, RAISED, DOOR, DOOR_OPEN, ROCK, FOAM, FOAM2,
	COBBLE, COBBLE2, RUIN, RUIN2, MOSS, FLAG, BASALT, BASALT2, HALLWALL, HALLWALL2, CHANNEL, DAIS,
	DECK, DECK2, HULL, HULL2, SILT, QUAY,
	HUB_SAND, HUB_SAND2, HUB_WALL, HUB_WALL2, HUB_LOW, HUB_RAISED,
	SHADE_S, SHADE_W, SHADE_E, SHADE_SW, SHADE_SE, SHADE_WE, SHADE_SWE, COUNT }

const SOLID := [WALL, WALL2, DOOR, ROCK, RUIN, RUIN2, HALLWALL, HALLWALL2, HULL, HULL2, HUB_WALL, HUB_WALL2]
## Wall tiles come in pairs: the face (a wall with floor to its south, seen from the front)
## and the top (every other wall cell). room_template.tile_at picks by neighbour.
## The shade tiles (38-44) are no longer drawn: since map Stage 03 the terrain tiles carry
## each edge's shadow. They keep their indices so the enum and the strip stay in step.
## Themes: the flats (sand and wet rock), the drowned streets (cobbles and brick), the deep
## hall (basalt), the sunken harbour (deck planks, tarred hulls, silt and quay).
enum Look { FLATS, STREETS, DEEP, HARBOUR, HUB }

static var _tileset: TileSet
static var _beyond_tileset: TileSet
static var _terrain_tileset: TileSet
static var _water_edge_tileset: TileSet
static var _cells_tileset: TileSet
static var _patch_tileset: TileSet

## The dual-grid ground (map Stage 03, tools/gen_terrain.py): tiles sit on cell corners and are
## picked by which of the four cells round a corner hold the layer (case bits TL=1 TR=2 BL=4
## BR=8). terrain.png has four rows per look (low, floor, raised, wall); column case * 3 +
## variant, then three full fills. water_edge.png: shallow frames in rows 0-2, deep in 3-4,
## the full deep bodies in row 5.
const TERRAIN_TEXTURE := preload("res://assets/sprites/terrain.png")
const WATER_EDGE_TEXTURE := preload("res://assets/sprites/water_edge.png")
const TERRAIN_VARIANTS := 3
const TERRAIN_FILL := 48
const TERRAIN_LAYERS := 4
## Ground patches (map Stage 04): three overlay rows per look, laid out as terrain.png.
const PATCH_TEXTURE := preload("res://assets/sprites/patch.png")
const WATER_EDGE_DEEP_ROW := 3
const WATER_EDGE_BODY_ROW := 5


## The void atlas as a TileSet with no physics: the room's Beyond layer (art Stage 12).
static func beyond_tileset() -> TileSet:
	if _beyond_tileset:
		return _beyond_tileset
	var ts := TileSet.new()
	ts.tile_size = Vector2i(SIZE, SIZE)
	var src := TileSetAtlasSource.new()
	src.texture = BEYOND_TEXTURE
	src.texture_region_size = Vector2i(SIZE, SIZE)
	ts.add_source(src, 0)
	for r in 3:
		for c in Scenery.VOID_COLS:
			src.create_tile(Vector2i(c, r))
	_beyond_tileset = ts
	return ts


## An atlas as a TileSet with no physics, every cell a tile.
static func _visual(tex: Texture2D) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(SIZE, SIZE)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(SIZE, SIZE)
	ts.add_source(src, 0)
	for r in tex.get_height() / SIZE:
		for c in tex.get_width() / SIZE:
			src.create_tile(Vector2i(c, r))
	return ts


static func terrain_tileset() -> TileSet:
	if not _terrain_tileset:
		_terrain_tileset = _visual(TERRAIN_TEXTURE)
	return _terrain_tileset


static func patch_tileset() -> TileSet:
	if not _patch_tileset:
		_patch_tileset = _visual(PATCH_TEXTURE)
	return _patch_tileset


static func water_edge_tileset() -> TileSet:
	if not _water_edge_tileset:
		_water_edge_tileset = _visual(WATER_EDGE_TEXTURE)
	return _water_edge_tileset


## tiles.png with no collision: the room draws its rocks and doors from it over the terrain.
static func cells_tileset() -> TileSet:
	if not _cells_tileset:
		_cells_tileset = _visual(TEXTURE)
	return _cells_tileset


static func tileset() -> TileSet:
	if _tileset:
		return _tileset
	var ts := TileSet.new()
	ts.tile_size = Vector2i(SIZE, SIZE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)  # "world"
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = TEXTURE
	src.texture_region_size = Vector2i(SIZE, SIZE)
	var half := SIZE / 2.0
	var box := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)
	])
	# The source must belong to the TileSet before tile physics data exists.
	ts.add_source(src, 0)
	for i in COUNT:
		src.create_tile(Vector2i(i, 0))
		if i in SOLID:
			var td := src.get_tile_data(Vector2i(i, 0), 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, box)
	_tileset = ts
	return ts


static func coords(index: int) -> Vector2i:
	return Vector2i(index, 0)
