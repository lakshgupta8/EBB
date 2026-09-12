extends TestCase
## M7, the village: dialog data, affinity, Fen's chain, contracts, the Log, the Ledger's
## branches, epilogues, save migration, fish and the codex tabs.

const NPCS := ["orla", "fen", "bram", "wren", "cartographer", "maren", "nessa", "idris", "aldous", "pell", "choir"]


func _scratch(name: String) -> void:
	SaveManager.use_path("user://test_%s.json" % name)
	SaveManager.wipe()


func _done() -> void:
	SaveManager.wipe()
	SaveManager.use_path(SaveManager.PATH)


func test_dialog_files_lint() -> void:
	var npcs := Dialog.load_file("npcs")
	var chains := Dialog.load_file("affinity")
	assert_true(not npcs.is_empty() and not chains.is_empty(), "both dialog files parse")
	for id in ["nessa", "idris", "aldous", "pell", "choir"]:
		assert_true(npcs.has(id) and npcs[id].size() >= 5, id + " has idle lines")
		var last: Dictionary = npcs[id][npcs[id].size() - 1]
		assert_true(last.get("when", []).is_empty(), id + " ends with a line that always holds")
	var seen := {}
	for id in npcs:
		for e in npcs[id]:
			assert_true(e.has("text") and str(e.text).length() <= 200, "%s line fits: %s" % [id, str(e.get("text", ""))])
			assert_true(not seen.has(e.text), "duplicate line: " + str(e.text))
			seen[e.text] = true
			for c in e.get("when", []):
				assert_true(Dialog.valid_condition(str(c)), "%s: unknown condition %s" % [id, c])
	for id in NPCS:
		assert_eq(Dialog.chain_count(id), 3, id + " has three affinity chains")
		for k in 3:
			var ch := Dialog.chain(id, k + 1)
			assert_true(ch.get("lines", []).size() >= 2, "%s chain %d has lines" % [id, k + 1])
			assert_true(ch.has("reward"), "%s chain %d pays" % [id, k + 1])
			for line in ch.lines:
				assert_true(str(line).length() <= 160, "%s chain line fits: %s" % [id, line])
				assert_true(not seen.has(line), "duplicate line: " + str(line))
				seen[line] = true
		assert_true(Dialog.chain(id, 3).reward.has("perk"), id + "'s last chain gives a perk")
	assert_true(Dialog.chain("nobody", 1).is_empty())
	for m in KeeperLog.ALL:
		assert_true(Dialog.valid_condition(str(m.cond)), "log condition " + str(m.cond))
	for q in Quests.FEN:
		assert_true(Dialog.valid_condition(str(q.cond)), "quest condition " + str(q.cond))
	for k in Ledger.BRANCH_NEEDS:
		var need: String = Ledger.BRANCH_NEEDS[k]
		assert_true(need == "" or Dialog.valid_condition(need), "branch need " + need)


func test_dialog_conditions_read_the_profile() -> void:
	_scratch("dialog")
	assert_true(not Dialog.check("wins>=1") and Dialog.check("!wins>=1"))
	SaveManager.data.wins = 2
	assert_true(Dialog.check("wins>=1") and Dialog.check("wins>=2") and not Dialog.check("wins>=3"))
	assert_true(not Dialog.check("flag:echo_bram"))
	SaveManager.set_flag("echo_bram")
	assert_true(Dialog.check("flag:echo_bram") and Dialog.check("echoes>=1") and not Dialog.check("echoes>=2"))
	SaveManager.data["affinity"] = {"nessa": 2}
	assert_true(Dialog.check("affinity:nessa>=2") and not Dialog.check("affinity:nessa>=3") and not Dialog.check("affinity:pell>=1"))
	SaveManager.count("vaults", 3)
	assert_true(Dialog.check("stat:vaults>=3") and not Dialog.check("stat:vaults>=4"))
	Story.record_ending("break")
	assert_true(Dialog.check("ending:break") and Dialog.check("any_ending") and Dialog.check("epilogue:break") and not Dialog.check("epilogue:keep"))
	assert_true(Dialog.check("endings>=1") and not Dialog.check("endings>=2"))
	assert_true(not Dialog.check("nonsense") and not Dialog.valid_condition("nonsense"))
	# The first matching entry wins: Nessa's post-ending line beats her contract line.
	assert_true(Story.nessa().begins_with("The dock is under"), "Nessa reads the epilogue: " + Story.nessa())
	SaveManager.data["epilogue"] = ""
	SaveManager.data["endings"] = []
	assert_true(Story.nessa().begins_with("You are the keeper"), "a fresh Nessa: " + Story.nessa())
	for f in [Story.idris, Story.aldous, Story.pell, Story.choir]:
		assert_true(f.call().length() > 20, "everyone new has a line")
	_done()


