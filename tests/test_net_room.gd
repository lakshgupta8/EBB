extends TestCase
## A room has to cross the wire as text and come out the same: generated rooms have no file
## on the guest's disk.


func _same(a: RoomTemplate, b: RoomTemplate) -> void:
	assert_eq(b.name, a.name)
	assert_eq(b.rows, a.rows)
	assert_eq(b.player_spawn, a.player_spawn)
	assert_eq(b.enemy_spawns, a.enemy_spawns)
	assert_eq(b.doors, a.doors)
	assert_eq(b.pieces.size(), a.pieces.size())
	assert_eq(b.currents.size(), a.currents.size())


func test_saved_room_round_trips_through_text() -> void:
	var dir := "res://data/rooms/"
	var found := false
	for sub in DirAccess.get_directories_at(dir):
		for f in DirAccess.get_files_at(dir + sub):
			if f.ends_with(".txt") and not found:
				var t := RoomTemplate.load_file(dir + sub + "/" + f)
				_same(t, RoomTemplate.parse(t.to_text(), t.name))
				found = true
	assert_true(found, "found a saved room to test with")


func test_generated_room_round_trips_through_text() -> void:
	var t := RoomGen.generate(Tiles.Look.FLATS, 12345, "combat")
	_same(t, RoomTemplate.parse(t.to_text(), t.name))
