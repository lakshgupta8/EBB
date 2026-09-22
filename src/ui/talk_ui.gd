class_name TalkUI
extends CanvasLayer
## Someone talking, one line at a time, at the bottom of the screen: a portrait, a name,
## and text that types itself out at the speed in Settings. E / click / Enter advances;
## a line still typing is finished first. Chains already read can show at once (Settings).

signal finished

const PROPS := preload("res://assets/sprites/props.png")

var is_open: bool = false
var _lines: Array = []
var _line: int = -1
var _shown: int = 0
var _acc: float = 0.0
var _seen_before: bool = false
var _root: Control
var _text: Label
var _name: Label
var _hint: Label
var _portrait: TextureRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	visible = false


## Show `lines` as `who` (a Prop.PORTRAIT key). `seen` marks a chain already read.
func talk(who: String, name: String, lines: Array, seen: bool = false) -> void:
	if is_open or lines.is_empty():
		return
	is_open = true
	_lines = lines
	_line = -1
	_seen_before = seen
	get_tree().paused = true
	visible = true
	if _root:
		_root.queue_free()
	_build(who, name)
	_next()


func _build(who: String, name: String) -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var panel := PanelContainer.new()
	# Paper in an iron frame at the bottom third (STYLE.md 15).
	panel.add_theme_stylebox_override("panel", UI.panel_style(6))
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = -78
	panel.offset_bottom = -10
	_root.add_child(panel)
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UI.paper_style(6))
	panel.add_child(paper)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	paper.add_child(h)
	_portrait = TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = PROPS
	at.atlas = Prop.PORTRAITS
	at.region = Rect2(int(Prop.PORTRAIT.get(who, 0)) * 16, 0, 16, 16)
	_portrait.texture = at
	# A 16x16 portrait slot at 1x (pixel art is never scaled); portraits arrive with the
	# character sheets.
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_portrait.custom_minimum_size = Vector2(16, 16)
	var pbox := PanelContainer.new()
	pbox.add_theme_stylebox_override("panel", UI._row_style(0))
	pbox.custom_minimum_size = Vector2(22, 22)
	pbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pbox.add_child(_portrait)
	h.add_child(pbox)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_name = UI.label(name.to_upper(), 8, UI.ACCENT)
	v.add_child(_name)
	_text = UI.label("", 8, UI.PRIMARY)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(440, 30)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	_hint = UI.label("", 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_RIGHT)
	v.add_child(_hint)


func _next() -> void:
	_line += 1
	if _line >= _lines.size():
		close()
		return
	_shown = 0
	_acc = 0.0
	_text.text = ""
	_hint.text = ""
	if Settings.dialog_speed() <= 0.0 or (_seen_before and Settings.skip_seen()):
		_shown = str(_lines[_line]).length()
		_text.text = str(_lines[_line])
		_show_hint()


func _show_hint() -> void:
	_hint.text = UI.hint("interact") + (" continue" if _line + 1 < _lines.size() else " done")


func _process(delta: float) -> void:
	if not is_open or _line < 0 or _line >= _lines.size():
		return
	var full := str(_lines[_line])
	if _shown >= full.length():
		return
	# 40 letters a second at normal speed.
	_acc += delta * 40.0 * Settings.dialog_speed()
	while _acc >= 1.0 and _shown < full.length():
		_acc -= 1.0
		_shown += 1
	_text.text = full.substr(0, _shown)
	if _shown >= full.length():
		_show_hint()


func _advance() -> void:
	var full := str(_lines[_line]) if _line >= 0 and _line < _lines.size() else ""
	if _shown < full.length():
		_shown = full.length()
		_text.text = full
		_show_hint()
		return
	_next()


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = false
	visible = false
	finished.emit()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if UI.is_close(event) or click or UI.nav(event) == "accept":
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("pause") and not (event is InputEventJoypadButton):
			# Esc skips the whole chain.
			close()
			return
		_advance()