func test_affinity_and_gifts() -> void:
	_scratch("gifts")
	assert_true(Story.give_gift("bram").is_empty(), "nothing in hand: no gift")
	SaveManager.data["glass"] = 1
	SaveManager.data["shells"] = 2
	var first := Story.give_gift("bram")
	assert_true(not first.is_empty() and not first.seen_before, "the first gift is new")
	assert_eq(Story.affinity("bram"), 1)
	assert_eq(int(SaveManager.data.glass), 0, "glass is spent first")
	assert_eq(int(SaveManager.data.shells), 2)
	assert_eq(int(SaveManager.data.pearls), 10, "level one pays ten pearls")
	assert_eq(first.lines.size(), 3, "two lines and what you got")
	var second := Story.give_gift("bram")
	assert_eq(Story.affinity("bram"), 2)
	assert_eq(int(SaveManager.data.shells), 1, "then shells")
	assert_eq(int(SaveManager.data.shards), 2, "level two pays shards")
	assert_true(not second.is_empty())
	Story.give_gift("bram")
	assert_eq(Story.affinity("bram"), 3)
	assert_true(Story.perk("bram"), "level three gives the perk")
	assert_eq(int(SaveManager.data.shells), 0)
	SaveManager.data["shells"] = 5
	assert_true(Story.give_gift("bram").is_empty(), "nothing past level three")
	assert_eq(SaveManager.stat("gifts"), 3)
	assert_eq(Story.affinity("bram"), 3)
	# Cosmetic gifts open a coat.
	SaveManager.data["affinity"] = {"maren": 2}
	assert_true(not KeeperLog.owns_cosmetic("verger"))
	Story.give_gift("maren")
	assert_true(KeeperLog.owns_cosmetic("verger") and Story.perk("maren"))
	_done()


func test_fen_chain_advances_in_order() -> void:
	_scratch("fen")
	assert_eq(Quests.FEN.size(), 6)
	var ids := {}
	for q in Quests.FEN:
		assert_true(not ids.has(q.id), "unique quest id")
		ids[q.id] = true
		assert_true(str(q.ask).length() > 10 and str(q.done).length() > 10)
	assert_true(not Quests.fen_ready() and not Quests.fen_done())
	assert_eq(Quests.fen_current().id, "fen_1")
	assert_true(Quests.fen_hand_in().is_empty(), "nothing to hand in yet")
	SaveManager.data.best_depth = 2
	assert_true(Quests.fen_ready())
	var q := Quests.fen_hand_in()
	assert_eq(q.id, "fen_1")
	assert_eq(int(SaveManager.data.shells), 1, "a shell")
	assert_eq(int(SaveManager.data.pearls), 5)
	assert_eq(Quests.fen_current().id, "fen_2", "the chain moves on")
	assert_true(not Quests.fen_ready(), "the Wreck still stands")
	SaveManager.data.wins = 1  # the last quest holds, but it is not the current one
	assert_true(not Quests.fen_ready(), "quests come in order")
	SaveManager.set_flag("boss_wreck_broken")
	SaveManager.count("wet_rooms")
	SaveManager.count("glass_found")
	SaveManager.set_flag("echo_wren")
	for i in 5:
		assert_true(Quests.fen_ready(), "quest %d ready" % (i + 2))
		Quests.fen_hand_in()
	assert_true(Quests.fen_done() and not Quests.fen_ready())
	assert_eq(int(SaveManager.data.shells), 6)
	assert_eq(SaveManager.stat("shells_found"), 6)
	assert_true(Story.fen().length() > 0)
	_done()


