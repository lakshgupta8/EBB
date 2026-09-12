class_name Player
extends CharacterBody2D
## The Tidekeeper. Movement, dash, damage intake, riptide (perfect dodge), the lantern
## glow meter and flare. Weapons are children and handle their own attacks.
## `mods` is the bag of stat modifiers that tidemarks and the Ledger write into.

const FLASH_SHADER := preload("res://src/combat/hit_flash.gdshader")
const SHEET := preload("res://assets/sprites/player.png")

const TILE := 16.0
const SPEED := 6.0 * TILE          # 6 tiles/sec
const DASH_DISTANCE := 3.0 * TILE  # 3 tiles
const DASH_TIME := 0.15
const DASH_CHARGES := 3
const DASH_RECHARGE := 1.2
const HURT_KNOCKBACK_DECAY := 10.0
const LUNGE_WINDOW := 0.12         # seconds after a dash ends where attack = lunge
const DASH_GRACE := 0.06           # i-frames linger this long after the dash

const GLOW_MAX := 100.0
const GLOW_PER_HIT := 9.0
const GLOW_PER_KILL := 12.0
const FLARE_RADIUS := 100.0
const FLARE_DAMAGE := 6
const FLARE_STUN := 1.5

const MASK_WORLD := 1
const MASK_WORLD_AND_ENEMIES := 1 | 4

var mods: Dictionary = {
	"damage": 1.0, "heavy_damage": 1.0, "crit_chance": 0.0, "bleed": false,
	"dash_guard": false, "kill_heal": 0, "dash_wake": false,
	"speed": 1.0, "water_speed": 0.7,
	"salt_mult": 1.0, "glow_mult": 1.0,
	"riptide_window": 3.0, "riptide_crit": 2.0,
	"second_chance": false,
	# M4 additions
	"lunge_mult": 1.0, "wall_damage": 3, "held_bonus": 0.0, "room_shield": false,
	"knockback_taken": 1.0, "flare_heal": 0, "dash_recharge": 1.0, "riptide_refund": false,
	"dash_dist": 1.0, "tide_heals": false, "water_damage": 1.0,
	"ranged_mult": 1.0, "lit_bonus": 0.0, "execute": false, "rally_per": 0.0,
	"regen": false, "low_guard": false, "dash_grace": DASH_GRACE, "free_water_dash": false,
	"panic_speed": 1.0, "riptide_heal": 0, "pearl_bonus": 0, "water_kill_heal": 0,
}

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
var parry_t: float = 0.0    # the bell's toll: nothing lands while > 0
var attack_held: bool = false
var aim_dist: float = 64.0  # distance to the cursor (bots: a fixed reach)
var rally: float = 0.0      # Rally tidemark: damage bonus built up in this room
var _regen_t: float = 0.0

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
var _second_chance_used: bool = false
var _wake: Hitbox
var _lantern: PointLight2D

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
var weapon: Weapon


func _ready() -> void:
	add_to_group("player")
	_equip(Game.weapon_id())
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
	hurtbox.shielded.connect(_on_shielded)
	EventBus.room_cleared.connect(_on_room_cleared)
	health.died.connect(_on_died)
	health.changed.connect(func(c, m): EventBus.player_health_changed.emit(c, m))
	EventBus.enemy_died.connect(_on_enemy_died)
	_build_wake()
	# The keeper's lantern: the warm pool of light you carry through the night.
	_lantern = Atmosphere.light(self, Color(1.0, 0.9, 0.72), 5.0, 1.15, Vector2(-4, -6))
	Atmosphere.breathe(_lantern, 1.05, 1.25, 2.4)


## Swap the weapon child for the chosen one. The scene ships with the gaff as a placeholder.
func _equip(weapon_id: String) -> void:
	var old := get_node_or_null("Weapon")
	if old:
		old.name = "OldWeapon"
		old.queue_free()
	weapon = Weapon.scene_for(weapon_id).instantiate()
	weapon.name = "Weapon"
	weapon.position = Vector2(0, -6)
	add_child(weapon)


## How far away the cursor is (thrown things fly to it). Bots get a fixed reach.
func aim_distance() -> float:
	return aim_dist


