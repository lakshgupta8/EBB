class_name Tiles
extends RefCounted
## Tile indices into assets/sprites/tiles.png (mirrors TILE_NAMES in tools/gen_sprites.py)
## and a code-built TileSet with collision on the solid ones.

const TEXTURE := preload("res://assets/sprites/tiles.png")
const WATER_TEXTURE := preload("res://assets/sprites/water.png")
## The void beyond the walls (tools/gen_scenery.py): 3 rows by look (Scenery.Void), 3 variants.
const BEYOND_TEXTURE := preload("res://assets/sprites/beyond.png")
const SIZE := 16

## The water overlay atlas (tools/gen_water.py), 16 columns by 6 rows, coords (col, row):
## row 0 bodies: shallow A f0-2 (0-2), shallow B f0-2 (3-5), deep ring A f0-1 (6-7),
## deep ring B f0-1 (8-9), deep f0-1 (10-11), abyss ring f0-1 (12-13), abyss f0-1 (14-15).
## rows 1-3: foam by dry-neighbour bits (N=1 E=2 S=4 W=8), one row per frame.
## row 4: wet band by flooded-neighbour bits. row 5: tide line by higher-floor bits.
const WATER_COLS := 16
const WATER_ROWS := 6
const WATER_FOAM_ROW := 1
const WATER_WET_ROW := 4
const WATER_LINE_ROW := 5

enum { SAND, SAND2, WALL, WALL2, WATER, WATER2, DEEP, LOW, RAISED, DOOR, DOOR_OPEN, ROCK, FOAM, FOAM2,
	COBBLE, COBBLE2, RUIN, RUIN2, MOSS, FLAG, BASALT, BASALT2, HALLWALL, HALLWALL2, CHANNEL, DAIS,
	DECK, DECK2, HULL, HULL2, SILT, QUAY,
	HUB_SAND, HUB_SAND2, HUB_WALL, HUB_WALL2, HUB_LOW, HUB_RAISED,
	SHADE_S, SHADE_W, SHADE_E, SHADE_SW, SHADE_SE, SHADE_WE, SHADE_SWE, COUNT }

const SOLID := [WALL, WALL2, DOOR, ROCK, RUIN, RUIN2, HALLWALL, HALLWALL2, HULL, HULL2, HUB_WALL, HUB_WALL2]
## Wall tiles come in pairs: the face (a wall with floor to its south, seen from the front)
## and the top (every other wall cell). room_template.tile_at picks by neighbour.
## Shade tiles are the walls' cast shadow on the floor (STYLE.md 4): a 3 px band south of a
## wall, 1 px bands east and west, drawn on an overlay layer by room.gd.
## Themes: the flats (sand and wet rock), the drowned streets (cobbles and brick), the deep
## hall (basalt), the sunken harbour (deck planks, tarred hulls, silt and quay).
enum Look { FLATS, STREETS, DEEP, HARBOUR, HUB }

static var _tileset: TileSet
static var _water_tileset: TileSet
static var _beyond_tileset: TileSet


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


## The overlay atlas as a TileSet with no physics: the room's water, foam and edge layers.
static func water_tileset() -> TileSet:
	if _water_tileset:
		return _water_tileset
	var ts := TileSet.new()
	ts.tile_size = Vector2i(SIZE, SIZE)
	var src := TileSetAtlasSource.new()
	src.texture = WATER_TEXTURE
	src.texture_region_size = Vector2i(SIZE, SIZE)
	ts.add_source(src, 0)
	for r in WATER_ROWS:
		for c in WATER_COLS:
			src.create_tile(Vector2i(c, r))
	_water_tileset = ts
	return ts


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
