class_name Enemy
extends CharacterBody2D
## Shared enemy plumbing: health, hurt reaction, knockback, flash, death, facing.
## Subclasses implement _setup_animations() and _tick(delta) and drive `state`.

const FLASH_SHADER := preload("res://src/combat/hit_flash.gdshader")

@export var display_name: String = "Enemy"
@export var speed: float = 32.0
@export var knockback_resist: float = 0.0  # 0..1
@export var death_color: Color = Color(0.6, 0.7, 0.5)
@export var flying: bool = false  # ignores water
@export var amphibious: bool = false  # fast in water, slow on land (swimmers)
@export var salt_drop: int = 2
@export var pearl_drop: int = 0

const WATER_SPEED_MULT := 0.7
const LAND_SPEED_MULT := 0.45   # amphibious things out of the water
const KINDLE_SPEED_MULT := 1.35
const NET_TEX := preload("res://assets/sprites/net.png")

var is_elite: bool = false
var is_boss: bool = false
## Elite affixes: salt-crusted (armour), lit (fast, glows), anchored (cannot be moved, and
## its hits drag you a step), hollow (splits into two of its kind when it dies).
const AFFIXES := ["crusted", "lit", "anchored", "hollow"]
const AFFIX_NAMES := {"crusted": "Salt-crusted", "lit": "Lit", "anchored": "Anchored", "hollow": "Hollow"}
var affix: String = ""
var armour: float = 1.0          # incoming damage multiplier from the crust
var hollow_child: bool = false   # a half of a hollow elite: weaker, drops little
var room: Room
var cracked_t: float = 0.0       # takes double damage while > 0 (heavy hit)
var _wall_slam_armed: bool = false
var _pull_timer: float = 0.0
var _pull_total: float = 0.0
var _pull_from: Vector2
var _pull_to: Vector2
var _bleed_ticks: int = 0
var _bleed_t: float = 0.0
var netted_t: float = 0.0        # rooted under a net; takes extra damage
var lit_t: float = 0.0           # marked by the storm lantern; takes extra damage
var slowed_t: float = 0.0        # inside a beacon
var tethered_t: float = 0.0      # on the harpoon line
var _lit_light: PointLight2D
var kindled_t: float = 0.0       # sped up by a lamplighter
var _net_sprite: Sprite2D


## Rooted under the net for `duration`. Bosses get the short version from the weapon.
func net(duration: float) -> void:
	netted_t = maxf(netted_t, duration)
	stunned = maxf(stunned, duration)
	if hitbox and hitbox.active:
		hitbox.deactivate()
	if _net_sprite == null:
		_net_sprite = Sprite2D.new()
		_net_sprite.texture = NET_TEX
		_net_sprite.position = Vector2(0, -6)
		_net_sprite.z_index = 4
		_net_sprite.modulate = Color(1, 1, 1, 0.9)
		add_child(_net_sprite)
	_net_sprite.visible = true
	_net_sprite.rotation = randf() * TAU
	_refresh_mult()


func kindle(duration: float) -> void:
	kindled_t = maxf(kindled_t, duration)
	FX.burst(global_position + Vector2(0, -8), Color(1.0, 0.8, 0.5), 6, 40.0)


func lit(duration: float) -> void:
	lit_t = maxf(lit_t, duration)
	if _lit_light == null:
		_lit_light = Atmosphere.light(self, Color(1.0, 0.9, 0.6), 2.4, 0.9, Vector2(0, -8))
	_lit_light.visible = true
	_refresh_mult()


func slow(duration: float) -> void:
	slowed_t = maxf(slowed_t, duration)


func tether(duration: float) -> void:
	tethered_t = maxf(tethered_t, duration)
	_refresh_mult()


func is_held() -> bool:
	return netted_t > 0.0 or _pull_timer > 0.0 or tethered_t > 0.0


## Incoming damage multiplier from every status at once.
func _refresh_mult() -> void:
	var m := 1.0
	if cracked_t > 0.0:
		m *= 2.0
	if netted_t > 0.0:
		m *= 1.25
	if is_held() and player:
		m *= 1.0 + float(player.mods.held_bonus)
	if lit_t > 0.0:
		m *= 1.3 + (float(player.mods.lit_bonus) if player else 0.0)
	if player and player.mods.execute and health.hp * 4 <= health.max_hp:
		m *= 2.0
	if player and stunned > 0.0 and float(player.mods.stun_bonus) > 0.0:
		m *= 1.0 + float(player.mods.stun_bonus)
	if player and float(player.mods.wet_bonus) > 0.0 and room and room.is_flooded_at(global_position):
		m *= 1.0 + float(player.mods.wet_bonus)
	hurtbox.damage_mult = m * armour


