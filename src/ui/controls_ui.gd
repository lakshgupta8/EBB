class_name ControlsUI
extends CanvasLayer
## Rebinding: every action in a row with its key and its pad button. Pick a row (click,
## number, or the cursor and Enter), then press the key, mouse button or pad button you
## want; Esc cancels. Another action already using that input takes the old one, so
## nothing is left unbound. "Reset" puts the project's bindings back.

signal closed

var is_open: bool = false
var listening: String = ""   # the action waiting for a press, or ""
var _root: Control
var _rows: Dictionary = {}   # action -> [key label, pad label, button]
var _cursor: UI.Cursor
var _status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 6
	visible = false


func open() -> void:
	if is_open:
		return
	is_open = true
	listening = ""
	get_tree().paused = true
	visible = true
	if _root:
		_root.queue_free()
	_build()


func close() -> void:
	if not is_open:
		return
	is_open = false
	listening = ""
	get_tree().paused = false
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if listening != "":
		_listen(event)
		get_viewport().set_input_as_handled()
		return
	var i := UI.menu_index(event)
	var nav := UI.nav(event)
	if i >= 0 and i < Settings.BINDABLE.size():
		_cursor.index = i
		_cursor.apply()
		_start_listen(Settings.BINDABLE[i])
		get_viewport().set_input_as_handled()
	elif nav != "" and _cursor.handle(nav):
		get_viewport().set_input_as_handled()
	elif UI.is_close(event):
		close()
		get_viewport().set_input_as_handled()


## The press that lands here is the new binding; motion and releases are ignored.
func _listen(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_stop_listen("kept as it was")
			return
		if Settings.bind(listening, event):
			_stop_listen("%s: %s" % [Settings.ACTION_NAMES[listening], Settings.key_name(listening)])
	elif event is InputEventMouseButton and event.pressed:
		if Settings.bind(listening, event):
			_stop_listen("%s: %s" % [Settings.ACTION_NAMES[listening], Settings.key_name(listening)])
	elif event is InputEventJoypadButton and event.pressed:
		if Settings.bind(listening, event):
			_stop_listen("%s: %s" % [Settings.ACTION_NAMES[listening], Settings.pad_name(listening)])


func _start_listen(action: String) -> void:
	listening = action
	_status.text = "press a key, a mouse button or a pad button for %s   (Esc keeps it)" % Settings.ACTION_NAMES[action].to_lower()
	UI.hint_kind(_status, "accent")
	_refresh()


func _stop_listen(text: String) -> void:
	listening = ""
	_status.text = text
	UI.hint_kind(_status, "ok")
	Audio.play("ui", 0.0, -8.0)
	_refresh()


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
	box.add_theme_constant_override("separation", 2)
	box.custom_minimum_size = Vector2(360, 0)
	panel.add_child(box)
	box.add_child(UI.header("CONTROLS"))
	box.add_child(UI.label("pick a row, then press what you want it to be", 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(2))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var h0 := UI.label("", 8, UI.SECONDARY)
	h0.custom_minimum_size = Vector2(130, 0)
	var h1 := UI.label("keyboard / mouse", 8, UI.SECONDARY)
	h1.custom_minimum_size = Vector2(110, 0)
	var h2 := UI.label("pad", 8, UI.SECONDARY)
	h2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(h0)
	head.add_child(h1)
	head.add_child(h2)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_child(head)
	box.add_child(margin)
	_rows = {}
	var buttons: Array = []
	for i in Settings.BINDABLE.size():
		var a: String = Settings.BINDABLE[i]
		var b := UI.row_button()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var n := UI.label("[%d] %s" % [i + 1, Settings.ACTION_NAMES[a]], 8)
		n.custom_minimum_size = Vector2(130, 0)
		var k := UI.label("", 8, UI.PRIMARY)
		k.custom_minimum_size = Vector2(110, 0)
		var p := UI.label("", 8, UI.PRIMARY)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(k)
		h.add_child(p)
		b.add_child(h)
		UI.fill(h, 6.0, 3.0)
		b.custom_minimum_size = Vector2(340, 16)
		b.pressed.connect(func():
			_cursor.index = i
			_cursor.apply()
			_start_listen(a))
		box.add_child(b)
		_rows[a] = [k, p, b]
		buttons.append(b)
	box.add_child(UI.spacer(2))
	_status = UI.label(" ", 8, UI.PRIMARY, HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(340, 0)
	box.add_child(_status)
	box.add_child(UI.label("Menus: arrows or the move keys, Enter or A picks, Esc or B leaves; numbers jump", 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var reset := UI.text_button("Reset to defaults")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func():
		Settings.reset_bindings()
		_status.text = "back to the keeper's own bindings"
		UI.hint_kind(_status, "ok")
		Audio.play("ui", 0.0, -8.0)
		_refresh())
	row.add_child(reset)
	var leave := UI.text_button("Done   [Esc]")
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(close)
	row.add_child(leave)
	box.add_child(row)
	buttons.append(reset)
	buttons.append(leave)
	_root = center
	_cursor = UI.Cursor.new(buttons)
	_refresh()


func _refresh() -> void:
	for a in _rows:
		var k: Label = _rows[a][0]
		var p: Label = _rows[a][1]
		if a == listening:
			k.text = "..."
			p.text = "..."
			k.modulate = UI.ACCENT
			p.modulate = UI.ACCENT
			continue
		var kn := Settings.key_name(a)
		var pn := Settings.pad_name(a)
		k.text = kn if kn != "" else "-"
		p.text = pn if pn != "" else "-"
		var changed := Settings.is_rebound(a)
		k.modulate = UI.PRIMARY if changed else Color.WHITE
		p.modulate = k.modulate
