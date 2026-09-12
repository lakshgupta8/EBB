extends Enemy
## Tidewisp: a light that hangs over the flats where a keeper went under. It never comes
## close. It drifts to a distance it likes, throws a slow bead of cold light, and backs
## off the moment you close on it. Fragile, and it ignores the water entirely.

const SHEET := preload("res://assets/sprites/tidewisp.png")
const SHOT := preload("res://assets/sprites/wisp_shot.png")
## It watches the whole room: a thing that keeps its distance must never be able to sit
## out of notice in a corner, or a room with one left in it can never be cleared.
const NOTICE := 800.0
const KEEP_DISTANCE := 120.0
const FLEE_DISTANCE := 70.0
## Backing off is slower than a keeper walks, so it can always be run down.
const FLEE_SPEED := 1.3
const CAST_EVERY := 2.2
const WINDUP := 0.5
const SHOT_SPEED := 130.0
const SHOT_DAMAGE := 6
const FLEE_TIME := 1.0

var _drift_dir: float = 1.0
var _cast_t: float = 0.0


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, {
		"drift": {"frames": [0, 1, 2, 3], "fps": 6},
		"windup": {"frames": [4], "fps": 1},
		"cast": {"frames": [5], "fps": 1},
		"hurt": {"frames": [6], "fps": 1},
	})
	_drift_dir = 1.0 if randf() < 0.5 else -1.0
	_cast_t = randf_range(0.4, 1.6)
	var glow := Atmosphere.light(self, Color(0.6, 0.9, 1.0), 2.6, 0.9, Vector2(0, -10))
	Atmosphere.breathe(glow, 0.7, 1.1, 1.6)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle", &"drift", &"flee":
			play("drift")
			if s == &"drift" and randf() < 0.3:
				_drift_dir = -_drift_dir
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
		&"cast":
			play("cast")
			velocity = Vector2.ZERO
			_cast()


func _tick(delta: float) -> void:
	var d := to_player()
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO and d.length() < NOTICE:
				change_state(&"drift")
		&"drift":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			var dist := d.length()
			if dist < FLEE_DISTANCE:
				change_state(&"flee")
				return
			var radial := d.normalized() * (1.0 if dist > KEEP_DISTANCE + 16.0 else 0.0)
			var tangent := d.normalized().orthogonal() * _drift_dir
			velocity = (radial * 0.9 + tangent * 0.7).normalized() * speed
			face(d.x)
			if is_on_wall():
				_drift_dir = -_drift_dir
			_cast_t += delta
			if _cast_t >= CAST_EVERY and dist < 220.0:
				_cast_t = 0.0
				change_state(&"windup")
		&"flee":
			# Backs off fast, then settles again.
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			velocity = -d.normalized() * speed * FLEE_SPEED
			face(d.x)
			if state_t >= FLEE_TIME or d.length() > KEEP_DISTANCE:
				change_state(&"drift")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"cast")
		&"cast":
			velocity = Vector2.ZERO
			if state_t >= 0.2:
				change_state(&"drift" if d.length() > FLEE_DISTANCE else &"flee")


func _cast() -> void:
	var d := to_player()
	var dir := d.normalized() if d != Vector2.ZERO else Vector2.RIGHT
	var p := Projectile.spawn(get_parent(), global_position + Vector2(0, -10) + dir * 10.0,
		dir * SHOT_SPEED, SHOT_DAMAGE, SHOT, self, 64, 2.6)
	p.knockback = 70.0
	p.spin = 6.0
	Atmosphere.light(p, Color(0.6, 0.9, 1.0), 1.4, 0.8)
	FX.burst(global_position, Color(0.6, 0.9, 1.0), 6, 40.0)
	Audio.play("lantern", 0.2, -6.0)


func _on_hurt_extra(_info: DamageInfo) -> void:
	play("hurt")
	stunned = 0.1
	# Being hit sends it running.
	if state in [&"drift", &"idle"]:
		change_state(&"flee")