## Dash wake hitbox (used only with the Wake tidemark).
func _build_wake() -> void:
	_wake = Hitbox.new()
	_wake.collision_layer = 0
	_wake.collision_mask = 128  # enemy_hurtbox
	_wake.damage = 2
	_wake.knockback = 40.0
	_wake.hitstop = 0.02
	_wake.tags = PackedStringArray(["wake"])
	_wake.source = self
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 10.0
	shape.shape = c
	_wake.add_child(shape)
	add_child(_wake)
	_wake.landed.connect(func(t, _i): FX.spark(t.global_position); add_glow(GLOW_PER_HIT * 0.5))


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
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if aim_override != Vector2.ZERO:
		aim = aim_override.normalized()
	elif stick.length() > 0.35:
		# Right stick: aim there, reach with the tilt.
		aim = stick.normalized()
		aim_dist = 40.0 + 56.0 * minf(stick.length(), 1.0)
	elif Game.gamepad:
		# Pad without the stick: aim where you walk, keep the last aim when still.
		if input != Vector2.ZERO:
			aim = input.normalized()
		aim_dist = 64.0
	else:
		aim = (get_global_mouse_position() - global_position)
		aim_dist = aim.length()
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
		velocity = _dash_dir * (DASH_DISTANCE * float(mods.dash_dist) / DASH_TIME)
		if _dash_timer <= 0.0 and _wake.active:
			_wake.deactivate()
	else:
		var speed: float = SPEED * float(mods.speed) * (float(mods.water_speed) if in_water else 1.0) * weapon.move_mult()
		if health.hp * 2 < health.max_hp:
			speed *= float(mods.panic_speed)
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
	var ghosting := is_dashing() or is_yanked() or _since_dash < float(mods.dash_grace)
	health.invulnerable = ghosting or parry_t > 0.0
	parry_t = maxf(0.0, parry_t - delta)
	var taken := 0.7 if (mods.dash_guard and _since_dash < 1.0) else 1.0
	if mods.low_guard and health.hp * 10 < health.max_hp * 3:
		taken *= 0.75
	hurtbox.damage_mult = taken
	_tick_regen(delta)
	collision_mask = MASK_WORLD if ghosting else MASK_WORLD_AND_ENEMIES
	_recharge(delta)
	move_and_slide()
	_animate(input)


func _start_dash(dir: Vector2) -> void:
	if not (mods.free_water_dash and in_water):
		dash_charges -= 1
	weapon.on_dash(dir)
	_dash_timer = DASH_TIME
	_dash_dir = dir
	weapon.cancel()
	FX.burst(global_position + Vector2(0, 4), Color(0.9, 0.85, 0.7, 0.8), 6, 30.0)
	Audio.play("splash" if in_water else "dash", 0.12, -4.0)
	if mods.dash_wake:
		_wake.activate()
		FX.burst(global_position, Color(0.6, 0.9, 1.0, 0.8), 6, 40.0)


## Slow Salt: a point of health every 4 s on dry ground.
func _tick_regen(delta: float) -> void:
	if not mods.regen or in_water or dead:
		_regen_t = 0.0
		return
	_regen_t += delta
	if _regen_t >= 4.0:
		_regen_t = 0.0
		if health.hp < health.max_hp:
			health.heal(1)


func _recharge(delta: float) -> void:
	if dash_charges >= max_dash:
		_recharge_timer = 0.0
		return
	_recharge_timer += delta
	var every: float = DASH_RECHARGE * float(mods.dash_recharge)
	if _recharge_timer >= every:
		_recharge_timer -= every
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
	if riptide_t > 0.0:
		sprite.modulate = Color(0.8, 0.95, 1.0).lerp(Color.WHITE, 0.5 + 0.5 * sin(riptide_t * 12.0))
	elif weapon.is_charging():
		var f := weapon.charge_fraction()
		sprite.modulate = Color(1.0 + 0.3 * f, 1.0 + 0.2 * f, 1.0)
	elif glow_full():
		sprite.modulate = Color(1.0, 0.95, 0.8).lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0))
	else:
		sprite.modulate = Color.WHITE


# --- riptide -------------------------------------------------------------------------
## An enemy attack passed through us mid-dash: perfect dodge.
func _on_dodged(_info: DamageInfo) -> void:
	if _dodge_cd > 0.0 or not (is_dashing() or _since_dash < float(mods.dash_grace)):
		return
	_dodge_cd = 0.6
	if int(mods.riptide_heal) > 0:
		health.heal(int(mods.riptide_heal))
	riptide_t = mods.riptide_window
	dash_charges = max_dash if mods.riptide_refund else mini(max_dash, dash_charges + 1)
	Juice.slowmo(0.25, 0.28)
	FX.ring(global_position, Color(0.6, 0.9, 1.0), 1.2)
	FX.text(global_position, "RIPTIDE", Color(0.7, 0.95, 1.0))
	EventBus.request_shake.emit(0.2)
	Audio.play("riptide", 0.05)


## The next hit is a crit if riptide is armed. Weapons call this when a hitbox goes live.
func consume_riptide() -> bool:
	if riptide_t <= 0.0:
		return false
	riptide_t = 0.0
	return true


# --- lantern -------------------------------------------------------------------------
func add_glow(amount: float) -> void:
	var was_full := glow_full()
	glow = minf(GLOW_MAX, glow + amount * mods.glow_mult)
	if glow_full() and not was_full:
		FX.burst(global_position + Vector2(-6, -2), Color(1.0, 0.9, 0.5), 8, 35.0)
		FX.text(global_position, "LANTERN READY", Color(1.0, 0.9, 0.55))
		Audio.play("pearl", 0.0, -6.0)
	if _lantern:
		_lantern.color = Color(1.0, 0.9, 0.72).lerp(Color(1.0, 0.97, 0.85), glow / GLOW_MAX)


