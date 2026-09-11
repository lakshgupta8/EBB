class_name Player
extends CharacterBody2D
## The Tidekeeper. Movement, dash, damage intake and animation. Weapons are children.

const FLASH_SHADER := preload("res://src/combat/hit_flash.gdshader")
const SHEET := preload("res://assets/sprites/player.png")

const TILE := 16.0
const SPEED := 6.0 * TILE          # 6 tiles/sec
const DASH_DISTANCE := 3.0 * TILE  # 3 tiles
const DASH_TIME := 0.15
const DASH_CHARGES := 3
const DASH_RECHARGE := 1.2
const WATER_SPEED_MULT := 0.7
const HURT_KNOCKBACK_DECAY := 10.0

var dash_charges: int = DASH_CHARGES
var facing: Vector2 = Vector2.RIGHT
var aim: Vector2 = Vector2.RIGHT
var in_water: bool = false
var dead: bool = false
## Bots and tests set this to steer aim without a mouse. Vector2.ZERO = use the mouse.
var aim_override: Vector2 = Vector2.ZERO

const MASK_WORLD := 1
const MASK_WORLD_AND_ENEMIES := 1 | 4

var _dash_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _recharge_timer: float = 0.0
var _yank_timer: float = 0.0
var _yank_target: Vector2 = Vector2.ZERO
var _yank_from: Vector2 = Vector2.ZERO
var _yank_total: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _hurt_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var weapon: GaffHook = $Weapon


func _ready() -> void:
	add_to_group("player")
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, {
		"idle": {"frames": [0, 1], "fps": 3},
		"walk": {"frames": [2, 3, 4, 5], "fps": 9},
		"hurt": {"frames": [6], "fps": 1},
		"dash": {"frames": [7], "fps": 1},
	})
	sprite.material = ShaderMaterial.new()
	sprite.material.shader = FLASH_SHADER
	sprite.play("idle")
	hurtbox.hit.connect(_on_hurt)
	health.died.connect(_on_died)
	health.changed.connect(func(c, m): EventBus.player_health_changed.emit(c, m))


func is_dashing() -> bool:
	return _dash_timer > 0.0


func is_yanked() -> bool:
	return _yank_timer > 0.0


## Pulled by the hook: fly to `target` over `duration` seconds with i-frames.
func yank_to(target: Vector2, duration: float) -> void:
	_yank_from = global_position
	_yank_target = target
	_yank_total = duration
	_yank_timer = duration


func _physics_process(delta: float) -> void:
	if dead:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if aim_override != Vector2.ZERO:
		aim = aim_override.normalized()
	else:
		aim = (get_global_mouse_position() - global_position)
		aim = aim.normalized() if aim.length() > 0.5 else facing

	if Input.is_action_just_pressed("attack"):
		weapon.try_attack()
	if Input.is_action_just_pressed("special"):
		weapon.try_special()

	if is_yanked():
		_yank_timer -= delta
		var t := 1.0 - maxf(_yank_timer, 0.0) / _yank_total
		var target := _yank_from.lerp(_yank_target, ease(t, 0.5))
		velocity = (target - global_position) / delta
	elif is_dashing():
		_dash_timer -= delta
		velocity = _dash_dir * (DASH_DISTANCE / DASH_TIME)
	else:
		var speed := SPEED * (WATER_SPEED_MULT if in_water else 1.0) * weapon.move_mult()
		velocity = input * speed + _knockback
		if input != Vector2.ZERO:
			facing = input.normalized()
		if Input.is_action_just_pressed("dash") and dash_charges > 0:
			_start_dash(input.normalized() if input != Vector2.ZERO else facing)

	_knockback = _knockback.lerp(Vector2.ZERO, HURT_KNOCKBACK_DECAY * delta)
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	var ghosting := is_dashing() or is_yanked()
	health.invulnerable = ghosting
	collision_mask = MASK_WORLD if ghosting else MASK_WORLD_AND_ENEMIES
	_recharge(delta)
	move_and_slide()
	_animate(input)


func _start_dash(dir: Vector2) -> void:
	dash_charges -= 1
	_dash_timer = DASH_TIME
	_dash_dir = dir
	weapon.cancel()
	FX.burst(global_position + Vector2(0, 4), Color(0.9, 0.85, 0.7, 0.8), 6, 30.0)


func _recharge(delta: float) -> void:
	if dash_charges >= DASH_CHARGES:
		_recharge_timer = 0.0
		return
	_recharge_timer += delta
	if _recharge_timer >= DASH_RECHARGE:
		_recharge_timer -= DASH_RECHARGE
		dash_charges += 1


func _animate(input: Vector2) -> void:
	sprite.flip_h = aim.x < 0.0
	var anim := "idle"
	if _hurt_timer > 0.0:
		anim = "hurt"
	elif is_dashing() or is_yanked():
		anim = "dash"
	elif input != Vector2.ZERO:
		anim = "walk"
	if sprite.animation != anim:
		sprite.play(anim)
	# Walking backwards relative to aim plays the walk in reverse.
	if anim == "walk":
		sprite.speed_scale = -1.0 if signf(input.x) == -signf(aim.x) and input.x != 0.0 else 1.0
	else:
		sprite.speed_scale = 1.0


func _on_hurt(info: DamageInfo) -> void:
	_knockback = info.direction * info.knockback
	_hurt_timer = 0.25
	weapon.cancel()
	_flash()
	EventBus.request_shake.emit(0.5)
	EventBus.request_hitstop.emit(0.08)
	FX.burst(global_position, Color(0.9, 0.3, 0.3), 10, 70.0)


func _flash() -> void:
	sprite.material.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_property(sprite.material, "shader_parameter/flash", 0.0, 0.18)


func _on_died() -> void:
	dead = true
	sprite.play("hurt")
	sprite.modulate = Color(0.6, 0.6, 0.7)
	weapon.cancel()
	weapon.visible = false
	EventBus.player_died.emit()
