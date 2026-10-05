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
	# The fork: halfway down, two doors, the second a fight and the wet one.
	var fork := g.fork_depth()
	assert_eq(fork, 4)
	assert_eq(g.options_for(fork).size(), 2, "two doors at the fork")
	assert_true(g.options_for(fork)[1] in [RoomGraph.COMBAT, RoomGraph.ELITE], "the wet way is a fight")
	assert_true(g.is_wet(fork, 1) and not g.is_wet(fork, 0), "only the second door is wet")
	assert_true(not g.is_wet(fork + 1, 1), "no wet mark elsewhere")
	for t in [RoomGraph.CHALLENGE, RoomGraph.VAULT, RoomGraph.DIVE]:
		assert_true(RoomGraph.NAMES.has(t) and RoomGraph.ICON.has(t), "new room types are named and signed")


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
	for dir in ["res://data/rooms/biome1/", "res://data/rooms/harbour/", "res://data/rooms/biome2/", "res://data/rooms/biome3/"]:
		_check_templates(dir)


func _check_templates(dir: String) -> void:
	var files := DirAccess.get_files_at(dir)
	assert_true(files.size() >= 18, "at least 18 templates in " + dir)
	# Every room type the graph can offer has a template here (the harbour and the hall once
	# had no echo room: Pell's and Aldous's cages came up as a black screen).
	for prefix in ["fountain", "shop", "altar", "treasure", "boss", "echo", "challenge", "vault", "dive"]:
		var found := false
		for f in files:
			if f.begins_with(prefix):
				found = true
		assert_true(found, "%s has a %s template" % [dir, prefix])
	for f in files:
		var t := RoomTemplate.load_file(dir + f)
		# STYLE.md 22: S is one screen (40x23, the 16:9 stretch), L is two by two (80x46).
		assert_true(t.width >= 40 and t.width <= 80, f + " width %d in 40-80" % t.width)
		assert_true(t.height >= 23 and t.height <= 46, f + " height %d in 23-46" % t.height)
		assert_true(t.player_spawn.x >= 0, f + " has a player spawn")
		assert_true(t.doors.size() >= 1, f + " has a door slot")
		if f.begins_with("flats") or f.begins_with("harbour") or f.begins_with("streets") or f.begins_with("hall") or f.begins_with("boss") or f.begins_with("echo"):
			assert_true(t.enemy_spawns.size() >= 1, f + " has enemy spawns")
		if f.begins_with("echo"):
			assert_eq(t.marker_cells("E").size(), 1, f + " has one cage")
		if f.begins_with("challenge"):
			assert_true(t.enemy_spawns.size() >= 4 and t.marker_cells("T").size() >= 1, f + " has spawns and chests")
		if f.begins_with("vault"):
			assert_eq(t.marker_cells("T").size(), 1, f + " has one vault")
		if f.begins_with("dive"):
			assert_true(t.marker_cells("A").size() == 1 and t.marker_cells("T").size() == 1, f + " has an altar and a chest")
		if f.begins_with("boss"):
			assert_eq(t.doors.size(), 1, f + " has exactly one way down")
		assert_eq(t.height_at(0, 0), RoomTemplate.WALL_HEIGHT)
		assert_true(t.is_solid(0, 0))
		assert_true(not t.is_solid(t.player_spawn.x, t.player_spawn.y))


## Every biome carries everything the run needs, and the tide adds up the same way in each.
func test_biome_table() -> void:
	var ids := {}
	assert_eq(Run.BIOMES.size(), 4, "four biomes")
	for b in Run.BIOMES:
		assert_true(not ids.has(b.id), "unique biome id " + str(b.id))
		ids[b.id] = true
		assert_true(DirAccess.dir_exists_absolute(b.dir), "rooms for " + str(b.id))
		for k in ["name", "length", "theme", "boss", "boss_name", "stir", "echoes", "intro", "music", "place",
				"whisper", "boss_whisper", "boss_sfx", "tint", "won", "wet", "elite", "elite_name", "boss_music"]:
			assert_true(b.has(k), "%s has %s" % [b.id, k])
		assert_true(b.elite is PackedScene and str(b.elite_name) != "", "a named elite for " + str(b.id))
		assert_true(Story.WHISPERS.has(b.whisper) and Story.WHISPERS.has(b.boss_whisper), "whispers for " + str(b.id))
		var found := false
		for p in Codex.PLACES:
			if p.id == b.place:
				found = true
		assert_true(found, "codex place for " + str(b.id))
		var tide := TideSystem.new()
		tide.room_step = 1.44 / float(b.length + 1)
		for i in b.length + 1:
			tide.room_entered()
		assert_near(tide.level, 1.44, 0.01)
	assert_eq(Run.BIOMES[1].id, "harbour", "the harbour sits between the flats and the streets")
	# Every whisper the run asks for by name has to exist, including the built-up ones.
	for t in range(1, Run.TIERS.size() + 1):
		assert_true(Story.WHISPERS.has("tide_%d" % t), "a whisper for spring tide %d" % t)
	for k in ["cage", "death", "taken", "challenge", "dive", "netted", "choir", "harbour_ships", "harbour_hands",
			"page", "glass", "choir_spared", "shortcut", "launch"]:
		assert_true(Story.WHISPERS.has(k), "the run asks for the whisper " + k)
	# Every cage echo the biomes name is someone the rock knows.
	for b in Run.BIOMES:
		for id in b.echoes:
			assert_true(id in Story.ECHO_IDS and Run.ECHOES.has(id) and Prop.ECHO_FRAME.has(id), "echo " + str(id))


