extends Control
## In-run HUD drawn with primitives so it stays crisp at 1x. Every bar says what it is:
## health, dashes, the weapon's special, the lantern (Q when full), the marks you hold,
## fish (F), salt and pearls, the tide staff with a word for how high it is, the boss bar.

const BAR_W := 80
const BAR_H := 6
const ICONS := preload("res://assets/sprites/pickups.png")
const FONT := preload("res://assets/fonts/ebb.fnt")
const MUTED := Color("#8494a8")
const DIM := Color("#5d6b82")
const WARM := Color("#f2c85c")
const SEA_PALE := Color("#5f9c9f")

var _hp: int = 100
var _max_hp: int = 100
var _tide: float = 0.0
var _salt: int = 0
var _pearls: int = 0
var _keys: int = 0
var _player: Player
var _boss: Enemy
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


func set_boss(b: Enemy) -> void:
	_boss = b


## The staff lights up for a moment: the water has just crossed a mark.
func flash_tide() -> void:
	_tide_flash = 0.9


func _process(delta: float) -> void:
	_tide_flash = maxf(0.0, _tide_flash - delta)
	_hp_hit = maxf(0.0, _hp_hit - delta)
	queue_redraw()


func _text(pos: Vector2, s: String, color: Color, size: int = 8, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		pos.x -= FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(FONT, pos + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UI.INK)
	draw_string(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


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
	# Health: the bar, the number, and a blink when it just dropped.
	var low := _hp * 10 < _max_hp * 3
	draw_rect(Rect2(x - 1, y - 1, BAR_W + 2, BAR_H + 2), UI.INK)
	draw_rect(Rect2(x, y, BAR_W, BAR_H), Color(0.35, 0.12, 0.14))
	var frac := float(_hp) / maxf(1.0, float(_max_hp))
	var hp_col := Color(0.86, 0.32, 0.30)
	if _hp_hit > 0.0 and int(_hp_hit * 20) % 2 == 0:
		hp_col = Color(1.0, 0.85, 0.8)
	elif low and int(Time.get_ticks_msec() / 400) % 2 == 0:
		hp_col = Color(0.95, 0.45, 0.4)
	draw_rect(Rect2(x, y, int(BAR_W * frac), BAR_H), hp_col)
	draw_rect(Rect2(x, y, int(BAR_W * frac), 2), Color(0.95, 0.55, 0.5))
	_text(Vector2(x + BAR_W + 5, y + 7), "%d" % _hp, Color(0.95, 0.9, 0.85))
	_text(Vector2(x + BAR_W + 5 + str(_hp).length() * 6 + 3, y + 7), "hp", DIM)
	if _player and is_instance_valid(_player):
		# Dashes
		var py := y + BAR_H + 4
		for i in _player.max_dash:
			var col := Color(0.55, 0.8, 0.95) if i < _player.dash_charges else Color(0.2, 0.25, 0.35)
			draw_rect(Rect2(x + i * 9, py, 7, 4), col)
		var dx := x + _player.max_dash * 9 + 1
		_text(Vector2(dx, py + 4), "dash", DIM)
		# The weapon's special, with its name so the bar means something.
		var sx := dx + 36
		var f := _player.weapon.special_cooldown_fraction()
		draw_rect(Rect2(sx - 1, py - 1, 26, 6), UI.INK)
		draw_rect(Rect2(sx, py, 24, 4), Color(0.2, 0.25, 0.35))
		draw_rect(Rect2(sx, py, int(24 * f), 4), Color(0.95, 0.8, 0.4) if f >= 1.0 else Color(0.6, 0.5, 0.3))
		_text(Vector2(sx + 28, py + 4), "special", WARM if f >= 1.0 else DIM)
		# Riptide armed, else the weapon's ammo line
		var ax := sx + 28 + 7 * 6 + 6
		if _player.riptide_t > 0.0:
			_text(Vector2(ax, py + 4), "RIPTIDE: hits crit", Color(0.7, 0.95, 1.0))
		elif _player.weapon.ammo_text() != "":
			_text(Vector2(ax, py + 4), _player.weapon.ammo_text(), Color(0.85, 0.85, 0.9))
		# Lantern glow: fills with kills; full means Q.
		var gy := py + 7
		var gf := _player.glow / Player.GLOW_MAX
		draw_rect(Rect2(x - 1, gy - 1, 58, 5), UI.INK)
		draw_rect(Rect2(x, gy, 56, 3), Color(0.25, 0.22, 0.18))
		var gcol := Color(1.0, 0.9, 0.5) if gf >= 1.0 else Color(0.85, 0.65, 0.3)
		if gf >= 1.0 and int(Time.get_ticks_msec() / 250) % 2 == 0:
			gcol = Color(1.0, 1.0, 0.85)
		draw_rect(Rect2(x, gy, int(56 * gf), 3), gcol)
		_text(Vector2(x + 60, gy + 4), "Q  flare ready" if gf >= 1.0 else "lantern", WARM if gf >= 1.0 else DIM)
		# Fish carried: one icon each, F to eat the first.
		if _run and _run.state.fish.size() > 0:
			var fx := x + 60 + 15 * 6 + 8
			for i in _run.state.fish.size():
				_draw_icon(Vector2(fx + i * 10, gy - 3), 6)
			_text(Vector2(fx + _run.state.fish.size() * 10 + 2, gy + 4), "F  eat", WARM)
		# Tidemarks owned: family-coloured pips, and how many.
		if _run and _run.state.tidemarks.size() > 0:
			var ty := gy + 8
			for i in _run.state.tidemarks.size():
				var col: Color = Tidemarks.color_of(_run.state.tidemarks[i])
				draw_rect(Rect2(x - 1 + i * 8, ty - 1, 7, 7), UI.INK)
				draw_rect(Rect2(x + i * 8, ty, 5, 5), col)
			_text(Vector2(x + _run.state.tidemarks.size() * 8 + 2, ty + 5), "marks", DIM)
			# Active marks: a cooldown bar each, R when one is ready.
			var actives: Array = _run.state.actives()
			var ay := ty + 10
			var any_ready := false
			for i in actives.size():
				var id: String = actives[i]
				var cd := float(_run.state.active_cd.get(id, 0.0))
				var total := maxf(1.0, Tidemarks.cooldown_of(id))
				var ready := cd <= 0.0
				any_ready = any_ready or ready
				draw_rect(Rect2(x - 1, ay - 1 + i * 6, 42, 5), UI.INK)
				draw_rect(Rect2(x, ay + i * 6, 40, 3), Color(0.2, 0.22, 0.3))
				draw_rect(Rect2(x, ay + i * 6, int(40 * (1.0 - cd / total)), 3), Tidemarks.color_of(id) if ready else Tidemarks.color_of(id).darkened(0.4))
			if actives.size() > 0:
				_text(Vector2(x + 44, ay + 4), "R  active ready" if any_ready else "active", WARM if any_ready else DIM)
		# Heavy charge, under the keeper.
		var cf := _player.weapon.charge_fraction()
		if cf > 0.0:
			var p := _player.global_position + Vector2(-8, 6)
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(18, 4)), UI.INK)
			draw_rect(Rect2(p, Vector2(int(16 * cf), 2)), Color(1.0, 0.9, 0.6))

	if _run == null:
		return
	# Currency (top right), each with its name under the number.
	var rx := 640 - 8
	if _keys > 0:
		_draw_icon(Vector2(rx - 98, y - 1), 2)
		_text(Vector2(rx - 88, y + 7), "%d" % _keys, Color(0.95, 0.85, 0.5))
		_text(Vector2(rx - 80, y + 17), "key", DIM, 8, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_icon(Vector2(rx - 64, y - 1), 0)
	_text(Vector2(rx - 54, y + 7), "%d" % _salt, Color(0.98, 0.9, 0.6))
	_text(Vector2(rx - 46, y + 17), "salt", DIM, 8, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_icon(Vector2(rx - 30, y - 1), 1)
	_text(Vector2(rx - 20, y + 7), "%d" % _pearls, Color(0.92, 0.92, 0.98))
	_text(Vector2(rx, y + 17), "pearls", DIM, 8, HORIZONTAL_ALIGNMENT_RIGHT)

	# The tide staff (right edge): fills upward as the water rises; the three marks are the
	# three steps of ground it covers, and the word under it says where it stands now.
	var mx := 640 - 12
	var my := 44
	var mh := 120
	_text(Vector2(mx + 6, my - 6), "TIDE", MUTED, 8, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_rect(Rect2(mx - 1, my - 1, 6, mh + 2), UI.INK)
	draw_rect(Rect2(mx, my, 4, mh), Color(0.16, 0.18, 0.26))
	var tf := clampf(_tide / TideSystem.MAX_LEVEL, 0.0, 1.0)
	var fill := int(mh * tf)
	var water := Color(0.35, 0.6, 0.75)
	if _tide_flash > 0.0 and int(_tide_flash * 12) % 2 == 0:
		water = Color(0.75, 0.95, 1.0)
	draw_rect(Rect2(mx, my + mh - fill, 4, fill), water)
	draw_rect(Rect2(mx, my + mh - fill, 4, 1), Color(0.85, 0.95, 1.0, 0.8))
	for i in [1, 2, 3]:
		var ty := my + mh - int(mh * i / TideSystem.MAX_LEVEL)
		draw_rect(Rect2(mx - 2, ty, 8, 1), Color(0.8, 0.85, 0.95, 0.7))
	var word := tide_word(_tide)
	var wcol := SEA_PALE if _tide < 2.0 else (Color(0.8, 0.9, 1.0) if _tide < 3.0 else Color(0.95, 0.6, 0.5))
	if _tide_flash > 0.0:
		wcol = Color(1, 1, 1)
	_text(Vector2(mx + 6, my + mh + 10), word, wcol, 8, HORIZONTAL_ALIGNMENT_RIGHT)

	# Boss bar
	if _boss and is_instance_valid(_boss) and _boss.health.is_alive():
		var bw := 320
		var bx := 320 - bw / 2
		var by := 300
		draw_rect(Rect2(bx - 2, by - 2, bw + 4, 12), UI.INK)
		draw_rect(Rect2(bx, by, bw, 8), Color(0.3, 0.12, 0.14))
		var bf := float(_boss.health.hp) / float(_boss.health.max_hp)
		draw_rect(Rect2(bx, by, int(bw * bf), 8), Color(0.85, 0.35, 0.3))
		draw_rect(Rect2(bx, by, int(bw * bf), 2), Color(0.95, 0.6, 0.5))
		draw_rect(Rect2(bx + bw / 2 - 1, by, 2, 8), Color(0.09, 0.08, 0.14, 0.6))
		_text(Vector2(bx, by - 4), _boss.display_name.to_upper(), Color(0.95, 0.85, 0.8))
		_text(Vector2(bx + bw, by - 4), "%d%%" % int(round(bf * 100.0)), MUTED, 8, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_icon(at: Vector2, index: int) -> void:
	draw_texture_rect_region(ICONS, Rect2(at, Vector2(8, 8)), Rect2(index * 8, 0, 8, 8))
