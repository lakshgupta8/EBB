extends Node
## Drives the menus with injected keyboard events, the way a player would.
##   godot --headless --path . tests/sim_ui.tscn

const RUN := preload("res://src/run/run.tscn")

var run: Run
var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("sim_ui: ok   " + msg)
	else:
		_fails += 1
		printerr("sim_ui: FAIL " + msg)


func _key(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _find_buttons(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_find_buttons(c))
	return out


func _click(pos: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	Input.parse_input_event(mv)
	await get_tree().process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)
		await get_tree().process_frame
	await get_tree().process_frame


func _ready() -> void:
	SaveManager.use_path("user://sim_save.json")
	Game.run_seed = 5
	run = RUN.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	# Altar: open with three offers, press 2, expect the second mark taken and the menu gone.
	var offers := Tidemarks.roll(RandomNumberGenerator.new(), [], 3)
	run.altar_ui.open(offers)
	await get_tree().process_frame
	_check(run.altar_ui.is_open and get_tree().paused, "altar opens and pauses")
	await _key(KEY_2)
	_check(not run.altar_ui.is_open, "altar closed by key 2")
	_check(run.state.tidemarks == [offers[1]], "second offer was taken: %s" % [run.state.tidemarks])
	_check(not get_tree().paused, "tree unpaused after altar")

	# Altar again, this time by mouse: click the first card.
	offers = Tidemarks.roll(RandomNumberGenerator.new(), run.state.tidemarks, 3)
	run.altar_ui.open(offers)
	await get_tree().process_frame
	await get_tree().process_frame
	var btn: Button = null
	for b in _find_buttons(run.altar_ui):
		btn = b
		break
	_check(btn != null, "altar has clickable cards")
	if btn:
		await _click(btn.get_global_rect().get_center())
	_check(not run.altar_ui.is_open, "altar closed by mouse click")
	_check(run.state.tidemarks.size() == 2 and run.state.tidemarks[1] == offers[0], "clicked card taken: %s" % [run.state.tidemarks])

	# Numpad digits must work too.
	offers = Tidemarks.roll(RandomNumberGenerator.new(), run.state.tidemarks, 3)
	run.altar_ui.open(offers)
	await get_tree().process_frame
	await _key(KEY_KP_3)
	_check(not run.altar_ui.is_open and run.state.tidemarks[2] == offers[2], "numpad 3 picks the third card")

	# Shop: open, buy item 4 (lamp oil, cheap), close with E.
	run.state.salt = 50
	run.shop.restock()
	run.shop.open()
	await get_tree().process_frame
	_check(run.shop.is_open, "shop opens")
	await _key(KEY_4)
	_check(run.state.salt == 42, "bought lamp oil for 8 salt (salt=%d)" % run.state.salt)
	await _key(KEY_E)
	_check(not run.shop.is_open, "shop closed by E")
	_check(not get_tree().paused, "tree unpaused after shop")

	# Pause menu: Esc opens, Esc closes.
	await _key(KEY_ESCAPE)
	_check(get_tree().paused, "Esc pauses")
	await _key(KEY_ESCAPE)
	_check(not get_tree().paused, "Esc resumes")

	print("sim_ui: %s" % ("OK" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)
