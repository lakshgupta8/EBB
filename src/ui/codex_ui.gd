class_name CodexUI
extends CanvasLayer
## The codex: everything met so far. Tabs for the drowned, tidemarks, people and places;
## rows fill in as they are met. 1-7 switch tabs, wheel / W S / arrows scroll, E closes.
## C opens it from the world when nothing else is up; the pause menu has a button too.

signal closed

var is_open: bool = false
var _root: Control
var _tab: int = 0
var _tab_buttons: Array = []
var _scroll: ScrollContainer
var _list: VBoxContainer
var _count: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3
	visible = false


func open(tab: int = 0) -> void:
	if is_open:
		return
	is_open = true
	_tab = clampi(tab, 0, Codex.TABS.size() - 1)
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
		if event.is_action_pressed("codex") and not get_tree().paused:
			open()
			get_viewport().set_input_as_handled()
		return
	var i := UI.menu_index(event)
	var nav := UI.nav(event)
	if i >= 0 and i < Codex.TABS.size():
		_set_tab(i)
		get_viewport().set_input_as_handled()
	elif UI.is_close(event) or event.is_action_pressed("codex"):
		close()
		get_viewport().set_input_as_handled()
	elif nav == "left" or nav == "right":
		_set_tab(wrapi(_tab + (1 if nav == "right" else -1), 0, Codex.TABS.size()))
		get_viewport().set_input_as_handled()
	elif (nav == "up" or nav == "down") and _scroll:
		_scroll.scroll_vertical += (28 if nav == "down" else -28)
		get_viewport().set_input_as_handled()


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
	box.custom_minimum_size = Vector2(560, 0)
	panel.add_child(box)
	box.add_child(UI.label("CODEX", 16, Color(0.85, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(2))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_tab_buttons = []
	for i in Codex.TABS.size():
		var b := UI.text_button("", 8)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	box.add_child(tabs)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(560, 214)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	box.add_child(UI.spacer(2))
	_count = UI.label("", 8, Color(0.7, 0.75, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_count)
	var leave := UI.text_button("Leave   " + UI.hint("interact"))
	leave.pressed.connect(close)
	box.add_child(leave)
	_root = center
	_set_tab(_tab)


func _set_tab(i: int) -> void:
	_tab = i
	var kind: String = Codex.TABS[i]
	for j in _tab_buttons.size():
		var k: String = Codex.TABS[j]
		var b: Button = _tab_buttons[j]
		b.text = "[%d] %s" % [j + 1, Codex.TAB_NAMES[k]]
		b.add_theme_color_override("font_color", Color(1, 1, 1) if j == i else Color(0.7, 0.75, 0.85))
	for c in _list.get_children():
		c.queue_free()
	for e in Codex.entries(kind):
		_list.add_child(_row(e))
	_scroll.scroll_vertical = 0
	var n := Codex.count(kind)
	_count.text = "%d of %d met" % [n.x, n.y] if n.x < n.y else "all %d met" % n.y


func _row(e: Dictionary) -> Control:
	var p := UI.row_panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if e.found:
		if e.has("color"):
			# Family colour rides on a 2 px edge, never on the text (STYLE.md 15).
			var edge := ColorRect.new()
			edge.color = e.color
			edge.custom_minimum_size = Vector2(2, 0)
			h.add_child(edge)
		var a := UI.label(e.name, 8, Palette.TEXT.primary)
		a.custom_minimum_size = Vector2(150, 0)
		h.add_child(a)
		var d := UI.flex_label(e.desc)
		d.clip_text = false
		d.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(d)
		v.add_child(h)
		var lore := UI.label(e.lore, 8, Color(0.62, 0.66, 0.78))
		lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lore.custom_minimum_size = Vector2(520, 0)
		v.add_child(lore)
	else:
		var a := UI.label("???", 8, Color(0.45, 0.47, 0.55))
		a.custom_minimum_size = Vector2(150, 0)
		h.add_child(a)
		h.add_child(UI.flex_label("not yet met", 8, Color(0.45, 0.47, 0.55)))
		v.add_child(h)
	return p