## Dragged to a point (the hook). Stunned for a moment on arrival.
func pull_to(target: Vector2, duration: float) -> void:
	_pull_from = global_position
	_pull_to = target
	_pull_total = duration
	_pull_timer = duration
	stunned = maxf(stunned, duration + 0.4)
	if hitbox and hitbox.active:
		hitbox.deactivate()
	_refresh_mult()


func apply_bleed(ticks: int = 3) -> void:
	_bleed_ticks = maxi(_bleed_ticks, ticks)
	_bleed_t = 0.0

var state: StringName = &"idle"
var state_t: float = 0.0  # seconds in current state
var player: Player
var stunned: float = 0.0
var _knockback: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = get_node_or_null("Hitbox")


func _ready() -> void:
	add_to_group("enemies")
	sprite.material = ShaderMaterial.new()
	sprite.material.shader = FLASH_SHADER
	_setup_animations()
	hurtbox.hit.connect(_on_hurt)
	health.died.connect(_on_died)
	if hitbox:
		hitbox.source = self
		hitbox.landed.connect(_on_hit_landed)
	player = get_tree().get_first_node_in_group("player") as Player
	room = get_tree().get_first_node_in_group("room") as Room
	health.changed.connect(func(_c, _m): _refresh_mult())
	if hollow_child:
		health.max_hp = maxi(1, health.max_hp * 2 / 5)
		health.hp = health.max_hp
		salt_drop = 1
		scale *= 0.85
	_enter_state(&"idle")


## Tougher variant with a pearl drop. Call right after instantiating, before add_child completes.
## With an affix (see AFFIXES) it also gets a quirk and a name to warn you.
func make_elite(p_affix: String = "") -> void:
	is_elite = true
	affix = p_affix if p_affix in AFFIXES else ""
	display_name = (str(AFFIX_NAMES[affix]) + " " if affix != "" else "Elite ") + display_name
	scale = Vector2(1.25, 1.25)
	call_deferred("_apply_stat_mult", 2.5, 1.15)
	if affix != "":
		call_deferred("_apply_affix")
	pearl_drop += 1
	salt_drop += 6
	death_color = Color(0.95, 0.8, 0.4)


func make_boss(p_name: String) -> void:
	is_boss = true
	display_name = p_name
	scale = Vector2(1.9, 1.9)
	call_deferred("_apply_stat_mult", 9.0, 1.3)
	knockback_resist = 0.9
	pearl_drop += 4
	salt_drop += 10
	death_color = Color(0.95, 0.8, 0.4)


func _apply_stat_mult(hp_mult: float, speed_mult: float) -> void:
	health.max_hp = int(health.max_hp * hp_mult)
	health.hp = health.max_hp
	speed *= speed_mult


func _apply_affix() -> void:
	match affix:
		"crusted":
			armour = 0.6
			sprite.modulate = Color(0.92, 0.97, 0.92)
			_refresh_mult()
		"lit":
			speed *= 1.35
			var l := Atmosphere.light(self, Color(1.0, 0.85, 0.5), 2.2, 0.8, Vector2(0, -8))
			Atmosphere.breathe(l, 0.6, 1.0, 1.0)
		"anchored":
			knockback_resist = 1.0
			if hitbox:
				hitbox.landed.connect(_anchored_pull)
		"hollow":
			pass


## Anchored: every hit it lands drags you a step toward it.
func _anchored_pull(_target: Hurtbox, _info: DamageInfo) -> void:
	if player and not player.dead:
		var to := global_position - player.global_position
		player.yank_to(player.global_position + to.normalized() * 18.0, 0.1)
		FX.text(player.global_position, "ANCHORED", Color(0.85, 0.8, 0.7))


