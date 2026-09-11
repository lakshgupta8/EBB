class_name Player
extends CharacterBody2D
## The Tidekeeper. Movement, dash, damage intake, riptide (perfect dodge), the lantern
## glow meter and flare. Weapons are children and handle their own attacks.

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
const LUNGE_WINDOW := 0.12         # seconds after a dash ends where attack = lunge
const DASH_GRACE := 0.06           # i-frames linger this long after the dash

const GLOW_MAX := 100.0
const GLOW_PER_HIT := 9.0
const GLOW_PER_KILL := 12.0
const FLARE_RADIUS := 100.0
const FLARE_DAMAGE := 6
const FLARE_STUN := 1.5
const RIPTIDE_WINDOW := 3.0

const MASK_WORLD := 1
const MASK_WORLD_AND_ENEMIES := 1 | 4

var max_dash: int = DASH_CHARGES
var dash_charges: int = DASH_CHARGES
var facing: Vector2 = Vector2.RIGHT
var aim: Vector2 = Vector2.RIGHT
var in_water: bool = false
var dead: bool = false
## Bots and tests set this to steer aim without a mouse. Vector2.ZERO = use the mouse.
var aim_override: Vector2 = Vector2.ZERO
var last_hit_tags: PackedStringArray = []
var glow: float = 0.0
var riptide_t: float = 0.0  # crit armed while > 0
var attack_held: bool = false

var _dash_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _since_dash: float = 10.0
var _recharge_timer: float = 0.0
var _yank_timer: float = 0.0
var _yank_target: Vector2 = Vector2.ZERO
var _yank_from: Vector2 = Vector2.ZERO
var _yank_total: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _lunge_vel: Vector2 = Vector2.ZERO
var _hurt_timer: float = 0.0
var _dodge_cd: float = 0.0

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
	hurtbox.dodged.connect(_on_dodged)
	health.died.connect(_on_died)
	health.changed.connect(func(c, m): EventBus.player_health_changed.emit(c, m))
	EventBus.enemy_died.connect(func(_e): add_glow(GLOW_PER_KILL))


func is_dashing() -> bool:
	return _dash_timer > 0.0


func is_yanked() -> bool:
	return _yank_timer > 0.0


func glow_full() -> bool:
	return glow >= GLOW_MAX


## Pulled by the hook: fly to `target` over `duration` seconds with i-frames.
func yank_to(target: Vector2, duration: float) -> void:
	_yank_from = global_position
	_yank_target = target
	_yank_total = duration
	_yank_timer = duration


## Short forward push used by the lunge attack.
func lunge(dir: Vector2, speed: float = 260.0) -> void:
	_lunge_vel = dir.normalized() * speed


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

	attack_held = Input.is_action_pressed("attack")
	if Input.is_action_just_pressed("attack"):
		if is_dashing() or _since_dash < LUNGE_WINDOW:
			weapon.try_lunge()
		else:
			weapon.try_attack()
	weapon.set_held(attack_held)
	if Input.is_action_just_pressed("special"):
		weapon.try_special()
	if Input.is_action_just_pressed("use_item") and glow_full():
		flare()

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
		velocity = input * speed + _knockback + _lunge_vel
		if input != Vector2.ZERO:
			facing = input.normalized()
		if Input.is_action_just_pressed("dash") and dash_charges > 0:
			_start_dash(input.normalized() if input != Vector2.ZERO else facing)

	_since_dash = 0.0 if is_dashing() else _since_dash + delta
	_knockback = _knockback.lerp(Vector2.ZERO, HURT_KNOCKBACK_DECAY * delta)
	_lunge_vel = _lunge_vel.lerp(Vector2.ZERO, 14.0 * delta)
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	riptide_t = maxf(0.0, riptide_t - delta)
	# A short grace after the dash keeps late dodges honest.
	var ghosting := is_dashing() or is_yanked() or _since_dash < DASH_GRACE
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
	if dash_charges >= max_dash:
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
	if anim == "walk":
		sprite.speed_scale = -1.0 if signf(input.x) == -signf(aim.x) and input.x != 0.0 else 1.0
	else:
		sprite.speed_scale = 1.0
	# Riptide armed: faint blue pulse. Glow full: warm pulse.
	if riptide_t > 0.0:
		sprite.modulate = Color(0.8, 0.95, 1.0).lerp(Color.WHITE, 0.5 + 0.5 * sin(riptide_t * 12.0))
	elif glow_full():
		sprite.modulate = Color(1.0, 0.95, 0.8).lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0))
	else:
		sprite.modulate = Color.WHITE


# --- riptide -------------------------------------------------------------------------
## An enemy attack passed through us mid-dash: perfect dodge.
func _on_dodged(_info: DamageInfo) -> void:
	if _dodge_cd > 0.0 or not (is_dashing() or _since_dash < DASH_GRACE):
		return
	_dodge_cd = 0.6
	riptide_t = RIPTIDE_WINDOW
	dash_charges = mini(max_dash, dash_charges + 1)
	Juice.slowmo(0.25, 0.28)
	FX.ring(global_position, Color(0.6, 0.9, 1.0), 1.2)
	FX.text(global_position, "RIPTIDE", Color(0.7, 0.95, 1.0))
	EventBus.request_shake.emit(0.2)


## The next hit is a crit if riptide is armed. Weapons call this when a hitbox goes live.
func consume_riptide() -> bool:
	if riptide_t <= 0.0:
		return false
	riptide_t = 0.0
	return true


# --- lantern -------------------------------------------------------------------------
func add_glow(amount: float) -> void:
	var was_full := glow_full()
	glow = minf(GLOW_MAX, glow + amount)
	if glow_full() and not was_full:
		FX.burst(global_position + Vector2(-6, -2), Color(1.0, 0.9, 0.5), 8, 35.0)
		FX.text(global_position, "LANTERN READY", Color(1.0, 0.9, 0.55))


func flare() -> void:
	glow = 0.0
	Juice.hitstop(0.08)
	EventBus.request_shake.emit(0.7)
	FX.flash_screen(Color(1.0, 0.95, 0.8, 0.55), 0.3)
	FX.ring(global_position, Color(1.0, 0.9, 0.5), 2.6)
	FX.burst(global_position, Color(1.0, 0.9, 0.5), 24, 140.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.global_position.distance_to(global_position) > FLARE_RADIUS:
			continue
		var info := DamageInfo.make(FLARE_DAMAGE, self, e.global_position - global_position, 120.0)
		info.tags = PackedStringArray(["flare", "lantern"])
		info.hitstop = 0.0
		e.hurtbox.receive(info)
		e.stunned = maxf(e.stunned, FLARE_STUN if not e.is_boss else FLARE_STUN * 0.5)
		FX.spark(e.global_position)


# --- damage --------------------------------------------------------------------------
## Chip damage from deep water: ignores i-frames, no knockback, softer feedback.
func take_tide_damage(info: DamageInfo) -> void:
	if dead or health.invulnerable:
		return
	if health.take(info, true):
		last_hit_tags = info.tags
		_flash()
		EventBus.request_shake.emit(0.15)
		FX.burst(global_position + Vector2(0, 2), Color(0.5, 0.75, 0.9, 0.9), 6, 40.0)


func _on_hurt(info: DamageInfo) -> void:
	last_hit_tags = info.tags
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
