extends CanvasLayer
## Esc pauses. Buttons for resume / give up / fullscreen / quit; keys still work.
## Lives in the run and in the hub; "give up" only shows during a run.

var _open: bool = false
var _root: Control
var _quit_btn: Button
var _rest_btn: Button
var _quit_armed: bool = false
var _cursor: UI.Cursor


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# Other menus (shop, ledger, altar) handle Esc first and mark it handled.
		toggle()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("use_item") and _in_run():
		_quit_to_hub()
		get_viewport().set_input_as_handled()
	elif _open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X:
		_quit_game()
		get_viewport().set_input_as_handled()
	elif _open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_open_codex()
		get_viewport().set_input_as_handled()
	elif _open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_open_log()
		get_viewport().set_input_as_handled()
	elif _open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S:
		_open_settings()
		get_viewport().set_input_as_handled()
	elif _open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T and not _in_run():
		_to_title()
		get_viewport().set_input_as_handled()
	elif _open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and _in_run():
		_rest()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("interact") and not (event is InputEventKey):
		# The pad's B backs out like Esc does.
		toggle()
		get_viewport().set_input_as_handled()
	elif _open:
		var nav := UI.nav(event)
		if nav != "" and _cursor.handle(nav):
			get_viewport().set_input_as_handled()


func toggle() -> void:
	_open = not _open
	get_tree().paused = _open
	visible = _open
	if _open and _root == null:
		_build()
	if _open:
		_disarm_quit()
		_refresh_rest()
		_cursor.index = -1
		_cursor.apply()


func _in_run() -> bool:
	return get_parent() is Run


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.08, 0.7)
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
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(200, 0)
	panel.add_child(box)
	box.add_child(UI.label("PAUSED", 16, Color(0.9, 0.9, 0.95), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(4))
	var buttons: Array = []
	var resume := UI.text_button("Resume   " + UI.hint("pause"))
	resume.pressed.connect(toggle)
	box.add_child(resume)
	buttons.append(resume)
	var codex := UI.text_button("Codex   [C]")
	codex.pressed.connect(_open_codex)
	box.add_child(codex)
	buttons.append(codex)
	var log_btn := UI.text_button("Keeper's Log   [L]")
	log_btn.pressed.connect(_open_log)
	box.add_child(log_btn)
	buttons.append(log_btn)
	var settings := UI.text_button("Settings   [S]")
	settings.pressed.connect(_open_settings)
	box.add_child(settings)
	buttons.append(settings)
	if _in_run():
		_rest_btn = UI.text_button("Rest here   [R]")
		_rest_btn.pressed.connect(_rest)
		box.add_child(_rest_btn)
		buttons.append(_rest_btn)
		var give_up := UI.text_button("Give up and return   [Q]", 8, Color(1.0, 0.75, 0.7))
		give_up.pressed.connect(_quit_to_hub)
		box.add_child(give_up)
		buttons.append(give_up)
	else:
		var title := UI.text_button("Back to the title   [T]")
		title.pressed.connect(_to_title)
		box.add_child(title)
		buttons.append(title)
	_quit_btn = UI.text_button("Quit game   [X]", 8, Color(0.85, 0.7, 0.7))
	_quit_btn.pressed.connect(_quit_game)
	box.add_child(_quit_btn)
	buttons.append(_quit_btn)
	_cursor = UI.Cursor.new(buttons)
	box.add_child(UI.spacer(6))
	var hint := Color(0.6, 0.7, 0.8)
	if _in_run():
		box.add_child(UI.label("LMB attack (gaff: hold to charge)   RMB special", 8, hint, HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(UI.label("Space dash (attack out of it: lunge)", 8, hint, HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(UI.label("Q lantern flare when the glow is full   R active tidemark   F eat", 8, hint, HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(UI.label("Dash on an enemy's white flash: riptide", 8, hint, HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(UI.label("Rest in a cleared room: the shore continues the night", 8, hint, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		box.add_child(UI.label("E talks to people; the shore leads down", 8, hint, HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(UI.label("Pearls and rescues are already saved", 8, hint, HORIZONTAL_ALIGNMENT_CENTER))
	_root = center


func _open_codex() -> void:
	var c := get_parent().get_node_or_null("CodexUI") as CodexUI
	if c == null:
		return
	toggle()
	c.open()


func _open_log() -> void:
	var l := get_parent().get_node_or_null("LogUI") as LogUI
	if l == null:
		return
	toggle()
	l.open(0, get_parent() if _in_run() else null)


func _open_settings() -> void:
	var s := get_parent().get_node_or_null("SettingsUI") as SettingsUI
	if s == null:
		return
	toggle()
	s.open()


## Rest is only offered once the room is cleared and its doors are open.
func _refresh_rest() -> void:
	if _rest_btn == null:
		return
	var run := get_parent() as Run
	var ok := run != null and run.can_rest()
	_rest_btn.text = "Rest here   [R]" if ok else "Rest here   [R]   (clear the room first)"
	_rest_btn.disabled = not ok


## Save the night at this room and go back up; the shore picks it up next time.
func _rest() -> void:
	var run := get_parent() as Run
	if run == null or not run.can_rest():
		_refresh_rest()
		return
	get_tree().paused = false
	_open = false
	visible = false
	if run.rest():
		Game.go_to_hub()


func _to_title() -> void:
	get_tree().paused = false
	_open = false
	visible = false
	SaveManager.save_profile()
	Game.go_to_title()


## Quit is two presses so a stray click cannot end the night.
func _quit_game() -> void:
	if not _quit_armed:
		_quit_armed = true
		_quit_btn.text = "Really quit?   [X] again"
		return
	SaveManager.save_profile()
	get_tree().quit()


func _disarm_quit() -> void:
	_quit_armed = false
	if _quit_btn:
		_quit_btn.text = "Quit game   [X]"


func _quit_to_hub() -> void:
	get_tree().paused = false
	_open = false
	visible = false
	var run := get_parent() as Run
	if run and not run.state.ended:
		run.give_up()
	else:
		Game.go_to_hub()
