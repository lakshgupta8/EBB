extends Node2D
## The entrance: Marrow Rock seen from the water at night. Stars, a thin moon, the
## lighthouse sweeping its lamp over the sea, and Tam on the near shore with the one warm
## light. The menu sits over the water. Keep the tide starts (or continues) at the rock.
## Everything here is drawn on the pixel grid; nothing is scaled. The logo is drawn at
## its own size by tools/gen_logo.py (Stage 18).

const LOGO := preload("res://assets/sprites/logo.png")
const GLOW := preload("res://assets/sprites/haze.png")  # a soft sprite; the light texture is two-zone now
const PLAYER_SHEET := preload("res://assets/sprites/player.png")
const GULL_SHEET := preload("res://assets/sprites/gull.png")

# The palette (STYLE.md section 6).
const INK := Color("#10121c")
const ABYSS := Color("#151a2a")
const NIGHT1 := Color("#1f2536")
const NIGHT2 := Color("#2c3447")
const SLATE := Color("#414c62")
const WET := Color("#5d6b82")
const PALE := Color("#8494a8")
const SALT := Color("#d9e3e8")
const FOAM := Color("#f4f8f6")
const DEEP := Color("#1c3048")
const SEA := Color("#26485e")
const SHALLOW := Color("#357083")
const SEA_PALE := Color("#5f9c9f")
const IRON_D := Color("#2b2f37")
const IRON := Color("#4a515c")
const IRON_L := Color("#7f8894")
const AMBER := Color("#dc8f3c")
const WARM := Color("#f2c85c")
const CREAM := Color("#fbeccb")

const HORIZON := 150
const SHORE_Y := 300
const LAMP := Vector2(484, 87)   # the lamp room window
const MOON := Vector2(552, 44)
const TAM := Vector2(128, 292)
const REDRAW_HZ := 15.0          # the sea and stars step, they do not glide

var _t: float = 0.0
var _beam_angle: float = 3.9     # starts pointing away over the land, sweeps in during the intro
var _cursor: UI.Cursor
var _buttons: Array = []
var _busy: bool = false
var _backdrop: Backdrop
var _sea: Sea
var _beams: Array = []
var _lamp_glow: Sprite2D
var _lamp_halo: Sprite2D
var _lantern: Sprite2D
var _lantern_pool: Sprite2D
var _gull: Sprite2D
var _gull_t: float = -1.0
var _gull_next: float = 5.0
var _gull_y: float = 80.0
var _marker: Polygon2D
var _box: VBoxContainer
var _logo: TextureRect

@onready var codex_ui: CodexUI = $CodexUI
@onready var settings_ui: SettingsUI = $SettingsUI
@onready var log_ui: LogUI = $LogUI
@onready var layer: CanvasLayer = $Layer
var slots_ui: SlotsUI
var modes_ui: ModesUI


func _ready() -> void:
	Game.state = Game.State.BOOT
	if "--sim-save" in OS.get_cmdline_user_args():
		SaveManager.use_path("user://sim_save.json")
	process_mode = Node.PROCESS_MODE_ALWAYS  # the sea keeps moving behind the codex
	_build_world()
	_build_menu()
	Audio.ambient("ambient_sea", -12.0)
	Audio.music("music_title", -9.0)
	Audio.gulls_enabled = true
	slots_ui = SlotsUI.new()
	slots_ui.name = "SlotsUI"
	add_child(slots_ui)
	modes_ui = ModesUI.new()
	modes_ui.name = "ModesUI"
	add_child(modes_ui)
	modes_ui.closed.connect(_refresh)
	modes_ui.start.connect(_start_mode)
	codex_ui.closed.connect(_refresh)
	settings_ui.closed.connect(_refresh)
	log_ui.closed.connect(_refresh)
	slots_ui.closed.connect(_refresh)
	_intro()
	_handle_screenshot_arg()


