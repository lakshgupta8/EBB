extends Node
## Persistent profile in user://save.json. Versioned; migrate() is the place for upgrades.

const PATH := "user://save.json"
const VERSION := 2

var data: Dictionary = _defaults()
var path: String = PATH


## Bots and tests point this at a scratch file so they never touch the real profile.
func use_path(p: String) -> void:
	path = p
	load_profile()


# --- M8: three save slots -----------------------------------------------------------------
## Slot 1 is the profile every earlier version wrote; 2 and 3 sit beside it.
static func slot_path(n: int) -> String:
	return PATH if n <= 1 else "user://save_%d.json" % n


func use_slot(n: int) -> void:
	use_path(slot_path(clampi(n, 1, 3)))


## The slot the profile came from; a scratch profile (bots, screenshots) reports the chosen slot.
func slot_in_use() -> int:
	for n in [1, 2, 3]:
		if path == slot_path(n):
			return n
	return Settings.slot()


## What a slot holds, without switching to it: {} when it is empty.
static func slot_summary(n: int) -> Dictionary:
	var p := slot_path(n)
	if not FileAccess.file_exists(p):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (parsed is Dictionary):
		return {}
	var flags: Dictionary = parsed.get("flags", {})
	var echoes := 0
	for id in Story.ECHO_IDS:
		if bool(flags.get("echo_" + id, false)):
			echoes += 1
	return {"runs": int(parsed.get("runs", 0)), "wins": int(parsed.get("wins", 0)), "pearls": int(parsed.get("pearls", 0)),
		"echoes": echoes, "endings": parsed.get("endings", []).size(), "weapon": str(parsed.get("weapon", "gaff")),
		"saved": int(parsed.get("saved", 0)), "suspended": parsed.get("suspended", {}) is Dictionary and not parsed.get("suspended", {}).is_empty()}


## Empty a slot: its file goes; the one in use starts fresh in memory too.
func wipe_slot(n: int) -> void:
	var p := slot_path(n)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if p == path:
		data = _defaults()


static func _defaults() -> Dictionary:
	return {
		"version": VERSION,
		"pearls": 0,
		"runs": 0,
		"wins": 0,
		"best_depth": 0,
		"total_kills": 0,
		"ledger": {},   # meta upgrades (M3)
		"flags": {},    # story flags: echo_bram, echo_wren, echo_cartographer...
		"weapon": "gaff",         # chosen at Bram's forge
		"weapons": ["gaff", "net"],  # forged so far
		"blessed_family": "",     # Wren: every altar offers this family
		"charted_room": -1,       # the Cartographer: room type guaranteed at depth 2
		"echoes": 0,
		"codex": {},              # kind -> [ids met]
		"endings": [],            # endings seen, in order
		"suspended": {},          # a night rested at a cleared room (Run.snapshot)
		"shards": 0,              # echo shards: from rescues, named elites and bosses; buy aspects
		"aspects": {},            # weapon id -> aspect id in use ("" or missing = plain)
		"aspects_owned": [],      # aspect ids bought from Bram
		"tide_tier": 0,           # spring tide chosen at the Ledger (0 = calm)
		"tide_unlocked": 0,       # highest tier that may be chosen; a win at tier n opens n+1
		# --- M7: the village ---
		"affinity": {},           # npc id -> level 0..3, raised with gifts
		"glass": 0,               # salt-glass, from dives: a gift
		"shells": 0,              # shells, from Fen's quests: a gift
		"journals": [],           # keeper journal pages found (1..9), in order found
		"contracts_done": [],     # Nessa's contracts completed, ever
		"contracts_offered": [],  # the three on offer for the next night
		"contracts_run": -1,      # the run number the offer was rolled for
		"fen_quest": 0,           # how far along Fen's shell chain you are
		"log": [],                # Keeper's Log milestones claimed
		"kills_by": {},           # enemy id -> kills, ever (the codex's second paragraph)
		"stats": {},              # counters the Log and contracts read (see Run.count)
		"fish": [],               # consumables carried into the next night (Nessa)
		"keel": "",               # Idris: the keel in use ("" = none)
		"keels_owned": [],
		"launch_harbour": false,  # Idris: the next night starts at the harbour
		"cosmetics": {"lantern": "warm", "coat": "keeper"},
		"cosmetics_owned": ["warm", "keeper"],
		"epilogue": "",           # the last ending chosen: the hub stays that way
		"chains_seen": [],        # affinity chains already read (skippable)
		"saved": 0,               # when the profile was last written (unix time)
		# --- M8: modes ---
		"history": [],            # the last fifty nights: date, seed, mode, weapon, depth, marks, time, cause
		"daily_scores": [],       # one entry per daily played: date, seed, depth, time, cause, pearls, assisted
	}


