class_name Contracts
extends RefCounted
## Nessa's contracts: three on the board every night, each done once, paid in pearls (and
## sometimes shards or a fish). Every one is judged from the night's own counters
## (RunState.stats) when the night ends, so a bot can complete any of them.
## Kinds: kills (arg = enemy id, n), stat (arg = a run counter, n), untouched (n = depth
## reached before the first hit), boss (arg = boss id), win_weapon (arg), win_tier (n),
## tide_boss (arg = biome index, max = tide level at its boss), no_shop, salt (n), rest.

const OFFER := 3

const ALL := [
	{"id": "gulls", "name": "Gull cull", "desc": "kill 6 salt gulls in one night", "kind": "kills", "arg": "gull", "n": 6, "pearls": 8},
	{"id": "shells", "name": "Shell the shellbacks", "desc": "kill 8 shellbacks in one night", "kind": "kills", "arg": "shellback", "n": 8, "pearls": 8},
	{"id": "crabs", "name": "Crab pots", "desc": "kill 5 wrack crabs in one night", "kind": "kills", "arg": "wrack_crab", "n": 5, "pearls": 8},
	{"id": "wisps", "name": "Lights out", "desc": "kill 3 tidewisps in one night", "kind": "kills", "arg": "tidewisp", "n": 3, "pearls": 10},
	{"id": "hands", "name": "Cast off", "desc": "kill 6 moorings in one night", "kind": "kills", "arg": "mooring", "n": 6, "pearls": 12},
	{"id": "swarm", "name": "Scrape the hulls", "desc": "kill 8 barnacle swarms in one night", "kind": "kills", "arg": "barnacle", "n": 8, "pearls": 12},
	{"id": "deck", "name": "Behind the shield", "desc": "kill 5 deckhands in one night", "kind": "kills", "arg": "deckhand", "n": 5, "pearls": 12},
	{"id": "citizens", "name": "Still life", "desc": "kill 10 still citizens in one night", "kind": "kills", "arg": "still_citizen", "n": 10, "pearls": 14},
	{"id": "lamps", "name": "Lamps out", "desc": "kill 4 lamplighters in one night", "kind": "kills", "arg": "lamplighter", "n": 4, "pearls": 14},
	{"id": "ringers", "name": "Quiet bells", "desc": "kill 3 bell ringers in one night", "kind": "kills", "arg": "bell_ringer", "n": 3, "pearls": 14},
	{"id": "swimmers", "name": "Out of the water", "desc": "kill 4 swimmers in one night", "kind": "kills", "arg": "swimmer", "n": 4, "pearls": 14},
	{"id": "shades", "name": "Old keepers", "desc": "kill 4 keeper's shades in one night", "kind": "kills", "arg": "keeper_shade", "n": 4, "pearls": 18},
	{"id": "anchors", "name": "Weigh anchor", "desc": "kill 4 anchors in one night", "kind": "kills", "arg": "anchor", "n": 4, "pearls": 18},
	{"id": "maws", "name": "Close the mouths", "desc": "kill 3 deep maws in one night", "kind": "kills", "arg": "deep_maw", "n": 3, "pearls": 18},
	{"id": "forty", "name": "A long night", "desc": "40 kills in one night", "kind": "stat", "arg": "kills", "n": 40, "pearls": 15},
	{"id": "hundred", "name": "The whole street", "desc": "100 kills in one night", "kind": "stat", "arg": "kills", "n": 100, "pearls": 30, "shards": 1},
	{"id": "clean_5", "name": "Dry boots", "desc": "reach the fifth room without being hit", "kind": "untouched", "n": 5, "pearls": 15},
	{"id": "clean_9", "name": "Not a scratch", "desc": "reach the ninth room without being hit", "kind": "untouched", "n": 9, "pearls": 30, "shards": 1},
	{"id": "wreck", "name": "The boat", "desc": "break the Wreck", "kind": "boss", "arg": "wreck", "pearls": 12},
	{"id": "crane", "name": "The crane", "desc": "break the Chainmother", "kind": "boss", "arg": "chainmother", "pearls": 18},
	{"id": "bell", "name": "The bell", "desc": "silence the Bell of Saltmere", "kind": "boss", "arg": "bell", "pearls": 24},
	{"id": "wet2", "name": "Two wet rooms", "desc": "clear two wet rooms in one night", "kind": "stat", "arg": "wet_rooms", "n": 2, "pearls": 14},
	{"id": "hold", "name": "Hold", "desc": "hold a challenge until the tide turns", "kind": "stat", "arg": "challenges", "n": 1, "pearls": 12},
	{"id": "vault", "name": "The strongroom", "desc": "open a vault", "kind": "stat", "arg": "vaults", "n": 1, "pearls": 12},
	{"id": "dive", "name": "Go under", "desc": "take the altar in a dive", "kind": "stat", "arg": "dives", "n": 1, "pearls": 12},
	{"id": "named", "name": "The one with a name", "desc": "kill a named elite", "kind": "stat", "arg": "named_elites", "n": 1, "pearls": 16, "shards": 1},
	{"id": "salt150", "name": "Salt the sea", "desc": "end a night carrying 150 salt", "kind": "salt", "n": 150, "pearls": 15},
	{"id": "marks8", "name": "Marked", "desc": "hold eight tidemarks at once", "kind": "stat", "arg": "marks", "n": 8, "pearls": 15},
	{"id": "flares", "name": "Burn it", "desc": "flare the lantern 5 times in one night", "kind": "stat", "arg": "flares", "n": 5, "pearls": 12},
	{"id": "riptides", "name": "Read the sea", "desc": "riptide 8 times in one night", "kind": "stat", "arg": "riptides", "n": 8, "pearls": 16},
	{"id": "no_shop", "name": "Nothing bought", "desc": "win a night without buying from the merchant", "kind": "no_shop", "pearls": 25, "fish": "eel"},
	{"id": "win_bell", "name": "Ring it home", "desc": "win a night with the Keeper's Bell", "kind": "win_weapon", "arg": "bell", "pearls": 25, "shards": 1},
	{"id": "win_line", "name": "Line home", "desc": "win a night with the Line & Sinker", "kind": "win_weapon", "arg": "line", "pearls": 25, "shards": 1},
	{"id": "tide2", "name": "Spring tide", "desc": "win at spring tide 2 or higher", "kind": "win_tier", "n": 2, "pearls": 30, "shards": 1},
	{"id": "quick_wreck", "name": "Before the water", "desc": "reach the Wreck with the tide under 1.3", "kind": "tide_boss", "arg": 0, "max": 1.3, "pearls": 16},
	{"id": "rested", "name": "Sleep on it", "desc": "rest a night and still win it", "kind": "rest", "pearls": 20, "fish": "broth"},
]


