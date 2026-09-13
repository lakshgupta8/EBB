extends Node
## Player settings in user://settings.json: volumes, screen shake, flashes, fullscreen,
## dialogue, hints, and (M8) key and pad bindings, assists, accessibility, the save slot.
## Creates the Music and SFX buses so the sliders have something to move. Settings are
## global: they belong to the machine, not to a save slot.

signal changed(key: String)

const PATH := "user://settings.json"
const DEFAULTS := {
	"master": 0.8,     # 0..1
	"music": 0.6,
	"sfx": 1.0,
	"shake": 1.0,      # 0 off, 0.5 low, 1 full
	"flash": true,     # full-screen flashes (riptide, rescues, the flare)
	"fullscreen": true,
	"dialog_speed": 1.0,  # letters per tick of talk: 0.5 slow, 1 normal, 2 fast; 0 = at once
	"skip_seen": false,   # chains already read show all at once
	"hints": true,        # journal hints and the door's second look
	# --- M8: options ---
	"keys": {},           # action -> {"key": physical keycode, "mouse": button, "pad": button}; missing = default
	"assist_tide": 1.0,   # the tide rises this much as fast: 1, 0.75, 0.5
	"assist_damage": 1.0, # damage taken is scaled by this: 1, 0.75, 0.5
	"assist_aim": false,  # the aim leans toward the nearest enemy
	"water_tint": "sea",  # sea / amber (colourblind-safe) / high (high contrast)
	"hud_scale": 1.0,     # 1, 1.25, 1.5
	"text_size": 1.0,     # menus and prompts: 1, 1.25, 1.5
	"reduced_motion": false,  # no shake, no flashes, no slow time, no edge pulses
	"ghost": true,        # the last night on this seed walks beside you, faint
	"slot": 1,            # the save slot in use (1..3)
}
## Values a float setting may take (anything else is clamped to 0..1).
const RANGES := {"dialog_speed": [0.0, 2.0], "assist_tide": [0.5, 1.0], "assist_damage": [0.5, 1.0],
	"hud_scale": [1.0, 1.5], "text_size": [1.0, 1.5]}
const WATER_TINTS := {
	"sea": {"name": "sea", "color": Color(1, 1, 1, 0.62)},
	"amber": {"name": "amber (colourblind)", "color": Color(1.0, 0.72, 0.4, 0.72)},
	"high": {"name": "high contrast", "color": Color(1.35, 1.35, 1.6, 0.85)},
}

## Actions a player can rebind, in the order the controls menu lists them.
const BINDABLE := ["move_up", "move_down", "move_left", "move_right", "dash", "attack", "special",
	"interact", "use_item", "active", "consume", "codex", "pause"]
const ACTION_NAMES := {"move_up": "Move up", "move_down": "Move down", "move_left": "Move left", "move_right": "Move right",
	"dash": "Dash", "attack": "Attack", "special": "Special", "interact": "Use / talk", "use_item": "Lantern flare",
	"active": "Active tidemark", "consume": "Eat", "codex": "Codex", "pause": "Pause"}
const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "d-pad up", JOY_BUTTON_DPAD_DOWN: "d-pad down", JOY_BUTTON_DPAD_LEFT: "d-pad left", JOY_BUTTON_DPAD_RIGHT: "d-pad right"}
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5"}

var data: Dictionary = DEFAULTS.duplicate(true)
var path: String = PATH
## The project's own bindings, read from the InputMap before anything is changed.
var _default_events: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	for a in BINDABLE:
		_default_events[a] = InputMap.action_get_events(a).duplicate()
	# Bots and screenshots keep off the real settings: `--sim-save` uses a scratch file,
	# and `--set=key:value` sets a value for that run (say `--set=hud_scale:1.5`).
	var args := OS.get_cmdline_user_args()
	if "--sim-save" in args:
		path = "user://sim_settings.json"
	load_settings()
	for a in args:
		if a.begins_with("--set="):
			var kv := a.trim_prefix("--set=").split(":")
			if kv.size() == 2 and DEFAULTS.has(kv[0]):
				var v = kv[1]
				if DEFAULTS[kv[0]] is bool:
					v = kv[1] in ["true", "on", "1"]
				elif DEFAULTS[kv[0]] is float:
					v = float(kv[1])
				elif DEFAULTS[kv[0]] is int:
					v = int(kv[1])
				data[kv[0]] = v
	apply()