func _ready() -> void:
	use_slot(Settings.slot())


func load_profile() -> void:
	if not FileAccess.file_exists(path):
		data = _defaults()
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		data = _defaults()
		data.merge(parsed, true)
		migrate()
	else:
		push_warning("save.json unreadable, starting fresh")
		data = _defaults()


func save_profile() -> void:
	data["saved"] = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


## Older profiles: fill in what they never had, recount what changed meaning.
func migrate() -> void:
	var from := int(data.get("version", 1))
	var fresh := _defaults()
	for k in fresh:
		if not data.has(k):
			data[k] = fresh[k]
		elif typeof(data[k]) != typeof(fresh[k]):
			# JSON hands every number back as a float; anything else of the wrong shape is reset.
			if fresh[k] is int and data[k] is float:
				data[k] = int(data[k])
			elif fresh[k] is bool and (data[k] is float or data[k] is int):
				data[k] = bool(data[k])
			elif not (fresh[k] is float and data[k] is int):
				data[k] = fresh[k]
	for k in fresh.cosmetics:
		if not data.cosmetics.has(k):
			data.cosmetics[k] = fresh.cosmetics[k]
	# Page numbers come back from JSON as floats; keep them ints so `in` finds them.
	var pages: Array = []
	for n in data.get("journals", []):
		if not int(n) in pages:
			pages.append(int(n))
	data["journals"] = pages
	if from < 2:
		# Echoes are now counted from their flags: seven people can come home, and the
		# old counter only ever knew four.
		var n := 0
		for id in Story.ECHO_IDS:
			if flag("echo_" + id):
				n += 1
		data["echoes"] = maxi(n, int(data.get("echoes", 0)))
	data["version"] = VERSION


## Story flags survive a lost run: set the moment something happens.
func set_flag(name: String, value: bool = true) -> void:
	data["flags"][name] = value
	save_profile()


func flag(name: String) -> bool:
	return bool(data["flags"].get(name, false))


## A counter in the profile's stats (the Log and the contracts read these).
func count(key: String, by: int = 1) -> void:
	data["stats"][key] = int(data["stats"].get(key, 0)) + by


func stat(key: String) -> int:
	return int(data.get("stats", {}).get(key, 0))


const HISTORY_KEEP := 50


func record_run(result: Dictionary) -> void:
	data["runs"] += 1
	var mode := str(result.get("mode", "night"))
	count("runs_" + mode)
	if mode == "daily":
		count("dailies")
	_record_history(result)
	data["pearls"] += int(result.get("pearls", 0))
	data["total_kills"] += int(result.get("kills", 0))
	data["best_depth"] = maxi(int(data["best_depth"]), int(result.get("depth", 0)))
	count("pearls_earned", int(result.get("pearls", 0)))
	count("time_played", int(result.get("time", 0.0)))
	if result.get("victory", false):
		data["wins"] += 1
		var t := int(result.get("tier", 0))
		if t >= int(data.get("tide_unlocked", 0)):
			data["tide_unlocked"] = mini(8, t + 1)
		count("wins_" + str(result.get("weapon", "")))
		count("wins_tier_%d" % t)
		if mode != "night":
			count("wins_" + mode)
	elif result.get("taken", false):
		count("taken")
	else:
		count("deaths")
	data["suspended"] = {}  # a finished night cannot also be waiting at the shore
	save_profile()


## The night goes into the history (the last fifty) and, for a daily, onto the board.
func _record_history(result: Dictionary) -> void:
	var entry := {"date": Modes.today(), "seed": int(result.get("seed", 0)), "mode": str(result.get("mode", "night")),
		"weapon": str(result.get("weapon", "")), "depth": int(result.get("depth", 0)), "marks": result.get("marks", []).duplicate(),
		"time": snappedf(float(result.get("time", 0.0)), 0.1), "cause": Modes.cause_of(result), "pearls": int(result.get("pearls", 0)),
		"tier": int(result.get("tier", 0)), "assisted": float(result.get("assist_mult", 1.0)) < 1.0}
	var hist: Array = data.get("history", [])
	hist.append(entry)
	while hist.size() > HISTORY_KEEP:
		hist.pop_front()
	data["history"] = hist
	if entry.mode == "daily":
		var board: Array = data.get("daily_scores", [])
		board.append(entry.duplicate())
		while board.size() > HISTORY_KEEP:
			board.pop_front()
		data["daily_scores"] = board


func wipe() -> void:
	data = _defaults()
	save_profile()
