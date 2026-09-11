extends Enemy
## Wrack Crab: skitters sideways to keep distance, then raises its claws and charges in
## a straight line. Bounces off walls and stuns itself if it misses.

const SHEET := preload("res://assets/sprites/wrack_crab.png")
const KEEP_DISTANCE := 84.0
const WINDUP := 0.42
const CHARGE_TIME := 0.5
const CHARGE_SPEED := 270.0
const RECOVER := 0.55
const BONK_STUN := 0.7

var _strafe_dir: float = 1.0
var _skitter_t: float = 1.0
var _charge_dir: Vector2 = Vector2.RIGHT


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, {
		"idle": {"frames": [0, 1], "fps": 3},
		"walk": {"frames": [2, 3], "fps": 10},
		"windup": {"frames": [4], "fps": 1},
		"charge": {"frames": [5], "fps": 1},
		"hurt": {"frames": [6], "fps": 1},
	})
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	_skitter_t = randf_range(0.7, 1.4)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle": play("idle")
		&"skitter":
			play("walk")
			_skitter_t = randf_range(0.7, 1.4)
			if randf() < 0.3:
				_strafe_dir = -_strafe_dir
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
			FX.burst(global_position + Vector2(0, 4), Color(0.75, 0.68, 0.5, 0.8), 4, 25.0)
		&"charge":
			play("charge")
			var d := to_player()
			_charge_dir = d.normalized() if d != Vector2.ZERO else _charge_dir
			face(_charge_dir.x)
			hitbox.activate()
		&"bonk":
			play("hurt")
			hitbox.deactivate()
			velocity = Vector2.ZERO
			EventBus.request_shake.emit(0.2)
			FX.burst(global_position, Color(0.8, 0.75, 0.6), 6, 50.0)
		&"recover":
			play("idle")
			hitbox.deactivate()


func _exit_state(s: StringName) -> void:
	if s == &"charge":
		hitbox.deactivate()


func _tick(delta: float) -> void:
	var d := to_player()
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO and d.length() < 200.0:
				change_state(&"skitter")
		&"skitter":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			var dist := d.length()
			var radial := d.normalized() * (1.0 if dist > KEEP_DISTANCE + 12.0 else (-1.0 if dist < KEEP_DISTANCE - 12.0 else 0.0))
			var tangent := d.normalized().orthogonal() * _strafe_dir
			velocity = (radial * 0.8 + tangent).normalized() * speed
			face(d.x)
			if is_on_wall():
				_strafe_dir = -_strafe_dir
			if state_t >= _skitter_t and dist < 160.0:
				change_state(&"windup")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= WINDUP:
				change_state(&"charge")
		&"charge":
			velocity = _charge_dir * CHARGE_SPEED
			if is_on_wall():
				change_state(&"bonk")
			elif state_t >= CHARGE_TIME:
				change_state(&"recover")
		&"bonk":
			if state_t >= BONK_STUN:
				change_state(&"skitter")
		&"recover":
			velocity = Vector2.ZERO
			if state_t >= RECOVER:
				change_state(&"skitter")


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"skitter" or state == &"idle":
		play("hurt")
		stunned = 0.15


func _on_hit_landed(_target: Hurtbox, _info: DamageInfo) -> void:
	change_state(&"recover")
