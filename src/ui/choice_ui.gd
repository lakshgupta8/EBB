class_name ChoiceUI
extends CanvasLayer
## One menu for the rescued echoes at the hub: a title, a line of dialogue, a list of
## rows to pick from (click or 1-9), the current pick marked. E / Esc / Leave closes.
## The handler decides what a pick does and returns the hint to show ("" = refused).

signal closed

var is_open: bool = false
var _root: Control
var _rows: Array = []
var _options: Array = []
var _selected: int = -1
var _hint: Label
var _accent: Color = Color(0.9, 0.85, 0.7)
var _handler: Callable
var _cursor: UI.Cursor


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3
	visible = false


## options: [{"name", "desc", "right" (text shown at the right when not selected),
## "fail" (hint when refused)}]. handler(i) -> String hint, or "" when refused.
func open(title: String, line: String, options: Array, selected: int, accent: Color, handler: Callable = Callable()) -> void:
	if is_open:
		return
	_options = options
	_selected = selected
	_accent = accent
	_handler = handler
	is_open = true
	get_tree().paused = true
	visible = true
	if _root:
		_root.queue_free()
	_build(title, line)


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
	if i >= 0 and i < _options.size():
		_pick(i)
		get_viewport().set_input_as_handled()
	elif nav != "" and _cursor.handle(nav):
		get_viewport().set_input_as_handled()
	elif UI.is_close(event) or nav == "accept":
		close()
		get_viewport().set_input_as_handled()


func _pick(i: int) -> void:
	var hint := ""
	if _handler.is_valid():
		hint = str(_handler.call(i))
	if hint == "":
		_hint.text = str(_options[i].get("fail", "not now"))
		_hint.modulate = Color(1.0, 0.6, 0.55)
		Audio.play("ui", 0.0, -6.0)
		return
	_selected = i
	_hint.text = hint
	_hint.modulate = Color(0.75, 0.95, 0.8)
	Audio.play("buy")
	_refresh()


func _build(title: String, line: String) -> void:
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
	box.custom_minimum_size = Vector2(440, 0)
	panel.add_child(box)
	box.add_child(UI.label(title, 16, _accent, HORIZONTAL_ALIGNMENT_CENTER))
	var l := UI.label("\"%s\"" % line, 8, Color(0.75, 0.75, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	box.add_child(l)
	box.add_child(UI.spacer(4))
	_rows = []
	for i in _options.size():
		var o: Dictionary = _options[i]
		var b := UI.row_button(_accent)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var a := UI.label("[%d] %s" % [i + 1, o.name], 8)
		a.custom_minimum_size = Vector2(110, 0)
		var d := UI.flex_label(o.desc)
		var c := UI.label("", 8, _accent, HORIZONTAL_ALIGNMENT_RIGHT)
		c.custom_minimum_size = Vector2(70, 0)
		h.add_child(a)
		h.add_child(d)
		h.add_child(c)
		b.add_child(h)
		UI.fill(h, 6.0, 4.0)
		b.custom_minimum_size = Vector2(420, 20)
		b.pressed.connect(_pick.bind(i))
		box.add_child(b)
		_rows.append([a, d, c, b])
	box.add_child(UI.spacer(4))
	_hint = UI.label(" ", 8, Color(0.75, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_hint)
	var leave := UI.text_button("Leave   " + UI.hint("interact"))
	leave.pressed.connect(close)
	box.add_child(leave)
	_root = center
	_cursor = UI.Cursor.new(_rows.map(func(r): return r[3]))
	_refresh()


## Rows may change their right-hand text after a pick (a price paid, a weapon owned).
func set_right(i: int, text: String) -> void:
	if i >= 0 and i < _options.size():
		_options[i]["right"] = text
	_refresh()


func _refresh() -> void:
	for i in _rows.size():
		var on := i == _selected
		var right: String = "in hand" if on else str(_options[i].get("right", ""))
		_rows[i][2].text = right
		_rows[i][2].add_theme_color_override("font_color", _accent if on else Color(0.8, 0.8, 0.85))
		_rows[i][0].add_theme_color_override("font_color", Color(1, 1, 1) if on else Color(0.85, 0.85, 0.9))
