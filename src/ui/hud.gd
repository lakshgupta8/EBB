extends Control
## In-run HUD drawn with primitives so it stays crisp at 1x. Health, dash pips, special.

const BAR_W := 80
const BAR_H := 6

var _hp: int = 100
var _max_hp: int = 100
var _player: Player
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	EventBus.player_health_changed.connect(func(c, m): _hp = c; _max_hp = m; queue_redraw())
	_player = get_tree().get_first_node_in_group("player") as Player


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
	# Dash pips
	if _player and is_instance_valid(_player):
		for i in Player.DASH_CHARGES:
			var col := Color(0.55, 0.8, 0.95) if i < _player.dash_charges else Color(0.2, 0.25, 0.35)
			draw_rect(Rect2(x + i * 9, y + BAR_H + 4, 7, 4), col)
		# Special cooldown
		var f := _player.weapon.special_cooldown_fraction()
		draw_rect(Rect2(x + 32, y + BAR_H + 4, 24, 4), Color(0.2, 0.25, 0.35))
		draw_rect(Rect2(x + 32, y + BAR_H + 4, int(24 * f), 4), Color(0.95, 0.8, 0.4) if f >= 1.0 else Color(0.6, 0.5, 0.3))
