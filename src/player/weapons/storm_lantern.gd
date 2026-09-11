class_name StormLantern
extends Weapon
## Maren's lantern, rehung on a chain. Light for a weapon.
##   LMB tap/hold  wide, quick arcs of light. Low damage, but everything they touch is
##                 LIT (takes more damage from anything) and every hit charges the flare fast.
##   dash + LMB    LUNGE: a lash of light out of the dash.
##   RMB           BEACON: throw a pool of light to the cursor. Enemies inside are lit and
##                 slowed while it burns.

enum State { IDLE, SWING, LUNGE }

const ANTICIPATION := 0.05
const ACTIVE := 0.1
const RECOVERY := 0.12
const DAMAGE := 3
const KNOCKBACK := 45.0
const ARC := deg_to_rad(150.0)
const SWING_MOVE_MULT := 0.75
const LIT_TIME := 3.5
const GLOW_MULT := 1.6

const LUNGE_ANTICIPATION := 0.03
const LUNGE_ACTIVE := 0.1
const LUNGE_RECOVERY := 0.14
const LUNGE_DAMAGE := 4
const LUNGE_REACH := 24.0

const BEACON_RANGE := 5.0 * 16.0
const BEACON_RADIUS := 56.0
const BEACON_TIME := 4.0
const BEACON_COOLDOWN := 6.0
const BEACON_DAMAGE := 2
const BEACON_TEX := preload("res://assets/sprites/beacon.png")

var state: State = State.IDLE
var _phase_t: float = 0.0
var _buffered: bool = false
var _held: bool = false
var _swing_sign: float = 1.0
var _sweep_from: float = 0.0
var _sweep_to: float = 0.0
var _beacon_cd: float = 0.0
var _beacon_t: float = 0.0
var _beacon_tick: float = 0.0
var _player: Player
var _shape_home: Vector2
var _beacon_light: PointLight2D

@onready var pivot: Node2D = $Pivot
@onready var sprite: Sprite2D = $Pivot/Sprite
@onready var hitbox: Hitbox = $Pivot/Hitbox
@onready var hit_shape: CollisionShape2D = $Pivot/Hitbox/Shape
@onready var beacon: Sprite2D = $Beacon


func _ready() -> void:
	id = "lantern"
	_player = get_parent() as Player
	hitbox.source = _player
	hitbox.landed.connect(_on_hit_landed)
	_shape_home = hit_shape.position
	beacon.visible = false
	_beacon_light = Atmosphere.light(beacon, Color(1.0, 0.9, 0.6), 4.0, 1.4)
	_beacon_light.visible = false


func move_mult() -> float:
	match state:
		State.SWING: return SWING_MOVE_MULT
		State.LUNGE: return 0.3
		_: return 1.0


func is_busy() -> bool:
	return state != State.IDLE


func special_ready() -> bool:
	return _beacon_cd <= 0.0


func special_cooldown_fraction() -> float:
	return clampf(1.0 - _beacon_cd / BEACON_COOLDOWN, 0.0, 1.0)


func try_attack() -> void:
	match state:
		State.IDLE: _start_swing()
		State.SWING: _buffered = true
		_: pass


func set_held(held: bool) -> void:
	_held = held


func try_lunge() -> void:
	if state == State.IDLE or state == State.SWING:
		_start_lunge()


func try_special() -> void:
	if special_ready():
		_throw_beacon()


func cancel() -> void:
	if state != State.IDLE:
		hitbox.deactivate()
		hit_shape.position = _shape_home
		state = State.IDLE
		_buffered = false
		sprite.position = Vector2(2, 0)


func _process(delta: float) -> void:
	_beacon_cd = maxf(0.0, _beacon_cd - delta)
	_tick_beacon(delta)
	match state:
		State.IDLE:
			pivot.rotation = _player.aim.angle()
			sprite.flip_v = _player.aim.x < 0.0
			sprite.position = Vector2(2, 0)
			if _held:
				_start_swing()
		State.SWING:
			_tick_swing(delta)
		State.LUNGE:
			_tick_lunge(delta)


# --- arcs ----------------------------------------------------------------------------
func _start_swing() -> void:
	state = State.SWING
	_phase_t = 0.0
	_buffered = false
	_swing_sign = -_swing_sign
	var aim_angle := _player.aim.angle()
	hitbox.damage = DAMAGE
	hitbox.knockback = KNOCKBACK
	hitbox.pull = false
	hitbox.hitstop = 0.03
	hitbox.tags = PackedStringArray(["melee", "light"])
	hit_shape.position = _shape_home
	sprite.flip_v = _player.aim.x < 0.0
	_sweep_from = aim_angle - _swing_sign * ARC * 0.5
	_sweep_to = aim_angle + _swing_sign * ARC * 0.5
	pivot.rotation = _sweep_from


func _tick_swing(delta: float) -> void:
	_phase_t += delta
	var t0 := ANTICIPATION
	var t1 := t0 + ACTIVE
	var t_end := t1 + RECOVERY
	if _phase_t >= t0 and _phase_t < t1:
		if not hitbox.active:
			_arm_and_activate(false)
	elif hitbox.active:
		hitbox.deactivate()
	if _phase_t >= t_end:
		state = State.IDLE
		if _buffered or _held:
			_start_swing()