## Hollow: two smaller copies of its kind climb out of the body.
func _hollow_split() -> void:
	if affix != "hollow" or scene_file_path == "" or get_parent() == null:
		return
	var scene: PackedScene = load(scene_file_path)
	for i in 2:
		var e: Enemy = scene.instantiate()
		e.hollow_child = true
		var side := 1.0 if i == 0 else -1.0
		e.global_position = global_position + Vector2(side * 12.0, randf_range(-4.0, 4.0))
		get_parent().call_deferred("add_child", e)
	FX.text(global_position + Vector2(0, -14), "HOLLOW", Color(0.8, 0.9, 0.85))


func _setup_animations() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func change_state(new_state: StringName) -> void:
	if new_state == state:
		return
	_exit_state(state)
	state = new_state
	state_t = 0.0
	_cued = false
	_enter_state(new_state)


func _enter_state(_s: StringName) -> void:
	pass


func _exit_state(_s: StringName) -> void:
	pass


func to_player() -> Vector2:
	if player == null or player.dead:
		return Vector2.ZERO
	return player.global_position - global_position


func face(dir_x: float) -> void:
	if absf(dir_x) > 0.1:
		sprite.flip_h = dir_x < 0.0
		if hitbox:
			hitbox.scale.x = -1.0 if dir_x < 0.0 else 1.0


## The "dodge now" tell: a white flash and a ring right before an attack lands.
## Subclasses call this once, ~0.2 s before the hit. Dash on the flash for a riptide.
const STRIKE_CUE_LEAD := 0.2
var _cued: bool = false


func strike_cue() -> void:
	if _cued:
		return
	_cued = true
	sprite.material.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_property(sprite.material, "shader_parameter/flash", 0.0, 0.2)
	FX.ring(global_position + Vector2(0, -6), Color(1.0, 0.9, 0.7), 0.7)


