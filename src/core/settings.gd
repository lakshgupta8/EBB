extends Node
## Player settings in user://settings.json: volumes, screen shake, flashes, fullscreen.
## Creates the Music and SFX buses so the sliders have something to move.

const PATH := "user://settings.json"
const DEFAULTS := {
	"master": 0.8,     # 0..1
	"music": 0.6,
	"sfx": 1.0,
	"shake": 1.0,      # 0 off, 0.5 low, 1 full
	"flash": true,     # full-screen flashes (riptide, rescues, the flare)
	"fullscreen": true,
}

var data: Dictionary = DEFAULTS.duplicate()
var path: String = PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	load_settings()
	apply()


func _make_buses() -> void:
	for name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(name) == -1:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, "Master")


func load_settings() -> void:
	data = DEFAULTS.duplicate()
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for k in DEFAULTS:
			if parsed.has(k):
				data[k] = parsed[k]


func save_settings() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func set_value(key: String, value) -> void:
	if not DEFAULTS.has(key):
		return
	if DEFAULTS[key] is float:
		value = clampf(float(value), 0.0, 1.0)
	elif DEFAULTS[key] is bool:
		value = bool(value)
	data[key] = value
	apply()
	save_settings()


func value(key: String):
	return data.get(key, DEFAULTS.get(key))


## Push every setting into the engine.
func apply() -> void:
	_bus("Master", float(data.master))
	_bus("Music", float(data.music))
	_bus("SFX", float(data.sfx))
	var w := get_window()
	if w == null:
		return
	var is_full := w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	if bool(data.fullscreen) and not is_full:
		w.mode = Window.MODE_FULLSCREEN
	elif not bool(data.fullscreen) and is_full:
		w.mode = Window.MODE_WINDOWED
		w.size = Vector2i(1280, 720)
		w.move_to_center()


func _bus(name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(name)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, linear <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.001)))


## Camera shake multiplier (0, 0.5, 1).
func shake() -> float:
	return float(data.shake)


func flashes() -> bool:
	return bool(data.flash)
