extends Enemy
## Reef Ray (the Reef, map Stage 11h): rides the current. It circles at a distance, curls its
## wingtips, then glides straight through where you stand. With the water running behind it the
## glide is faster and longer; against it, short. It glides past rather than stopping on you,
## so the answer is to step aside, not back. It skims a hand over the floor, so the water
## under it is never deep enough to slow it, but the current still carries it.

const SHEET := preload("res://assets/sprites/reef_ray.png")
## Like the wisp, it watches the whole room, so one cannot sit unnoticed in a corner.
const NOTICE := 800.0
const KEEP_DISTANCE := 110.0
const WINDUP := 0.5
const GLIDE_TIME := 0.55
const GLIDE_SPEED := 225.0
const RIDE := 2.5            # how much of the current under it the glide takes up
const RECOVER := 0.55

var _circle_dir: float = 1.0
var _circle_t: float = 2.0
var _glide_dir: Vector2 = Vector2.RIGHT


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, anims(
		{"idle": "idle", "swim": "walk", "windup": "windup", "glide": "attack", "hurt": "hurt"}, {"idle": 5, "swim": 7}))
	_circle_dir = 1.0 if randf() < 0.5 else -1.0


func _enter_state(s: StringName) -> void:
	match s:
		&"idle": play("idle")
		&"circle":
			play("swim")
			_circle_t = randf_range(1.6, 2.6)
			if randf() < 0.35:
				_circle_dir = -_circle_dir
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
		&"glide":
			play("glide")
			var d := to_player()
			_glide_dir = d.normalized() if d != Vector2.ZERO else _glide_dir
			face(_glide_dir.x)
			hitbox.activate()
			FX.burst(global_position, Color(0.6, 0.85, 0.9, 0.8), 5, 40.0)
		&"recover":
			play("idle")
			hitbox.deactivate()


func _exit_state(s: StringName) -> void:
	if s == &"glide":
		hitbox.deactivate()


## The current under it along `dir`, px/s (negative against it).
func _ride(dir: Vector2) -> float:
	if room == null or room.current == null:
		return 0.0
	return room.current.push_at(global_position).dot(dir)


func _tick(_delta: float) -> void:
	_steer()
	# It skims: the base slows a body in water, so the ray asks for that much more.
	if room and room.is_flooded_at(global_position):
		velocity /= WATER_SPEED_MULT


func _steer() -> void:
	var d := to_player()
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO and d.length() < NOTICE:
				change_state(&"circle")
		&"circle":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			var dist := d.length()
			var radial := d.normalized() * (1.0 if dist > KEEP_DISTANCE + 14.0 else (-1.0 if dist < KEEP_DISTANCE - 14.0 else 0.0))
			var tangent := d.normalized().orthogonal() * _circle_dir
			velocity = (radial * 0.7 + tangent).normalized() * speed
			face(velocity.x)
			if is_on_wall():
				_circle_dir = -_circle_dir
			if state_t >= _circle_t and dist < 220.0:
				change_state(&"windup")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"glide")
		&"glide":
			var ride := _ride(_glide_dir) * RIDE
			velocity = _glide_dir * maxf(GLIDE_SPEED * 0.6, GLIDE_SPEED + ride)
			if is_on_wall() or state_t >= GLIDE_TIME * clampf(1.0 + ride / GLIDE_SPEED, 0.6, 1.6):
				change_state(&"recover")
		&"recover":
			velocity = velocity * 0.85
			if state_t >= RECOVER:
				change_state(&"circle")


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"circle" or state == &"idle":
		play("hurt")
		stunned = 0.1
