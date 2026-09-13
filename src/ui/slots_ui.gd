class_name SlotsUI
extends CanvasLayer
## Three keepers, three slots. Each row says what the slot holds; picking one makes it
## the profile in use (the title redraws for it). The slot in use can be wiped, twice.

signal closed

var is_open: bool = false
var _root: Control
var _cursor: UI.Cursor
var _wipe_btn: Button
var _wipe_armed: bool = false
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	visible = false


func open() -> void:
	if is_open:
		return
	is_open = true
	_wipe_armed = false
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
	if i >= 0 and i < 3:
		pick(i + 1)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X:
		_wipe()
		get_viewport().set_input_as_handled()
	elif nav != "" and _cursor.handle(nav):
		get_viewport().set_input_as_handled()
	elif UI.is_close(event) or nav == "accept":
		close()
		get_viewport().set_input_as_handled()


## Make slot n the profile in use.
func pick(n: int) -> void:
	if n == SaveManager.slot_in_use():
		_hint.text = "already the keeper in use"
		return
	Settings.set_value("slot", n)
	SaveManager.use_slot(n)
	Audio.play("buy")
	_wipe_armed = false
	if _root:
		_root.queue_free()
	_build()
	_hint.text = "slot %d in use" % n


static func summary_text(n: int) -> String:
	var s := SaveManager.slot_summary(n)
	if s.is_empty():
		return "empty: a new keeper"
	var t := "night %d   wins %d   pearls %d   echoes %d/%d" % [int(s.runs) + 1, int(s.wins), int(s.pearls), int(s.echoes), Story.ECHO_IDS.size()]
	if int(s.endings) > 0:
		t += "   endings %d/3" % int(s.endings)
	if bool(s.suspended):
		t += "   a night waits"
	return t


static func saved_text(n: int) -> String:
	var s := SaveManager.slot_summary(n)
	if s.is_empty() or int(s.saved) <= 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(int(s.saved))
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


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
	box.custom_minimum_size = Vector2(380, 0)
	panel.add_child(box)
	box.add_child(UI.label("KEEPERS", 16, Color(0.85, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("three slots; the one marked is in use", 8, Color(0.6, 0.65, 0.75), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(4))
	var buttons: Array = []
	var current := SaveManager.slot_in_use()
	for n in [1, 2, 3]:
		var on: bool = n == current
		var b := UI.row_button(Color(0.95, 0.8, 0.5) if on else UI.PANEL_EDGE)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var a := UI.label("[%d] Slot %d%s" % [n, n, "   (in use)" if on else ""], 8, Color(1, 1, 1) if on else Color(0.85, 0.85, 0.9))
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var d := UI.label(saved_text(n), 8, Color(0.6, 0.65, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)
		h.add_child(a)
		h.add_child(d)
		v.add_child(h)
		v.add_child(UI.label(summary_text(n), 8, Color(0.75, 0.8, 0.85)))
		b.add_child(v)
		UI.fill(v, 6.0, 4.0)
		b.custom_minimum_size = Vector2(360, 30)
		b.pressed.connect(pick.bind(n))
		box.add_child(b)
		buttons.append(b)
	box.add_child(UI.spacer(4))
	_hint = UI.label(" ", 8, Color(0.75, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_wipe_btn = UI.text_button("Wipe slot %d   [X]" % current, 8, Color(0.85, 0.7, 0.7))
	_wipe_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wipe_btn.pressed.connect(_wipe)
	row.add_child(_wipe_btn)
	var leave := UI.text_button("Done   " + UI.hint("interact"))
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(close)
	row.add_child(leave)
	box.add_child(row)
	buttons.append(_wipe_btn)
	buttons.append(leave)
	_root = center
	_cursor = UI.Cursor.new(buttons)
	_cursor.index = current - 1
	_cursor.apply()


## Wiping is two presses so a stray click cannot end a keeper.
func _wipe() -> void:
	var n := SaveManager.slot_in_use()
	if not _wipe_armed:
		_wipe_armed = true
		_wipe_btn.text = "Really wipe slot %d?   [X] again" % n
		_hint.text = "everything in it goes: nights, pearls, everyone brought home"
		_hint.modulate = Color(1.0, 0.6, 0.55)
		return
	SaveManager.wipe_slot(n)
	Audio.play("splash", 0.0, -4.0)
	_wipe_armed = false
	if _root:
		_root.queue_free()
	_build()
	_hint.text = "slot %d is empty: a new keeper" % n
	_hint.modulate = Color(0.75, 0.95, 0.8)
