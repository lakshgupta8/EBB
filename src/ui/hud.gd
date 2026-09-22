extends Control
## In-run HUD drawn as instruments at 1x (art Stage 16, STYLE.md 15): the health bar in an
## iron frame, dash lozenges, the special's bronze bar, the lantern whose glass fills with
## glow, the marks you hold as family icons, salt and pearls, the tide staff on the right
## edge, and the boss bar bound with rope. Every bar says what it is.

const BAR_W := 64
const BAR_H := 6
const ICONS := preload("res://assets/sprites/pickups.png")
const HEALTH := preload("res://assets/sprites/hud_health.png")
const PIP := preload("res://assets/sprites/hud_pip.png")
const SPECIAL := preload("res://assets/sprites/hud_special.png")
const LANTERN := preload("res://assets/sprites/hud_lantern.png")
const STAFF := preload("res://assets/sprites/hud_staff.png")
const BOSS := preload("res://assets/sprites/hud_boss.png")
const FAMILY := preload("res://assets/sprites/family_icons.png")
const FONT := preload("res://assets/fonts/ebb.fnt")
const DISPLAY := preload("res://assets/fonts/ebb_display.fnt")
const PRIMARY := Palette.SALT_WHITE
const MUTED := Palette.WET_GREY
const SECONDARY := Palette.PALE_SLATE
const WARM := Palette.WARM_YELLOW
const SEA_PALE := Palette.SEA_PALE
## The staff: its channel is x 2..7, y 6..121 of the 10x128 sprite.
const STAFF_TOP := 6
const STAFF_BOTTOM := 121

var _hp: int = 100
var _max_hp: int = 100
var _tide: float = 0.0
var _salt: int = 0
var _pearls: int = 0
var _keys: int = 0
var _player: Player
var _boss: Enemy
var _boss_shown: bool = false
var _run: Node
var _tide_flash: float = 0.0
var _hp_was: int = -1
var _hp_hit: float = 0.0


func _ready() -> void:
	EventBus.player_health_changed.connect(func(c, m):
		if _hp_was >= 0 and c < _hp_was:
			_hp_hit = 0.35
		_hp_was = c
		_hp = c
		_max_hp = m)
	EventBus.tide_changed.connect(func(l): _tide = l)
	EventBus.salt_changed.connect(func(v): _salt = v)
	EventBus.pearls_changed.connect(func(v): _pearls = v)
	EventBus.keys_changed.connect(func(v): _keys = v)
	_player = get_tree().get_first_node_in_group("player") as Player


func bind(run: Node) -> void:
	_run = run
	_rescale()
	Settings.changed.connect(func(k): if k == "hud_scale": _rescale())


## The HUD size setting: the whole layer scales, and the right edge moves in to match.
func _rescale() -> void:
	var s := Settings.hud_scale()
	scale = Vector2(s, s)


## The screen's width in HUD pixels (less than 640 when the HUD is scaled up).
func _w() -> float:
	return 640.0 / maxf(scale.x, 0.01)


func set_boss(b: Enemy) -> void:
	_boss = b


## The staff lights up for a moment: the water has just crossed a mark.
func flash_tide() -> void:
	_tide_flash = 0.9


func _process(delta: float) -> void:
	_tide_flash = maxf(0.0, _tide_flash - delta)
	_hp_hit = maxf(0.0, _hp_hit - delta)
	queue_redraw()