func test_contracts_are_decidable_and_paid_once() -> void:
	var ids := {}
	for c in Contracts.ALL:
		assert_true(not ids.has(c.id), "unique contract " + c.id)
		ids[c.id] = true
		assert_true(c.desc.length() * 6 <= 300, "contract desc fits: " + c.desc)
		assert_true(not Contracts.check(c, {}), c.id + " is not free")
	# A perfect night satisfies every contract there is.
	var perfect := {"victory": true, "weapon": "bell", "tier": 8, "salt": 200, "marks": 9, "kills": 120,
		"untouched_depth": 12, "shop_buys": 0, "rested": 1, "wet_rooms": 3, "challenges": 2, "vaults": 2, "dives": 2,
		"named_elites": 2, "flares": 6, "riptides": 9, "boss_wreck": 1, "boss_chainmother": 1, "boss_bell": 1, "tide_at_boss_0": 1.0}
	for e in Codex.ENEMIES:
		perfect["kills_" + e.id] = 12
	for c in Contracts.ALL:
		if c.kind == "win_weapon" and c.arg != "bell":
			var alt := perfect.duplicate()
			alt["weapon"] = c.arg
			assert_true(Contracts.check(c, alt), c.id + " with its weapon")
		else:
			assert_true(Contracts.check(c, perfect), c.id + " on a perfect night")
	assert_true(not Contracts.check(Contracts.get_contract("quick_wreck"), {"tide_at_boss_0": 1.5}), "too much water")
	assert_true(not Contracts.check(Contracts.get_contract("no_shop"), {"victory": true, "shop_buys": 1}))
	_scratch("contracts")
	var offer := Contracts.offered()
	assert_eq(offer.size(), 3, "three on the board")
	assert_eq(Contracts.offered(), offer, "the offer holds until a night is played")
	var s := RunState.new()
	s.victory = true
	s.stats = perfect.duplicate()
	s.salt = 200
	s.tier = 8
	s.tidemarks = ["salt_edge", "brine_hp", "current_dash", "deep_slow", "salt_crit", "brine_guard", "current_wake", "deep_salt", "salt_first"]
	s.kills = 120
	var paid := Contracts.settle(s.ledger())
	assert_eq(paid.size(), 3, "a perfect night completes the board")
	assert_true(int(SaveManager.data.pearls) > 0 and Contracts.done().size() == 3)
	assert_eq(SaveManager.stat("contracts"), 3)
	assert_true(Contracts.settle(s.ledger()).is_empty(), "nothing on the board after settling")
	SaveManager.data.runs = 1
	var next := Contracts.offered()
	assert_eq(next.size(), 3)
	for id in next:
		assert_true(not id in Contracts.done(), "done contracts are not offered again")
	# Every contract can be reached: keep settling perfect nights, with either weapon.
	for i in 20:
		SaveManager.data.runs = 2 + i
		s.stats["weapon"] = "line" if i % 2 == 0 else "bell"
		Contracts.offered()
		Contracts.settle(s.ledger())
	assert_eq(Contracts.done().size(), Contracts.ALL.size(), "the whole board, eventually")
	assert_true(Contracts.offered().is_empty(), "nothing left to offer")
	_done()


func test_log_claims_once_and_opens_cosmetics() -> void:
	var ids := {}
	for m in KeeperLog.ALL:
		assert_true(not ids.has(m.id), "unique milestone " + m.id)
		ids[m.id] = true
		assert_true(int(m.get("pearls", 0)) + int(m.get("shards", 0)) > 0, m.id + " pays")
	assert_eq(KeeperLog.ALL.size(), 40, "forty milestones")
	_scratch("log")
	assert_true(KeeperLog.claim_all().is_empty(), "a fresh keeper has done nothing")
	SaveManager.data.runs = 1
	SaveManager.count("kills", 10)
	var got := KeeperLog.claim_all()
	assert_eq(got.size(), 2, "first night and ten kills")
	assert_eq(int(SaveManager.data.pearls), 10)
	assert_true(KeeperLog.claim_all().is_empty(), "claimed once")
	assert_true(KeeperLog.is_claimed("first_night"))
	SaveManager.data.wins = 1
	KeeperLog.claim_all()
	assert_true(KeeperLog.owns_cosmetic("cold") and not KeeperLog.owns_cosmetic("white"), "the first win opens the cold lantern")
	assert_eq(KeeperLog.lantern_color(), KeeperLog.LANTERNS.warm.color, "still warm until chosen")
	SaveManager.data["cosmetics"]["lantern"] = "cold"
	assert_eq(KeeperLog.lantern_color(), KeeperLog.LANTERNS.cold.color)
	assert_true(KeeperLog.coat_sheet().ends_with("player.png"))
	SaveManager.data["cosmetics"]["coat"] = "fisher"
	assert_true(KeeperLog.coat_sheet().ends_with("player_fisher.png") and ResourceLoader.exists(KeeperLog.coat_sheet()))
	_done()


