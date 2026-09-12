class_name KeepersBell
extends Weapon
## A keeper's hand bell on a short haft, swung like a hammer. Slow, heavy, and it answers.
##   LMB tap       two-hit combo: a wide swing, then an overhead slam that sends a ring
##                 through the floor and stuns whatever it reaches.
##   dash + LMB    LUNGE: a shoulder-first charge out of the dash.
##   RMB           TOLL: ring the bell. For a moment nothing can hurt you, everything close
##                 staggers, and anything that strikes you while it rings is stunned for
##                 a long time (a parry). Time it on the flash.

enum State { IDLE, SWING, SLAM, LUNGE, TOLL }

const ANTICIPATION := [0.12, 0.18]
const ACTIVE := [0.1, 0.12]
const RECOVERY := [0.26, 0.4]
const DAMAGE := [7, 10]
const KNOCKBACK := [160.0, 200.0]
const SWING_ARC := deg_to_rad(140.0)
const SWING_MOVE_MULT := 0.4
const WAVE_RADIUS := 36.0
const WAVE_STUN := 0.6

const LUNGE_ANTICIPATION := 0.03
const LUNGE_ACTIVE := 0.1
const LUNGE_RECOVERY := 0.16
const LUNGE_DAMAGE := 6
const LUNGE_KNOCKBACK := 140.0
const LUNGE_REACH := 22.0

const PARRY_WINDOW := 0.35
const PARRY_STUN := 2.0
const TOLL_RADIUS := 60.0
const TOLL_STUN := 0.8
const TOLL_COOLDOWN := 4.0
const TOLL_HEAL := 4

var state: State = State.IDLE
var combo := ComboTracker.new(2, 0.7)

var _step: int = 0
var _phase_t: float = 0.0
var _buffered: bool = false
var _swing_sign: float = 1.0
var _sweep_from: float = 0.0
var _sweep_to: float = 0.0
var _toll_cd: float = 0.0
var _parry_window: float = PARRY_WINDOW
var _parry_stun: float = PARRY_STUN
var _wave_radius: float = WAVE_RADIUS
var _slam_bonus: int = 0
var _player: Player
var _shape_home: Vector2
var _shape_radius: float = 14.0

@onready var pivot: Node2D = $Pivot
@onready var sprite: Sprite2D = $Pivot/Sprite
@onready var hitbox: Hitbox = $Pivot/Hitbox
@onready var hit_shape: CollisionShape2D = $Pivot/Hitbox/Shape


func _ready() -> void:
	id = "bell"
	_player = get_parent() as Player
	hitbox.source = _player
	hitbox.landed.connect(_on_hit_landed)
	_shape_home = hit_shape.position
	_shape_radius = hit_shape.shape.radius
	_load_aspect()
	match aspect:
		"bell_keeper":
			_parry_window = 0.55
			_parry_stun = 3.0
		"bell_sunken":
			_wave_radius = 52.0
			_slam_bonus = 3
	if _player and _player.hurtbox:
		_player.hurtbox.dodged.connect(_on_player_dodged)


func move_mult() -> float:
	match state:
		State.SWING: return SWING_MOVE_MULT
		State.SLAM: return 0.2
		State.LUNGE: return 0.3
		State.TOLL: return 0.5
		_: return 1.0


func is_busy() -> bool:
	return state != State.IDLE


func special_ready() -> bool:
	return _toll_cd <= 0.0 and state != State.TOLL


func special_cooldown_fraction() -> float:
	return clampf(1.0 - _toll_cd / TOLL_COOLDOWN, 0.0, 1.0)


func try_attack() -> void:
	match state:
		State.IDLE: _start_swing()
		State.SWING, State.SLAM: _buffered = true
		_: pass


func try_lunge() -> void:
	if state == State.IDLE or state == State.SWING:
		_start_lunge()


func try_special() -> void:
	if special_ready():
		_start_toll()


func cancel() -> void:
	if state in [State.SWING, State.SLAM, State.LUNGE]:
		hitbox.deactivate()
		hit_shape.position = _shape_home
		hit_shape.shape.radius = _shape_radius
		state = State.IDLE
		_buffered = false
		sprite.position = Vector2(2, 0)