func _start_lunge() -> void:
	state = State.LUNGE
	_phase_t = 0.0
	_buffered = false
	hitbox.damage = LUNGE_DAMAGE
	hitbox.knockback = KNOCKBACK * 2.0
	hitbox.pull = false
	hitbox.hitstop = 0.05
	hitbox.tags = PackedStringArray(["melee", "light", "lunge"])
	hit_shape.position = Vector2(LUNGE_REACH, 0)
	pivot.rotation = _player.aim.angle()
	sprite.flip_v = _player.aim.x < 0.0
	var tw := create_tween()
	tw.tween_property(sprite, "position:x", 14.0, LUNGE_ANTICIPATION + LUNGE_ACTIVE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:x", 2.0, LUNGE_RECOVERY)
	_player.lunge(_player.aim)
	FX.burst(global_position, Color(1.0, 0.95, 0.8, 0.8), 6, 40.0)


func _tick_lunge(delta: float) -> void:
	_phase_t += delta
	if _phase_t >= LUNGE_ANTICIPATION and _phase_t < LUNGE_ANTICIPATION + LUNGE_ACTIVE:
		if not hitbox.active:
			_arm_and_activate(true)
	elif hitbox.active:
		hitbox.deactivate()
	if _phase_t >= LUNGE_ANTICIPATION + LUNGE_ACTIVE + LUNGE_RECOVERY:
		hit_shape.position = _shape_home
		state = State.IDLE


func _arm_and_activate(lunge: bool) -> void:
	var m: Dictionary = _player.mods
	var crit: bool = _player.consume_riptide() or randf() < float(m.crit_chance)
	hitbox.crit = crit
	hitbox.damage_mult = arm_mult(_player, false, lunge, crit)
	hitbox.activate()
	if lunge:
		return
	pivot.rotation = _sweep_from
	var tw := create_tween()
	tw.tween_property(pivot, "rotation", _sweep_to, ACTIVE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	FX.slash(global_position, (_sweep_from + _sweep_to) * 0.5, _swing_sign < 0.0, 1.25)
	Audio.play("lantern", 0.15, -3.0)


func _on_hit_landed(target: Hurtbox, info: DamageInfo) -> void:
	FX.spark(target.global_position)
	_player.add_glow(Player.GLOW_PER_HIT * GLOW_MULT)
	var crit := info.tags.has("crit")
	EventBus.request_shake.emit(0.15)
	EventBus.request_hitstop.emit(info.hitstop * (1.6 if crit else 1.0))
	var enemy := target.get_parent() as Enemy
	if enemy:
		enemy.lit(LIT_TIME)
	if crit:
		FX.text(target.global_position, "CRIT", Color(1.0, 0.95, 0.6))
		Audio.play("crit", 0.05)
	else:
		Audio.play("hit", 0.2, -5.0)


# --- beacon ----------------------------------------------------------------------------
func _throw_beacon() -> void:
	_beacon_cd = BEACON_COOLDOWN
	var origin := _player.global_position
	var dir := _player.aim
	var target := origin + dir * minf(BEACON_RANGE, _player.aim_distance())
	var ray := PhysicsRayQueryParameters2D.create(origin, target, 1)
	var wall := get_world_2d().direct_space_state.intersect_ray(ray)
	if wall:
		target = wall.position - dir * 8.0
	beacon.visible = true
	beacon.modulate = Color(1, 1, 1, 1)
	beacon.global_position = origin
	beacon.scale = Vector2(0.3, 0.3)
	_beacon_light.visible = true
	var fly := clampf(origin.distance_to(target) / 480.0, 0.06, 0.2)
	var tw := create_tween()
	tw.tween_property(beacon, "global_position", target, fly)
	tw.parallel().tween_property(beacon, "scale", Vector2(BEACON_RADIUS / 11.0, BEACON_RADIUS / 11.0), fly)
	tw.tween_callback(func():
		_beacon_t = BEACON_TIME
		FX.ring(target, Color(1.0, 0.9, 0.6), 2.0)
		Audio.play("beacon", 0.05)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Enemy and e.global_position.distance_to(target) <= BEACON_RADIUS:
				var info := DamageInfo.make(int(round(BEACON_DAMAGE * float(_player.mods.damage) * float(_player.mods.ranged_mult))), _player, e.global_position - target, 30.0)
				info.tags = PackedStringArray(["light", "beacon"])
				info.hitstop = 0.0
				if e.hurtbox.receive(info):
					EventBus.damage_dealt.emit(e, info)
	)
	Audio.play("dash", 0.2, -8.0)


func _tick_beacon(delta: float) -> void:
	if _beacon_t <= 0.0:
		return
	_beacon_t -= delta
	_beacon_tick += delta
	beacon.modulate.a = 0.6 + 0.4 * sin(_beacon_t * 9.0)
	if _beacon_tick >= 0.2:
		_beacon_tick = 0.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Enemy and e.global_position.distance_to(beacon.global_position) <= BEACON_RADIUS:
				e.lit(0.8)
				e.slow(0.3)
	if _beacon_t <= 0.0:
		var tw := create_tween()
		tw.tween_property(beacon, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func():
			beacon.visible = false
			_beacon_light.visible = false)
