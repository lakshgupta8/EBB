extends TestCase
## Tidemarks and the Ledger: data integrity and purchase logic.


func test_tidemark_ids_unique_and_coloured() -> void:
	var seen := {}
	for m in Tidemarks.ALL:
		assert_true(not seen.has(m.id), "duplicate id " + m.id)
		seen[m.id] = true
		assert_true(Tidemarks.FAMILY_COLOR.has(m.family), m.id + " has a known family")
	assert_true(Tidemarks.ALL.size() >= 12)


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


func test_room_graph_offers_altar_early() -> void:
	var g := RoomGraph.new(3, 8)
	assert_true(RoomGraph.ALTAR in g.options_for(1), "altar at depth 1")
	for d in range(1, 8):
		var opts: Array = g.options_for(d)
		var prev: Array = g.options_for(d - 1)
		for t in RoomGraph.NO_REPEAT:
			if t in prev and d != 1 and d != 4:
				assert_true(not t in opts, "%s repeated at depth %d" % [RoomGraph.NAMES[t], d])
