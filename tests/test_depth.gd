extends TestCase
## Depth (art Stage 12): the inside of a wall mass is the void, far scenery stands only on the
## void, foreground silhouettes keep to the south rim away from doors, and decor follows the
## rules in STYLE.md 8.

const BLOCK := """
################
################
################
###..........###
###.######...###
###.######...###
###.######...###
###.######...###
###.######...###
###..........###
###..........###
###..........###
###...P......###
######D#########
"""

const SPECK := """
##########
#........#
#..####..#
#..####..#
#..####..#
#........#
#...P....#
####D#####
"""


static func _open(name: String, w: int = 40, h: int = 23, pool: bool = false) -> RoomTemplate:
	var rows: PackedStringArray = []
	for y in h:
		var row := ""
		for x in w:
			var wall := x == 0 or y == 0 or x == w - 1 or y == h - 1
			var ch := "#" if wall else "."
			if pool and x >= 10 and x <= 20 and y >= 8 and y <= 12:
				ch = "_"
			if x == 20 and y == 0:
				ch = "D"
			if x == 0 and y == 12:
				ch = "D"
			if x == 5 and y == 18:
				ch = "P"
			row += ch
		rows.append(row)
	return RoomTemplate.parse("\n".join(rows), name)


func _rng(seed: int = 7) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


func test_the_inside_of_a_wall_mass_is_beyond() -> void:
	var t := RoomTemplate.parse(BLOCK, "block")
	assert_true(t.is_beyond(5, 0), "three cells from the floor: the void")
	assert_true(t.is_beyond(0, 7), "and in the west mass")
	assert_true(not t.is_beyond(1, 7), "two cells from the floor: the rim is two thick (map Stage 06)")
	assert_true(not t.is_beyond(2, 7), "the rim's inner ring")
	assert_true(not t.is_beyond(6, 6), "a speck of void inside an outcrop stays rock")
	assert_true(not t.is_beyond(4, 4), "the outcrop's edge touches floor")
	assert_true(not t.is_beyond(3, 3), "floor is never beyond")
	assert_eq(Scenery.beyond_cells(t).size(), 42, "the outer mass only")


func test_the_ground_leaves_beyond_cells_to_the_void() -> void:
	var r := Room.new()
	r.build(RoomTemplate.parse(BLOCK, "block"))
	assert_eq(r._ground.get_cell_source_id(Vector2i(5, 0)), -1, "no ground tile inside the mass")
	assert_true(r._ground.get_cell_source_id(Vector2i(1, 7)) != -1, "the rim keeps its wall tile")
	var void_layer: TileMapLayer = r._beyond.get_node("Void")
	assert_eq(void_layer.get_cell_source_id(Vector2i(5, 0)), 0, "the void is painted there")
	assert_eq(void_layer.get_cell_atlas_coords(Vector2i(5, 0)).y, Scenery.Void.SEA, "the Flats void is the night sea")
	assert_eq(void_layer.get_cell_source_id(Vector2i(-1, -1)), 0, "and one cell past the room")
	assert_eq(void_layer.get_cell_source_id(Vector2i(3, 3)), -1, "never under floor")
	r.free()


func test_scenery_stands_only_on_beyond_cells() -> void:
	# The old block: a 4x3 outcrop, all of it within two cells of the floor, so no void at all.
	var small := RoomTemplate.parse(SPECK, "speck")
	assert_eq(Scenery.beyond_cells(small).size(), 0, "no void in a small outcrop")
	assert_eq(Scenery.place_scenery(small, Tiles.Look.FLATS, _rng()).size(), 0, "nothing stands on rock")
	# a 12x8 mass: plenty of room
	var rows: PackedStringArray = []
	for y in 23:
		var row := ""
		for x in 40:
			var mass := x >= 20 and x <= 33 and y >= 5 and y <= 14
			row += "#" if (x == 0 or y == 0 or x == 39 or y == 22 or mass) else "."
		rows.append(row)
	var t := RoomTemplate.parse("\n".join(rows), "flats_mass")
	for look in [Tiles.Look.FLATS, Tiles.Look.STREETS, Tiles.Look.DEEP, Tiles.Look.HUB]:
		var placed := Scenery.place_scenery(t, look, _rng(3))
		assert_true(placed.size() >= 1, "something stands beyond the mass")
		var seen: Dictionary = {}
		for p in placed:
			for c in p.cells:
				assert_true(t.is_beyond(c.x, c.y), "every covered cell is beyond")
				assert_true(not seen.has(c), "pieces never overlap")
				seen[c] = true


