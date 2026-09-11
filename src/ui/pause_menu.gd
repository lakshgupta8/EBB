extends CanvasLayer
## Esc pauses. Built in code; keeps processing while the tree is paused.

var _open: bool = false
var _root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("use_item"):
		_quit_to_hub()


func toggle() -> void:
	_open = not _open
	get_tree().paused = _open
	visible = _open
	if _open and _root == null:
		_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.08, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(180, 0)
	panel.add_child(box)
	box.add_child(UI.label("PAUSED", 16, Color(0.9, 0.9, 0.95), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(4))
	box.add_child(UI.label("[Esc]  resume", 8, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("[Q]  give up and return", 8, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("[F11]  fullscreen / window", 8, Color(0.6, 0.6, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(6))
	box.add_child(UI.label("LMB swing (hold: heavy)   RMB hook", 8, Color(0.6, 0.7, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("Space dash (attack out of it: lunge)", 8, Color(0.6, 0.7, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("Q lantern flare when the glow is full", 8, Color(0.6, 0.7, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
	_root = center


func _quit_to_hub() -> void:
	get_tree().paused = false
	var run := get_tree().current_scene as Run
	if run and not run.state.ended:
		run.give_up()
	else:
		Game.go_to_hub()
