extends TestCase
## Tidemarks and the Ledger: data integrity and purchase logic.


func test_tidemark_ids_unique_and_coloured() -> void:
	var seen := {}
	for m in Tidemarks.ALL:
		assert_true(not seen.has(m.id), "duplicate id " + m.id)
		seen[m.id] = true
		assert_true(Tidemarks.FAMILY_COLOR.has(m.family), m.id + " has a known family")
	assert_true(Tidemarks.ALL.size() >= 40, "M4: at least 40 tidemarks")
	for fam in Tidemarks.FAMILY_COLOR:
		var n := 0
		for m in Tidemarks.ALL:
			if m.family == fam:
				n += 1
		assert_true(n >= 10, fam + " has at least 10 marks")


func test_tidemark_roll_excludes_owned() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var owned := ["salt_edge", "brine_hp"]
	for i in 20:
		var r := Tidemarks.roll(rng, owned, 3)
		assert_eq(r.size(), 3)
		for id in r:
			assert_true(not id in owned, "rolled an owned mark")
		assert_true(r[0] != r[1] and r[1] != r[2] and r[0] != r[2], "distinct offers")


func test_tidemark_roll_honours_a_blessing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 20:
		var r := Tidemarks.roll(rng, [], 3, "deep")
		var found := false
		for id in r:
			if Tidemarks.get_mark(id).family == "deep":
				found = true
		assert_true(found, "a blessed family is always offered")


func test_ledger_tiers_and_costs() -> void:
	SaveManager.use_path("user://test_save.json")
	SaveManager.wipe()
	assert_eq(Ledger.tier("constitution"), 0)
	assert_eq(Ledger.next_cost("constitution"), 10)
	assert_true(not Ledger.can_buy("constitution"), "no pearls yet")
	SaveManager.data.pearls = 100
	assert_true(Ledger.buy("constitution"))
	assert_eq(Ledger.tier("constitution"), 1)
	assert_eq(int(SaveManager.data.pearls), 90)
	assert_eq(Ledger.next_cost("constitution"), 20)
	assert_true(Ledger.buy("constitution"))
	assert_true(Ledger.buy("constitution"))
	assert_eq(Ledger.next_cost("constitution"), -1, "maxed")
	assert_true(not Ledger.buy("constitution"), "cannot buy past max")
	assert_eq(int(SaveManager.data.pearls), 35)
	SaveManager.wipe()
	SaveManager.use_path(SaveManager.PATH)


func test_menu_texts_fit_their_rows() -> void:
	# 6 px per glyph in the pixel font; keep descriptions inside the row's description column.
	for u in Ledger.UPGRADES:
		assert_true(u.desc.length() * 6 <= 200, "ledger desc too long: " + u.desc)
	for it in Shop.ITEMS:
		assert_true(it.desc.length() * 6 <= 150, "shop desc too long: " + it.desc)
	for m in Tidemarks.ALL:
		assert_true(m.desc.length() * 6 <= 260, "tidemark desc too long: " + m.desc)
	for id in Weapon.ALL:
		assert_true(Weapon.ALL[id].desc.length() * 6 <= 240, "weapon desc too long: " + Weapon.ALL[id].desc)


func test_codex_covers_every_enemy_and_mark() -> void:
	var ids: Array = []
	for e in Codex.ENEMIES:
		ids.append(e.id)
	var dir := DirAccess.open("res://src/enemies")
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			assert_true(f.get_basename() in ids, "codex entry for " + f)
	assert_eq(Codex.entries("mark").size(), Tidemarks.ALL.size(), "every tidemark listed")
	for e in Codex.ENEMIES + Codex.PEOPLE + Codex.PLACES:
		assert_true(e.desc.length() * 6 <= 300, "codex desc too long: " + e.desc)
	for id in Story.ENDINGS:
		assert_true(Story.ENDINGS[id].desc.length() * 6 <= 240, "ending desc too long: " + id)


func test_codex_discovery_and_endings_gate() -> void:
	SaveManager.use_path("user://test_codex.json")
	SaveManager.wipe()
	assert_eq(Codex.count("enemy").x, 0, "nothing met yet")
	assert_true(Codex.discover("enemy", "shellback"), "first meeting counts")
	assert_true(not Codex.discover("enemy", "shellback"), "second does not")
	assert_eq(Codex.count("enemy").x, 1)
	assert_true(Codex.found("people", "orla") and not Codex.found("people", "bram"), "people follow echo flags")
	assert_true(Codex.found("place", "rock") and not Codex.found("place", "flats"), "places open as reached")
	# Whispers are once per profile.
	assert_true(Story.whisper("cage") != "", "first whisper speaks")
	assert_eq(Story.whisper("cage"), "", "then stays quiet")
	assert_eq(Story.whisper("nonsense"), "", "unknown keys are silent")
	# Endings: keep is always there, break needs the three echoes, walk needs everyone and 3 wins.
	assert_true(Story.ending_available("keep"))
	assert_true(not Story.ending_available("break"))
	assert_true(not Story.ending_visible("walk"), "walk is hidden until everyone is home")
	for id in ["bram", "wren", "cartographer"]:
		SaveManager.set_flag("echo_" + id)
	assert_true(Story.ending_available("break"), "break opens with the three")
	SaveManager.set_flag("echo_maren")
	assert_true(Story.ending_visible("walk") and not Story.ending_available("walk"), "walk shows, still locked")
	SaveManager.data.wins = 3
	assert_true(Story.ending_available("walk"), "walk opens at three wins")
	Story.record_ending("keep")
	Story.record_ending("keep")
	assert_eq(Story.endings_seen(), ["keep"], "endings recorded once")
	assert_true(Story.maren().length() > 0 and Story.fen().length() > 0 and Story.orla().length() > 0, "everyone has a line")
	SaveManager.wipe()
	SaveManager.use_path(SaveManager.PATH)


func test_room_graph_offers_altar_early() -> void:
	var g := RoomGraph.new(3, 8)
	assert_true(RoomGraph.ALTAR in g.options_for(1), "altar at depth 1")
	for d in range(1, 8):
		var opts: Array = g.options_for(d)
		var prev: Array = g.options_for(d - 1)
		for t in RoomGraph.NO_REPEAT:
			if t in prev and d != 1 and d != 4:
				assert_true(not t in opts, "%s repeated at depth %d" % [RoomGraph.NAMES[t], d])