# --- the view ------------------------------------------------------------------------
func _build_world() -> void:
	_backdrop = Backdrop.new()
	add_child(_backdrop)
	_sea = Sea.new()
	add_child(_sea)
	for i in 2:
		var b := _make_beam(_beam_angle + PI * i)
		add_child(b)
		_beams.append(b)
	_lamp_halo = _glow(LAMP, AMBER, 0.16, Vector2(2.4, 2.4))
	_lamp_glow = _glow(LAMP, WARM, 0.7, Vector2(0.55, 0.55))
	_gull = Sprite2D.new()
	_gull.texture = GULL_SHEET
	_gull.region_enabled = true
	_gull.region_rect = Rect2(0, 0, 24, 24)
	_gull.modulate = NIGHT2   # far off and unlit: a shape against the sky
	_gull.flip_h = true
	_gull.visible = false
	add_child(_gull)
	add_child(Shore.new())
	# Tam, in whatever coat the Log has earned, looking out at the rock.
	var tam := AnimatedSprite2D.new()
	var sheet = load(KeeperLog.coat_sheet()) if ResourceLoader.exists(KeeperLog.coat_sheet()) else null
	tam.sprite_frames = SheetFrames.build(sheet if sheet is Texture2D else PLAYER_SHEET, 24, {
		"idle": {"frames": [0, 1], "fps": 3}})
	tam.position = TAM
	tam.play("idle")
	add_child(tam)
	_lantern_pool = _glow(TAM + Vector2(6, 6), AMBER, 0.22, Vector2(1.8, 0.7))
	_lantern = _glow(TAM + Vector2(8, -3), WARM, 0.55, Vector2(0.9, 0.9))


