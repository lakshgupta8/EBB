class_name NetKnife
extends Weapon
## Bram's first gift. Close and cruel.
##   LMB tap/hold  four fast stabs; the fourth is a deep cut that makes enemies bleed.
##                 Holding keeps stabbing. You stay mobile while you work.
##   dash + LMB    LUNGE: a fast forward stab out of the dash.
##   RMB           throw a net toward the cursor. Everything under it is rooted for a
##                 moment and takes extra damage while held. Bosses only stumble.

enum State { IDLE, STAB, LUNGE, THROW }

const ANTICIPATION := [0.03, 0.03, 0.03, 0.06]
const ACTIVE := [0.06, 0.06, 0.06, 0.08]
const RECOVERY := [0.08, 0.08, 0.08, 0.24]
const DAMAGE := [2, 2, 2, 4]
const KNOCKBACK := [25.0, 25.0, 25.0, 110.0]
const STAB_MOVE_MULT := 0.7
const STAB_REACH := 13.0
const FINISHER_REACH := 17.0

const LUNGE_ANTICIPATION := 0.03
const LUNGE_ACTIVE := 0.1
const LUNGE_RECOVERY := 0.14
const LUNGE_DAMAGE := 4
const LUNGE_KNOCKBACK := 90.0
const LUNGE_REACH := 24.0

const NET_RANGE := 4.5 * 16.0
const NET_RADIUS := 34.0
const NET_COOLDOWN := 4.5
const NET_MISS_COOLDOWN := 2.0
const NET_HOLD := 2.2
const NET_HOLD_BOSS := 0.9
const NET_DAMAGE := 2
const NET_TEX := preload("res://assets/sprites/net.png")

var state: State = State.IDLE
var combo := ComboTracker.new(4, 0.5)

var _step: int = 0
var _phase_t: float = 0.0
var _buffered: bool = false
var _held: bool = false
var _net_cd: float = 0.0
var _net_cd_total: float = NET_COOLDOWN
var _player: Player
var _shape_home: Vector2
var _stab_side: float = 1.0

@onready var pivot: Node2D = $Pivot
@onready var sprite: Sprite2D = $Pivot/Sprite
@onready var hitbox: Hitbox = $Pivot/Hitbox
@onready var hit_shape: CollisionShape2D = $Pivot/Hitbox/Shape
@onready var net_sprite: Sprite2D = $Net


func _ready() -> void:
	id = "net"
	_player = get_parent() as Player
	hitbox.source = _player
	hitbox.landed.connect(_on_hit_landed)
	_shape_home = hit_shape.position
	net_sprite.visible = false


func move_mult() -> float:
	match state:
		State.STAB: return STAB_MOVE_MULT
		State.LUNGE: return 0.3
		_: return 1.0


func is_busy() -> bool:
	return state != State.IDLE


func special_ready() -> bool:
	return _net_cd <= 0.0 and state != State.THROW


func special_cooldown_fraction() -> float:
	return clampf(1.0 - _net_cd / _net_cd_total, 0.0, 1.0)


func try_attack() -> void:
	match state:
		State.IDLE: _start_stab()
		State.STAB: _buffered = true
		_: pass


func set_held(held: bool) -> void:
	_held = held


func try_lunge() -> void:
	if state == State.IDLE or state == State.STAB:
		_start_lunge()


func try_special() -> void:
	if special_ready():
		_start_throw()


func cancel() -> void:
	if state in [State.STAB, State.LUNGE]:
		hitbox.deactivate()
		hit_shape.position = _shape_home
		state = State.IDLE
		_buffered = false
		sprite.position = Vector2(2, 0)


func _process(delta: float) -> void:
	_net_cd = maxf(0.0, _net_cd - delta)
	match state:
		State.IDLE:
			pivot.rotation = _player.aim.angle()
			sprite.flip_v = _player.aim.x < 0.0
			sprite.position = Vector2(2, 0)
			if _held:
				_start_stab()
		State.STAB:
			_tick_stab(delta)
		State.LUNGE:
			_tick_lunge(delta)
		State.THROW:
			pivot.rotation = _player.aim.angle()


# --- stabs ---------------------------------------------------------------------------
func _start_stab() -> void:
	_step = combo.next_step(Time.get_ticks_msec() / 1000.0)
	var i := _step - 1
	state = State.STAB
	_phase_t = 0.0
	_buffered = false
	_stab_side = -_stab_side
	var finisher := combo.is_finisher(_step)
	hitbox.damage = DAMAGE[i]
	hitbox.knockback = KNOCKBACK[i]
	hitbox.pull = false
	hitbox.hitstop = 0.03 if not finisher else 0.08
	hitbox.tags = PackedStringArray(["melee", "knife", "finisher"] if finisher else ["melee", "knife"])
	hit_shape.position = Vector2(FINISHER_REACH if finisher else STAB_REACH, 0)
	hit_shape.shape.radius = 12.0 if finisher else 9.0
	pivot.rotation = _player.aim.angle() + (0.0 if finisher else _stab_side * 0.18)
	sprite.flip_v = _player.aim.x < 0.0
	sprite.position = Vector2(2, 0)
	var reach := 14.0 if finisher else 10.0
	var tw := create_tween()
	tw.tween_property(sprite, "position:x", reach, ANTICIPATION[i] + ACTIVE[i]).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:x", 2.0, RECOVERY[i])


