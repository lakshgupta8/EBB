class_name EndingUI
extends CanvasLayer
## Plays an ending: the screen goes dark, the story comes in cards, then the title.
## E / click / Space advances. The hub hands over a `tide` callable so the sea can rise
## or fall behind the words while they are read.

signal finished

var is_open: bool = false
var tide: Callable  # (level: float) -> void; optional
var id: String = ""
var card: int = -1
var can_advance: bool = false

var _cards: Array = []
var _root: Control
var _black: ColorRect
var _glow: ColorRect
var _title: Label
var _text: Label
var _sub: Label
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 6
	visible = false


func play(ending: String) -> void:
	if is_open or not Story.ENDINGS.has(ending):
		return
	id = ending
	_cards = Story.ENDINGS[id].cards
	card = -1
	can_advance = false
	is_open = true
	get_tree().paused = true
	visible = true
	Story.record_ending(id)
	if _root:
		_root.queue_free()
	_build()
	Audio.play("ebb", 0.0, -4.0)
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 1.6)
	tw.tween_interval(0.4)
	tw.tween_callback(_next)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_black = ColorRect.new()
	_black.color = Color(0.03, 0.03, 0.06, 0.0)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_black)
	_glow = ColorRect.new()
	_glow.color = Color(1.0, 0.85, 0.55, 0.0)
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_glow)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(400, 0)
	center.add_child(box)
	_title = UI.label("", 20, Color(0.95, 0.9, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	_title.modulate.a = 0.0
	box.add_child(_title)
	_text = UI.label("", 8, Color(0.9, 0.9, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(400, 0)
	_text.modulate.a = 0.0
	box.add_child(_text)
	_sub = UI.label("", 8, Color(0.65, 0.7, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	_sub.modulate.a = 0.0
	box.add_child(_sub)
	box.add_child(UI.spacer(16))
	_hint = UI.label("", 8, Color(0.55, 0.6, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_hint)


func _next() -> void:
	card += 1
	can_advance = false
	_hint.text = ""
	if card >= _cards.size():
		_show_title()
		return
	_text.modulate.a = 0.0
	_text.text = _cards[card]
	var tw := create_tween()
	tw.tween_property(_text, "modulate:a", 1.0, 0.7)
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		can_advance = true
		_hint.text = "[E] continue")
	_effect()


## The world behind the words: the sea rising, falling, or the lantern's warmth.
func _effect() -> void:
	match id:
		"break":
			if card == 2:
				_reveal(0.45)
				_sea(0.6, 1.0)
			elif card == 3:
				_reveal(1.0)
		"walk":
			if card == 1:
				_reveal(0.45)
				_sea(0.6, 0.0)
			elif card == 2:
				_reveal(1.0)
		"keep":
			if card == 1:
				create_tween().tween_property(_glow, "color:a", 0.18, 3.0)
			elif card == 3:
				create_tween().tween_property(_glow, "color:a", 0.0, 3.0)


func _reveal(darkness: float) -> void:
	create_tween().tween_property(_black, "color:a", darkness, 1.5)


func _sea(from: float, to: float) -> void:
	if tide.is_valid():
		create_tween().tween_method(tide, from, to, 6.0)


func _show_title() -> void:
	_text.text = ""
	_title.text = Story.ENDINGS[id].title
	var seen := Story.endings_seen().size()
	_sub.text = "an ending   %d of %d seen" % [seen, Story.ENDINGS.size()]
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 0.8)
	tw.tween_property(_title, "modulate:a", 1.0, 1.0)
	tw.tween_property(_sub, "modulate:a", 1.0, 0.6)
	tw.tween_callback(func():
		can_advance = true
		_hint.text = "[E] back to the lighthouse")
	Audio.play("rescue", 0.0, -6.0)


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if UI.is_close(event) or click or event.is_action_pressed("dash"):
		get_viewport().set_input_as_handled()
		if not can_advance:
			return
		if card >= _cards.size():
			_finish()
		else:
			_next()


func _finish() -> void:
	is_open = false
	can_advance = false
	get_tree().paused = false
	visible = false
	finished.emit()
	Game.go_to_hub()