static func get_contract(id: String) -> Dictionary:
	for c in ALL:
		if c.id == id:
			return c
	return {}


## Does the night's ledger satisfy a contract? `s` is RunState.stats plus the fields
## RunState.result() adds (victory, weapon, tier, salt).
static func check(c: Dictionary, s: Dictionary) -> bool:
	match str(c.kind):
		"kills": return int(s.get("kills_" + str(c.arg), 0)) >= int(c.n)
		"stat": return int(s.get(str(c.arg), 0)) >= int(c.n)
		"untouched": return int(s.get("untouched_depth", 0)) >= int(c.n)
		"boss": return int(s.get("boss_" + str(c.arg), 0)) >= 1
		"win_weapon": return bool(s.get("victory", false)) and str(s.get("weapon", "")) == str(c.arg)
		"win_tier": return bool(s.get("victory", false)) and int(s.get("tier", 0)) >= int(c.n)
		"tide_boss":
			var key := "tide_at_boss_%d" % int(c.arg)
			return s.has(key) and float(s[key]) <= float(c.max)
		"no_shop": return bool(s.get("victory", false)) and int(s.get("shop_buys", 0)) == 0
		"salt": return int(s.get("salt", 0)) >= int(c.n)
		"rest": return bool(s.get("victory", false)) and int(s.get("rested", 0)) >= 1
	return false


static func done() -> Array:
	return SaveManager.data.get("contracts_done", [])


## The three on the board for the coming night: rolled once per run number from the
## contracts not yet done, so the offer holds until a night is played.
static func offered() -> Array:
	var d := SaveManager.data
	var runs := int(d.get("runs", 0))
	if int(d.get("contracts_run", -1)) == runs:
		return d["contracts_offered"]
	var pool: Array = []
	for c in ALL:
		if not c.id in done():
			pool.append(c.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7777 + runs * 131
	var out: Array = []
	while out.size() < OFFER and pool.size() > 0:
		var k := rng.randi() % pool.size()
		out.append(pool[k])
		pool.remove_at(k)
	d["contracts_offered"] = out
	d["contracts_run"] = runs
	SaveManager.save_profile()
	return out


## Judge the offered contracts against a finished night. Pays out and returns the ones
## completed (call once per run, before record_run bumps the run number).
static func settle(s: Dictionary) -> Array:
	var completed: Array = []
	var list: Array = done()
	for id in offered():
		var c := get_contract(id)
		if c.is_empty() or id in list or not check(c, s):
			continue
		list.append(id)
		completed.append(c)
		SaveManager.data["pearls"] = int(SaveManager.data.pearls) + int(c.get("pearls", 0))
		SaveManager.data["shards"] = int(SaveManager.data.get("shards", 0)) + int(c.get("shards", 0))
		if c.has("fish"):
			SaveManager.data["fish"].append(str(c.fish))
		SaveManager.count("contracts")
	SaveManager.data["contracts_done"] = list
	SaveManager.data["contracts_offered"] = []
	SaveManager.save_profile()
	return completed
