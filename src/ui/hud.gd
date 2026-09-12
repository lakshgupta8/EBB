extends Control
## In-run HUD drawn with primitives so it stays crisp at 1x.
## Health, dash pips, hook cooldown, lantern glow, tide meter, salt, pearls, boss bar.

const BAR_W := 80
const BAR_H := 6
const ICONS := preload("res://assets/sprites/pickups.png")
const FONT := preload("res://assets/fonts/ebb.fnt")

var _hp: int = 100
var _max_hp: int = 100
var _tide: float = 0.0
var _salt: int = 0
var _pearls: int = 0
var _keys: int = 0
var _player: Player
var _boss: Enemy
var _run: Node


func _ready() -> void:
	EventBus.player_health_changed.connect(func(c, m): _hp = c; _max_hp = m)
	EventBus.tide_changed.connect(func(l): _tide = l)
	EventBus.salt_changed.connect(func(v): _salt = v)
	EventBus.pearls_changed.connect(func(v): _pearls = v)
	EventBus.keys_changed.connect(func(v): _keys = v)
	_player = get_tree().get_first_node_in_group("player") as Player


func bind(run: Node) -> void:
	_run = run


func set_boss(b: Enemy) -> void:
	_boss = b


func _process(_delta: float) -> void:
	queue_redraw()


func _text(pos: Vector2, s: String, color: Color, size: int = 8, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(FONT, pos + Vector2(1, 1), s, align, -1, size, UI.INK)
	draw_string(FONT, pos, s, align, -1, size, color)


func _draw() -> void:
	var x := 8
	var y := 8
	# Health
	draw_rect(Rect2(x - 1, y - 1, BAR_W + 2, BAR_H + 2), UI.INK)
	draw_rect(Rect2(x, y, BAR_W, BAR_H), Color(0.35, 0.12, 0.14))
	var frac := float(_hp) / maxf(1.0, float(_max_hp))
	draw_rect(Rect2(x, y, int(BAR_W * frac), BAR_H), Color(0.86, 0.32, 0.30))
	draw_rect(Rect2(x, y, int(BAR_W * frac), 2), Color(0.95, 0.55, 0.5))
	_text(Vector2(x + BAR_W + 5, y + 7), "%d" % _hp, Color(0.95, 0.9, 0.85))
	if _player and is_instance_valid(_player):
		# Dash pips
		var py := y + BAR_H + 4
		for i in _player.max_dash:
			var col := Color(0.55, 0.8, 0.95) if i < _player.dash_charges else Color(0.2, 0.25, 0.35)
			draw_rect(Rect2(x + i * 9, py, 7, 4), col)
		# Hook cooldown
		var f := _player.weapon.special_cooldown_fraction()
		draw_rect(Rect2(x + 32, py, 24, 4), Color(0.2, 0.25, 0.35))
		draw_rect(Rect2(x + 32, py, int(24 * f), 4), Color(0.95, 0.8, 0.4) if f >= 1.0 else Color(0.6, 0.5, 0.3))
		# Lantern glow
		var gy := py + 7
		var gf := _player.glow / Player.GLOW_MAX
		draw_rect(Rect2(x - 1, gy - 1, 58, 5), UI.INK)
		draw_rect(Rect2(x, gy, 56, 3), Color(0.25, 0.22, 0.18))
		var gcol := Color(1.0, 0.9, 0.5) if gf >= 1.0 else Color(0.85, 0.65, 0.3)
		if gf >= 1.0 and int(Time.get_ticks_msec() / 250) % 2 == 0:
			gcol = Color(1.0, 1.0, 0.85)
		draw_rect(Rect2(x, gy, int(56 * gf), 3), gcol)
		_text(Vector2(x + 60, gy + 4), "Q" if gf >= 1.0 else "", Color(1.0, 0.95, 0.7))
		# Riptide armed, else the weapon's ammo line
		if _player.riptide_t > 0.0:
			_text(Vector2(x + 60, py + 4), "RIPTIDE", Color(0.7, 0.95, 1.0))
		elif _player.weapon.ammo_text() != "":
			_text(Vector2(x + 60, py + 4), _player.weapon.ammo_text(), Color(0.85, 0.85, 0.9))
		# Tidemarks owned: family-coloured pips
		if _run and _run.state.tidemarks.size() > 0:
			var ty := gy + 7
			for i in _run.state.tidemarks.size():
				var col: Color = Tidemarks.color_of(_run.state.tidemarks[i])
				draw_rect(Rect2(x - 1 + i * 8, ty - 1, 7, 7), UI.INK)
				draw_rect(Rect2(x + i * 8, ty, 5, 5), col)
			# Active marks: a cooldown bar each, R when one is ready
			var actives: Array = _run.state.actives()
			var ay := ty + 9
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
				_text(Vector2(x + 44, ay + 4), "R" if any_ready else "", Color(1.0, 0.95, 0.7))
		# Fish carried: one icon each, F to eat the first
		if _run and _run.state.fish.size() > 0:
			var fy := 8 + BAR_H + 4
			for i in _run.state.fish.size():
				_draw_icon(Vector2(x + 96 + i * 10, fy - 2), 6)
			_text(Vector2(x + 96 + _run.state.fish.size() * 10 + 2, fy + 4), "F", Color(0.95, 0.85, 0.6))
		# Heavy charge
		var cf := _player.weapon.charge_fraction()
		if cf > 0.0:
			var p := _player.global_position + Vector2(-8, 6)
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(18, 4)), UI.INK)
			draw_rect(Rect2(p, Vector2(int(16 * cf), 2)), Color(1.0, 0.9, 0.6))

	if _run == null:
		return
	# Currency (top right)
	var rx := 640 - 8
	if _keys > 0:
		_draw_icon(Vector2(rx - 98, y - 1), 2)
		_text(Vector2(rx - 88, y + 7), "%d" % _keys, Color(0.95, 0.85, 0.5))
	_draw_icon(Vector2(rx - 64, y - 1), 0)
	_text(Vector2(rx - 54, y + 7), "%d" % _salt, Color(0.98, 0.9, 0.6))
	_draw_icon(Vector2(rx - 30, y - 1), 1)
	_text(Vector2(rx - 20, y + 7), "%d" % _pearls, Color(0.92, 0.92, 0.98))

	# Tide meter (right edge, vertical). Fills upward as the water rises.
	var mx := 640 - 12
	var my := 40
	var mh := 120
	draw_rect(Rect2(mx - 1, my - 1, 6, mh + 2), UI.INK)
	draw_rect(Rect2(mx, my, 4, mh), Color(0.16, 0.18, 0.26))
	var tf := clampf(_tide / TideSystem.MAX_LEVEL, 0.0, 1.0)
	var fill := int(mh * tf)
	draw_rect(Rect2(mx, my + mh - fill, 4, fill), Color(0.35, 0.6, 0.75))
	for i in [1, 2, 3]:
		var ty := my + mh - int(mh * i / TideSystem.MAX_LEVEL)
		draw_rect(Rect2(mx - 2, ty, 8, 1), Color(0.8, 0.85, 0.95, 0.7))
	_text(Vector2(mx - 22, my + mh + 10), "tide", Color(0.7, 0.8, 0.9))

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


func _draw_icon(at: Vector2, index: int) -> void:
	draw_texture_rect_region(ICONS, Rect2(at, Vector2(8, 8)), Rect2(index * 8, 0, 8, 8))
