extends TestCase
## M8 modes: gating, the daily's seed, seed determinism (graph, spawns, altar offers),
## the history and the daily board in the profile.


func _scratch() -> void:
	SaveManager.use_path("user://test_modes.json")
	SaveManager.wipe()


func _done() -> void:
	SaveManager.wipe()
	SaveManager.use_path(SaveManager.PATH)


func test_mode_gating() -> void:
	_scratch()
	assert_eq(Modes.ALL.size(), 5, "five ways down besides the night")
	assert_true(Modes.available("daily") and Modes.available("seeded"), "the daily and a seed are always open")
	assert_true(not Modes.available("trial") and not Modes.available("neap") and not Modes.available("riptide"), "the trials wait")
	assert_eq(Modes.locked_reason("trial"), "break the Ebb first")
	SaveManager.record_run({"pearls": 0, "kills": 0, "depth": 0, "victory": true, "tier": 0})
	assert_true(Modes.available("neap") and Modes.available("riptide"), "a win opens neap and riptide")
	assert_true(not Modes.available("trial"), "the trial still waits for the Ebb")
	SaveManager.set_flag("ebb_broken")
	assert_true(Modes.available("trial"))
	assert_eq(Modes.locked_reason("nonsense"), "unknown")
	for m in Modes.ALL:
		assert_true(str(m.cond) == "" or Dialog.valid_condition(str(m.cond)), "mode condition " + str(m.cond))
	_done()


func test_daily_seed_is_the_date() -> void:
	assert_eq(Modes.daily_seed("2026-09-13"), Modes.daily_seed("2026-09-13"), "the same day, the same seed")
	assert_true(Modes.daily_seed("2026-09-13") != Modes.daily_seed("2026-09-14"), "another day, another seed")
	assert_true(Modes.daily_seed() > 0 and Modes.daily_seed() == Modes.daily_seed(Modes.today()))
	assert_eq(Modes.today().length(), 10, "YYYY-MM-DD")
	assert_eq(Modes.parse_seed("  1234 "), 1234)
	assert_eq(Modes.parse_seed(""), 0, "nothing typed: the menu rolls one")
	assert_true(Modes.parse_seed("marrow rock") > 0 and Modes.parse_seed("marrow rock") == Modes.parse_seed("marrow rock"), "words hash to a seed")
	assert_eq(Modes.parse_seed("-7"), 7)


func test_same_seed_same_night() -> void:
	# The graph, the spawn cells and the altar's offers all come from the seed.
	var a := RoomGraph.new(9001, 10, [3], -1)
	var b := RoomGraph.new(9001, 10, [3], -1)
	for d in 11:
		assert_eq(a.options_for(d), b.options_for(d), "graph at depth %d" % d)
	var t := RoomTemplate.load_file("res://data/rooms/biome1/flats_01.txt")
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 9001
	r2.seed = 9001
	assert_eq(t.spawn_cells(5, r1), t.spawn_cells(5, r2), "spawn cells")
	assert_eq(Tidemarks.roll(r1, [], 3), Tidemarks.roll(r2, [], 3), "altar offers")
	var c := RoomGraph.new(9002, 10, [3], -1)
	var differs := false
	for d in 11:
		if c.options_for(d) != a.options_for(d):
			differs = true
	assert_true(differs, "another seed is another night")


func test_history_and_daily_board() -> void:
	_scratch()
	for i in 55:
		SaveManager.record_run({"seed": 100 + i, "mode": "night", "weapon": "gaff", "depth": i, "marks": ["salt_edge"],
			"time": 60.0 + i, "victory": false, "taken": i % 2 == 0, "pearls": 3, "kills": 1, "tier": 0})
	var hist: Array = SaveManager.data.history
	assert_eq(hist.size(), 50, "the history keeps fifty")
	assert_eq(int(hist[0].seed), 105, "the oldest five fell off")
	assert_eq(str(hist[49].cause), "tide", "taken by the tide")
	assert_eq(str(hist[48].cause), "deep")
	assert_eq(hist[49].marks, ["salt_edge"])
	assert_true(SaveManager.data.daily_scores.is_empty(), "ordinary nights are not on the daily board")
	SaveManager.record_run({"seed": Modes.daily_seed(), "mode": "daily", "weapon": "net", "depth": 4, "time": 90.0,
		"victory": true, "pearls": 9, "kills": 3, "tier": 0, "assist_mult": 0.7})
	assert_eq(SaveManager.data.daily_scores.size(), 1, "a daily goes on the board")
	var s: Dictionary = Modes.daily_played()
	assert_eq(str(s.cause), "won")
	assert_true(bool(s.assisted), "assists are marked on the board")
	assert_eq(SaveManager.stat("dailies"), 1)
	assert_eq(SaveManager.stat("wins_daily"), 1)
	assert_eq(SaveManager.stat("runs_night"), 55)
	assert_true(Modes.daily_played("1999-01-01").is_empty())
	assert_true(Modes.par_seconds(10) > 0.0, "par exists with or without the balance file")
	assert_eq(Modes.time_text(125.0), "2:05")
	# The rested night keeps its mode.
	var st := RunState.new()
	st.mode = "riptide"
	var back := RunState.new()
	back.from_dict(st.to_dict())
	assert_eq(back.mode, "riptide")
	assert_eq(st.result().mode, "riptide")
	_done()


func test_log_has_a_milestone_per_mode() -> void:
	for id in ["daily_1", "trial_win", "neap_win", "riptide_win"]:
		var m := KeeperLog.get_milestone(id)
		assert_true(not m.is_empty() and Dialog.valid_condition(str(m.cond)), "milestone " + id)
