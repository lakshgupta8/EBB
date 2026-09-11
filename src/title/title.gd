extends Node2D
## The title: Marrow Rock at night behind the logo, the sea breathing, and a short menu.
## Keep the tide starts (or continues) at the lighthouse.

const HUB_TEMPLATE := "res://data/rooms/hub.txt"
const LOGO := preload("res://assets/sprites/logo.png")

var room: Room
var _cursor: UI.Cursor
var _buttons: Array = []
var _busy: bool = false

@onready var codex_ui: CodexUI = $CodexUI
@onready var settings_ui: SettingsUI = $SettingsUI
@onready var layer: CanvasLayer = $Layer


func _ready() -> void:
	Game.state = Game.State.BOOT
	if "--sim-save" in OS.get_cmdline_user_args():
		SaveManager.use_path("user://sim_save.json")
	room = Room.new()
	$RoomHolder.add_child(room)
	room.build(RoomTemplate.load_file(HUB_TEMPLATE))
	room.set_tide(0.62)
	var h_cells: Array = room.template.marker_cells("h")
	if h_cells.size() > 0:
		var lo: Vector2i = h_cells[0]
		var hi: Vector2i = h_cells[0]
		for c in h_cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		var tower := Prop.new()
		room.add_child(tower)
		tower.setup(Prop.Kind.LIGHTHOUSE, (room.cell_to_world(lo) + room.cell_to_world(hi)) * 0.5)
	Atmosphere.build(self, Vector2(640, 368))
	Audio.ambient("ambient_sea", -12.0)
	Audio.music("music_hub", -10.0)
	Audio.gulls_enabled = true
	_breathe()
	_build_menu()
	codex_ui.closed.connect(_refresh)
	settings_ui.closed.connect(_refresh)
	_handle_screenshot_arg()


## The sea comes and goes under the rock.
func _breathe() -> void:
	var tw := create_tween().set_loops()
	tw.tween_method(room.set_tide, 0.62, 0.78, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(room.set_tide, 0.78, 0.62, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_menu() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.08, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.stretch_mode = TextureRect.STRETCH_KEEP
	logo.scale = Vector2(2, 2)
	logo.position = Vector2(320 - LOGO.get_width(), 44)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(logo)
	var tag := UI.label("keep the tide", 8, Color(0.75, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	tag.position = Vector2(220, 44 + LOGO.get_height() * 2 + 6)
	tag.size = Vector2(200, 10)
	layer.add_child(tag)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.position = Vector2(320 - 110, 176)
	box.size = Vector2(220, 0)
	layer.add_child(box)
	_buttons = []
	var s := SaveManager.data
	var first := int(s.runs) == 0
	var items := [
		["Keep the tide   [1]" if first else "Keep the tide   [1]", func(): _start()],
		["Codex   [2]", func(): codex_ui.open()],
		["Settings   [3]", func(): settings_ui.open()],
		["Quit   [4]", func(): _quit()],
	]
	for it in items:
		var b := UI.text_button(it[0])
		b.custom_minimum_size = Vector2(220, 20)
		b.pressed.connect(it[1])
		box.add_child(b)
		_buttons.append(b)
	_cursor = UI.Cursor.new(_buttons)
	_cursor.index = 0
	_cursor.apply()

	var info := UI.label("", 8, Color(0.6, 0.65, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	info.name = "Info"
	info.position = Vector2(120, 300)
	info.size = Vector2(400, 10)
	layer.add_child(info)
	var ver := UI.label("EBB %s" % Game.VERSION, 8, Color(0.45, 0.5, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
	ver.position = Vector2(520, 344)
	ver.size = Vector2(114, 10)
	layer.add_child(ver)
	_refresh()


func _refresh() -> void:
	var s := SaveManager.data
	var info: Label = layer.get_node("Info")
	if int(s.runs) == 0:
		info.text = "a new keeper.  the tide is out."
	else:
		var endings := Story.endings_seen().size()
		info.text = "night %d   wins %d   echoes %d   pearls %d%s" % [int(s.runs) + 1, s.wins, int(s.get("echoes", 0)), s.pearls,
			"   endings %d/3" % endings if endings > 0 else ""]


func _input(event: InputEvent) -> void:
	if _busy or codex_ui.is_open or settings_ui.is_open:
		return
	var i := UI.menu_index(event)
	var nav := UI.nav(event)
	if i >= 0 and i < _buttons.size():
		_buttons[i].pressed.emit()
		get_viewport().set_input_as_handled()
	elif nav != "" and _cursor.handle(nav):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_start()
		get_viewport().set_input_as_handled()


func _start() -> void:
	if _busy:
		return
	_busy = true
	Audio.play("door", 0.0, -4.0)
	var fade := ColorRect.new()
	fade.color = Color(0.04, 0.03, 0.08, 0.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6)
	tw.tween_callback(Game.go_to_hub)


func _quit() -> void:
	SaveManager.save_profile()
	get_tree().quit()


func _handle_screenshot_arg() -> void:
	if not "--screenshot" in OS.get_cmdline_user_args():
		return
	for i in 50:
		await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	print("screenshot -> %s/title.png (%s)" % [dir, error_string(img.save_png(dir + "/title.png"))])
	get_tree().quit()