func play(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


func _physics_process(delta: float) -> void:
	state_t += delta
	_tick_bleed(delta)
	# Stun and water bonuses come and go every frame; the multiplier is cheap to redo.
	if player and (stunned > 0.0 or float(player.mods.wet_bonus) > 0.0):
		_refresh_mult()
	if _pull_timer > 0.0:
		_pull_timer -= delta
		var t := 1.0 - maxf(_pull_timer, 0.0) / _pull_total
		var goal := _pull_from.lerp(_pull_to, ease(t, 0.4))
		velocity = (goal - global_position) / delta
		move_and_slide()
		if _pull_timer <= 0.0:
			_refresh_mult()
		return
	if stunned > 0.0:
		stunned -= delta
		velocity = _knockback
	else:
		_tick(delta)
		if not flying and room:
			var wet := room.is_flooded_at(global_position)
			if amphibious:
				if not wet:
					velocity *= LAND_SPEED_MULT
			elif wet:
				velocity *= WATER_SPEED_MULT
		if kindled_t > 0.0:
			velocity *= KINDLE_SPEED_MULT
		if slowed_t > 0.0:
			velocity *= 0.6
		velocity += _knockback
	_knockback = _knockback.lerp(Vector2.ZERO, 12.0 * delta)
	move_and_slide()
	_stay_inside()
	_wall_slam()
	if cracked_t > 0.0:
		cracked_t -= delta
		if cracked_t <= 0.0:
			_refresh_mult()
			sprite.modulate = Color.WHITE if not is_boss else sprite.modulate
	if netted_t > 0.0:
		netted_t -= delta
		if netted_t <= 0.0:
			if _net_sprite:
				_net_sprite.visible = false
			_refresh_mult()
	slowed_t = maxf(0.0, slowed_t - delta)
	if tethered_t > 0.0:
		tethered_t -= delta
		if tethered_t <= 0.0:
			_refresh_mult()
	if lit_t > 0.0:
		lit_t -= delta
		if lit_t <= 0.0:
			if _lit_light:
				_lit_light.visible = false
			_refresh_mult()
	if kindled_t > 0.0:
		kindled_t -= delta
		if kindled_t <= 0.0:
			sprite.modulate = Color.WHITE if not is_boss else sprite.modulate
		elif cracked_t <= 0.0 and not is_boss:
			sprite.modulate = Color(1.0, 0.9, 0.75)


func _tick_bleed(delta: float) -> void:
	if _bleed_ticks <= 0:
		return
	_bleed_t += delta
	if _bleed_t >= 0.5:
		_bleed_t = 0.0
		_bleed_ticks -= 1
		var info := DamageInfo.make(1, null, Vector2.ZERO, 0.0)
		info.tags = PackedStringArray(["bleed"])
		info.hitstop = 0.0
		if health.take(info, true):
			FX.burst(global_position + Vector2(0, -6), Color(0.8, 0.2, 0.2), 3, 25.0)
			EventBus.damage_dealt.emit(self, info)


## A body wedged into a wall or shoved out of the room can never be reached, and the
## room never clears. Put it back on open floor. (Two bodies spawned on one point once
## walked each other through a wall this way; flyers cross walls on purpose.)
func _stay_inside() -> void:
	if room == null:
		return
	var size := room.size_px()
	var outside := global_position.x < 0.0 or global_position.y < 0.0 or global_position.x >= size.x or global_position.y >= size.y
	if not outside:
		if flying:
			return
		var c := room.world_to_cell(global_position)
		if not room.template.is_solid(c.x, c.y):
			return
	global_position = room.clamp_inside(global_position)
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	_wall_slam_armed = false


## Knocked hard into a wall: bonus damage and a thud.
func _wall_slam() -> void:
	if not _wall_slam_armed:
		return
	if _knockback.length() < 60.0:
		_wall_slam_armed = false
		return
	if is_on_wall():
		_wall_slam_armed = false
		_knockback = Vector2.ZERO
		var wall_dmg: int = int(player.mods.wall_damage) if player else 3
		var info := DamageInfo.make(wall_dmg, null, Vector2.ZERO, 0.0)
		info.tags = PackedStringArray(["wall"])
		info.hitstop = 0.0
		if health.take(info, true):
			EventBus.request_shake.emit(0.3)
			EventBus.request_hitstop.emit(0.04)
			FX.spark(global_position + Vector2(0, -6))
			FX.burst(global_position, Color(0.75, 0.68, 0.5), 6, 40.0)
			EventBus.damage_dealt.emit(self, info)
			if not health.is_alive():
				pass  # died signal already handled


func crack(duration: float) -> void:
	cracked_t = duration
	_refresh_mult()
	sprite.modulate = Color(1.0, 0.75, 0.7)
	stunned = maxf(stunned, 0.5)


func _on_hurt(info: DamageInfo) -> void:
	_knockback = info.direction * info.knockback * (1.0 - knockback_resist)
	_wall_slam_armed = _knockback.length() >= 60.0
	stunned = maxf(stunned, 0.12)
	if info.tags.has("heavy") and not is_boss:
		crack(3.0)
	elif info.tags.has("heavy"):
		stunned = maxf(stunned, 0.35)
	if info.tags.has("crit"):
		FX.burst(global_position + Vector2(0, -6), Color(1.0, 0.95, 0.6), 10, 70.0)
	sprite.material.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_property(sprite.material, "shader_parameter/flash", 0.0, 0.15)
	_on_hurt_extra(info)


func _on_hurt_extra(_info: DamageInfo) -> void:
	pass


func _on_hit_landed(_target: Hurtbox, _info: DamageInfo) -> void:
	pass


func _on_died() -> void:
	FX.burst(global_position, death_color, 16, 90.0)
	FX.burst(global_position, Color.WHITE, 6, 50.0)
	Audio.play("death", 0.2, 0.0 if not is_boss else 4.0)
	EventBus.request_hitstop.emit(0.1)
	EventBus.request_shake.emit(0.3)
	_hollow_split()
	_leave_body()
	EventBus.enemy_died.emit(self)
	queue_free()


## The last frame, left behind: it squashes flat, tints to the death colour and fades.
func _leave_body() -> void:
	if sprite == null or sprite.sprite_frames == null or get_parent() == null:
		return
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var body := Sprite2D.new()
	body.texture = tex
	body.flip_h = sprite.flip_h
	body.flip_v = sprite.flip_v
	body.offset = sprite.offset
	body.centered = sprite.centered
	body.z_index = z_index
	get_parent().add_child(body)
	body.global_transform = sprite.global_transform
	body.modulate = sprite.modulate
	var tint := death_color
	tint.a = 0.0
	var big := 1.6 if is_boss else 1.25
	var tw := body.create_tween()
	tw.tween_property(body, "scale", body.scale * Vector2(big, 0.35), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(body, "modulate", tint, 0.5 if not is_boss else 1.2)
	tw.tween_callback(body.queue_free)
