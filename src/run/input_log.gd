class_name InputLog
extends RefCounted
## A night's inputs, one row per physics tick: which actions were down and where the aim
## pointed, plus the keeper's position every few ticks. Written to user://replays/ when
## the night ends, so a bug can be sent as a file and played back with `--replay=<file>`
## (same seed, same graph and drops; the fight itself replays as closely as the frame
## rate allows). The same file draws the faint ghost of the last night on the same seed.

const DIR := "user://replays/"
const KEEP := 10  # files kept; older ones go
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "dash", "attack", "special",
	"interact", "use_item", "active", "consume"]
const POS_EVERY := 4

var seed_value: int = 0
var weapon: String = ""
var tier: int = 0
var mode: String = "night"
var ticks: Array = []      # [mask, aim_x * 100, aim_y * 100]
var positions: Array = []  # [depth_total, tick in room, x, y]
var _room_tick: int = 0
var _room_depth: int = -1
var _play_at: int = 0


## --- recording -------------------------------------------------------------------
func record(player: Player, depth_total: int) -> void:
	var mask := 0
	for i in ACTIONS.size():
		if Input.is_action_pressed(ACTIONS[i]):
			mask |= 1 << i
	ticks.append([mask, int(round(player.aim.x * 100.0)), int(round(player.aim.y * 100.0))])
	if depth_total != _room_depth:
		_room_depth = depth_total
		_room_tick = 0
	if _room_tick % POS_EVERY == 0:
		positions.append([depth_total, _room_tick, int(round(player.global_position.x)), int(round(player.global_position.y))])
	_room_tick += 1


func to_dict() -> Dictionary:
	return {"version": 1, "seed": seed_value, "weapon": weapon, "tier": tier, "mode": mode,
		"written": int(Time.get_unix_time_from_system()), "ticks": ticks, "positions": positions}


## Write the log and prune the folder to the newest KEEP files. Returns the path.
func save() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var name := "replay_%d_%d.json" % [seed_value, int(Time.get_unix_time_from_system())]
	var f := FileAccess.open(DIR + name, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))
	var files := list_files()
	while files.size() > KEEP:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + files.pop_back()))
	return DIR + name


## Replay files, newest first.
static func list_files() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(DIR)):
		return out
	for f in DirAccess.get_files_at(DIR):
		if f.begins_with("replay_") and f.ends_with(".json"):
			out.append(f)
	out.sort_custom(func(a, b): return _stamp(a) > _stamp(b))
	return out


static func _stamp(name: String) -> int:
	var parts := name.trim_suffix(".json").split("_")
	return int(parts[2]) if parts.size() >= 3 else 0


static func load_file(path: String) -> InputLog:
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return null
	var log := InputLog.new()
	log.seed_value = int(parsed.get("seed", 0))
	log.weapon = str(parsed.get("weapon", ""))
	log.tier = int(parsed.get("tier", 0))
	log.mode = str(parsed.get("mode", "night"))
	for t in parsed.get("ticks", []):
		log.ticks.append([int(t[0]), int(t[1]), int(t[2])])
	for p in parsed.get("positions", []):
		log.positions.append([int(p[0]), int(p[1]), int(p[2]), int(p[3])])
	return log


## The newest log played on this seed, or null.
static func latest_for_seed(seed_value: int) -> InputLog:
	for f in list_files():
		if f.begins_with("replay_%d_" % seed_value):
			return load_file(DIR + f)
	return null


static func latest() -> String:
	var files := list_files()
	return DIR + files[0] if files.size() > 0 else ""


## --- playback ---------------------------------------------------------------------
func done() -> bool:
	return _play_at >= ticks.size()


## Press this tick's actions and aim the keeper where the log says.
func play_tick(player: Player) -> void:
	if done():
		return
	var t: Array = ticks[_play_at]
	_play_at += 1
	var mask: int = t[0]
	for i in ACTIONS.size():
		if mask & (1 << i):
			Input.action_press(ACTIONS[i])
		else:
			Input.action_release(ACTIONS[i])
	var aim := Vector2(float(t[1]) / 100.0, float(t[2]) / 100.0)
	player.aim_override = aim if aim.length() > 0.1 else Vector2(1, 0)


## Where the keeper stood in room `depth_total` at `tick` into it: the last sample at or
## before that tick, so the ghost is never ahead of where it was. Vector2.INF when the log
## never reached that room. The ghost asks this every physics
## tick, so the samples are indexed by room the first time and walked with a cursor.
var _by_room: Dictionary = {}   # depth -> Array of [tick, x, y]
var _cursor_room: int = -1
var _cursor: int = 0


func position_at(depth_total: int, tick: int) -> Vector2:
	if _by_room.is_empty() and positions.size() > 0:
		for p in positions:
			var list: Array = _by_room.get(int(p[0]), [])
			list.append([int(p[1]), int(p[2]), int(p[3])])
			_by_room[int(p[0])] = list
	var room: Array = _by_room.get(depth_total, [])
	if room.is_empty():
		return Vector2.INF
	if depth_total != _cursor_room:
		_cursor_room = depth_total
		_cursor = 0
	# Walk forward to the last sample at or before this tick; the ghost only moves forward.
	while _cursor + 1 < room.size() and int(room[_cursor + 1][0]) <= tick:
		_cursor += 1
	while _cursor > 0 and int(room[_cursor][0]) > tick:
		_cursor -= 1
	var at: Array = room[_cursor]
	return Vector2(at[1], at[2])