func test_hub_template() -> void:
	var t := RoomTemplate.load_file("res://data/rooms/hub.txt")
	assert_eq(t.marker_cells("X").size(), 1, "one descend marker")
	assert_true(t.marker_cells("h").size() >= 1, "lighthouse marker")
	for m in ["O", "B", "W", "C", "N", "K", "S", "I", "L", "V", "Y"]:
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


func test_run_state_survives_json() -> void:
	var s := RunState.new()
	s.seed = 987654321
	s.biome = 1
	s.depth = 4
	s.depth_total = 13
	s.rooms_cleared = 12
	s.kills = 40
	s.salt = 55
	s.pearls = 7
	s.time = 512.5
	s.bargain = true
	s.still_water = true
	s.tide.level = 1.37
	s.tide.rate_mult = 0.75
	s.tidemarks = ["salt_edge", "brine_hp", "deep_slow"]
	s.echoes = ["wren"]
	s.keys = 2
	s.ended = true
	var text := JSON.stringify(s.to_dict())
	var back := RunState.new()
	back.from_dict(JSON.parse_string(text))
	for k in RunState.SAVED:
		assert_eq(back.get(k), s.get(k), k)
	assert_true(typeof(back.depth) == TYPE_INT, "ints come back as ints")
	assert_near(back.tide.level, 1.37)
	assert_near(back.tide.rate_mult, 0.75)
	assert_eq(back.tidemarks, ["salt_edge", "brine_hp", "deep_slow"], "tidemarks keep their order")
	assert_eq(back.echoes, ["wren"])
	assert_true(not back.ended, "a rested night is not over")


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
	for dir in ["res://data/rooms/biome1/", "res://data/rooms/harbour/", "res://data/rooms/biome2/", "res://data/rooms/biome3/",
			"res://data/rooms/test/"]:
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


func test_spawn_cells_never_stack() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	for dir in ["res://data/rooms/biome1/", "res://data/rooms/harbour/", "res://data/rooms/biome2/", "res://data/rooms/biome3/"]:
		for f in DirAccess.get_files_at(dir):
			var t := RoomTemplate.load_file(dir + f)
			if t.enemy_spawns.is_empty():
				continue
			var open := t.reachable_cells()
			for m in t.enemy_spawns:
				assert_true(open.has(m), "%s: marker %s is on reachable floor" % [f, m])
			# A deep streets room asks for more bodies than any template marks (seed 202
			# put eight on streets_07's four, and a stacked pair fell out of the world).
			var cells := t.spawn_cells(12, rng)
			assert_eq(cells.size(), 12, f)
			for i in cells.size():
				var c: Vector2i = cells[i]
				assert_true(open.has(c), "%s: body %d at %s is on reachable floor" % [f, i, c])
				assert_true(maxi(absi(c.x - t.player_spawn.x), absi(c.y - t.player_spawn.y)) >= 2, "%s: body %d at %s is off the player" % [f, i, c])
				for j in i:
					assert_true(cells[j] != c, "%s: bodies %d and %d share %s" % [f, j, i, c])
			# With no more bodies than markers, the markers themselves are used.
			var few := t.spawn_cells(t.enemy_spawns.size(), rng)
			for m in t.enemy_spawns:
				assert_true(m in few, "%s: marker %s is used when there is room" % [f, m])


func test_clamp_inside_finds_floor() -> void:
	var room := Room.new()
	room.build(RoomTemplate.load_file("res://data/rooms/biome2/streets_07.txt"))
	var t := room.template
	# Out of the world above the top wall (where the stacked pair ended up), inside a
	# building block, and on the outer wall next to a door.
	for p in [Vector2(88, -252), Vector2(72, 48), Vector2(400, 900), Vector2(312, 4), Vector2(-40, 200)]:
		var q: Vector2 = room.clamp_inside(p)
		var c := room.world_to_cell(q)
		assert_true(not t.is_solid(c.x, c.y), "%s lands on floor, not %s" % [p, c])
		assert_true(t.char_at(c.x, c.y) != "D", "%s does not land in a door" % p)
		assert_true(q.x > 0.0 and q.y > 0.0 and q.x < room.size_px().x and q.y < room.size_px().y, "%s lands inside" % p)
	var open := room.cell_to_world(t.player_spawn)
	assert_eq(room.clamp_inside(open), open, "open floor is left alone")
	# Deep inside a thick mass (map Stage 09: rims and blocks of many cells), still out on floor.
	for y in t.height:
		for x in t.width:
			if t.is_beyond(x, y):
				var q: Vector2 = room.clamp_inside(room.cell_to_world(Vector2i(x, y)))
				var c := room.world_to_cell(q)
				assert_true(not t.is_solid(c.x, c.y), "from deep in the mass at %d,%d to floor" % [x, y])
	room.free()
