class_name MpMenu
extends Control
## The Multiplayer screen: host a night or join one by address, then the lobby (mode, ready,
## start). Every page is rebuilt from `Net.state`, so coming back from a match lands in the lobby.

const CLIENT_SCENE := "res://src/net/client_view.tscn"
const PVP_SCENE := "res://src/multiplayer/pvp_arena.tscn"

var _content: Control
var _status: Label
var _addr: LineEdit
var _note: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	Net.state_changed.connect(_on_state)
	Net.left.connect(_on_left)
	Net.lobby_changed.connect(_render)
	_render()


func _exit_tree() -> void:
	for pair in [[Net.state_changed, _on_state], [Net.left, _on_left], [Net.lobby_changed, _render]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func _process(_delta: float) -> void:
	if _status != null and Net.state == NetSession.State.LOBBY:
		_status.text = "link %d ms" % int(Net.rtt_ms)


func _unhandled_input(event: InputEvent) -> void:
	if UI.is_close(event):
		_back()
		get_viewport().set_input_as_handled()


func _back() -> void:
	Net.leave("")
	Game.go_to_title()


func _on_left(reason: String) -> void:
	_note = reason
	_render()


func _on_state(s: int) -> void:
	if s == NetSession.State.IN_COOP:
		_launch_coop()
	elif s == NetSession.State.IN_PVP:
		_launch(PVP_SCENE)
	else:
		_render()


func _launch_coop() -> void:
	if Net.is_host():
		Game.go_to_run()
	else:
		_launch(CLIENT_SCENE)


func _launch(path: String) -> void:
	if ResourceLoader.exists(path):
		get_tree().call_deferred("change_scene_to_file", path)
	else:
		_note = "that mode is not built into this version"
		Net.return_to_lobby()


# --- pages ----------------------------------------------------------------------------------

func _render() -> void:
	if _content != null:
		_content.queue_free()
	_status = null
	_addr = null
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_content = center
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.custom_minimum_size = Vector2(360, 0)
	panel.add_child(box)
	box.add_child(UI.header("TWO KEEPERS"))
	match Net.state:
		NetSession.State.IDLE:
			_page_menu(box)
		NetSession.State.HOSTING:
			_page_waiting(box)
		NetSession.State.JOINING:
			box.add_child(UI.label("reaching the other keeper...", 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER))
			box.add_child(_button("Cancel", func(): Net.leave("")))
		_:
			_page_lobby(box)
	if _note != "":
		box.add_child(UI.spacer(4))
		box.add_child(UI.label(_note, 8, UI.DANGER, HORIZONTAL_ALIGNMENT_CENTER))


func _page_menu(box: VBoxContainer) -> void:
	box.add_child(UI.label("co-op through the ruins, or a duel on the sand", 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(4))
	box.add_child(_button("Host a night", func():
		_note = ""
		var err := Net.host()
		if err != OK:
			_note = "could not open port %d (%s)" % [NetProtocol.DEFAULT_PORT, error_string(err)]
		_render()))
	box.add_child(UI.spacer(2))
	box.add_child(UI.label("or join a keeper at their address", 8, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_addr = LineEdit.new()
	_addr.text = "192.168."
	_addr.placeholder_text = "host address"
	_addr.custom_minimum_size = Vector2(0, 18)
	UI.set_size(_addr, 8)
	_addr.text_submitted.connect(func(_t): _join())
	box.add_child(_addr)
	box.add_child(_button("Join", _join))
	box.add_child(UI.spacer(4))
	box.add_child(_button("Back", _back))


func _page_waiting(box: VBoxContainer) -> void:
	box.add_child(UI.label("waiting for the other keeper", 8, UI.PRIMARY, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("tell them: " + _addresses(), 8, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("port %d (UDP), both on the same version" % NetProtocol.DEFAULT_PORT, 8, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(4))
	box.add_child(_button("Cancel", func(): Net.leave("")))


func _page_lobby(box: VBoxContainer) -> void:
	_status = UI.label("", 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_status)
	var mode_text := "Night: co-op" if Net.mode == "coop" else "Night: duel (PvP)"
	if Net.is_host():
		box.add_child(_button(mode_text + "  (click to change)", func():
			Net.set_mode("pvp" if Net.mode == "coop" else "coop")))
	else:
		box.add_child(UI.label(mode_text + "  (the host chooses)", 8, UI.PRIMARY, HORIZONTAL_ALIGNMENT_CENTER))
	var mine := Net.host_ready if Net.is_host() else Net.guest_ready
	var theirs := Net.guest_ready if Net.is_host() else Net.host_ready
	box.add_child(UI.label("you: %s     them: %s" % ["ready" if mine else "not ready", "ready" if theirs else "not ready"], 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_button("Not ready" if mine else "Ready", func(): Net.set_ready(not mine)))
	if Net.is_host():
		var start := _button("Start", func():
			if not Net.start_game():
				_note = "both keepers must be ready")
		box.add_child(start)
	box.add_child(UI.spacer(4))
	box.add_child(_button("Leave", _back))


func _join() -> void:
	if _addr == null:
		return
	_note = ""
	var err := Net.join(_addr.text.strip_edges())
	if err != OK:
		_note = "could not start the connection (%s)" % error_string(err)
	_render()


func _button(text: String, cb: Callable) -> Button:
	var b := UI.text_button(text, 8, UI.PRIMARY)
	b.custom_minimum_size = Vector2(0, 20)
	b.pressed.connect(cb)
	return b


## The addresses another machine can try, never loopback or link-local.
static func _addresses() -> String:
	var out: PackedStringArray = []
	var rx := RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+\\.\\d+$")
	for a in IP.get_local_addresses():
		if rx.search(a) != null and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return ", ".join(out) if not out.is_empty() else "(no network found)"
