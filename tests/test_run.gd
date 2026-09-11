extends TestCase
## Run-layer logic: room graph, tide, templates, run state accounting.


func test_room_graph_is_deterministic() -> void:
	var a := RoomGraph.new(42, 8)
	var b := RoomGraph.new(42, 8)
	for d in 9:
		assert_eq(a.options_for(d), b.options_for(d), "depth %d" % d)


func test_room_graph_shape() -> void:
	var g := RoomGraph.new(7, 8)
	assert_eq(g.options_for(0), [RoomGraph.COMBAT])
	assert_eq(g.options_for(8), [RoomGraph.BOSS])
	assert_eq(g.options_for(99), [RoomGraph.BOSS])
	assert_true(RoomGraph.FOUNTAIN in g.options_for(7), "fountain offered before the boss")
	for d in range(1, 8):
		var opts: Array = g.options_for(d)
		assert_true(opts.size() >= 1 and opts.size() <= 2, "1-2 options at depth %d" % d)
		assert_true(not RoomGraph.BOSS in opts, "no boss before the end")
		if d < 3:
			assert_true(not RoomGraph.ELITE in opts, "no elite before depth 3")
		if d < 2:
			assert_true(not RoomGraph.SHOP in opts, "no merchant before depth 2")
	assert_true(RoomGraph.SHOP in g.options_for(4), "a merchant is guaranteed at depth 4")


func test_shop_template() -> void:
	var t := RoomTemplate.load_file("res://data/rooms/biome1/shop_01.txt")
	assert_eq(t.marker_cells("M").size(), 1, "one merchant")


func test_tide_levels() -> void:
	var t := TideSystem.new()
	assert_true(not t.is_flooded(0))
	t.room_entered()
	assert_true(t.is_flooded(0), "low ground floods after the first room")
	assert_true(not t.is_flooded(1))
	for i in 5:
		t.room_entered()
	assert_true(not t.is_flooded(1), "sand is dry through 6 rooms at full speed")
	t.room_entered()
	t.room_entered()
	assert_true(t.is_flooded(1), "sand is shallow by room 8")
	t.advance(300.0)
	assert_true(t.is_flooded(1), "sand is flooded on a 5-minute run")
	assert_true(not t.is_deep(1), "but is not deep yet")
	t.advance(400.0)
	assert_true(t.is_deep(1), "dawdling past 10 minutes drowns the sand")
	t.advance(100000.0)
	assert_near(t.level, TideSystem.MAX_LEVEL)
	assert_true(t.is_deep(1))


func test_templates_parse() -> void:
	var dir := "res://data/rooms/biome1/"
	var files := DirAccess.get_files_at(dir)
	assert_true(files.size() >= 8, "at least 8 biome-1 templates")
	for f in files:
		var t := RoomTemplate.load_file(dir + f)
		assert_eq(t.width, 40, f + " width")
		assert_eq(t.height, 23, f + " height (16:9 stretch)")
		assert_true(t.player_spawn.x >= 0, f + " has a player spawn")
		if not f.begins_with("boss"):
			assert_true(t.doors.size() >= 1, f + " has a door slot")
		if f.begins_with("flats") or f.begins_with("boss"):
			assert_true(t.enemy_spawns.size() >= 1, f + " has enemy spawns")
		assert_eq(t.height_at(0, 0), RoomTemplate.WALL_HEIGHT)
		assert_true(t.is_solid(0, 0))
		assert_true(not t.is_solid(t.player_spawn.x, t.player_spawn.y))


func test_hub_template() -> void:
	var t := RoomTemplate.load_file("res://data/rooms/hub.txt")
	assert_eq(t.marker_cells("X").size(), 1, "one descend marker")
	assert_true(t.marker_cells("h").size() >= 1, "lighthouse marker")


func test_run_result_conversion() -> void:
	var s := RunState.new()
	s.salt = 10
	s.pearls = 3
	assert_eq(s.result().pearls, 3, "killed: salt is lost")
	s.taken = true
	assert_eq(s.result().pearls, 8, "taken: half the salt converts")
	s.victory = true
	assert_eq(s.result().pearls, 13, "victory: half salt + 5")
