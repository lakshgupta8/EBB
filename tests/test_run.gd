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


func test_tide_pause_holds_the_level() -> void:
	var t := TideSystem.new()
	t.pause(5.0)
	t.advance(4.0)
	assert_near(t.level, 0.0)
	t.advance(2.0)
	assert_true(t.level > 0.0, "rises again after the hold")


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
	for dir in ["res://data/rooms/biome1/", "res://data/rooms/biome2/", "res://data/rooms/biome3/"]:
		_check_templates(dir)


func _check_templates(dir: String) -> void:
	var files := DirAccess.get_files_at(dir)
	assert_true(files.size() >= 8, "at least 8 templates in " + dir)
	for f in files:
		var t := RoomTemplate.load_file(dir + f)
		assert_eq(t.width, 40, f + " width")
		assert_eq(t.height, 23, f + " height (16:9 stretch)")
		assert_true(t.player_spawn.x >= 0, f + " has a player spawn")
		assert_true(t.doors.size() >= 1, f + " has a door slot")
		if f.begins_with("flats") or f.begins_with("streets") or f.begins_with("hall") or f.begins_with("boss") or f.begins_with("echo"):
			assert_true(t.enemy_spawns.size() >= 1, f + " has enemy spawns")
		if f.begins_with("echo"):
			assert_eq(t.marker_cells("E").size(), 1, f + " has one cage")
		if f.begins_with("boss"):
			assert_eq(t.doors.size(), 1, f + " has exactly one way down")
		assert_eq(t.height_at(0, 0), RoomTemplate.WALL_HEIGHT)
		assert_true(t.is_solid(0, 0))
		assert_true(not t.is_solid(t.player_spawn.x, t.player_spawn.y))


func test_hub_template() -> void:
	var t := RoomTemplate.load_file("res://data/rooms/hub.txt")
	assert_eq(t.marker_cells("X").size(), 1, "one descend marker")
	assert_true(t.marker_cells("h").size() >= 1, "lighthouse marker")
	for m in ["O", "B", "W", "C", "N"]:
		assert_eq(t.marker_cells(m).size(), 1, "one spot for " + m)


func test_street_tiles_are_themed() -> void:
	var t := RoomTemplate.load_file("res://data/rooms/biome2/streets_01.txt")
	assert_eq(t.tile_at(0, 0, Tiles.Look.STREETS) in [Tiles.RUIN, Tiles.RUIN2], true, "ruin walls")
	assert_eq(t.tile_at(0, 0, Tiles.Look.FLATS) in [Tiles.WALL, Tiles.WALL2], true, "flats walls")
	assert_true(Tiles.RUIN in Tiles.SOLID and Tiles.COBBLE not in Tiles.SOLID)
	assert_eq(t.tile_at(0, 0, Tiles.Look.DEEP) in [Tiles.HALLWALL, Tiles.HALLWALL2], true, "hall walls")
	assert_eq(Tiles.COUNT * 16, Tiles.TEXTURE.get_width(), "tile strip matches the enum")


func test_room_graph_places_echo_cages_and_charted_rooms() -> void:
	var g := RoomGraph.new(11, 8, [3], RoomGraph.TREASURE)
	assert_true(RoomGraph.ECHO in g.options_for(3), "echo cage at depth 3")
	assert_true(RoomGraph.TREASURE in g.options_for(2), "charted treasure at depth 2")
	var g2 := RoomGraph.new(11, 9, [3, 6])
	assert_true(RoomGraph.ECHO in g2.options_for(3) and RoomGraph.ECHO in g2.options_for(6), "two cages")
	var g3 := RoomGraph.new(11, 8)
	for d in 9:
		assert_true(not RoomGraph.ECHO in g3.options_for(d), "no cages when everyone is home")


func test_run_result_conversion() -> void:
	var s := RunState.new()
	s.salt = 10
	s.pearls = 3
	assert_eq(s.result().pearls, 3, "killed: salt is lost")
	s.taken = true
	assert_eq(s.result().pearls, 8, "taken: half the salt converts")
	s.victory = true
	assert_eq(s.result().pearls, 13, "victory: half salt + 5")
	s.victory = false
	s.taken = false
	s.bargain = true
	assert_eq(s.result().pearls, 8, "sea's bargain: killed still converts half")


## Every open cell in every template must be walkable from the player spawn (no
## diagonal-only gaps, no sealed chest rooms). Pure flood fill on the template.
func test_templates_are_connected() -> void:
	for dir in ["res://data/rooms/biome1/", "res://data/rooms/biome2/", "res://data/rooms/biome3/"]:
		for f in DirAccess.get_files_at(dir):
			var t := RoomTemplate.load_file(dir + f)
			var seen := {}
			var stack: Array = [t.player_spawn]
			seen[t.player_spawn] = true
			while stack.size() > 0:
				var c: Vector2i = stack.pop_back()
				for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + off
					if seen.has(n) or t.is_solid(n.x, n.y) or t.char_at(n.x, n.y) == "D":
						continue
					seen[n] = true
					stack.append(n)
			var unreachable := 0
			for y in t.height:
				for x in t.width:
					if not t.is_solid(x, y) and t.char_at(x, y) != "D" and not seen.has(Vector2i(x, y)):
						unreachable += 1
			assert_eq(unreachable, 0, "%s has %d cells you cannot walk to" % [f, unreachable])
			for d in t.doors:
				var ok := false
				for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if seen.has(d + off):
						ok = true
				assert_true(ok, "%s door %s is reachable" % [f, d])
