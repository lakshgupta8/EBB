extends TestCase
## Ground at scale (map Stage 04, STYLE.md 22): every room's floor is broken up by patches that
## have a reason to be where they are, and decor gathers in clusters.

const DIRS := {"res://data/rooms/biome1/": Tiles.Look.FLATS, "res://data/rooms/harbour/": Tiles.Look.HARBOUR,
	"res://data/rooms/biome2/": Tiles.Look.STREETS, "res://data/rooms/biome3/": Tiles.Look.DEEP,
	"res://data/rooms/test/": Tiles.Look.FLATS}


func test_no_room_is_more_than_half_bare_floor() -> void:
	for dir in DIRS:
		for f in DirAccess.get_files_at(dir):
			var t := RoomTemplate.load_file(dir + f)
			var p := GroundPatches.plan(t, DIRS[dir], 7)
			assert_true(GroundPatches.base_share(t, p) <= GroundPatches.MAX_BASE + 0.001,
				"%s%s is %.2f bare" % [dir.get_file(), f, GroundPatches.base_share(t, p)])


func test_patches_have_reasons() -> void:
	var t := RoomTemplate.load_file("res://data/rooms/test/flats_L_test.txt")
	var p := GroundPatches.plan(t, Tiles.Look.FLATS, 7)
	# Flats patch 0 is wet ground: every floor cell beside low ground carries it.
	for y in t.height:
		for x in t.width:
			if not GroundPatches.is_floor(t, x, y):
				continue
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + off
				if not t.is_solid(n.x, n.y) and t.height_at(n.x, n.y) == 0:
					assert_eq(int(p.get(Vector2i(x, y), -1)), 0, "wet beside low ground at %d,%d" % [x, y])
	# Streets patch 0 is the worn route: the spawn stands on it.
	var s := RoomTemplate.load_file("res://data/rooms/biome2/streets_02.txt")
	var sp := GroundPatches.plan(s, Tiles.Look.STREETS, 7)
	assert_eq(int(sp.get(s.player_spawn, -1)), 0, "the route starts where the keeper does")
	assert_eq(GroundPatches.plan(t, Tiles.Look.FLATS, 7), p, "the same seed lays the same ground")


func test_decor_gathers_in_clusters() -> void:
	for f in ["flats_01", "flats_05", "flats_09"]:
		var t := RoomTemplate.load_file("res://data/rooms/biome1/%s.txt" % f)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var plan := DecorRules.plan(t, Tiles.Look.FLATS, rng)
		var alone := 0
		for d in plan:
			var near := 0
			for e in plan:
				if e != d and maxi(absi(e.cell.x - d.cell.x), absi(e.cell.y - d.cell.y)) <= DecorRules.CLUSTER_RADIUS * 2:
					near += 1
			if near == 0:
				alone += 1
		assert_true(alone * 5 <= plan.size(), "%s: %d of %d pieces stand alone" % [f, alone, plan.size()])


func test_large_rooms_take_decor_by_area() -> void:
	var t := RoomTemplate.load_file("res://data/rooms/test/flats_L_test.txt")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	assert_true(DecorRules.plan(t, Tiles.Look.FLATS, rng).size() >= 25, "an L room takes more than a screen's worth")


func test_decals_lie_on_clear_bare_floor() -> void:
	var t := RoomTemplate.load_file("res://data/rooms/test/flats_L_test.txt")
	var p := GroundPatches.plan(t, Tiles.Look.FLATS, 7)
	var d := GroundPatches.decals(t, p, 7)
	assert_true(d.size() >= 2, "an L room takes a few")
	var blocked := DecorRules.blocked_cells(t)
	for e in d:
		for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var c: Vector2i = e.cell + off
			assert_true(GroundPatches.is_floor(t, c.x, c.y) and not p.has(c) and not blocked.has(c), "clear bare floor at %s" % c)
