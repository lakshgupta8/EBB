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
