class_name Player
extends CharacterBody2D
## The Tidekeeper. Movement and dash live here; weapons attach as children.

const TILE := 16.0
const SPEED := 6.0 * TILE          # 6 tiles/sec
const DASH_DISTANCE := 3.0 * TILE  # 3 tiles
const DASH_TIME := 0.15
const DASH_CHARGES := 3
const DASH_RECHARGE := 1.2
const WATER_SPEED_MULT := 0.7

var dash_charges: int = DASH_CHARGES
var facing: Vector2 = Vector2.RIGHT
var aim: Vector2 = Vector2.RIGHT
var in_water: bool = false

var _dash_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _recharge_timer: float = 0.0

@onready var sprite: ColorRect = $Sprite


func is_dashing() -> bool:
	return _dash_timer > 0.0


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	aim = (get_global_mouse_position() - global_position).normalized()

	if is_dashing():
		_dash_timer -= delta
		velocity = _dash_dir * (DASH_DISTANCE / DASH_TIME)
	else:
		var speed := SPEED * (WATER_SPEED_MULT if in_water else 1.0)
		velocity = input * speed
		if input != Vector2.ZERO:
			facing = input.normalized()
		if Input.is_action_just_pressed("dash") and dash_charges > 0:
			_start_dash(input.normalized() if input != Vector2.ZERO else facing)

	_recharge(delta)
	move_and_slide()
	_update_placeholder_visual()


func _start_dash(dir: Vector2) -> void:
	dash_charges -= 1
	_dash_timer = DASH_TIME
	_dash_dir = dir


func _recharge(delta: float) -> void:
	if dash_charges >= DASH_CHARGES:
		_recharge_timer = 0.0
		return
	_recharge_timer += delta
	if _recharge_timer >= DASH_RECHARGE:
		_recharge_timer -= DASH_RECHARGE
		dash_charges += 1


func _update_placeholder_visual() -> void:
	# Placeholder until sprites land: stretch along dash, tint by charges.
	if sprite == null:
		return
	sprite.color = Color(0.95, 0.85, 0.55) if not is_dashing() else Color(1.0, 1.0, 1.0)
	sprite.modulate.a = 0.5 + 0.5 * (float(dash_charges) / DASH_CHARGES)