func flare() -> void:
	glow = 0.0
	Juice.hitstop(0.08)
	EventBus.request_shake.emit(0.7)
	FX.flash_screen(Color(1.0, 0.95, 0.8, 0.55), 0.3)
	FX.ring(global_position, Color(1.0, 0.9, 0.5), 2.6)
	FX.burst(global_position, Color(1.0, 0.9, 0.5), 24, 140.0)
	Audio.play("flare")
	if int(mods.flare_heal) > 0:
		health.heal(int(mods.flare_heal))
		FX.text(global_position + Vector2(0, -16), "+%d" % int(mods.flare_heal), Color(0.6, 0.95, 0.7))
	if _lantern:
		var tw := create_tween()
		_lantern.energy = 4.0
		tw.tween_property(_lantern, "energy", 1.15, 0.7)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.global_position.distance_to(global_position) > FLARE_RADIUS:
			continue
		var info := DamageInfo.make(int(FLARE_DAMAGE * mods.damage), self, e.global_position - global_position, 120.0)
		info.tags = PackedStringArray(["flare", "lantern"])
		info.hitstop = 0.0
		e.hurtbox.receive(info)
		e.stunned = maxf(e.stunned, FLARE_STUN if not e.is_boss else FLARE_STUN * 0.5)
		FX.spark(e.global_position)


func _on_enemy_died(_e: Node) -> void:
	add_glow(GLOW_PER_KILL)
	if mods.kill_heal > 0 and not dead:
		health.heal(mods.kill_heal)
	if int(mods.water_kill_heal) > 0 and in_water and not dead:
		health.heal(int(mods.water_kill_heal))
	if float(mods.rally_per) > 0.0:
		rally = minf(rally + float(mods.rally_per), float(mods.rally_per) * 10.0)


# --- damage --------------------------------------------------------------------------
## Chip damage from deep water: ignores i-frames, no knockback, softer feedback.
func take_tide_damage(info: DamageInfo) -> void:
	if dead or health.invulnerable:
		return
	if mods.tide_heals:
		if health.hp < health.max_hp:
			health.heal(info.amount)
			FX.burst(global_position + Vector2(0, 2), Color(0.5, 0.9, 0.7, 0.9), 4, 30.0)
		return
	if health.take(info, true):
		last_hit_tags = info.tags
		_flash()
		EventBus.request_shake.emit(0.15)
		FX.burst(global_position + Vector2(0, 2), Color(0.5, 0.75, 0.9, 0.9), 6, 40.0)
		Audio.play("splash", 0.2, -8.0)


func _on_hurt(info: DamageInfo) -> void:
	last_hit_tags = info.tags
	_knockback = info.direction * info.knockback * float(mods.knockback_taken)
	_hurt_timer = 0.25 if float(mods.knockback_taken) >= 1.0 else 0.12
	weapon.cancel()
	_flash()
	EventBus.request_shake.emit(0.5)
	EventBus.request_hitstop.emit(0.08)
	FX.burst(global_position, Color(0.9, 0.3, 0.3), 10, 70.0)
	Audio.play("hurt", 0.1)


func _on_shielded(_info: DamageInfo) -> void:
	FX.ring(global_position, Color(0.55, 0.75, 0.95), 1.1)
	FX.text(global_position, "ABSORBED", Color(0.6, 0.8, 1.0))
	FX.burst(global_position, Color(0.55, 0.75, 0.95), 8, 50.0)
	Audio.play("splash", 0.1, -6.0)
	EventBus.request_hitstop.emit(0.04)


## Salt Skin: a fresh shield charge after every cleared room.
func _on_room_cleared(_room: Node) -> void:
	if mods.room_shield and not dead:
		hurtbox.shield_count = 1
		FX.text(global_position, "SALT SKIN", Color(0.6, 0.8, 1.0))


func _flash() -> void:
	sprite.material.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_property(sprite.material, "shader_parameter/flash", 0.0, 0.18)


func _on_died() -> void:
	if mods.second_chance and not _second_chance_used:
		# Keeper's Tether: the lantern holds you one more time.
		_second_chance_used = true
		health.hp = 30
		health.changed.emit(health.hp, health.max_hp)
		health._iframes = 1.5
		Juice.slowmo(0.2, 0.5)
		FX.flash_screen(Color(1.0, 0.95, 0.8, 0.7), 0.6)
		FX.ring(global_position, Color(1.0, 0.9, 0.5), 3.0)
		FX.text(global_position, "THE TETHER HOLDS", Color(1.0, 0.9, 0.55))
		Audio.play("altar")
		return
	dead = true
	sprite.play("hurt")
	sprite.modulate = Color(0.6, 0.6, 0.7)
	weapon.cancel()
	weapon.visible = false
	# Fall over, away from the last hit, and go still.
	var side := -1.0 if sprite.flip_h else 1.0
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", side * PI * 0.5, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sprite, "position:y", sprite.position.y + 5.0, 0.45)
	tw.tween_property(sprite, "modulate", Color(0.45, 0.45, 0.55), 0.8)
	FX.burst(global_position, Color(0.75, 0.8, 0.95), 14, 60.0)
	EventBus.player_died.emit()
