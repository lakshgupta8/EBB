extends TestCase
## Set pieces (map Stage 05): the table matches the atlas, footprints sit inside their sprites,
## a template's `@` line makes the footprint solid, and nothing else about the room changes.


func test_every_piece_fits_its_atlas() -> void:
	var tex := SetPieces.TEXTURE
	assert_true(SetPieces.table().size() >= 32, "both batches: eight a look")
	for id in SetPieces.table():
		var info := SetPieces.info(id)
		var r: Array = info.region
		assert_true(r[0] + r[2] <= tex.get_width() and r[1] + r[3] <= tex.get_height(), id + " inside the atlas")
		var size := SetPieces.size(id)
		var o: Array = info.origin
		assert_true(o[0] + size.x * Tiles.SIZE <= r[2] + 16, id + " footprint as wide as its sprite")
		assert_true(o[1] + size.y * Tiles.SIZE <= r[3], id + " footprint ends inside the sprite")
		assert_true(str(info.look) in ["flats", "streets", "deep", "harbour", "reef"], id + " has a look")


func test_a_placed_piece_is_solid() -> void:
	var t := RoomTemplate.parse("""
##########
#........#
#........#
#...P....#
####D#####
@ boat 2 1
""", "t")
	assert_eq(t.height, 5, "the @ line is not a row")
	assert_eq(t.pieces.size(), 1)
	for x in range(2, 5):
		assert_true(t.is_solid(x, 1), "the boat's footprint is solid at %d" % x)
	assert_true(not t.is_solid(5, 1), "beside it is floor")
	assert_eq(t.char_at(3, 1), ".", "the ground under it is still floor")
	var bad := RoomTemplate.parse("####\n#P.#\n####\n@ nothing 1 1\n", "bad")
	assert_eq(bad.pieces.size(), 0, "an unknown piece is ignored")


## The second batch: a footprint's '=' cells lay a deck and its '_' cells water into the plan.
func test_a_piece_lays_its_ground() -> void:
	var t := RoomTemplate.parse("""
############
#..........#
#..........#
#..______..#
#..______..#
#..........#
#..........#
#....P.....#
#####D######
@ bridge 3 2
""", "lay")
	assert_eq(t.char_at(4, 3), "=", "the bridge's deck over the water")
	assert_eq(t.height_at(4, 3), 2, "raised: the last ground to flood")
	assert_true(t.is_solid(4, 2), "its north parapet is solid")
	assert_true(not t.is_solid(5, 4), "the deck is walkable")
	var pool := RoomTemplate.parse("""
############
#..........#
#..........#
#..........#
#..........#
#....P.....#
#####D######
@ tidepool 2 1
""", "pool")
	assert_eq(pool.char_at(3, 2), "_", "the tide pool lays its water")
	assert_eq(pool.char_at(5, 3), ".", "its open side stays floor")
	# Map Stage 12d: a marker on a deck keeps its cell (the Streets' cage on its bridge).
	var caged := RoomTemplate.parse("""
############
#..........#
#..........#
#..___E__..#
#..______..#
#..........#
#..........#
#....P.....#
#####D######
@ bridge 3 2
""", "caged")
	assert_eq(caged.marker_cells("E").size(), 1, "the cage on the bridge is still there")
	assert_eq(caged.height_at(6, 3), 2, "and stands on the deck")
	assert_eq(caged.char_at(5, 3), "=", "the deck round it is laid")


func test_test_rooms_place_their_pieces() -> void:
	var t := RoomTemplate.load_file("res://data/rooms/test/flats_L_test.txt")
	assert_eq(t.pieces.size(), 3, "wreck, arch, boat")
	assert_true(t.is_solid(33, 25), "the wreck stands where the rocks were")
	assert_true(not t.is_solid(7, 36), "the arch's gap is open")
	var r := Room.new()
	r.build(t, 3, Tiles.Look.FLATS)
	assert_true(r.get_node("PiecesAbove").get_child_count() >= 3, "each piece rises over the keeper")
	r.free()


## Map Stage 06: a rock cell is the look's obstacle (a boulder, rubble, masonry, a crate or a
## bollard), drawn in two parts like a piece, and no longer a grey square on the cell layer.
func test_rocks_are_drawn_as_the_looks_obstacles() -> void:
	var t := RoomTemplate.parse("""
##########
#........#
#..o..o..#
#...P....#
####D#####
""", "rocks")
	for look in [Tiles.Look.FLATS, Tiles.Look.HARBOUR]:
		var r := Room.new()
		r.build(t, 3, look)
		var under: Node = r.get_node("Pieces")
		assert_eq(under.get_child_count(), 2, "one sprite per rock under the bodies")
		assert_eq(r.get_node("PiecesAbove").get_child_count(), 2, "and its top over them")
		var s: Sprite2D = under.get_child(0)
		assert_eq(int(s.region_rect.position.y) / 24, look, "the look's row of obstacles")
		assert_eq(r._cells.get_cell_source_id(Vector2i(3, 2)), -1, "no grey square on the cell layer")
		assert_true(t.is_solid(3, 2), "still solid")
		r.free()


## The sample rooms (tools/gen_sample_rooms.py; the Reef's since map Stage 11c) keep STYLE.md 22: a major piece each, a
## rim two cells thick, and the ground broken up by patches.
func test_sample_rooms_keep_the_map_rules() -> void:
	var looks := {"flats": Tiles.Look.FLATS, "harbour": Tiles.Look.HARBOUR,
		"streets": Tiles.Look.STREETS, "hall": Tiles.Look.DEEP, "reef": Tiles.Look.REEF}
	for k: String in looks:
		var t := RoomTemplate.load_file("res://data/rooms/test/sample_%s.txt" % k)
		assert_true(t.width >= 60 and t.height >= 34, k + " is M or L")
		assert_true(t.pieces.size() >= 8, k + " has its set pieces, both batches")
		assert_true(t.doors.size() >= 3, k + " has three doors or more")
		for y in t.height:
			for x in t.width:
				if t.is_beyond(x, y):
					for dy in range(-2, 3):
						for dx in range(-2, 3):
							assert_true(t.char_at(x + dx, y + dy) == "#", "%s: the void is two cells from the floor at %d,%d" % [k, x, y])
		# World light (map Stage 07): one to three lights a room besides the Hall's candle drifts,
		# the biome's warm rule kept, and no more than three warm sources beside Tam's lantern.
		var l := SetPieces.lights(t)
		var n: int = l.WARM + l.FLAME + l.COLD
		assert_true(n >= 1 and n <= 3, "%s: %d world lights" % [k, n])
		assert_true(l.WARM + l.FLAME + l.candles <= 3, k + ": Tam plus three warm at most")
		match k:
			"streets": assert_eq(l.WARM + l.FLAME, 0, "the Streets' lamps burn cold")
			"reef": assert_eq(l.WARM + l.FLAME + l.candles, 0, "on the Reef only Tam's lantern is warm")
			"harbour", "flats": assert_true(l.WARM <= 1 and l.FLAME == 0, k + ": one warm lamp or the beacon")
			"hall": assert_true(l.candles >= 1 and l.WARM == 0, "the Hall's warm light is its candles")
		var share := GroundPatches.base_share(t, GroundPatches.plan(t, looks[k], 7))
		assert_true(share <= GroundPatches.MAX_BASE + 0.01, "%s: bare floor %.2f" % [k, share])