func test_foreground_keeps_to_the_south_rim_away_from_doors() -> void:
	var t := _open("flats_01")
	# a south door for the test
	t.rows[22] = t.rows[22].substr(0, 19) + "D" + t.rows[22].substr(20)
	t.doors.append(Vector2i(19, 22))
	for seed in range(1, 6):
		var placed := Scenery.place_foreground(t, Tiles.Look.FLATS, _rng(seed))
		assert_true(placed.size() >= Scenery.FORE_MIN and placed.size() <= Scenery.FORE_MAX, "two or three pieces")
		for p in placed:
			assert_eq(p.cell.y, 22, "on the south rim")
			assert_true(absi(p.cell.x - 19) > Scenery.DOOR_CLEAR, "clear of the door")
			for q in placed:
				assert_true(q == p or absi(q.cell.x - p.cell.x) >= Scenery.FORE_GAP, "pieces stand apart")


func test_decor_keeps_out_of_doorways_and_off_stone() -> void:
	var t := _open("flats_01", 40, 23, true)
	var plan := DecorRules.plan(t, Tiles.Look.FLATS, _rng())
	assert_true(plan.size() >= 10 and plan.size() <= 18, "a fighting room takes 10-18 pieces")
	for d in plan:
		var c: Vector2i = d.cell
		var ch := t.char_at(c.x, c.y)
		assert_true(ch == "." or ch == "_", "only on floor or low ground")
		for door in t.doors:
			assert_true(maxi(absi(door.x - c.x), absi(door.y - c.y)) > DecorRules.DOOR_CLEAR, "never before a door")
		assert_true(maxi(absi(t.player_spawn.x - c.x), absi(t.player_spawn.y - c.y)) > DecorRules.MARKER_CLEAR, "never on the spawn")
		if int(d.kind) == 1:
			assert_true(DecorRules.allowed(t, c, DecorRules.Rule.BY_WATER), "kelp only by water")
		if int(d.kind) == 4:
			assert_true(t.height_at(c.x, c.y) == 0, "puddles only on low ground")


func test_room_type_sets_the_density() -> void:
	assert_true(DecorRules.plan(_open("fountain_01"), Tiles.Look.FLATS, _rng()).size() <= 9, "fountain rooms are sparse")
	assert_true(DecorRules.plan(_open("altar_01"), Tiles.Look.STREETS, _rng()).size() <= 9, "altar rooms are sparse")
	var treasure := DecorRules.plan(_open("treasure_01"), Tiles.Look.DEEP, _rng())
	assert_true(treasure.size() >= 16, "treasure rooms are cluttered")
	var left := 0
	for d in treasure:
		if int(d.cell.x) * 2 < 40:
			left += 1
	assert_true(left <= treasure.size() / 4 or left >= treasure.size() * 3 / 4, "and on one side")
	assert_true(DecorRules.plan(_open("boss_01"), Tiles.Look.FLATS, _rng()).size() <= 8, "the arena is nearly bare")


func test_hall_candles_sit_in_corners() -> void:
	var rows: PackedStringArray = []
	for y in 23:
		var row := ""
		for x in 40:
			var pillar := (x == 6 or x == 7) and (y == 6 or y == 7)
			row += "#" if (x == 0 or y == 0 or x == 39 or y == 22 or pillar) else ("P" if x == 20 and y == 11 else ".")
		rows.append(row)
	var t := RoomTemplate.parse("\n".join(rows), "hall_01")
	var candles := 0
	for seed in range(1, 8):
		for d in DecorRules.plan(t, Tiles.Look.DEEP, _rng(seed)):
			if int(d.kind) == 0:
				candles += 1
				assert_true(DecorRules.allowed(t, d.cell, DecorRules.Rule.CORNER), "a candle drift needs two walls")
	assert_true(candles > 0, "some room got candles")