func _process(delta: float) -> void:
	_toll_cd = maxf(0.0, _toll_cd - delta)
	match state:
		State.IDLE:
			pivot.rotation = _player.aim.angle()
			sprite.flip_v = _player.aim.x < 0.0
			sprite.position = Vector2(2, 0)
		State.SWING, State.SLAM:
			_tick_swing(delta)
		State.LUNGE:
			_tick_lunge(delta)
		State.TOLL:
			pivot.rotation = _player.aim.angle()
			_phase_t += delta
			sprite.position = Vector2(2, -2.0 * sin(_phase_t * 40.0))
			if _phase_t >= _parry_window:
				_end_toll()


# --- swing and slam --------------------------------------------------------------------
func _start_swing() -> void:
	_step = combo.next_step(Time.get_ticks_msec() / 1000.0)
	var i := _step - 1
	var slam := combo.is_finisher(_step)
	state = State.SLAM if slam else State.SWING
	_phase_t = 0.0
	_buffered = false
	_swing_sign = -_swing_sign
	var aim_angle := _player.aim.angle()
	hitbox.damage = DAMAGE[i] + (_slam_bonus if slam else 0)
	hitbox.knockback = KNOCKBACK[i]
	hitbox.pull = false
	hitbox.hitstop = 0.08 if not slam else 0.14
	hitbox.tags = PackedStringArray(["melee", "heavy", "finisher", "slam"] if slam else ["melee", "bell"])
	sprite.flip_v = _player.aim.x < 0.0
	if slam:
		hit_shape.position = Vector2(16, 0)
		hit_shape.shape.radius = _wave_radius * 0.75
		pivot.rotation = aim_angle
	else:
		hit_shape.position = _shape_home
		hit_shape.shape.radius = _shape_radius
		_sweep_from = aim_angle - _swing_sign * SWING_ARC * 0.5
		_sweep_to = aim_angle + _swing_sign * SWING_ARC * 0.5
		pivot.rotation = _sweep_from


func _tick_swing(delta: float) -> void:
	var i := _step - 1
	_phase_t += delta
	var t0: float = ANTICIPATION[i]
	var t1: float = t0 + ACTIVE[i]
	var t_end: float = t1 + RECOVERY[i]
	if state == State.SLAM and _phase_t < t0:
		# Wind up: the bell rises over the shoulder.
		sprite.position = Vector2(2, -6.0 * (_phase_t / t0))
	if _phase_t >= t0 and _phase_t < t1:
		if not hitbox.active:
			_arm_and_activate()
	elif hitbox.active:
		hitbox.deactivate()
	if _phase_t >= t_end:
		state = State.IDLE
		hit_shape.position = _shape_home
		hit_shape.shape.radius = _shape_radius
		sprite.position = Vector2(2, 0)
		if _buffered:
			_buffered = false
			_start_swing()


