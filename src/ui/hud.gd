extends Control
## In-run HUD drawn with primitives so it stays crisp at 1x.
## Health, dash pips, special, tide meter, salt, pearls, boss bar.

const BAR_W := 80
const BAR_H := 6
const ICONS := preload("res://assets/sprites/pickups.png")

var _hp: int = 100
var _max_hp: int = 100
var _tide: float = 0.0
var _salt: int = 0
var _pearls: int = 0
var _player: Player
var _boss: Enemy
var _font: Font
var _run: Node


func _ready() -> void:
	_font = ThemeDB.fallback_font
	EventBus.player_health_changed.connect(func(c, m): _hp = c; _max_hp = m)
	EventBus.tide_changed.connect(func(l): _tide = l)
	EventBus.salt_changed.connect(func(v): _salt = v)
	EventBus.pearls_changed.connect(func(v): _pearls = v)
	_player = get_tree().get_first_node_in_group("player") as Player


func bind(run: Node) -> void:
	_run = run


func set_boss(b: Enemy) -> void:
	_boss = b


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var x := 8
	var y := 8
	# Health
	draw_rect(Rect2(x - 1, y - 1, BAR_W + 2, BAR_H + 2), Color(0.09, 0.08, 0.14))
	draw_rect(Rect2(x, y, BAR_W, BAR_H), Color(0.35, 0.12, 0.14))
	var frac := float(_hp) / maxf(1.0, float(_max_hp))
	draw_rect(Rect2(x, y, int(BAR_W * frac), BAR_H), Color(0.86, 0.32, 0.30))
	draw_rect(Rect2(x, y, int(BAR_W * frac), 2), Color(0.95, 0.55, 0.5))
	draw_string(_font, Vector2(x + BAR_W + 5, y + 7), "%d" % _hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.95, 0.9, 0.85))
	if _player and is_instance_valid(_player):
		for i in Player.DASH_CHARGES:
			var col := Color(0.55, 0.8, 0.95) if i < _player.dash_charges else Color(0.2, 0.25, 0.35)
			draw_rect(Rect2(x + i * 9, y + BAR_H + 4, 7, 4), col)
		var f := _player.weapon.special_cooldown_fraction()
		draw_rect(Rect2(x + 32, y + BAR_H + 4, 24, 4), Color(0.2, 0.25, 0.35))
		draw_rect(Rect2(x + 32, y + BAR_H + 4, int(24 * f), 4), Color(0.95, 0.8, 0.4) if f >= 1.0 else Color(0.6, 0.5, 0.3))

	if _run == null:
		return
	# Currency (top right)
	var rx := 640 - 8
	_draw_icon(Vector2(rx - 60, y - 1), 0)
	draw_string(_font, Vector2(rx - 50, y + 7), "%d" % _salt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.98, 0.9, 0.6))
	_draw_icon(Vector2(rx - 28, y - 1), 1)
	draw_string(_font, Vector2(rx - 18, y + 7), "%d" % _pearls, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.92, 0.92, 0.98))

	# Tide meter (right edge, vertical). Fills upward as the water rises.
	var mx := 640 - 12
	var my := 40
	var mh := 120
	draw_rect(Rect2(mx - 1, my - 1, 6, mh + 2), Color(0.09, 0.08, 0.14))
	draw_rect(Rect2(mx, my, 4, mh), Color(0.16, 0.18, 0.26))
	var tf := clampf(_tide / TideSystem.MAX_LEVEL, 0.0, 1.0)
	var fill := int(mh * tf)
	draw_rect(Rect2(mx, my + mh - fill, 4, fill), Color(0.35, 0.6, 0.75))
	# Level ticks at 1, 2, 3 (where sand, then raised ground, floods)
	for i in [1, 2, 3]:
		var ty := my + mh - int(mh * i / TideSystem.MAX_LEVEL)
		draw_rect(Rect2(mx - 2, ty, 8, 1), Color(0.8, 0.85, 0.95, 0.7))
	draw_string(_font, Vector2(mx - 18, my + mh + 10), "tide", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.8, 0.9))

	# Boss bar
	if _boss and is_instance_valid(_boss) and _boss.health.is_alive():
		var bw := 320
		var bx := 320 - bw / 2
		var by := 334
		draw_rect(Rect2(bx - 2, by - 2, bw + 4, 12), Color(0.09, 0.08, 0.14))
		draw_rect(Rect2(bx, by, bw, 8), Color(0.3, 0.12, 0.14))
		var bf := float(_boss.health.hp) / float(_boss.health.max_hp)
		draw_rect(Rect2(bx, by, int(bw * bf), 8), Color(0.85, 0.35, 0.3))
		draw_rect(Rect2(bx, by, int(bw * bf), 2), Color(0.95, 0.6, 0.5))
		draw_rect(Rect2(bx + bw / 2 - 1, by, 2, 8), Color(0.09, 0.08, 0.14, 0.6))  # phase mark
		draw_string(_font, Vector2(bx, by - 4), _boss.display_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.85, 0.8))


func _draw_icon(at: Vector2, index: int) -> void:
	draw_texture_rect_region(ICONS, Rect2(at, Vector2(8, 8)), Rect2(index * 8, 0, 8, 8))
