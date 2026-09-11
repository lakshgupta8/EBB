extends Node
## Persistent profile in user://save.json. Versioned; migrate() is the place for upgrades.

const PATH := "user://save.json"
const VERSION := 1

var data: Dictionary = _defaults()
var path: String = PATH


## Bots and tests point this at a scratch file so they never touch the real profile.
func use_path(p: String) -> void:
	path = p
	load_profile()


static func _defaults() -> Dictionary:
	return {
		"version": VERSION,
		"pearls": 0,
		"runs": 0,
		"wins": 0,
		"best_depth": 0,
		"total_kills": 0,
		"ledger": {},   # meta upgrades (M3)
		"flags": {},    # story flags (M3+)
	}


func _ready() -> void:
	load_profile()


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
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func migrate() -> void:
	data["version"] = VERSION


func record_run(result: Dictionary) -> void:
	data["runs"] += 1
	data["pearls"] += int(result.get("pearls", 0))
	data["total_kills"] += int(result.get("kills", 0))
	data["best_depth"] = maxi(int(data["best_depth"]), int(result.get("depth", 0)))
	if result.get("victory", false):
		data["wins"] += 1
	save_profile()


func wipe() -> void:
	data = _defaults()
	save_profile()
