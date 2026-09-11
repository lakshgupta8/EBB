extends Enemy
## Gull: fragile flyer that orbits, pauses, then dives at where you were.

const SHEET := preload("res://assets/sprites/gull.png")
const ORBIT_RADIUS := 76.0
const ORBIT_ANGULAR := 1.6  # rad/s
const WINDUP := 0.45
const DIVE_TIME := 0.38
const DIVE_SPEED := 230.0
const RECOVER := 0.8

var _orbit_angle: float = 0.0
var _orbit_dir: float = 1.0
var _next_dive: float = 2.0
var _dive_dir: Vector2 = Vector2.RIGHT


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, {
		"fly": {"frames": [0, 1, 2, 3], "fps": 10},
		"dive": {"frames": [4], "fps": 1},
		"hurt": {"frames": [5], "fps": 1},
	})
	_orbit_angle = randf() * TAU
	_orbit_dir = 1.0 if randf() < 0.5 else -1.0
	_next_dive = randf_range(1.2, 2.4)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle", &"orbit":
			play("fly")
			_next_dive = randf_range(1.5, 2.6)
		&"windup":
			play("dive")
			velocity = Vector2.ZERO
		&"dive":
			play("dive")
			var d := to_player()
			_dive_dir = d.normalized() if d != Vector2.ZERO else _dive_dir
			face(_dive_dir.x)
			hitbox.activate()
		&"recover":
			play("fly")


func _exit_state(s: StringName) -> void:
	if s == &"dive":
		hitbox.deactivate()


func _tick(delta: float) -> void:
	var d := to_player()
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				change_state(&"orbit")
		&"orbit":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			_orbit_angle += ORBIT_ANGULAR * _orbit_dir * delta
			var goal := player.global_position + Vector2.from_angle(_orbit_angle) * ORBIT_RADIUS
			var to_goal := goal - global_position
			velocity = to_goal.normalized() * minf(speed, to_goal.length() * 4.0)
			face(velocity.x if absf(velocity.x) > 8.0 else d.x)
			if state_t >= _next_dive and d.length() < ORBIT_RADIUS * 1.6:
				change_state(&"windup")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			# Little hop up-back as the tell.
			sprite.position.y = -8.0 - 3.0 * sin(state_t / WINDUP * PI)
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				sprite.position.y = -8.0
				change_state(&"dive")
		&"dive":
			velocity = _dive_dir * DIVE_SPEED
			if state_t >= DIVE_TIME:
				change_state(&"recover")
		&"recover":
			velocity = (-_dive_dir).rotated(_orbit_dir * 0.6) * speed
			if state_t >= RECOVER:
				_orbit_angle = (global_position - player.global_position).angle() if player else _orbit_angle
				change_state(&"orbit")


func _on_hurt_extra(_info: DamageInfo) -> void:
	play("hurt")
	if state == &"windup" or state == &"dive":
		change_state(&"recover")
	stunned = 0.25


func _on_hit_landed(_target: Hurtbox, _info: DamageInfo) -> void:
	change_state(&"recover")
