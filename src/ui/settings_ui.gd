class_name SettingsUI
extends CanvasLayer
## Settings: click a row (or press its number) to step it; left / right adjusts the
## highlighted row; E / Esc / B leaves. Everything is saved the moment it changes.

signal closed

const ROWS := [
	{"key": "master", "name": "Master volume", "kind": "volume"},
	{"key": "music", "name": "Music volume", "kind": "volume"},
	{"key": "sfx", "name": "Sound volume", "kind": "volume"},
	{"key": "shake", "name": "Screen shake", "kind": "shake"},
	{"key": "flash", "name": "Screen flashes", "kind": "bool"},
	{"key": "fullscreen", "name": "Fullscreen", "kind": "bool"},
	{"key": "dialog_speed", "name": "Dialogue speed", "kind": "speed"},
	{"key": "skip_seen", "name": "Skip dialogue seen before", "kind": "bool"},
	{"key": "hints", "name": "Hints (how things work)", "kind": "bool"},
]

var is_open: bool = false
var _root: Control
var _rows: Array = []  # [name label, value label, button]
var _cursor: UI.Cursor


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	visible = false


func open() -> void:
	if is_open:
		return
	is_open = true
	get_tree().paused = true
	visible = true
	if _root:
		_root.queue_free()
	_build()


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = false
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var i := UI.menu_index(event)
	var nav := UI.nav(event)
	if i >= 0 and i < ROWS.size():
		_cursor.index = i
		_cursor.apply()
		_step(i, 1)
		get_viewport().set_input_as_handled()
	elif nav == "left" or nav == "right":
		if _cursor.index >= 0:
			_step(_cursor.index, 1 if nav == "right" else -1)
		get_viewport().set_input_as_handled()
	elif nav != "" and _cursor.handle(nav):
		get_viewport().set_input_as_handled()
	elif UI.is_close(event) or nav == "accept":
		close()
		get_viewport().set_input_as_handled()


## Step a row: volumes by 10%, shake off / low / full, booleans flip.
func _step(i: int, dir: int) -> void:
	var r: Dictionary = ROWS[i]
	var v = Settings.value(r.key)
	match r.kind:
		"volume":
			var n := int(round(float(v) * 10.0)) + dir
			if dir > 0 and n > 10:
				n = 0
			Settings.set_value(r.key, clampf(n / 10.0, 0.0, 1.0))
		"shake":
			var steps := [0.0, 0.5, 1.0]
			var at := steps.find(float(v))
			if at < 0:
				at = 2
			Settings.set_value(r.key, steps[wrapi(at + dir, 0, steps.size())])
		"bool":
			Settings.set_value(r.key, not bool(v))
		"speed":
			var steps := [0.5, 1.0, 2.0, 0.0]
			var at := steps.find(float(v))
			if at < 0:
				at = 1
			Settings.set_value(r.key, steps[wrapi(at + dir, 0, steps.size())])
	Audio.play("ui", 0.0, -8.0)
	_refresh()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.08, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.custom_minimum_size = Vector2(320, 0)
	panel.add_child(box)
	box.add_child(UI.label("SETTINGS", 16, Color(0.85, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("click or number to step   %s adjust" % UI.hint("leftright"), 8, Color(0.6, 0.65, 0.75), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(4))
	_rows = []
	var buttons: Array = []
	for i in ROWS.size():
		var r: Dictionary = ROWS[i]
		var b := UI.row_button()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var a := UI.label("[%d] %s" % [i + 1, r.name], 8)
		a.custom_minimum_size = Vector2(160, 0)
		var c := UI.label("", 8, Color(0.92, 0.92, 0.98), HORIZONTAL_ALIGNMENT_RIGHT)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(c)
		b.add_child(h)
		UI.fill(h, 6.0, 4.0)
		b.custom_minimum_size = Vector2(300, 20)
		b.pressed.connect(func():
			_cursor.index = i
			_cursor.apply()
			_step(i, 1))
		box.add_child(b)
		_rows.append([a, c, b])
		buttons.append(b)
	box.add_child(UI.spacer(4))
	box.add_child(UI.label("Move WASD / stick   Aim mouse / right stick   Dash Space / A", 8, Color(0.55, 0.6, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("Attack LMB / X / RT   Special RMB / Y / LT   Flare Q / LB   Active R / RB", 8, Color(0.55, 0.6, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("Use E / B   Eat F / d-pad up   Codex C / Back   Log L   Pause Esc / Start", 8, Color(0.55, 0.6, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(4))
	var leave := UI.text_button("Done   " + UI.hint("interact"))
	leave.pressed.connect(close)
	box.add_child(leave)
	_root = center
	_cursor = UI.Cursor.new(buttons)
	_refresh()


func _refresh() -> void:
	for i in _rows.size():
		var r: Dictionary = ROWS[i]
		var v = Settings.value(r.key)
		var text := ""
		match r.kind:
			"volume":
				var n := int(round(float(v) * 10.0))
				text = "%s %d%%" % ["#".repeat(n) + "-".repeat(10 - n), n * 10]
			"shake":
				text = "off" if float(v) <= 0.0 else ("low" if float(v) < 1.0 else "full")
			"bool":
				text = "on" if bool(v) else "off"
			"speed":
				var s := float(v)
				text = "at once" if s <= 0.0 else ("slow" if s < 1.0 else ("fast" if s > 1.0 else "normal"))
		_rows[i][1].text = text