func _arm_and_activate() -> void:
	var m: Dictionary = _player.mods
	var crit: bool = _player.consume_riptide() or randf() < float(m.crit_chance)
	hitbox.crit = crit
	hitbox.damage_mult = arm_mult(_player, state == State.SLAM, state == State.LUNGE, crit)
	hitbox.activate()
	if state == State.LUNGE:
		return
	if state == State.SLAM:
		sprite.position = Vector2(6, 2)
		var at := _player.global_position + _player.aim * 16.0
		FX.ring(at, Color(0.95, 0.9, 0.75), _wave_radius / 24.0)
		FX.burst(at, Color(0.8, 0.75, 0.6), 12, 70.0)
		EventBus.request_shake.emit(0.55)
		Audio.play("heavy", 0.1, 1.0)
		Audio.play("bell", 0.0, -12.0)
		return
	pivot.rotation = _sweep_from
	var tw := create_tween()
	tw.tween_property(pivot, "rotation", _sweep_to, ACTIVE[0]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	FX.slash(global_position, (_sweep_from + _sweep_to) * 0.5, _swing_sign < 0.0, 1.3)
	Audio.play("swing", 0.15, 2.0)


# --- lunge -----------------------------------------------------------------------------
func _start_lunge() -> void:
	state = State.LUNGE
	_phase_t = 0.0
	_buffered = false
	hitbox.damage = LUNGE_DAMAGE
	hitbox.knockback = LUNGE_KNOCKBACK
	hitbox.pull = false
	hitbox.hitstop = 0.07
	hitbox.tags = PackedStringArray(["melee", "bell", "lunge"])
	hit_shape.position = Vector2(LUNGE_REACH, 0)
	hit_shape.shape.radius = _shape_radius
	pivot.rotation = _player.aim.angle()
	sprite.flip_v = _player.aim.x < 0.0
	sprite.position = Vector2(2, 0)
	_player.lunge(_player.aim, 240.0)
	FX.burst(global_position, Color(0.9, 0.9, 1.0, 0.8), 5, 40.0)


func _tick_lunge(delta: float) -> void:
	_phase_t += delta
	if _phase_t >= LUNGE_ANTICIPATION and _phase_t < LUNGE_ANTICIPATION + LUNGE_ACTIVE:
		if not hitbox.active:
			_arm_and_activate()
	elif hitbox.active:
		hitbox.deactivate()
	if _phase_t >= LUNGE_ANTICIPATION + LUNGE_ACTIVE + LUNGE_RECOVERY:
		hit_shape.position = _shape_home
		state = State.IDLE


func _on_hit_landed(target: Hurtbox, info: DamageInfo) -> void:
	FX.spark(target.global_position)
	_player.add_glow(Player.GLOW_PER_HIT * 1.2)
	var slam := info.tags.has("slam")
	var crit := info.tags.has("crit")
	EventBus.request_shake.emit(0.5 if slam else 0.3)
	EventBus.request_hitstop.emit(info.hitstop * (1.6 if crit else 1.0))
	var enemy := target.get_parent() as Enemy
	if enemy and slam and not enemy.is_boss:
		enemy.stunned = maxf(enemy.stunned, WAVE_STUN)
	if crit:
		FX.text(target.global_position, "CRIT", Color(1.0, 0.95, 0.6))
		Audio.play("crit", 0.05)
	else:
		Audio.play("hit", 0.15, 1.0 if slam else -1.0)


# --- toll: the parry ------------------------------------------------------------------
func _start_toll() -> void:
	state = State.TOLL
	_phase_t = 0.0
	_toll_cd = TOLL_COOLDOWN
	_player.parry_t = _parry_window
	FX.ring(_player.global_position, Color(0.95, 0.9, 0.7), TOLL_RADIUS / 24.0)
	FX.burst(_player.global_position, Color(0.95, 0.9, 0.7), 10, 60.0)
	Audio.play("bell", 0.0, -4.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.is_boss and e.global_position.distance_to(_player.global_position) <= TOLL_RADIUS:
			e.stunned = maxf(e.stunned, TOLL_STUN)


func _end_toll() -> void:
	if state != State.TOLL:
		return
	state = State.IDLE
	sprite.position = Vector2(2, 0)


## Something struck while the bell rang: it is stunned long, and the ring feeds you.
func _on_player_dodged(info: DamageInfo) -> void:
	if state != State.TOLL:
		return
	var enemy := info.source as Enemy
	if enemy and is_instance_valid(enemy):
		enemy.stunned = maxf(enemy.stunned, _parry_stun)
		if enemy.hitbox and enemy.hitbox.active:
			enemy.hitbox.deactivate()
		FX.text(enemy.global_position + Vector2(0, -16), "PARRIED", Color(1.0, 0.95, 0.7))
		FX.ring(enemy.global_position, Color(1.0, 0.95, 0.7), 0.9)
	_player.health.heal(TOLL_HEAL)
	_player.add_glow(Player.GLOW_PER_HIT * 2.0)
	EventBus.request_hitstop.emit(0.12)
	EventBus.request_shake.emit(0.4)
	Audio.play("crit", 0.0, 2.0)
