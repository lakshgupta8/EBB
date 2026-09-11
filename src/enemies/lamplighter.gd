extends Enemy
## Lamplighter: keeps its distance and tends the others. Every few seconds it kindles
## every enemy nearby (faster, warmer) and, when nobody is close enough to help, it
## lobs its lantern at you instead. Kill it first.

const SHEET := preload("res://assets/sprites/lamplighter.png")
const LANTERN := preload("res://assets/sprites/lantern_shot.png")
const KEEP_DISTANCE := 100.0
const ACT_EVERY := 3.6
const KINDLE_RADIUS := 130.0
const KINDLE_TIME := 5.0
const KINDLE_WINDUP := 0.5
const THROW_WINDUP := 0.45
const THROW_RANGE := 190.0
const SHOT_SPEED := 175.0
const SHOT_DAMAGE := 7

var _strafe_dir: float = 1.0
var _act_t: float = 0.0
var _glow: PointLight2D


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, {
		"idle": {"frames": [0, 1], "fps": 3},
		"walk": {"frames": [2, 3], "fps": 7},
		"kindle": {"frames": [4], "fps": 1},
		"throw": {"frames": [5], "fps": 1},
		"hurt": {"frames": [6], "fps": 1},
	})
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	_act_t = randf_range(1.0, 2.0)
	_glow = Atmosphere.light(self, Color(1.0, 0.8, 0.5), 2.2, 0.8, Vector2(6, -10))
	Atmosphere.breathe(_glow, 0.6, 1.0, 1.4)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle": play("idle")
		&"drift":
			play("walk")
			if randf() < 0.3:
				_strafe_dir = -_strafe_dir
		&"kindle_windup":
			play("kindle")
			velocity = Vector2.ZERO
		&"throw_windup":
			play("throw")
			velocity = Vector2.ZERO


func _tick(delta: float) -> void:
	var d := to_player()
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO and d.length() < 240.0:
				change_state(&"drift")
		&"drift":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			var dist := d.length()
			var radial := d.normalized() * (1.0 if dist > KEEP_DISTANCE + 14.0 else (-1.0 if dist < KEEP_DISTANCE - 14.0 else 0.0))
			var tangent := d.normalized().orthogonal() * _strafe_dir
			velocity = (radial * 0.9 + tangent * 0.7).normalized() * speed
			face(d.x)
			if is_on_wall():
				_strafe_dir = -_strafe_dir
			_act_t += delta
			if _act_t >= ACT_EVERY:
				_act_t = 0.0
				if _others_near().size() > 0:
					change_state(&"kindle_windup")
				elif dist < THROW_RANGE:
					change_state(&"throw_windup")
		&"kindle_windup":
			velocity = Vector2.ZERO
			if state_t >= KINDLE_WINDUP:
				_kindle()
				change_state(&"drift")
		&"throw_windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= THROW_WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= THROW_WINDUP:
				_throw(d)
				change_state(&"drift")


func _others_near() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not (e is Enemy):
			continue
		if e.global_position.distance_to(global_position) <= KINDLE_RADIUS:
			out.append(e)
	return out


func _kindle() -> void:
	FX.ring(global_position, Color(1.0, 0.8, 0.5), 2.4)
	FX.burst(global_position + Vector2(6, -10), Color(1.0, 0.85, 0.5), 12, 60.0)
	Audio.play("kindle", 0.1, -2.0)
	for e in _others_near():
		e.kindle(KINDLE_TIME)


func _throw(d: Vector2) -> void:
	var dir := d.normalized() if d != Vector2.ZERO else Vector2.RIGHT
	var p := Projectile.spawn(get_parent(), global_position + Vector2(6, -10), dir * SHOT_SPEED, SHOT_DAMAGE, LANTERN, self, 64, 1.4)
	p.knockback = 120.0
	Atmosphere.light(p, Color(1.0, 0.8, 0.5), 1.6, 0.9)
	Audio.play("kindle", 0.3, -6.0)


func _on_hurt_extra(_info: DamageInfo) -> void:
	play("hurt")
	stunned = 0.2
	if state == &"kindle_windup" or state == &"throw_windup":
		change_state(&"drift")
