class_name SettingsUI
extends CanvasLayer
## Settings on two pages: the screen and sound, and how the game plays (dialogue, hints,
## water colour, assists, controls). Click a row (or press its number) to step it; left /
## right adjusts the highlighted row; Tab or the shoulders turn the page; E / Esc / B leaves.
## Everything is saved the moment it changes.

signal closed

const PAGES := [
	{"name": "SCREEN AND SOUND", "rows": [
		{"key": "master", "name": "Master volume", "kind": "volume"},
		{"key": "music", "name": "Music volume", "kind": "volume"},
		{"key": "sfx", "name": "Sound volume", "kind": "volume"},
		{"key": "shake", "name": "Screen shake", "kind": "shake"},
		{"key": "flash", "name": "Screen flashes", "kind": "bool"},
		{"key": "fullscreen", "name": "Fullscreen", "kind": "bool"},
		{"key": "hud_scale", "name": "HUD size", "kind": "scale"},
		{"key": "text_size", "name": "Text size", "kind": "scale"},
		{"key": "reduced_motion", "name": "Reduced motion", "kind": "bool", "note": "no shake, flashes, slow time or edge pulses"},
	]},
	{"name": "PLAY", "rows": [
		{"key": "dialog_speed", "name": "Dialogue speed", "kind": "speed"},
		{"key": "skip_seen", "name": "Skip dialogue seen before", "kind": "bool"},
		{"key": "hints", "name": "Hints (how things work)", "kind": "bool"},
		{"key": "water_tint", "name": "Water colour", "kind": "tint"},
		{"key": "assist_tide", "name": "Assist: tide speed", "kind": "assist"},
		{"key": "assist_damage", "name": "Assist: damage taken", "kind": "assist"},
		{"key": "assist_aim", "name": "Assist: aim help", "kind": "bool"},
		{"key": "ghost", "name": "Ghost of your last night", "kind": "bool", "note": "on the same seed, the keeper you were walks it again beside you"},
		{"key": "", "name": "Controls and bindings...", "kind": "controls"},
	]},
]

var is_open: bool = false
var page: int = 0
var _root: Control
var _rows: Array = []  # [name label, value label, button]
var _cursor: UI.Cursor
var _tabs: Array = []
var _note: Label
var _controls: ControlsUI


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	visible = false
	_controls = ControlsUI.new()
	_controls.name = "ControlsUI"
	add_child(_controls)
	_controls.closed.connect(func():
		# Back to the settings page the player left from.
		open()
		_cursor.index = PAGES[page].rows.size() - 1
		_cursor.apply())


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


func _rows_here() -> Array:
	return PAGES[page].rows


func _input(event: InputEvent) -> void:
	if not is_open or _controls.is_open:
		return
	var i := UI.menu_index(event)
	var nav := UI.nav(event)
	var tab: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER])
	if tab:
		var back: bool = (event is InputEventKey and event.shift_pressed) or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER)
		set_page(wrapi(page + (-1 if back else 1), 0, PAGES.size()))
		get_viewport().set_input_as_handled()
	elif i >= 0 and i < _rows_here().size():
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


func set_page(p: int) -> void:
	page = clampi(p, 0, PAGES.size() - 1)
	if _root:
		_root.queue_free()
	_build()
	Audio.play("ui", 0.0, -12.0)


## Step a row: volumes by 10%, shake off / low / full, booleans flip, choices cycle.
func _step(i: int, dir: int) -> void:
	var r: Dictionary = _rows_here()[i]
	if r.kind == "controls":
		close()
		_controls.open()
		return
	var v = Settings.value(r.key)
	match r.kind:
		"volume":
			var n := int(round(float(v) * 10.0)) + dir
			if dir > 0 and n > 10:
				n = 0
			Settings.set_value(r.key, clampf(n / 10.0, 0.0, 1.0))
		"shake":
			_cycle(r.key, [0.0, 0.5, 1.0], float(v), dir, 2)
		"bool":
			Settings.set_value(r.key, not bool(v))
		"speed":
			_cycle(r.key, [0.5, 1.0, 2.0, 0.0], float(v), dir, 1)
		"scale":
			_cycle(r.key, [1.0, 1.25, 1.5], float(v), dir, 0)
		"assist":
			_cycle(r.key, [1.0, 0.75, 0.5], float(v), dir, 0)
		"tint":
			_cycle(r.key, Settings.WATER_TINTS.keys(), str(v), dir, 0)
	Audio.play("ui", 0.0, -8.0)
	_refresh()