func _make_buses() -> void:
	for name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(name) == -1:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, "Master")


func load_settings() -> void:
	data = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for k in DEFAULTS:
			if parsed.has(k):
				data[k] = _coerce(k, parsed[k])


## JSON hands numbers back as floats and knows nothing of our types.
func _coerce(key: String, value):
	var d = DEFAULTS[key]
	if d is bool:
		return bool(value)
	if d is int:
		return int(value)
	if d is float:
		return float(value)
	if d is String:
		return str(value)
	if d is Dictionary:
		return value if value is Dictionary else {}
	return value


func save_settings() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func set_value(key: String, value) -> void:
	if not DEFAULTS.has(key):
		return
	if DEFAULTS[key] is float:
		var r: Array = RANGES.get(key, [0.0, 1.0])
		value = clampf(float(value), r[0], r[1])
	elif DEFAULTS[key] is bool:
		value = bool(value)
	elif DEFAULTS[key] is int:
		value = int(value)
	elif DEFAULTS[key] is String:
		value = str(value)
	data[key] = value
	apply()
	save_settings()
	changed.emit(key)


func value(key: String):
	return data.get(key, DEFAULTS.get(key))


## Push every setting into the engine.
func apply() -> void:
	_bus("Master", float(data.master))
	_bus("Music", float(data.music))
	_bus("SFX", float(data.sfx))
	apply_bindings()
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


## Camera shake multiplier (0, 0.5, 1); none at all under reduced motion.
func shake() -> float:
	return 0.0 if reduced_motion() else float(data.shake)


func flashes() -> bool:
	return bool(data.flash) and not reduced_motion()


func dialog_speed() -> float:
	return float(data.get("dialog_speed", 1.0))


func skip_seen() -> bool:
	return bool(data.get("skip_seen", false))


func hints() -> bool:
	return bool(data.get("hints", true))


# --- M8: accessibility and assists ---------------------------------------------------
func reduced_motion() -> bool:
	return bool(data.get("reduced_motion", false))


func hud_scale() -> float:
	return float(data.get("hud_scale", 1.0))


func text_scale() -> float:
	return float(data.get("text_size", 1.0))


func water_tint() -> Color:
	return WATER_TINTS.get(str(data.get("water_tint", "sea")), WATER_TINTS.sea).color


func assist_tide() -> float:
	return float(data.get("assist_tide", 1.0))


func assist_damage() -> float:
	return float(data.get("assist_damage", 1.0))


func assist_aim() -> bool:
	return bool(data.get("assist_aim", false))


func assists_on() -> bool:
	return assist_tide() < 1.0 or assist_damage() < 1.0 or assist_aim()


## Assists are a trade, not a cheat: pearls at the end of a night are scaled by this.
## A slower tide or softer hits at three quarters pay 85%, at half 70%; aim help 90%.
func assist_pearl_mult() -> float:
	var m := 1.0
	for v in [assist_tide(), assist_damage()]:
		if v <= 0.5:
			m *= 0.7
		elif v < 1.0:
			m *= 0.85
	if assist_aim():
		m *= 0.9
	return m


func ghost() -> bool:
	return bool(data.get("ghost", true))


func slot() -> int:
	return clampi(int(data.get("slot", 1)), 1, 3)


