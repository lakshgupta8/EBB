extends TestCase
## The room generator (map Stage 08): the same seed is the same room, the chunks read, the
## validator catches a broken room, and the gate: 200 generated rooms keep the map rules.

const LOOKS := [Tiles.Look.FLATS, Tiles.Look.HARBOUR, Tiles.Look.STREETS, Tiles.Look.DEEP]


func test_a_seed_is_a_room() -> void:
	for look in LOOKS:
		var a := RoomGen.generate(look, 17)
		var b := RoomGen.generate(look, 17)
		assert_eq(a.rows, b.rows, "the same seed, the same plan")
		assert_eq(a.directives, b.directives, "and the same pieces")
		var c := RoomGen.generate(look, 18)
		assert_true(a.rows != c.rows, "another seed, another plan")


func test_every_chunk_reads() -> void:
	for look in LOOKS:
		var chunks := RoomChunks.for_look(look)
		assert_true(chunks.size() >= 5, "five chunks or more a look")
		for ch: Dictionary in chunks:
			var rows: PackedStringArray = ch.rows
			for r in rows:
				assert_eq(r.length(), rows[0].length(), "%s is a block" % ch.name)
			for p in ch.pieces:
				assert_true(SetPieces.has(str(p[0])), "%s places a known piece" % ch.name)


func test_the_validator_catches_a_broken_room() -> void:
	var t := RoomTemplate.parse("""
########################################
#......................................#
#..P...................................#
#......................................#
#####################################D##
#......................................D
########################################
""", "broken")
	var bad := RoomGen.validate(t, Tiles.Look.FLATS)
	assert_true(not bad.is_empty(), "a broken room fails")
	var joined := " ".join(bad)
	assert_true(joined.contains("unreachable"), "a door behind a wall is caught")
	assert_true(joined.contains("spawns"), "no drowned is caught")
	assert_true(joined.contains("world lights"), "no light is caught")


## The Stage 08 gate: 200 generated rooms (50 a look) pass the validator, each as the run would
## use it, and none was given up on.
func test_two_hundred_rooms_keep_the_map_rules() -> void:
	var failed := 0
	for look in LOOKS:
		for s in range(1, 51):
			var t := RoomGen.generate(look, s)
			var bad := RoomGen.validate(t, look)
			if not bad.is_empty():
				failed += 1
				print("  room_gen %d seed %d: %s" % [look, s, bad])
			assert_true(RoomGen.last_attempts <= RoomGen.TRIES, "made within its attempts")
	assert_eq(failed, 0, "every one of the 200 passes")


## Map Stage 10: each shape is the shape it says, and a generated name makes its room again.
func test_each_shape_is_its_shape() -> void:
	for look in LOOKS:
		for s in range(1, 4):
			var t := RoomGen.generate(look, s, "combat", Vector2i.ZERO, "", "corridor")
			assert_true(Vector2i(t.width, t.height) in [RoomGen.SIZE_LONG, RoomGen.SIZE_TALL], "a corridor is long and thin")
			t = RoomGen.generate(look, s, "combat", Vector2i.ZERO, "", "ring")
			assert_true(t.is_solid(t.width / 2, t.height / 2), "a ring has its middle fallen in")
			t = RoomGen.generate(look, s, "combat", Vector2i.ZERO, "", "ell")
			var dark := 0
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var c := Vector2i(int(t.width * (0.15 + 0.7 * corner.x)), int(t.height * (0.15 + 0.7 * corner.y)))
				dark += 1 if t.is_solid(c.x, c.y) and t.is_solid(c.x + 2, c.y + 2) and t.is_solid(c.x - 2, c.y - 2) else 0
			assert_true(dark >= 1, "an L has a corner of dark")
			var reach := 0
			var raised := 0
			var low := 0
			t = RoomGen.generate(look, s, "combat", Vector2i.ZERO, "", "split")
			for c: Vector2i in t.reachable_cells():
				reach += 1
				raised += 1 if t.height_at(c.x, c.y) == 2 else 0
			assert_true(raised > reach * 0.1, "a split level is raised on one side (%d %d: %d of %d)" % [look, s, raised, reach])
			t = RoomGen.generate(look, s, "combat", Vector2i.ZERO, "", "flooded")
			reach = 0
			for c: Vector2i in t.reachable_cells():
				reach += 1
				low += 1 if t.height_at(c.x, c.y) == 0 else 0
			assert_true(low > reach * 0.4, "a flooded room is mostly under (%d %d: %d of %d)" % [look, s, low, reach])


func test_a_generated_name_makes_its_room_again() -> void:
	for look in LOOKS:
		var t := RoomGen.generate(look, 4242, "combat", Vector2i.ZERO, "", "any")
		var again := RoomGen.from_name(t.name)
		assert_true(again != null, "%s reads as a generated room" % t.name)
		assert_eq(again.rows, t.rows, "the same plan from the name")
		assert_eq(again.directives, t.directives, "and the same pieces")
	assert_true(RoomGen.from_name("flats_02") == null, "a saved room's name is not a seed")


## The Stage 10 gate: 200 rooms of the new shapes (ten a shape a look) keep the map rules.
func test_two_hundred_shaped_rooms_keep_the_map_rules() -> void:
	var failed := 0
	for look in LOOKS:
		for shape: String in RoomGen.SHAPES:
			for s in range(1, 11):
				var t := RoomGen.generate(look, s, "combat", Vector2i.ZERO, "", shape)
				var bad := RoomGen.validate(t, look)
				if not bad.is_empty():
					failed += 1
					print("  room_gen %d %s seed %d: %s" % [look, shape, s, bad])
	assert_eq(failed, 0, "every one of the 200 passes")


## Map Stage 11d: the Reef's grammar. A seed is a room, its chunks read, and its gate: 50 open
## rooms and ten of each shape keep the map rules (cold light only among them).
func test_the_reef_keeps_the_map_rules() -> void:
	var look := Tiles.Look.REEF
	var a := RoomGen.generate(look, 17)
	assert_eq(a.rows, RoomGen.generate(look, 17).rows, "the same seed, the same Reef room")
	assert_eq(RoomGen.from_name(a.name).rows, a.rows, "a Reef room is made again from its name")
	var chunks := RoomChunks.for_look(look)
	assert_true(chunks.size() >= 10, "ten Reef chunks")
	for ch: Dictionary in chunks:
		for p in ch.pieces:
			assert_true(SetPieces.has(str(p[0])) and not SetPieces.info(str(p[0])).has("light"), "%s places a known, unlit piece" % ch.name)
	var failed := 0
	var reef_pieces := 0
	var runs: Array = []
	for s in range(1, 51):
		runs.append([s, ""])
	for shape: String in RoomGen.SHAPES:
		for s in range(1, 11):
			runs.append([s, shape])
	for run: Array in runs:
		var t := RoomGen.generate(look, run[0], "combat", Vector2i.ZERO, "", run[1])
		var bad := RoomGen.validate(t, look)
		if not bad.is_empty():
			failed += 1
			print("  reef %s seed %d: %s" % [run[1], run[0], bad])
		for p in t.pieces:
			if str(SetPieces.info(str(p.id)).get("look", "")) == "reef":
				reef_pieces += 1
	assert_eq(failed, 0, "every one of the 100 Reef rooms passes")
	assert_true(reef_pieces > 300, "the Reef's rooms stand on the Reef's own pieces (%d)" % reef_pieces)