func _cycle(key: String, steps: Array, current, dir: int, fallback: int) -> void:
	var at := steps.find(current)
	if at < 0:
		at = fallback
	Settings.set_value(key, steps[wrapi(at + dir, 0, steps.size())])


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = UI.DIM
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
	box.custom_minimum_size = Vector2(340, 0)
	panel.add_child(box)
	box.add_child(UI.header("SETTINGS"))
	# The two pages as tabs.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs = []
	for p in PAGES.size():
		var t := UI.tab_button(PAGES[p].name, p == page)
		t.custom_minimum_size = Vector2(150, 16)
		t.pressed.connect(set_page.bind(p))
		tabs.add_child(t)
		_tabs.append(t)
	box.add_child(tabs)
	box.add_child(UI.label("click or number to step   %s adjust   [Tab] page" % UI.hint("leftright"), 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(2))
	_rows = []
	var buttons: Array = []
	var rows := _rows_here()
	for i in rows.size():
		var r: Dictionary = rows[i]
		var b := UI.row_button()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var a := UI.label("[%d] %s" % [i + 1, r.name], 8)
		a.custom_minimum_size = Vector2(180, 0)
		var c := UI.label("", 8, UI.PRIMARY, HORIZONTAL_ALIGNMENT_RIGHT)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(c)
		var rail: UI.Rail = null
		if r.kind == "volume":
			# an iron rail with a brass slider, then the number
			rail = UI.Rail.new()
			rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(rail)
			c.custom_minimum_size = Vector2(30, 0)
		b.add_child(h)
		UI.fill(h, 6.0, 4.0)
		b.custom_minimum_size = Vector2(320, 18)
		b.pressed.connect(func():
			_cursor.index = i
			_cursor.apply()
			_step(i, 1))
		b.mouse_entered.connect(func(): _show_note(i))
		box.add_child(b)
		_rows.append([a, c, b, rail])
		buttons.append(b)
	box.add_child(UI.spacer(2))
	_note = UI.label(" ", 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(320, 0)
	box.add_child(_note)
	if page == 1:
		var m := Settings.assist_pearl_mult()
		box.add_child(UI.label("assists are a trade: pearls at the end of a night x%.2f" % m if m < 1.0
			else "assists off: full pearls", 8, UI.ACCENT if m < 1.0 else UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(2))
	var leave := UI.text_button("Done   " + UI.hint("interact"))
	leave.pressed.connect(close)
	box.add_child(leave)
	_root = center
	_cursor = UI.Cursor.new(buttons)
	_refresh()


func _show_note(i: int) -> void:
	if i < 0 or i >= _rows_here().size():
		return
	_note.text = str(_rows_here()[i].get("note", " "))


func _refresh() -> void:
	var rows := _rows_here()
	for i in _rows.size():
		var r: Dictionary = rows[i]
		var text := ""
		if r.kind == "controls":
			var n := 0
			for a in Settings.BINDABLE:
				if Settings.is_rebound(a):
					n += 1
			text = "as made" if n == 0 else "%d changed" % n
		else:
			var v = Settings.value(r.key)
			match r.kind:
				"volume":
					var n := int(round(float(v) * 10.0))
					text = "%d%%" % (n * 10)
					if _rows[i].size() > 3 and _rows[i][3] != null:
						_rows[i][3].frac = n / 10.0
				"shake":
					text = "off" if float(v) <= 0.0 else ("low" if float(v) < 1.0 else "full")
				"bool":
					text = "on" if bool(v) else "off"
				"speed":
					var s := float(v)
					text = "at once" if s <= 0.0 else ("slow" if s < 1.0 else ("fast" if s > 1.0 else "normal"))
				"scale":
					var s := float(v)
					text = "normal" if s <= 1.0 else ("large" if s < 1.5 else "largest")
				"assist":
					var s := float(v)
					text = "off" if s >= 1.0 else ("three quarters" if s > 0.5 else "half")
				"tint":
					text = str(Settings.WATER_TINTS.get(str(v), Settings.WATER_TINTS.sea).name)
		_rows[i][1].text = text
	if _cursor and _cursor.index >= 0:
		_show_note(_cursor.index)
