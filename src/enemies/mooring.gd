extends Enemy
## Mooring: a harbour hand with the mooring chain still wrapped round his arm. Keeps a
## chain's length away, then lashes: a straight chain along the deck, and whoever it
## catches is dragged a step toward him. Sidestep; the lash only goes where he was facing.

const SHEET := preload("res://assets/sprites/mooring.png")
const KEEP_DISTANCE := 88.0
const LASH_RANGE := 120.0
const WINDUP := 0.55
const LASH := 0.18
const RECOVER := 0.9
const DRAG := 26.0

var _strafe_dir: float = 1.0
var _drift_t: float = 1.0
var _aim: Vector2 = Vector2.RIGHT
var _chain: Line2D

@onready var lash_box: Hitbox = $LashBox


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, anims(
		{"idle": "idle", "walk": "walk", "windup": "windup", "lash": "attack", "hurt": "hurt"}, {"idle": 2, "walk": 6}))
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	_drift_t = randf_range(1.0, 1.8)
	_chain = Line2D.new()
	_chain.width = 1.0
	_chain.default_color = Color(0.7, 0.72, 0.78, 0.35)
	_chain.z_index = 3
	_chain.visible = false
	add_child(_chain)
	lash_box.source = self
	lash_box.landed.connect(_on_lash_landed)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle": play("idle")
		&"drift":
			play("walk")
			_drift_t = randf_range(1.0, 1.8)
			if randf() < 0.3:
				_strafe_dir = -_strafe_dir
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
			_chain.default_color = Color(0.7, 0.72, 0.78, 0.35)
			_chain.visible = true
		&"lash":
			play("lash")
			velocity = Vector2.ZERO
			lash_box.rotation = _aim.angle()
			lash_box.activate()
			_chain.default_color = Color(0.85, 0.88, 0.95, 1.0)
			_draw_chain(LASH_RANGE)
			Audio.play("chain", 0.1, -3.0)
			FX.burst(global_position + _aim * 30.0, Color(0.7, 0.72, 0.78), 6, 40.0)
		&"recover":
			play("idle")
			lash_box.deactivate()
			_chain.visible = false


func _exit_state(s: StringName) -> void:
	if s == &"lash":
		lash_box.deactivate()
		_chain.visible = false


func _draw_chain(length: float) -> void:
	_chain.clear_points()
	_chain.add_point(Vector2(0, -6))
	_chain.add_point(_aim * length + Vector2(0, -6))


func _tick(_delta: float) -> void:
	var d := to_player()
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO and d.length() < 220.0:
				change_state(&"drift")
		&"drift":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			var dist := d.length()
			var radial := d.normalized() * (1.0 if dist > KEEP_DISTANCE + 14.0 else (-1.0 if dist < KEEP_DISTANCE - 14.0 else 0.0))
			var tangent := d.normalized().orthogonal() * _strafe_dir
			velocity = (radial * 0.9 + tangent * 0.6).normalized() * speed
			face(d.x)
			if is_on_wall():
				_strafe_dir = -_strafe_dir
			if state_t >= _drift_t and dist < LASH_RANGE - 8.0:
				change_state(&"windup")
		&"windup":
			velocity = Vector2.ZERO
			# The chain follows you until the flash; after that it is committed.
			if d != Vector2.ZERO and state_t < WINDUP - STRIKE_CUE_LEAD:
				_aim = d.normalized()
				face(d.x)
			_draw_chain(LASH_RANGE * minf(1.0, state_t / (WINDUP - STRIKE_CUE_LEAD)))
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"lash")
		&"lash":
			velocity = Vector2.ZERO
			if state_t >= LASH:
				change_state(&"recover")
		&"recover":
			velocity = Vector2.ZERO
			if state_t >= RECOVER:
				change_state(&"drift")


## Caught on the chain: a step toward the hand that holds it.
func _on_lash_landed(_target: Hurtbox, _info: DamageInfo) -> void:
	if player and not player.dead:
		player.yank_to(player.global_position - _aim * DRAG, 0.12)
		FX.text(player.global_position, "DRAGGED", Color(0.85, 0.8, 0.7))


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"drift" or state == &"idle":
		play("hurt")
		stunned = 0.15