func test_ledger_branches_and_prerequisites() -> void:
	assert_eq(Ledger.UPGRADES.size(), 25, "twenty-five nodes")
	for b in Ledger.BRANCHES:
		assert_eq(Ledger.in_branch(b).size(), 5, b + " has five nodes")
	_scratch("ledger")
	SaveManager.data.pearls = 1000
	assert_eq(Ledger.prerequisite("constitution"), "", "roots have no prerequisite")
	assert_eq(Ledger.prerequisite("fourth_dash"), "constitution")
	assert_true(not Ledger.can_buy("fourth_dash"), "the second node waits for the first")
	assert_eq(Ledger.locked_reason("fourth_dash"), "needs Keeper's Constitution")
	assert_true(Ledger.buy("constitution"))
	assert_true(Ledger.can_buy("fourth_dash") and Ledger.buy("fourth_dash"))
	assert_true(not Ledger.can_buy("tether") or Ledger.tier("fourth_dash") > 0)
	assert_true(not Ledger.branch_open("lantern") and Ledger.locked_reason("bright_lantern") == "Bram must be on the rock")
	assert_true(not Ledger.buy("bright_lantern"))
	SaveManager.set_flag("echo_bram")
	assert_true(Ledger.branch_open("lantern") and Ledger.buy("bright_lantern"))
	assert_true(not Ledger.branch_open("memory"))
	SaveManager.data.wins = 1
	assert_true(Ledger.buy("keep_mark") and Ledger.buy("reroll") and Ledger.buy("second_active"))
	# The whole ledger costs about a dozen good nights.
	var total := 0
	for u in Ledger.UPGRADES:
		for c in u.costs:
			total += int(c)
	assert_true(total >= 900 and total <= 1200, "ledger costs %d pearls" % total)
	assert_eq(Ledger.KEELS.size(), 4)
	assert_true(Ledger.keel().is_empty())
	SaveManager.data["keel"] = "iron"
	assert_eq(Ledger.keel().id, "iron")
	_done()


func test_endings_gate_on_seven_echoes_and_leave_an_epilogue() -> void:
	_scratch("epilogue")
	assert_eq(Story.ECHO_IDS.size(), 7)
	for id in ["bram", "wren", "cartographer"]:
		SaveManager.set_flag("echo_" + id)
	assert_true(not Story.ending_available("break"), "three is not enough now")
	assert_true(Story.ending_locked_reason("break").begins_with("needs five"))
	SaveManager.set_flag("echo_pell")
	SaveManager.set_flag("echo_choir")
	assert_true(Story.ending_available("break"), "five opens Break")
	assert_true(not Story.ending_visible("walk"))
	SaveManager.set_flag("echo_aldous")
	SaveManager.set_flag("echo_maren")
	assert_eq(Story.echoes_home(), 7)
	assert_true(Story.ending_visible("walk") and not Story.ending_available("walk"))
	SaveManager.data.wins = 3
	assert_true(Story.ending_available("walk"))
	assert_eq(Story.epilogue(), "")
	Story.record_ending("keep")
	assert_eq(Story.epilogue(), "keep")
	Story.record_ending("walk")
	assert_eq(Story.epilogue(), "walk", "the last ending chosen shapes the rock")
	assert_eq(Story.endings_seen(), ["keep", "walk"])
	assert_true(Story.orla().length() > 0 and Story.nessa().begins_with("The sea is only"))
	_done()


func test_save_migrates_from_version_one() -> void:
	var path := "user://test_migrate.json"
	var old := {"version": 1, "pearls": 33, "runs": 9, "wins": 1, "best_depth": 12, "total_kills": 200,
		"ledger": {"constitution": 2}, "flags": {"echo_bram": true, "echo_wren": true, "whisper_cage": true},
		"weapon": "harpoon", "weapons": ["gaff", "net", "harpoon"], "echoes": 1, "codex": {"enemy": ["gull"]}, "endings": []}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f = null
	SaveManager.use_path(path)
	assert_eq(int(SaveManager.data.version), 2, "migrated")
	assert_eq(int(SaveManager.data.pearls), 33, "pearls kept")
	assert_eq(int(SaveManager.data.echoes), 2, "echoes recounted from flags")
	assert_eq(Ledger.tier("constitution"), 2, "ledger kept")
	for k in ["affinity", "journals", "contracts_done", "log", "kills_by", "stats", "fish", "cosmetics", "keel", "epilogue"]:
		assert_true(SaveManager.data.has(k), "new key " + k)
	assert_eq(str(SaveManager.data.cosmetics.lantern), "warm")
	assert_true(Story.echo("bram") and Codex.found("enemy", "gull"))
	SaveManager.count("vaults")
	assert_eq(SaveManager.stat("vaults"), 1)
	SaveManager.record_run({"pearls": 5, "kills": 3, "depth": 4, "victory": true, "tier": 0, "weapon": "harpoon", "time": 100.0})
	assert_eq(SaveManager.stat("wins_harpoon"), 1)
	assert_eq(SaveManager.stat("pearls_earned"), 5)
	_done()


