class_name Dialog
extends RefCounted
## Dialogue that lives in data/dialog/*.json rather than in code, so it can be linted and
## grown without touching a script.
##   npcs.json      {npc: [{"when": [conditions], "text": "..."}, ...]}  first match wins
##   affinity.json  {npc: [{"lines": [...], "reward": {...}}, ...]}      one chain per level
## Conditions are small strings: "flag:echo_bram", "!flag:x", "wins>=2", "runs>=3",
## "ending:break", "!ending:walk", "any_ending", "!any_ending", "epilogue:keep",
## "affinity:nessa>=2", "journals>=9", "echoes>=5", "fen>=3", "stat:vaults>=1",
## "best_depth>=9", "shards>=4", "log>=10", "contracts>=5", "fish>=1", "keel", "!keel".

const DIR := "res://data/dialog/"

static var _cache: Dictionary = {}


static func load_file(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + ".json"
	var out := {}
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			out = parsed
	_cache[name] = out
	return out


static func clear_cache() -> void:
	_cache = {}


## Every condition in the list holds (an empty list always holds).
static func when(conds: Array) -> bool:
	for c in conds:
		if not check(str(c)):
			return false
	return true


## Parse "key>=N" into [key, N], or [] when it is not a comparison.
static func _cmp(s: String) -> Array:
	var at := s.find(">=")
	if at < 0:
		return []
	return [s.substr(0, at), int(s.substr(at + 2))]


static func check(cond: String) -> bool:
	if cond.begins_with("!"):
		return not check(cond.substr(1))
	var d := SaveManager.data
	if cond.begins_with("flag:"):
		return SaveManager.flag(cond.substr(5))
	if cond.begins_with("ending:"):
		return Story.seen(cond.substr(7))
	if cond.begins_with("epilogue:"):
		return str(d.get("epilogue", "")) == cond.substr(9)
	if cond == "any_ending":
		return not Story.endings_seen().is_empty()
	if cond == "keel":
		return str(d.get("keel", "")) != ""
	var c := _cmp(cond)
	if c.is_empty():
		push_warning("dialog: unknown condition " + cond)
		return false
	var key: String = c[0]
	var n: int = c[1]
	if key.begins_with("affinity:"):
		return Story.affinity(key.substr(9)) >= n
	if key.begins_with("stat:"):
		return SaveManager.stat(key.substr(5)) >= n
	match key:
		"wins": return Story.wins() >= n
		"runs": return Story.runs() >= n
		"journals": return d.get("journals", []).size() >= n
		"echoes": return Story.echoes_home() >= n
		"fen": return int(d.get("fen_quest", 0)) >= n
		"best_depth": return int(d.get("best_depth", 0)) >= n
		"shards": return int(d.get("shards", 0)) >= n
		"log": return d.get("log", []).size() >= n
		"contracts": return d.get("contracts_done", []).size() >= n
		"fish": return d.get("fish", []).size() >= n
		"pearls": return int(d.get("pearls", 0)) >= n
		"endings": return Story.endings_seen().size() >= n
	push_warning("dialog: unknown condition " + cond)
	return false


## Is every condition string in the file one this parser knows? (for the lint test)
static func valid_condition(cond: String) -> bool:
	if cond.begins_with("!"):
		cond = cond.substr(1)
	for p in ["flag:", "ending:", "epilogue:"]:
		if cond.begins_with(p):
			return cond.length() > p.length()
	if cond in ["any_ending", "keel"]:
		return true
	var c := _cmp(cond)
	if c.is_empty():
		return false
	var key: String = c[0]
	if key.begins_with("affinity:") or key.begins_with("stat:"):
		return true
	return key in ["wins", "runs", "journals", "echoes", "fen", "best_depth", "shards", "log", "contracts", "fish", "pearls", "endings"]


## What `npc` says now: the first entry whose conditions hold.
static func line(npc: String) -> String:
	for entry in load_file("npcs").get(npc, []):
		if when(entry.get("when", [])):
			return str(entry.get("text", ""))
	return ""


## The affinity chain for `npc` at `level` (1..3): {lines, reward}, or {} when there is none.
static func chain(npc: String, level: int) -> Dictionary:
	var chains: Array = load_file("affinity").get(npc, [])
	if level < 1 or level > chains.size():
		return {}
	return chains[level - 1]


static func chain_count(npc: String) -> int:
	return load_file("affinity").get(npc, []).size()