func _tick_stab(delta: float) -> void:
	var i := _step - 1
	_phase_t += delta
	var t0: float = ANTICIPATION[i]
	var t1: float = t0 + ACTIVE[i]
	var t_end: float = t1 + RECOVERY[i]
	if _phase_t >= t0 and _phase_t < t1:
		if not hitbox.active:
			_arm_and_activate(false)
	elif hitbox.active:
		hitbox.deactivate()
	var finisher := combo.is_finisher(_step)
	# Quick stabs chain the moment they land; the finisher needs its recovery.
	if not finisher and _phase_t >= t1 and (_buffered or _held):
		_start_stab()
		return
	if _phase_t >= t_end:
		state = State.IDLE
		hit_shape.position = _shape_home
		hit_shape.shape.radius = 9.0
		if _buffered or _held:
			_start_stab()


# --- lunge ---------------------------------------------------------------------------
func _start_lunge() -> void:
	state = State.LUNGE
	_phase_t = 0.0
	_buffered = false
	hitbox.damage = LUNGE_DAMAGE
	hitbox.knockback = LUNGE_KNOCKBACK
	hitbox.pull = false
	hitbox.hitstop = 0.06
	hitbox.tags = PackedStringArray(["melee", "knife", "lunge"])
	hit_shape.position = Vector2(LUNGE_REACH, 0)
	hit_shape.shape.radius = 10.0
	pivot.rotation = _player.aim.angle()
	sprite.flip_v = _player.aim.x < 0.0
	sprite.position = Vector2(2, 0)
	var tw := create_tween()
	tw.tween_property(sprite, "position:x", 16.0, LUNGE_ANTICIPATION + LUNGE_ACTIVE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:x", 2.0, LUNGE_RECOVERY)
	_player.lunge(_player.aim)
	FX.burst(global_position, Color(0.9, 0.9, 1.0, 0.8), 5, 40.0)


func _tick_lunge(delta: float) -> void:
	_phase_t += delta
	if _phase_t >= LUNGE_ANTICIPATION and _phase_t < LUNGE_ANTICIPATION + LUNGE_ACTIVE:
		if not hitbox.active:
			_arm_and_activate(true)
	elif hitbox.active:
		hitbox.deactivate()
	if _phase_t >= LUNGE_ANTICIPATION + LUNGE_ACTIVE + LUNGE_RECOVERY:
		hit_shape.position = _shape_home
		hit_shape.shape.radius = 9.0
		state = State.IDLE


func _arm_and_activate(lunge: bool) -> void:
	var m: Dictionary = _player.mods
	var crit: bool = _player.consume_riptide() or randf() < float(m.crit_chance)
	hitbox.crit = crit
	hitbox.damage_mult = arm_mult(_player, false, lunge, crit)
	hitbox.activate()
	Audio.play("stab", 0.2, -2.0)


func _on_hit_landed(target: Hurtbox, info: DamageInfo) -> void:
	FX.spark(target.global_position)
	_player.add_glow(Player.GLOW_PER_HIT * 0.7)
	var crit := info.tags.has("crit")
	var finisher := info.tags.has("finisher")
	EventBus.request_shake.emit(0.32 if finisher else 0.12)
	EventBus.request_hitstop.emit(info.hitstop * (1.6 if crit else 1.0))
	var enemy := target.get_parent() as Enemy
	if crit:
		FX.text(target.global_position, "CRIT", Color(1.0, 0.95, 0.6))
		FX.ring(target.global_position, Color(1.0, 0.95, 0.7), 0.8)
		Audio.play("crit", 0.05)
	else:
		Audio.play("hit", 0.2, -4.0 if not finisher else 0.0)
	if enemy and finisher:
		enemy.apply_bleed(4 if _player.mods.bleed else 2)
		FX.text(target.global_position, "BLEED", Color(0.95, 0.4, 0.4))


# --- net -----------------------------------------------------------------------------
func _start_throw() -> void:
	state = State.THROW
	var origin := _player.global_position
	var dir := _player.aim
	var dist := minf(NET_RANGE, _player.aim_distance())
	var target := origin + dir * dist
	var ray := PhysicsRayQueryParameters2D.create(origin, target, 1)
	var wall := get_world_2d().direct_space_state.intersect_ray(ray)
	if wall:
		target = wall.position - dir * 6.0
	Audio.play("net", 0.1)
	net_sprite.visible = true
	net_sprite.modulate = Color(1, 1, 1, 1)
	net_sprite.global_position = origin
	net_sprite.scale = Vector2(0.4, 0.4)
	net_sprite.rotation = randf() * TAU
	var fly := clampf(origin.distance_to(target) / 520.0, 0.06, 0.18)
	var tw := create_tween()
	tw.tween_property(net_sprite, "global_position", target, fly)
	tw.parallel().tween_property(net_sprite, "scale", Vector2(1, 1), fly)
	tw.tween_callback(_land_net.bind(target))
	tw.tween_interval(NET_HOLD)
	tw.tween_property(net_sprite, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): net_sprite.visible = false)


func _land_net(at: Vector2) -> void:
	state = State.IDLE
	var caught := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.global_position.distance_to(at) > NET_RADIUS:
			continue
		var info := DamageInfo.make(int(round(NET_DAMAGE * float(_player.mods.damage))), _player, e.global_position - at, 0.0)
		info.tags = PackedStringArray(["net"])
		info.hitstop = 0.0
		if e.hurtbox.receive(info):
			EventBus.damage_dealt.emit(e, info)
		e.net(NET_HOLD_BOSS if e.is_boss else NET_HOLD)
		caught += 1
	_net_cd_total = NET_COOLDOWN if caught > 0 else NET_MISS_COOLDOWN
	_net_cd = _net_cd_total
	FX.burst(at, Color(0.85, 0.75, 0.55, 0.9), 8, 45.0)
	if caught > 0:
		FX.text(at + Vector2(0, -14), "NETTED" if caught == 1 else "NETTED x%d" % caught, Color(0.95, 0.85, 0.6))
		EventBus.request_hitstop.emit(0.04)
		_player.add_glow(Player.GLOW_PER_HIT * 0.5 * caught)
