class_name GaffHook
extends Node2D
## Starting weapon. LMB: 3-hit swing combo aimed at the mouse; the third hit pulls
## enemies in. RMB: throw the hook and yank yourself to whatever it catches.

const FLASH_SHADER := preload("res://src/combat/hit_flash.gdshader")

enum State { IDLE, SWING, THROW }

# Per-step timing (seconds) and stats. Index 0 = step 1.
const ANTICIPATION := [0.05, 0.05, 0.09]
const ACTIVE := [0.08, 0.08, 0.10]
const RECOVERY := [0.16, 0.16, 0.28]
const CHAIN_AT := [0.06, 0.06, 0.20]  # into recovery, when the next swing may start
const DAMAGE := [3, 3, 5]
const KNOCKBACK := [70.0, 70.0, 140.0]
const SWING_ARC := deg_to_rad(120.0)
const SWING_MOVE_MULT := 0.45

const THROW_RANGE := 5.0 * 16.0
const THROW_COOLDOWN := 2.5
const THROW_DAMAGE := 2

var state: State = State.IDLE
var combo := ComboTracker.new(3, 0.55)

var _step: int = 0
var _phase_t: float = 0.0
var _buffered: bool = false
var _swing_sign: float = 1.0
var _throw_cd: float = 0.0
var _player: Player

@onready var pivot: Node2D = $Pivot
@onready var sprite: Sprite2D = $Pivot/Sprite
@onready var hitbox: Hitbox = $Pivot/Hitbox


func _ready() -> void:
	_player = get_parent() as Player
	hitbox.source = _player
	hitbox.landed.connect(_on_hit_landed)


func move_mult() -> float:
	return SWING_MOVE_MULT if state == State.SWING else 1.0


func is_busy() -> bool:
	return state != State.IDLE


func special_ready() -> bool:
	return _throw_cd <= 0.0 and state == State.IDLE


func special_cooldown_fraction() -> float:
	return clampf(1.0 - _throw_cd / THROW_COOLDOWN, 0.0, 1.0)


## Called by the player on attack press.
func try_attack() -> void:
	match state:
		State.IDLE:
			_start_swing()
		State.SWING:
			_buffered = true
		State.THROW:
			pass


func try_special() -> void:
	if not special_ready():
		return
	_start_throw()


## Dash cancels everything.
func cancel() -> void:
	if state == State.SWING:
		hitbox.deactivate()
		state = State.IDLE
		_buffered = false


func _process(delta: float) -> void:
	_throw_cd = maxf(0.0, _throw_cd - delta)
	if state == State.IDLE:
		pivot.rotation = _player.aim.angle()
		sprite.flip_v = _player.aim.x < 0.0
		sprite.position = Vector2(2, 0)
	elif state == State.SWING:
		_tick_swing(delta)


# --- swing ------------------------------------------------------------------------
func _start_swing() -> void:
	_step = combo.next_step(Time.get_ticks_msec() / 1000.0)
	var i := _step - 1
	state = State.SWING
	_phase_t = 0.0
	_buffered = false
	_swing_sign = -_swing_sign if _step != 3 else 1.0
	var aim_angle := _player.aim.angle()
	hitbox.damage = DAMAGE[i]
	hitbox.knockback = KNOCKBACK[i]
	hitbox.pull = combo.is_finisher(_step)
	hitbox.hitstop = 0.05 if not hitbox.pull else 0.09
	hitbox.tags = PackedStringArray(["melee", "third_hit"] if hitbox.pull else ["melee"])
	sprite.flip_v = _player.aim.x < 0.0
	# Weapon sweeps across the arc over anticipation+active; hitbox aligns with aim.
	var from := aim_angle - _swing_sign * SWING_ARC * 0.5
	var to := aim_angle + _swing_sign * SWING_ARC * 0.5
	pivot.rotation = from
	var tw := create_tween()
	tw.tween_property(pivot, "rotation", to, ANTICIPATION[i] + ACTIVE[i]).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Visual: slash arc at the active window.
	get_tree().create_timer(ANTICIPATION[i]).timeout.connect(func():
		if state == State.SWING and _step == i + 1:
			var scale_mult := 1.35 if hitbox.pull else 1.0
			FX.slash(_player.global_position + _player.aim * 6.0, aim_angle, _swing_sign < 0.0, scale_mult)
	)


func _tick_swing(delta: float) -> void:
	var i := _step - 1
	_phase_t += delta
	var t_active_start: float = ANTICIPATION[i]
	var t_active_end: float = t_active_start + ACTIVE[i]
	var t_end: float = t_active_end + RECOVERY[i]
	if _phase_t >= t_active_start and _phase_t < t_active_end:
		if not hitbox.active:
			hitbox.activate()
	elif hitbox.active:
		hitbox.deactivate()
	if _phase_t >= t_active_end + CHAIN_AT[i] and _buffered and not combo.is_finisher(_step):
		_start_swing()
		return
	if _phase_t >= t_end:
		state = State.IDLE
		if _buffered:
			_buffered = false
			_start_swing()


func _on_hit_landed(target: Hurtbox, info: DamageInfo) -> void:
	FX.spark(target.global_position)
	EventBus.request_shake.emit(0.35 if info.tags.has("third_hit") else 0.18)
	EventBus.request_hitstop.emit(info.hitstop)


# --- throw ------------------------------------------------------------------------
func _start_throw() -> void:
	state = State.THROW
	_throw_cd = THROW_COOLDOWN
	var origin := _player.global_position
	var dir := _player.aim
	var space := get_world_2d().direct_space_state

	# Nearest thing along the aim line: walls (layer 1) or enemy hurtboxes (layer 8).
	var end := origin + dir * THROW_RANGE
	var target_point := end
	var target_hb: Hurtbox = null

	var ray := PhysicsRayQueryParameters2D.create(origin, end, 1)
	var wall := space.intersect_ray(ray)
	if wall:
		target_point = wall.position

	var seg := SegmentShape2D.new()
	seg.a = origin
	seg.b = target_point
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = seg
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = 1 << 7  # enemy_hurtbox
	var best := INF
	for r in space.intersect_shape(q, 8):
		var hb := r.collider as Hurtbox
		if hb == null:
			continue
		var d := origin.distance_to(hb.global_position)
		if d < best:
			best = d
			target_hb = hb
	if target_hb:
		target_point = target_hb.global_position

	# Fly the hook out, then yank.
	pivot.rotation = dir.angle()
	sprite.flip_v = dir.x < 0.0
	var dist := origin.distance_to(target_point)
	var fly_time := clampf(dist / 640.0, 0.04, 0.15)
	var tw := create_tween()
	tw.tween_property(sprite, "position", Vector2(dist - 6.0, 0), fly_time)
	tw.tween_callback(func():
		if target_hb and is_instance_valid(target_hb):
			var info := DamageInfo.make(THROW_DAMAGE, _player, target_hb.global_position - origin, 0.0)
			info.tags = PackedStringArray(["hook"])
			if target_hb.receive(info):
				FX.spark(target_hb.global_position)
				EventBus.request_hitstop.emit(0.04)
		var stop := target_point - dir * 12.0 if (target_hb or wall) else target_point
		_player.yank_to(stop, 0.12)
	)
	tw.tween_property(sprite, "position", Vector2(2, 0), 0.12)
	tw.tween_callback(func(): state = State.IDLE)
