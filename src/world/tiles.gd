class_name Tiles
extends RefCounted
## Tile indices into assets/sprites/tiles.png (mirrors TILE_NAMES in tools/gen_sprites.py)
## and a code-built TileSet with collision on the solid ones.

const TEXTURE := preload("res://assets/sprites/tiles.png")
const SIZE := 16

enum { SAND, SAND2, WALL, WALL2, WATER, WATER2, DEEP, LOW, RAISED, DOOR, DOOR_OPEN, ROCK, FOAM, FOAM2,
	COBBLE, COBBLE2, RUIN, RUIN2, MOSS, FLAG, COUNT }

const SOLID := [WALL, WALL2, DOOR, ROCK, RUIN, RUIN2]
## Themes: 0 = the flats (sand and wet rock), 1 = the drowned streets (cobbles and brick).
enum Look { FLATS, STREETS }

static var _tileset: TileSet


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