# --- M8: bindings ----------------------------------------------------------------------
## What an action is bound to on each device: {"key": physical keycode or 0,
## "mouse": button or 0, "pad": button or -1}. Overrides sit on top of the project's defaults.
func binding(action: String) -> Dictionary:
	var b := {"key": 0, "mouse": 0, "pad": -1}
	for ev in _default_events.get(action, []):
		if ev is InputEventKey:
			b.key = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		elif ev is InputEventMouseButton:
			b.mouse = ev.button_index
		elif ev is InputEventJoypadButton:
			b.pad = ev.button_index
	var o = data.get("keys", {}).get(action, null)
	if o is Dictionary:
		for k in ["key", "mouse", "pad"]:
			if o.has(k):
				b[k] = int(o[k])
	return b


func is_rebound(action: String) -> bool:
	return data.get("keys", {}).has(action)


## Bind `action` to the device of `event` (a key, a mouse button or a pad button). Another
## bindable action already holding that input takes this action's old one, so a swap leaves
## both with a key. When this action had nothing on that device (the move keys carry no pad
## button: the stick does), the other action simply loses it there and keeps its other
## devices. False when the event is not something bindable.
func bind(action: String, event: InputEvent) -> bool:
	if not action in BINDABLE:
		return false
	var device := ""
	var code := 0
	if event is InputEventKey:
		device = "key"
		code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_ESCAPE:
			return false  # Esc always backs out of menus
	elif event is InputEventMouseButton:
		device = "mouse"
		code = event.button_index
		if code in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return false
	elif event is InputEventJoypadButton:
		device = "pad"
		code = event.button_index
	else:
		return false
	var mine := binding(action)
	var old: int = mine[device]
	if old == code:
		return true
	for other in BINDABLE:
		if other != action and binding(other)[device] == code:
			_set_binding(other, device, old)
	_set_binding(action, device, code)
	apply_bindings()
	save_settings()
	changed.emit("keys")
	return true


func _set_binding(action: String, device: String, code: int) -> void:
	var keys: Dictionary = data.get("keys", {})
	var o: Dictionary = keys.get(action, {})
	o[device] = code
	keys[action] = o
	data["keys"] = keys


func reset_bindings() -> void:
	data["keys"] = {}
	apply_bindings()
	save_settings()
	changed.emit("keys")


## Rebuild the InputMap: every bindable action gets its key, mouse and pad button from
## `binding()`, and keeps the project's stick and trigger axes as they were.
func apply_bindings() -> void:
	for a in BINDABLE:
		if not InputMap.has_action(a):
			continue
		var b := binding(a)
		InputMap.action_erase_events(a)
		if int(b.key) != 0:
			var k := InputEventKey.new()
			k.physical_keycode = int(b.key) as Key
			InputMap.action_add_event(a, k)
		if int(b.mouse) != 0:
			var m := InputEventMouseButton.new()
			m.button_index = int(b.mouse) as MouseButton
			InputMap.action_add_event(a, m)
		if int(b.pad) >= 0:
			var j := InputEventJoypadButton.new()
			j.button_index = int(b.pad) as JoyButton
			InputMap.action_add_event(a, j)
		for ev in _default_events.get(a, []):
			if ev is InputEventJoypadMotion:
				InputMap.action_add_event(a, ev)


## The key for an action, as a label ("E", "Space", "LMB"); "" when nothing is bound.
func key_name(action: String) -> String:
	var b := binding(action)
	if int(b.mouse) != 0:
		return str(MOUSE_NAMES.get(int(b.mouse), "Mouse %d" % int(b.mouse)))
	if int(b.key) == 0:
		return ""
	var code := int(b.key) as Key
	if DisplayServer.get_name() != "headless":
		var mapped := DisplayServer.keyboard_get_keycode_from_physical(code)
		if mapped != KEY_NONE:
			code = mapped
	var s := OS.get_keycode_string(code)
	return s if s != "" else "key %d" % int(b.key)


func pad_name(action: String) -> String:
	var b := binding(action)
	if int(b.pad) < 0:
		return ""
	return str(PAD_NAMES.get(int(b.pad), "button %d" % int(b.pad)))