func _glow(at: Vector2, color: Color, alpha: float, scale_: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = GLOW
	s.position = at
	s.scale = scale_
	s.modulate = Color(color, alpha)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	add_child(s)
	return s


func _make_beam(rot: float) -> Polygon2D:
	var p := Polygon2D.new()
	var length := 600.0
	var half := length * tan(deg_to_rad(3.0))
	p.polygon = PackedVector2Array([Vector2.ZERO, Vector2(length, -half), Vector2(length, half)])
	p.vertex_colors = PackedColorArray([Color(WARM, 0.4), Color(WARM, 0.0), Color(WARM, 0.0)])
	p.position = LAMP
	p.rotation = rot
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	return p


func _process(delta: float) -> void:
	var was := _t
	_t += delta
	_beam_angle += delta * 0.42
	# The lamp turned toward us: the sea under it lights up, the beam itself brightens.
	var facing := maxf(0.0, sin(_beam_angle))
	for i in _beams.size():
		_beams[i].rotation = _beam_angle + PI * i
		_beams[i].modulate.a = 0.55 + 0.45 * (facing if i == 0 else maxf(0.0, -sin(_beam_angle)))
	_lamp_glow.modulate.a = 0.6 + 0.12 * sin(_t * 3.1)
	_lamp_halo.modulate.a = 0.12 + 0.08 * facing
	_lantern.modulate.a = 0.5 + 0.08 * sin(_t * 2.3) + 0.03 * sin(_t * 7.0)
	_lantern_pool.modulate.a = 0.2 + 0.04 * sin(_t * 2.3)
	_sea.facing = facing
	if int(_t * REDRAW_HZ) != int(was * REDRAW_HZ):
		_backdrop.t = _t
		_sea.t = _t
		_backdrop.queue_redraw()
		_sea.queue_redraw()
	_tick_gull(delta)


## Now and then a gull crosses the sky, right to left, far off.
func _tick_gull(delta: float) -> void:
	if _gull_t < 0.0:
		_gull_next -= delta
		if _gull_next <= 0.0:
			_gull_t = 0.0
			_gull_y = randf_range(36.0, 118.0)
			_gull.visible = true
		return
	_gull_t += delta
	var x := 672.0 - _gull_t * 34.0
	_gull.position = Vector2(roundf(x), roundf(_gull_y + sin(_gull_t * 1.1) * 5.0))
	_gull.region_rect = Rect2(24 * (int(_gull_t * 7.0) % 4), 0, 24, 24)
	if x < -40.0:
		_gull_t = -1.0
		_gull.visible = false
		_gull_next = randf_range(9.0, 18.0)


# --- the menu ------------------------------------------------------------------------
func _build_menu() -> void:
	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.stretch_mode = TextureRect.STRETCH_KEEP
	_logo.position = Vector2(320 - LOGO.get_width() / 2, 24)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_logo)
	var tag := UI.label("keep the tide", 8, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	UI.whisper(tag)
	tag.name = "Tag"
	tag.position = Vector2(200, 24 + LOGO.get_height() + 4)
	tag.size = Vector2(240, 10)
	layer.add_child(tag)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 2)
	_box.position = Vector2(64, 166)
	_box.size = Vector2(176, 0)
	layer.add_child(_box)
	_marker = Polygon2D.new()
	_marker.polygon = PackedVector2Array([Vector2(0, 0), Vector2(5, 3), Vector2(0, 6)])
	_marker.color = WARM
	layer.add_child(_marker)
	_buttons = []
	var items := [
		[_primary_text(), func(): _start()],
		["The sea keeps time", func(): modes_ui.open()],
		["Keeper's Log", func(): log_ui.open()],
		["Codex", func(): codex_ui.open()],
		["Settings", func(): settings_ui.open()],
		["Keeper", func(): slots_ui.open()],
		["Quit", func(): _quit()],
	]
	for i in items.size():
		var b := _menu_button(items[i][0], i + 1)
		b.pressed.connect(items[i][1])
		b.mouse_entered.connect(func():
			if _cursor.index != i:
				_cursor.index = i
				_apply_cursor())
		_box.add_child(b)
		_buttons.append(b)
	_cursor = UI.Cursor.new(_buttons)
	_cursor.index = 0

	var hints := UI.label("", 8, WET)
	hints.name = "Hints"
	hints.position = Vector2(16, 346)
	hints.size = Vector2(440, 10)
	layer.add_child(hints)
	var waits := UI.label("a night waits at the shore", 8, WARM, HORIZONTAL_ALIGNMENT_CENTER)
	waits.name = "Waits"
	waits.position = Vector2(120, 312)
	waits.size = Vector2(400, 10)
	layer.add_child(waits)
	var info := UI.label("", 8, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	info.name = "Info"
	info.position = Vector2(120, 326)
	info.size = Vector2(400, 10)
	layer.add_child(info)
	var ver := UI.label("EBB %s   slot %d" % [Game.VERSION, SaveManager.slot_in_use()], 8, WET, HORIZONTAL_ALIGNMENT_RIGHT)
	ver.name = "Version"
	ver.position = Vector2(520, 346)
	ver.size = Vector2(114, 10)
	layer.add_child(ver)
	_refresh()


## A row over the water: dark glass, a warm edge when it is the one you are on.
func _menu_button(text: String, slot: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _row(Color(NIGHT1, 0.6), IRON_D))
	b.add_theme_stylebox_override("hover", _row(Color(SLATE, 0.75), IRON_L))
	b.add_theme_stylebox_override("pressed", _row(Color(NIGHT1, 0.9), WARM))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.text = UI.t(text)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UI.set_size(b, 8)
	b.add_theme_color_override("font_color", SALT)
	b.add_theme_color_override("font_hover_color", FOAM)
	b.add_theme_color_override("font_pressed_color", WARM)
	b.custom_minimum_size = Vector2(176, 20)
	var key := UI.label(str(slot), 8, WET, HORIZONTAL_ALIGNMENT_RIGHT)
	UI.fill(key, 8, 5)
	b.add_child(key)
	return b


func _row(bg: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1)
	s.content_margin_left = 16
	s.content_margin_right = 8
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s


func _primary_text() -> String:
	if Game.has_suspended():
		return "Return to the shore"
	if int(SaveManager.data.runs) == 0:
		return "Begin the first night"
	return "Keep the tide"


func _apply_cursor() -> void:
	for i in _buttons.size():
		var b: Button = _buttons[i]
		b.modulate = Color.WHITE
		b.add_theme_color_override("font_color", WARM if i == _cursor.index else SALT)
	if _cursor.index >= 0 and _cursor.index < _buttons.size():
		var b: Button = _buttons[_cursor.index]
		_marker.visible = true
		_marker.position = Vector2(_box.position.x + 6, _box.position.y + b.position.y + 7)
	else:
		_marker.visible = false


func _refresh() -> void:
	var s := SaveManager.data
	_buttons[0].text = UI.t(_primary_text())
	var info: Label = layer.get_node("Info")
	var waits: Label = layer.get_node("Waits")
	if int(s.runs) == 0:
		info.text = "a new keeper.  the tide is out."
	else:
		var endings := Story.endings_seen().size()
		info.text = "night %d    wins %d    echoes %d    pearls %d%s" % [int(s.runs) + 1, s.wins,
			int(s.get("echoes", 0)), s.pearls, "    endings %d/3" % endings if endings > 0 else ""]
	waits.visible = Game.has_suspended()
	(layer.get_node("Version") as Label).text = "EBB %s   slot %d" % [Game.VERSION, SaveManager.slot_in_use()]
	var hints: Label = layer.get_node("Hints")
	hints.text = "%s choose    %s move    1-%d jump    F11 fullscreen" % [UI.hint("accept"),
		"[d-pad]" if Game.gamepad else "[%s / %s]" % [Settings.key_name("move_up"), Settings.key_name("move_down")], _buttons.size()]
	_apply_cursor()


func _input(event: InputEvent) -> void:
	if _busy or codex_ui.is_open or settings_ui.is_open or log_ui.is_open or slots_ui.is_open or modes_ui.is_open:
		return
	var i := UI.menu_index(event)
	var nav := UI.nav(event)
	if i >= 0 and i < _buttons.size():
		_cursor.index = i
		_apply_cursor()
		_buttons[i].pressed.emit()
		get_viewport().set_input_as_handled()
	elif nav != "" and _cursor.handle(nav):
		_apply_cursor()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_start()
		get_viewport().set_input_as_handled()


# --- in and out ----------------------------------------------------------------------
## Out of the dark: the lamp is already turning; the logo settles, then the menu.
func _intro() -> void:
	var fade := _full_rect(Color(INK, 1.0))
	_logo.modulate.a = 0.0
	layer.get_node("Tag").modulate.a = 0.0
	_box.modulate.a = 0.0
	_marker.modulate.a = 0.0
	layer.get_node("Hints").modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 1.1)
	tw.tween_callback(fade.queue_free)
	var tw2 := create_tween()
	tw2.tween_interval(0.4)
	tw2.tween_property(_logo, "modulate:a", 1.0, 0.7)
	tw2.parallel().tween_property(_logo, "position:y", 24.0, 0.7).from(20.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw2.tween_property(layer.get_node("Tag"), "modulate:a", 1.0, 0.5)
	var tw3 := create_tween()
	tw3.tween_interval(0.9)
	tw3.tween_property(_box, "modulate:a", 1.0, 0.5)
	tw3.parallel().tween_property(_marker, "modulate:a", 1.0, 0.5)
	tw3.parallel().tween_property(layer.get_node("Hints"), "modulate:a", 1.0, 0.5)


## A mode picked in the menu: the same tide, but it goes straight down.
func _start_mode(mode: String, seed_value: int) -> void:
	_start(func(): Game.go_to_run(seed_value, mode))


## The tide comes in over the screen, then the dark, then the rock.
func _start(then: Callable = Game.go_to_hub) -> void:
	if _busy:
		return
	_busy = true
	Audio.play("splash", 0.0, -2.0)
	var water := ColorRect.new()
	water.color = SEA
	water.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	water.offset_top = 360
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(water)
	var foam := ColorRect.new()
	foam.color = SALT
	foam.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	foam.offset_bottom = 2
	foam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.add_child(foam)
	var fade := _full_rect(Color(INK, 0.0))
	var tw := create_tween()
	tw.tween_property(water, "offset_top", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	tw.tween_callback(then)


func _full_rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	return r


func _quit() -> void:
	SaveManager.save_profile()
	get_tree().quit()


func _handle_screenshot_arg() -> void:
	if not "--screenshot" in OS.get_cmdline_user_args():
		return
	await get_tree().create_timer(2.4).timeout  # the intro is over by then
	var args := OS.get_cmdline_user_args()
	var name := "title"
	if "--settings" in args or "--settings2" in args:
		settings_ui.open()
		name = "title_settings"
		if "--settings2" in args:
			settings_ui.set_page(1)
			name = "title_settings2"
	elif "--controls" in args:
		settings_ui._controls.open()
		if "--listen" in args:
			settings_ui._controls._start_listen("dash")
		name = "title_controls"
	elif "--slots" in args:
		slots_ui.open()
		name = "title_slots"
	elif "--modes" in args:
		modes_ui.open()
		name = "title_modes"
	elif "--history" in args:
		modes_ui.open(1)
		name = "title_history"
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	print("screenshot -> %s/%s.png (%s)" % [dir, name, error_string(img.save_png(dir + "/%s.png" % name))])
	get_tree().quit()


# --- painted layers ------------------------------------------------------------------
## The sky, the stars, the moon, Marrow Rock and its tower. Stars step through three
## brightnesses rather than fading, so they read as pixels.
class Backdrop extends Node2D:
	var t: float = 0.0
	var _stars: Array = []   # [x, y, phase, speed, bright]
	const ISLAND := [[134, 474, 494], [136, 466, 502], [138, 458, 510], [140, 450, 518], [142, 442, 526],
		[144, 436, 534], [146, 430, 542], [148, 424, 548], [150, 418, 554], [152, 414, 558], [154, 412, 560]]

	func _init() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 130:
			_stars.append([rng.randi_range(2, 637), rng.randi_range(2, HORIZON - 16), rng.randf() * TAU,
				rng.randf_range(0.5, 2.0), rng.randf() < 0.22])

	func _draw() -> void:
		for b in [[0, 44, INK], [44, 84, Color("#131727")], [84, 116, ABYSS], [116, 138, Color("#1a2033")], [138, HORIZON, NIGHT1]]:
			draw_rect(Rect2(0, b[0], 640, b[1] - b[0]), b[2])
		_dither(44, INK, Color("#131727"))
		_dither(84, Color("#131727"), ABYSS)
		_dither(116, ABYSS, Color("#1a2033"))
		draw_rect(Rect2(0, HORIZON - 1, 640, 1), Color(SLATE, 0.6))  # the haze line
		for s in _stars:
			var k: float = sin(t * s[3] + s[2])
			if k < -0.45:
				continue
			var c: Color = SALT if s[4] else PALE
			c.a = 0.35 if k < 0.2 else (0.7 if k < 0.75 else 1.0)
			draw_rect(Rect2(s[0], s[1], 1, 1), c)
		# The moon: a thin one, its dark side the colour of the sky behind it.
		_disc(MOON, 9, SALT)
		_disc(MOON + Vector2(4, -2), 8, Color("#131727"))
		draw_rect(Rect2(MOON.x - 6, MOON.y + 3, 1, 1), FOAM)
		draw_rect(Rect2(MOON.x - 7, MOON.y - 2, 1, 1), FOAM)
		# Marrow Rock: a black shape on the horizon with a moonlit rim on its right side.
		for r in ISLAND:
			draw_rect(Rect2(r[1], r[0], r[2] - r[1], 2), INK)
			draw_rect(Rect2(r[2] - 2, r[0], 2, 1), NIGHT2)
		_tower()

	func _tower() -> void:
		var cx := int(LAMP.x)
		# Body: eight wide at the gallery, twelve at the foot; the lit face is to the left.
		for yy in range(96, 136, 2):
			var w := 8 + (yy - 96) / 10
			var x0 := cx - w / 2
			draw_rect(Rect2(x0, yy, w, 2), NIGHT2)
			draw_rect(Rect2(x0, yy, 2, 2), SLATE)
			draw_rect(Rect2(x0 + w - 1, yy, 1, 2), INK)
		for band in [104, 120]:
			draw_rect(Rect2(cx - 5, band, 10, 4), WET)
			draw_rect(Rect2(cx - 5, band, 2, 4), PALE)
		draw_rect(Rect2(cx - 8, 92, 16, 2), IRON_D)   # the gallery
		draw_rect(Rect2(cx - 8, 92, 16, 1), IRON)
		draw_rect(Rect2(cx - 6, 83, 12, 9), IRON_D)   # the lamp room
		draw_rect(Rect2(cx - 4, 84, 8, 6), WARM)
		draw_rect(Rect2(cx - 2, 85, 4, 3), CREAM)
		draw_rect(Rect2(cx - 6, 83, 1, 9), IRON)
		draw_rect(Rect2(cx + 5, 83, 1, 9), IRON)
		draw_rect(Rect2(cx - 5, 80, 10, 3), NIGHT1)   # the cap
		draw_rect(Rect2(cx - 3, 78, 6, 2), NIGHT1)
		draw_rect(Rect2(cx - 1, 76, 2, 2), IRON_L)

	func _disc(c: Vector2, r: int, col: Color) -> void:
		for dy in range(-r, r + 1):
			var hw := int(floor(sqrt(float(r * r - dy * dy))))
			draw_rect(Rect2(c.x - hw, c.y + dy, hw * 2 + 1, 1), col)

	## A one-pixel checker between two sky bands: the only place the sky is allowed to dither.
	func _dither(y: int, above: Color, below: Color) -> void:
		for x in range(0, 640, 2):
			draw_rect(Rect2(x, y - 1, 1, 1), below)
			draw_rect(Rect2(x + 1, y, 1, 1), above)


## Three bands of water with crests that drift and step, the lamp's road on the water
## when it turns this way, the moon's glitter, and the foam line along the shore.
class Sea extends Node2D:
	var t: float = 0.0
	var facing: float = 0.0
	const MID := Color("#213d54")

	func _draw() -> void:
		draw_rect(Rect2(0, HORIZON, 640, 42), DEEP)
		draw_rect(Rect2(0, HORIZON + 42, 640, 58), MID)
		draw_rect(Rect2(0, HORIZON + 100, 640, SHORE_Y + 10 - HORIZON - 100), SEA)
		for x in range(0, 640, 2):
			draw_rect(Rect2(x, HORIZON + 41, 1, 1), MID)
			draw_rect(Rect2(x + 1, HORIZON + 99, 1, 1), MID)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for row in 18:
			var y := HORIZON + 4 + int(row * 5 + row * row * 0.42)
			if y >= SHORE_Y - 3:
				break
			var depth := float(y - HORIZON) / float(SHORE_Y - HORIZON)
			var speed := 5.0 + 20.0 * depth
			var period := 36 + int(56 * depth)
			var col := SHALLOW.lerp(SEA_PALE, depth)
			col.a = 0.3 + 0.45 * depth
			var phase := rng.randf() * period
			var drift := speed if row % 3 != 1 else -speed * 0.6
			for k in 640 / period + 3:
				var x := int(fposmod(k * period + phase + t * drift, float(640 + period))) - period
				var w := 3 + int(9.0 * depth) + (k % 3) * 2
				var yy := y + int(roundf(sin(t * 0.8 + k * 1.7 + row) * (0.4 + depth)))
				draw_rect(Rect2(x, yy, w, 1), col)
				if depth > 0.55 and k % 4 == 1:
					draw_rect(Rect2(x + 1, yy - 1, w / 2, 1), Color(SALT, col.a * 0.5))
		# The lamp's road on the water, and the moon's.
		for i in 24:
			var y := HORIZON + 6 + i * 6
			if y > SHORE_Y - 4:
				break
			var jitter := int(roundf(sin(t * 2.1 + i * 1.3) * (1.5 + i * 0.35)))
			var w := 3 + i / 3
			var a := (0.1 + 0.6 * facing) * (1.0 - i / 28.0)
			draw_rect(Rect2(int(LAMP.x) - w / 2 + jitter, y, w, 1), Color(WARM, a))
			if i % 2 == 0:
				var mj := int(roundf(sin(t * 1.6 + i * 2.1) * (2.0 + i * 0.3)))
				draw_rect(Rect2(int(MOON.x) - 4 - i / 4 + mj, y + 3, 2 + i / 5, 1), Color(PALE, 0.35 * (1.0 - i / 26.0)))
		# Foam where the water meets the near shore.
		for k in 26:
			var x := int(fposmod(k * 26 + t * 9.0, 666.0)) - 26
			var w := 6 + (k % 3) * 4
			var yy := SHORE_Y - 2 + int(roundf(sin(t * 1.5 + k) * 1.0))
			draw_rect(Rect2(x, yy, w, 1), Color(SALT, 0.7))


## The near shore: the black rock we stand on, with a wet rim.
class Shore extends Node2D:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var h := 0
		for i in 80:
			var x := i * 8
			var target := 0
			if x >= 96 and x < 176:
				target = 10       # the ledge Tam stands on
			elif x >= 16 and x < 56:
				target = 16 - absi(x - 36) / 4   # a rock at the left
			elif x >= 560:
				target = 4 + (x - 560) / 20
			h = target + rng.randi_range(0, 2)
			draw_rect(Rect2(x, SHORE_Y - h, 8, 60 + h), INK)
			draw_rect(Rect2(x, SHORE_Y - h, 8, 1), NIGHT2)
			if rng.randf() < 0.3:
				draw_rect(Rect2(x + rng.randi_range(0, 6), SHORE_Y - h, 2, 1), Color(SALT, 0.6))
