extends TestCase
## The water overlay picks its cells from the height map (art Stage 10): foam only on the
## shore side, the wet band on the dry side, the tide line round dry low ground, deep water
## dithered where it meets shallow water, and the arch that matches the tide.

const POOL := """
############
#..........#
#..____....#
#._______..#
#.________.#
#.________=#
#..______==#
#...____...#
#..........#
############
"""


func _pool(tide: float) -> Room:
	var r := Room.new()
	r.build(RoomTemplate.parse(POOL, "pool"))
	r.set_tide(tide)
	return r


func test_low_ground_floods_first_with_foam_on_the_shore_side() -> void:
	var r := _pool(0.5)
	# (3, 2) is low ground with floor to the north and west: foam on those two edges only.
	assert_eq(int(r._foam_case.get(Vector2i(3, 2), 0)), 1 | 8, "foam faces the dry north and west")
	# (4, 4) is low ground surrounded by low ground: a body, no foam.
	assert_true(r._body.has(Vector2i(4, 4)), "the middle of the basin is water")
	assert_true(not r._foam_case.has(Vector2i(4, 4)), "no foam away from the shore")
	assert_true(int(r._body[Vector2i(4, 4)]) <= Room.Body.SHALLOW_B, "half a level of water is shallow")
	# The floor north of the basin carries the wet band on its south edge.
	assert_eq(r._edge.get_cell_atlas_coords(Vector2i(3, 1)), Vector2i(4, Tiles.WATER_WET_ROW), "wet band faces the water")
	assert_true(not r._body.has(Vector2i(3, 1)), "the floor is dry")
	r.free()


func test_dry_low_ground_keeps_a_tide_line() -> void:
	var r := _pool(0.0)
	assert_true(r._body.is_empty(), "nothing floods at tide 0")
	assert_eq(r._edge.get_cell_atlas_coords(Vector2i(3, 2)), Vector2i(1 | 8, Tiles.WATER_LINE_ROW), "the line faces the floor")
	assert_eq(r._edge.get_cell_atlas_coords(Vector2i(4, 4)), Vector2i(-1, -1), "no line inside the basin")
	r.free()


func test_deep_water_dithers_toward_shallow() -> void:
	var r := _pool(1.5)
	# The basin is deep, the floor shallow: the basin's rim is ring A, one in is ring B.
	assert_eq(int(r._body[Vector2i(3, 2)]), Room.Body.RING_A, "the rim of the deep pool is the half dither")
	assert_eq(int(r._body[Vector2i(4, 3)]), Room.Body.RING_B, "one tile in is the quarter dither")
	assert_eq(int(r._body[Vector2i(4, 4)]), Room.Body.DEEP, "three tiles from anything shallow is the deep body")
	assert_true(int(r._body[Vector2i(3, 1)]) <= Room.Body.SHALLOW_B, "the floor is shallow")
	assert_true(not r._foam_case.has(Vector2i(3, 2)), "no foam at the shallow-to-deep boundary")
	# The raised corner (10, 5) stays dry: foam on the water beside it.
	assert_eq(int(r._foam_case.get(Vector2i(9, 5), 0)) & 2, 2, "foam faces the dry raised stone")
	assert_true(r.is_deep_at(r.cell_to_world(Vector2i(4, 4))))
	assert_true(not r.is_deep_at(r.cell_to_world(Vector2i(3, 1))))
	r.free()


func test_door_frames_follow_the_tide() -> void:
	assert_eq(Door.frame_for(false, false, false), Door.Frame.SHUT)
	assert_eq(Door.frame_for(false, true, false), Door.Frame.OPEN)
	assert_eq(Door.frame_for(false, false, true), Door.Frame.WATER_CLOSED)
	assert_eq(Door.frame_for(false, true, true), Door.Frame.FLOODED)
	assert_eq(Door.frame_for(true, false, false), Door.Frame.WET_SHUT)
	assert_eq(Door.frame_for(true, true, true), Door.Frame.WET_OPEN)