func test_run_state_ledger_and_fish_survive_json() -> void:
	var s := RunState.new()
	s.fish = ["eel", "cod"]
	s.fish_cap = 4
	s.rerolls = 1
	s.pearl_mult = 1.1
	s.stats = {"kills_gull": 3, "weapon": "line", "tide_at_boss_0": 1.25, "untouched_depth": 4}
	s.salt = 20
	s.pearls = 10
	s.victory = true
	var back := RunState.new()
	back.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.fish, ["eel", "cod"])
	assert_eq(back.fish_cap, 4)
	assert_eq(back.rerolls, 1)
	assert_near(back.pearl_mult, 1.1)
	assert_eq(back.stats.kills_gull, 3)
	assert_eq(back.stats.weapon, "line", "strings stay strings")
	assert_near(float(back.stats.tide_at_boss_0), 1.25)
	assert_true(typeof(back.stats.kills_gull) == TYPE_INT)
	var l := s.ledger()
	assert_true(l.victory and l.salt == 20 and l.weapon == "line" and l.untouched_depth == 4)
	assert_eq(s.result().pearls, 28, "the tithe pays on top: (10 pearls + 10 from salt + 5) x 1.1")
	assert_eq(s.result().weapon, "line")


func test_fish_and_codex_tabs() -> void:
	assert_eq(Fish.ORDER.size(), 4)
	for id in Fish.ORDER:
		assert_true(Fish.ALL.has(id) and int(Fish.ALL[id].price) > 0)
	assert_eq(Fish.name_of("eel"), "Smoked eel")
	assert_eq(Codex.TABS.size(), 7)
	for k in Codex.TABS:
		assert_true(Codex.entries(k).size() > 0, "codex tab %s has rows" % k)
	assert_eq(Codex.entries("journal").size(), 9)
	assert_eq(Codex.entries("contract").size(), Contracts.ALL.size())
	assert_eq(Codex.entries("weapon").size(), Weapon.ALL.size())
	assert_eq(Codex.PEOPLE.size(), 11, "everyone on the rock")
	for e in Codex.ENEMIES:
		assert_true(Codex.ENEMY_MORE.has(e.id), "second paragraph for " + e.id)
	_scratch("codex_more")
	var lore0: String = Codex.entries("enemy")[0].lore
	SaveManager.data["kills_by"] = {"shellback": 20}
	var lore1: String = Codex.entries("enemy")[0].lore
	assert_true(lore1.length() > lore0.length() and lore1.ends_with(Codex.ENEMY_MORE.shellback), "twenty kills earn the second paragraph")
	assert_true(not Codex.found("people", "nessa"))
	SaveManager.data.runs = 2
	assert_true(Codex.found("people", "nessa"), "Nessa comes down after two nights")
	_done()


func test_hub_template_has_room_for_the_village() -> void:
	var t := RoomTemplate.load_file("res://data/rooms/hub.txt")
	assert_eq(t.width, 40)
	assert_eq(t.height, 23)
	for m in ["O", "B", "W", "C", "N", "K", "S", "I", "L", "V", "Y", "d"]:
		assert_eq(t.marker_cells(m).size(), 1, "one spot for " + m)
	assert_true(t.marker_cells("l").size() >= 4, "lantern posts")
	for m in ["S", "I", "L", "V", "Y"]:
		var c: Vector2i = t.marker_cells(m)[0]
		assert_true(not t.is_solid(c.x, c.y), m + " stands on open ground")
	assert_eq(Prop.PORTRAIT.size(), 11)
	for id in NPCS:
		assert_true(Prop.PORTRAIT.has(id), "a portrait for " + id)