## Body face at 8, the display face at 16 (STYLE.md 16); `pos` is the baseline's left end.
func _text(pos: Vector2, s: String, color: Color, size: int = 8, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f: Font = DISPLAY if size >= 16 else FONT
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		pos.x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		pos.x -= floorf(f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5)
	var sh := 2 if size >= 32 else 1
	draw_string(f, pos + Vector2(sh, sh), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Palette.INK)
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _width(s: String, size: int = 8) -> int:
	var f: Font = DISPLAY if size >= 16 else FONT
	return int(f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)


## Danger at 8 px is Salt white on a Salt red tag (STYLE.md 15).
func _tag(pos: Vector2, s: String, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var w := FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var x := pos.x - (w if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0)
	draw_rect(Rect2(x - 2, pos.y - 8, w + 4, 10), Palette.SALT_RED)
	draw_string(FONT, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, PRIMARY)


func _sprite(tex: Texture2D, at: Vector2, region: Rect2) -> void:
	draw_texture_rect_region(tex, Rect2(at, region.size), region)


## How high the water stands, in a word. The marks on the staff are the same three steps.
static func tide_word(level: float) -> String:
	if level < 1.0:
		return "out"
	if level < 2.0:
		return "pools"
	if level < 3.0:
		return "flooded"
	return "deep"


func _draw() -> void:
	var x := 8
	var y := 8
	# Health: Salt red over Night 1 in an iron frame, a Pale cream line on top of the fill.
	var low := _hp * 10 < _max_hp * 3
	_sprite(HEALTH, Vector2(x - 1, y - 1), Rect2(0, 0, 66, 8))
	draw_rect(Rect2(x, y, BAR_W, BAR_H), Palette.NIGHT_1)
	var frac := float(_hp) / maxf(1.0, float(_max_hp))
	var hp_col := Palette.SALT_RED
	if _hp_hit > 0.0 and int(_hp_hit * 20) % 2 == 0:
		hp_col = Palette.PALE_CREAM
	elif low and int(Time.get_ticks_msec() / 400) % 2 == 0:
		hp_col = Palette.AMBER_DEEP
	var hw := int(BAR_W * frac)
	draw_rect(Rect2(x, y, hw, BAR_H), hp_col)
	if hw > 0:
		draw_rect(Rect2(x, y, hw, 1), Palette.PALE_CREAM)
	_text(Vector2(x + BAR_W + 5, y + 7), "%d" % _hp, PRIMARY)
	_text(Vector2(x + BAR_W + 5 + _width("%d" % _hp) + 3, y + 7), "hp", MUTED)
	if _player and is_instance_valid(_player):
		# Dashes: iron lozenges filled Sea pale.
		var py := y + BAR_H + 4
		for i in _player.max_dash:
			_sprite(PIP, Vector2(x + i * 7, py - 1), Rect2(5 if i < _player.dash_charges else 0, 0, 5, 5))
		var dx := x + _player.max_dash * 7 + 3
		_text(Vector2(dx, py + 4), "dash", MUTED)
		# The weapon's special: a bronze frame, Warm yellow when ready.
		var sx := dx + 32
		var f := _player.weapon.special_cooldown_fraction()
		_sprite(SPECIAL, Vector2(sx - 1, py - 2), Rect2(0, 0, 26, 6))
		draw_rect(Rect2(sx, py - 1, 24, 4), Palette.NIGHT_1)
		draw_rect(Rect2(sx, py - 1, int(24 * f), 4), WARM if f >= 1.0 else Palette.BRONZE)
		_text(Vector2(sx + 28, py + 4), "special", WARM if f >= 1.0 else MUTED)
		# Riptide armed, else the weapon's ammo line
		var ax := sx + 28 + _width("special") + 6
		if _player.riptide_t > 0.0:
			_text(Vector2(ax, py + 4), "RIPTIDE: hits crit", WARM)
		elif _player.weapon.ammo_text() != "":
			_text(Vector2(ax, py + 4), _player.weapon.ammo_text(), SECONDARY)
		# Lantern glow: the glass fills with kills; full means Q, and the core pulses.
		var gy := py + 6
		var gf := _player.glow / Player.GLOW_MAX
		_sprite(LANTERN, Vector2(x, gy), Rect2(0, 0, 12, 14))
		draw_rect(Rect2(x + 3, gy + 4, 6, 7), Palette.NIGHT_1)
		var gh := int(round(7.0 * gf))
		if gh > 0:
			draw_rect(Rect2(x + 3, gy + 11 - gh, 6, gh), WARM)
		if gf >= 1.0 and int(Time.get_ticks_msec() / 250) % 2 == 0:
			draw_rect(Rect2(x + 5, gy + 6, 2, 3), Palette.PALE_CREAM)
		_text(Vector2(x + 16, gy + 10), "%s  flare ready" % UI.key("use_item") if gf >= 1.0 else "lantern", WARM if gf >= 1.0 else MUTED)
		# Fish carried: one icon each, F to eat the first.
		if _run and _run.state.fish.size() > 0:
			var fx := x + 16 + _width("%s  flare ready" % UI.key("use_item")) + 8
			for i in _run.state.fish.size():
				_draw_icon(Vector2(fx + i * 10, gy + 3), 6)
			_text(Vector2(fx + _run.state.fish.size() * 10 + 2, gy + 10), "%s  eat" % UI.key("consume"), WARM)
		# Tidemarks owned: a family icon each, and how many.
		if _run and _run.state.tidemarks.size() > 0:
			var ty := gy + 17
			for i in _run.state.tidemarks.size():
				var fam: String = str(Tidemarks.get_mark(_run.state.tidemarks[i]).get("family", "salt"))
				var fi := maxi(0, UI.FAMILIES.find(fam))
				_sprite(FAMILY, Vector2(x + i * 9, ty), Rect2(fi * 7, 0, 7, 7))
			_text(Vector2(x + _run.state.tidemarks.size() * 9 + 2, ty + 7), "marks", MUTED)
			# Active marks: a cooldown bar each, R when one is ready.
			var actives: Array = _run.state.actives()
			var ay := ty + 11
			var any_ready := false
			for i in actives.size():
				var id: String = actives[i]
				var cd := float(_run.state.active_cd.get(id, 0.0))
				var total := maxf(1.0, Tidemarks.cooldown_of(id))
				var ready := cd <= 0.0
				any_ready = any_ready or ready
				draw_rect(Rect2(x - 1, ay - 1 + i * 6, 42, 5), Palette.IRON_DARK)
				draw_rect(Rect2(x, ay + i * 6, 40, 3), Palette.NIGHT_1)
				draw_rect(Rect2(x, ay + i * 6, int(40 * (1.0 - cd / total)), 3), Tidemarks.color_of(id) if ready else Tidemarks.color_of(id).darkened(0.4))
			if actives.size() > 0:
				_text(Vector2(x + 44, ay + 4), "%s  active ready" % UI.key("active") if any_ready else "active", WARM if any_ready else MUTED)
		# Heavy charge, under the keeper.
		var cf := _player.weapon.charge_fraction()
		if cf > 0.0:
			var p := _player.global_position + Vector2(-8, 6)
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(18, 4)), Palette.INK)
			draw_rect(Rect2(p, Vector2(int(16 * cf), 2)), WARM)

	if _run == null:
		return
	# Currency (top right), each with its name under the number, on an Ink plate: over a
	# pale wall top or wet sand the figures had nothing to stand on (art Stage 20).
	var rx := int(_w()) - 8
	draw_rect(Rect2(rx - (102 if _keys > 0 else 70), y - 3, (108 if _keys > 0 else 76), 30), Color(Palette.INK, 0.42))
	if _keys > 0:
		_draw_icon(Vector2(rx - 98, y - 1), 2)
		_text(Vector2(rx - 88, y + 7), "%d" % _keys, PRIMARY)
		_text(Vector2(rx - 80, y + 17), "key", MUTED, 8, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_icon(Vector2(rx - 64, y - 1), 0)
	_text(Vector2(rx - 54, y + 7), "%d" % _salt, PRIMARY)
	_text(Vector2(rx - 46, y + 17), "salt", MUTED, 8, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_icon(Vector2(rx - 30, y - 1), 1)
	_text(Vector2(rx - 20, y + 7), "%d" % _pearls, PRIMARY)
	_text(Vector2(rx, y + 17), "pearls", MUTED, 8, HORIZONTAL_ALIGNMENT_RIGHT)

	# The tide staff (right edge): an iron pole with brass marks at the three steps of ground
	# the water covers; the Sea fills it, a Foam white line ripples on top, and the word under
	# it says where the water stands now.
	var mx := int(_w()) - 14
	var my := 36
	_sprite(STAFF, Vector2(mx, my), Rect2(0, 0, 10, 128))
	var tf := clampf(_tide / TideSystem.MAX_LEVEL, 0.0, 1.0)
	var span := STAFF_BOTTOM - STAFF_TOP
	var fill := int(round(span * tf))
	var water := Palette.SEA
	if _tide_flash > 0.0 and int(_tide_flash * 12) % 2 == 0:
		water = Palette.SEA_PALE
	if fill > 0:
		var top := my + STAFF_BOTTOM - fill
		draw_rect(Rect2(mx + 2, top, 6, fill + 1), water)
		# the surface line, rippling between two frames
		if int(Time.get_ticks_msec() / 500) % 2 == 0:
			draw_rect(Rect2(mx + 2, top, 6, 1), Palette.FOAM_WHITE)
		else:
			for i in 6:
				draw_rect(Rect2(mx + 2 + i, top - (1 if i % 2 == 1 and top > my + STAFF_TOP else 0), 1, 1), Palette.FOAM_WHITE)
	var word := tide_word(_tide)
	var wy := my + 128 + 8
	draw_rect(Rect2(mx - 16, wy - 2, 30, 12), Color(Palette.INK, 0.42))
	if _tide >= 3.0 and _tide_flash <= 0.0:
		_tag(Vector2(mx + 10, wy), word, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		var wcol := SEA_PALE if _tide < 2.0 else PRIMARY
		if _tide_flash > 0.0:
			wcol = Palette.FOAM_WHITE
		_text(Vector2(mx + 10, wy), word, wcol, 8, HORIZONTAL_ALIGNMENT_RIGHT)

	# Boss bar: 240 px of Salt red in an iron frame bound with rope, the name above at the
	# display size, a bronze tick at the phase mark.
	var boss_shown := _boss != null and is_instance_valid(_boss) and _boss.health.is_alive()
	if boss_shown != _boss_shown:
		_boss_shown = boss_shown
		get_tree().call_group("announcer", "set_boss_shown", boss_shown)
	if boss_shown:
		var bw := 236
		var bx := int(_w()) / 2 - 122
		var by := 296
		_sprite(BOSS, Vector2(bx, by), Rect2(0, 0, 244, 12))
		draw_rect(Rect2(bx + 4, by + 2, bw, 8), Palette.NIGHT_1)
		var bf := float(_boss.health.hp) / float(_boss.health.max_hp)
		var fw := int(bw * bf)
		draw_rect(Rect2(bx + 4, by + 2, fw, 8), Palette.SALT_RED)
		if fw > 0:
			draw_rect(Rect2(bx + 4, by + 2, fw, 1), Palette.PALE_CREAM)
		draw_rect(Rect2(bx + 4 + bw / 2, by + 2, 1, 8), Palette.BRONZE)
		_text(Vector2(bx + 122, by - 6), _boss.display_name.to_upper(), PRIMARY, 16, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(bx + 244, by - 4), "%d%%" % int(round(bf * 100.0)), MUTED, 8, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_icon(at: Vector2, index: int) -> void:
	draw_texture_rect_region(ICONS, Rect2(at, Vector2(8, 8)), Rect2(index * 8, 0, 8, 8))
