class_name GaffHook
extends Weapon
## Starting weapon.
##   LMB tap      3-hit aimed combo; the third hit pulls enemies in.
##   LMB hold     keep holding through a swing to wind the hook back and CHARGE. Once the
##                hook rings (charge full), release for a heavy sweep that cracks shells
##                (double damage for a few seconds). Let go before it rings: nothing at all,
##                no swing, no damage.
##   dash + LMB   LUNGE: a fast forward thrust out of the dash.
##   RMB          throw the hook. Light enemies are dragged to you; heavy ones drag you
##                to them. A miss just returns, on a short cooldown.
## Hits crit when riptide is armed (or by luck with the right tidemark).

enum State { IDLE, SWING, CHARGING, HEAVY, LUNGE, THROW }

# Light combo. Index 0 = step 1.
const ANTICIPATION := [0.05, 0.05, 0.09]
const ACTIVE := [0.08, 0.08, 0.10]
const RECOVERY := [0.16, 0.16, 0.28]
const CHAIN_AT := [0.06, 0.06, 0.20]
const DAMAGE := [3, 3, 5]
const KNOCKBACK := [70.0, 70.0, 140.0]
const SWING_ARC := deg_to_rad(120.0)
const SWING_MOVE_MULT := 0.45

# Heavy.
const HOLD_TIME := 0.3          # holding from idle this long starts a charge
const CHARGE_FULL := 0.8        # the charge completes here; release before it: nothing
const CHARGE_MAX := 1.6         # auto-release
const HEAVY_ANTICIPATION := 0.1
const HEAVY_ACTIVE := 0.12
const HEAVY_RECOVERY := 0.34
const HEAVY_DAMAGE := 13
const HEAVY_KNOCKBACK := 240.0
const HEAVY_ARC := deg_to_rad(210.0)
const CHARGE_MOVE_MULT := 0.55

# Lunge.
const LUNGE_ANTICIPATION := 0.03
const LUNGE_ACTIVE := 0.1
const LUNGE_RECOVERY := 0.14
const LUNGE_DAMAGE := 4
const LUNGE_KNOCKBACK := 100.0
const LUNGE_REACH := 26.0

# Hook throw.
const THROW_RANGE := 5.0 * 16.0
const THROW_COOLDOWN := 2.2
const THROW_MISS_COOLDOWN := 0.9
const THROW_DAMAGE := 3

var state: State = State.IDLE
var combo := ComboTracker.new(3, 0.55)

var _step: int = 0
var _phase_t: float = 0.0
var _buffered: bool = false
var _swing_sign: float = 1.0
var _throw_cd: float = 0.0
var _throw_cd_total: float = THROW_COOLDOWN
var _held: bool = false
var _held_t: float = 0.0
var _charge_t: float = 0.0
var _charge_full: float = CHARGE_FULL
var _player: Player
var _shape_home: Vector2
# The sweep happens during the ACTIVE window so the hitbox covers the whole arc.
var _sweep_from: float = 0.0
var _sweep_to: float = 0.0
var _sweep_time: float = 0.1
var _sweep_fx_scale: float = 1.0
var _sweep_double: bool = false

@onready var pivot: Node2D = $Pivot
@onready var sprite: Sprite2D = $Pivot/Sprite
@onready var hitbox: Hitbox = $Pivot/Hitbox
@onready var hit_shape: CollisionShape2D = $Pivot/Hitbox/Shape


func _ready() -> void:
	id = "gaff"
	_player = get_parent() as Player
	hitbox.source = _player
	hitbox.landed.connect(_on_hit_landed)
	_shape_home = hit_shape.position
	_load_aspect()
	if aspect == "gaff_maren":
		_charge_full = CHARGE_FULL * 0.6


func move_mult() -> float:
	match state:
		State.SWING: return SWING_MOVE_MULT
		State.CHARGING: return CHARGE_MOVE_MULT
		State.HEAVY: return 0.15
		State.LUNGE: return 0.3
		_: return 1.0


func is_busy() -> bool:
	return state != State.IDLE


func special_ready() -> bool:
	return _throw_cd <= 0.0 and state == State.IDLE


func special_cooldown_fraction() -> float:
	return clampf(1.0 - _throw_cd / _throw_cd_total, 0.0, 1.0)


func charge_fraction() -> float:
	return clampf(_charge_t / _charge_full, 0.0, 1.0) if state == State.CHARGING else 0.0


func is_charging() -> bool:
	return state == State.CHARGING


func charge_complete() -> bool:
	return state == State.CHARGING and _charge_t >= _charge_full


## Called by the player on attack press.
func try_attack() -> void:
	match state:
		State.IDLE:
			_start_swing()
		State.SWING:
			_buffered = true
		_:
			pass


## Called by the player every frame with the attack button state.
func set_held(held: bool) -> void:
	if held and not _held:
		_held_t = 0.0
	if not held and _held and state == State.CHARGING:
		if charge_complete():
			_start_heavy()
		else:
			_stop_charging()
	_held = held


func try_lunge() -> void:
	if state == State.IDLE or state == State.SWING:
		_start_lunge()


func try_special() -> void:
	if not special_ready():
		return
	_start_throw()


## Dash cancels everything.
func cancel() -> void:
	if state in [State.SWING, State.CHARGING, State.HEAVY, State.LUNGE]:
		hitbox.deactivate()
		hit_shape.position = _shape_home
		hit_shape.shape.radius = 16.0
		state = State.IDLE
		_buffered = false
		_charge_t = 0.0
		sprite.modulate = Color.WHITE
		sprite.position = Vector2(2, 0)


func _process(delta: float) -> void:
	_throw_cd = maxf(0.0, _throw_cd - delta)
	match state:
		State.IDLE:
			pivot.rotation = _player.aim.angle()
			sprite.flip_v = _player.aim.x < 0.0
			sprite.position = Vector2(2, 0)
			if _held:
				_held_t += delta
				if _held_t >= HOLD_TIME:
					_start_charging()
		State.SWING:
			_tick_swing(delta)
		State.CHARGING:
			_tick_charging(delta)
		State.HEAVY:
			_tick_timed(delta, HEAVY_ANTICIPATION, HEAVY_ACTIVE, HEAVY_RECOVERY)
		State.LUNGE:
			_tick_timed(delta, LUNGE_ANTICIPATION, LUNGE_ACTIVE, LUNGE_RECOVERY)


# --- light combo -------------------------------------------------------------------
func _start_swing() -> void:
	_step = combo.next_step(Time.get_ticks_msec() / 1000.0)
	var i := _step - 1
	state = State.SWING
	_phase_t = 0.0
	_buffered = false
	_swing_sign = -_swing_sign if _step != 3 else 1.0
	var aim_angle := _player.aim.angle()
	hitbox.damage = DAMAGE[i] + (2 if aspect == "gaff_drowned" and combo.is_finisher(_step) else 0)
	hitbox.knockback = KNOCKBACK[i]
	hitbox.pull = combo.is_finisher(_step)
	hitbox.hitstop = 0.05 if not hitbox.pull else 0.09
	hitbox.tags = PackedStringArray(["melee", "third_hit", "finisher"] if hitbox.pull else ["melee"])
	hit_shape.position = _shape_home
	sprite.flip_v = _player.aim.x < 0.0
	# Anticipation: hook held at the start of the arc. Active: sweep across it.
	_sweep_from = aim_angle - _swing_sign * SWING_ARC * 0.5
	_sweep_to = aim_angle + _swing_sign * SWING_ARC * 0.5
	_sweep_time = ACTIVE[i]
	_sweep_fx_scale = 1.15 if hitbox.pull else 1.0
	_sweep_double = false
	pivot.rotation = _sweep_from


func _tick_swing(delta: float) -> void:
	var i := _step - 1
	_phase_t += delta
	var t_active_start: float = ANTICIPATION[i]
	var t_active_end: float = t_active_start + ACTIVE[i]
	var t_end: float = t_active_end + RECOVERY[i]
	if _phase_t >= t_active_start and _phase_t < t_active_end:
		if not hitbox.active:
			_arm_and_activate(false)
	elif hitbox.active:
		hitbox.deactivate()
	# Still holding once the swing has landed: wind back into a charge right away.
	if _held and not _buffered and _phase_t >= t_active_end + 0.03:
		hitbox.deactivate()
		_start_charging()
		return
	if _phase_t >= t_active_end + CHAIN_AT[i] and _buffered and not combo.is_finisher(_step):
		_start_swing()
		return
	if _phase_t >= t_end:
		state = State.IDLE
		_held_t = 0.0
		if _buffered:
			_buffered = false
			_start_swing()


# --- heavy -------------------------------------------------------------------------
func _start_charging() -> void:
	state = State.CHARGING
	_charge_t = 0.0
	combo.reset()


## Let go early: the hook just drops back. No swing, no hitbox, a puff to say so.
func _stop_charging() -> void:
	state = State.IDLE
	_charge_t = 0.0
	_held_t = 0.0
	sprite.modulate = Color.WHITE
	sprite.position = Vector2(2, 0)
	FX.burst(global_position, Color(0.7, 0.7, 0.75, 0.6), 3, 20.0)


func _tick_charging(delta: float) -> void:
	_charge_t += delta
	var f := clampf(_charge_t / _charge_full, 0.0, 1.0)
	# Wound back over the shoulder, opposite to the aim, and glowing as it charges.
	var aim_angle := _player.aim.angle()
	var back := aim_angle - 2.4 * (1.0 if _player.aim.x >= 0.0 else -1.0)
	pivot.rotation = lerp_angle(pivot.rotation, back, 18.0 * delta)
	sprite.flip_v = _player.aim.x < 0.0
	sprite.position = Vector2(2, 0)
	sprite.modulate = Color(1.0 + f * 0.8, 1.0 + f * 0.6, 1.0 + f * 0.2)
	if int(_charge_t * 16.0) != int((_charge_t - delta) * 16.0):
		FX.burst(global_position + Vector2.from_angle(pivot.rotation) * 12.0, Color(1.0, 0.9, 0.6, 0.8), 1, 18.0)
	if f >= 1.0 and int((_charge_t - delta) / _charge_full) == 0 and int(_charge_t / _charge_full) == 1:
		# The hook rings: the charge is complete and the heavy is armed.
		FX.ring(_player.global_position, Color(1.0, 0.9, 0.6), 0.9)
		FX.text(_player.global_position + Vector2(0, -14), "READY", Color(1.0, 0.9, 0.6))
		Audio.play("crit", 0.05, -6.0)
	if _charge_t >= CHARGE_MAX:
		_start_heavy()


## Only ever reached from a complete charge.
func _start_heavy() -> void:
	state = State.HEAVY
	_phase_t = 0.0
	sprite.modulate = Color.WHITE
	sprite.position = Vector2(2, 0)
	var aim_angle := _player.aim.angle()
	hitbox.damage = HEAVY_DAMAGE
	hitbox.knockback = HEAVY_KNOCKBACK
	hitbox.pull = false
	hitbox.hitstop = 0.16
	hitbox.tags = PackedStringArray(["melee", "heavy"])
	# Bigger reach for the big swing.
	hit_shape.position = Vector2(18, 0)
	hit_shape.shape.radius = 20.0
	_swing_sign = 1.0
	_sweep_from = aim_angle - HEAVY_ARC * 0.5
	_sweep_to = aim_angle + HEAVY_ARC * 0.5
	_sweep_time = HEAVY_ACTIVE
	_sweep_fx_scale = 1.7
	_sweep_double = true
	pivot.rotation = _sweep_from
	EventBus.request_shake.emit(0.6)


# --- lunge -------------------------------------------------------------------------
func _start_lunge() -> void:
	state = State.LUNGE
	_phase_t = 0.0
	_buffered = false
	var aim_angle := _player.aim.angle()
	hitbox.damage = LUNGE_DAMAGE
	hitbox.knockback = LUNGE_KNOCKBACK
	hitbox.pull = false
	hitbox.hitstop = 0.06
	hitbox.tags = PackedStringArray(["melee", "lunge"])
	hit_shape.position = Vector2(LUNGE_REACH, 0)
	pivot.rotation = aim_angle
	sprite.flip_v = _player.aim.x < 0.0
	sprite.position = Vector2(2, 0)
	var tw := create_tween()
	tw.tween_property(sprite, "position:x", 14.0, LUNGE_ANTICIPATION + LUNGE_ACTIVE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:x", 2.0, LUNGE_RECOVERY)
	_player.lunge(_player.aim)
	FX.burst(global_position, Color(0.9, 0.9, 1.0, 0.8), 5, 40.0)


# --- shared timed phases (heavy, lunge) --------------------------------------------
func _tick_timed(delta: float, ant: float, act: float, rec: float) -> void:
	_phase_t += delta
	if _phase_t >= ant and _phase_t < ant + act:
		if not hitbox.active:
			_arm_and_activate(state == State.HEAVY)
	elif hitbox.active:
		hitbox.deactivate()
	if _phase_t >= ant + act + rec:
		hit_shape.position = _shape_home
		hit_shape.shape.radius = 16.0
		state = State.IDLE
		_held_t = 0.0


func _arm_and_activate(heavy: bool) -> void:
	var m: Dictionary = _player.mods
	var crit: bool = _player.consume_riptide() or randf() < float(m.crit_chance)
	hitbox.crit = crit
	hitbox.damage_mult = arm_mult(_player, heavy, state == State.LUNGE, crit)
	hitbox.activate()
	if state == State.LUNGE:
		return
	# Sweep the arc now, while the hitbox is live.
	var aim_angle := (_sweep_from + _sweep_to) * 0.5
	pivot.rotation = _sweep_from
	var tw := create_tween()
	tw.tween_property(pivot, "rotation", _sweep_to, _sweep_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	FX.slash(global_position, aim_angle, _swing_sign < 0.0, _sweep_fx_scale)
	if _sweep_double:
		FX.slash(global_position, aim_angle, _swing_sign >= 0.0, _sweep_fx_scale)
	Audio.play("heavy" if heavy else "swing", 0.15)


func _on_hit_landed(target: Hurtbox, info: DamageInfo) -> void:
	FX.spark(target.global_position)
	_player.add_glow(Player.GLOW_PER_HIT)
	var heavy := info.tags.has("heavy")
	var crit := info.tags.has("crit")
	EventBus.request_shake.emit(0.5 if heavy else (0.35 if info.tags.has("third_hit") else 0.18))
	EventBus.request_hitstop.emit(info.hitstop * (1.6 if crit else 1.0))
	var enemy := target.get_parent() as Enemy
	if crit:
		FX.text(target.global_position, "CRIT", Color(1.0, 0.95, 0.6))
		FX.ring(target.global_position, Color(1.0, 0.95, 0.7), 0.8)
		Audio.play("crit", 0.05)
	elif heavy and enemy and (not enemy.is_boss or aspect == "gaff_maren"):
		if enemy.is_boss:
			enemy.crack(3.0)
		FX.text(target.global_position, "CRACKED", Color(1.0, 0.7, 0.6))
		Audio.play("crit", 0.1, -3.0)
	else:
		Audio.play("hit", 0.15, -2.0 if not heavy else 2.0)
	if enemy and info.tags.has("third_hit") and _player.mods.bleed:
		enemy.apply_bleed(3)


# --- throw -------------------------------------------------------------------------
func _start_throw() -> void:
	state = State.THROW
	var origin := _player.global_position
	var dir := _player.aim
	var space := get_world_2d().direct_space_state

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

	_throw_cd_total = THROW_COOLDOWN if target_hb else THROW_MISS_COOLDOWN
	_throw_cd = _throw_cd_total
	Audio.play("hook", 0.1)
	pivot.rotation = dir.angle()
	sprite.flip_v = dir.x < 0.0
	var dist := origin.distance_to(target_point)
	var fly_time := clampf(dist / 640.0, 0.04, 0.15)
	var tw := create_tween()
	tw.tween_property(sprite, "position", Vector2(dist - 6.0, 0), fly_time)
	tw.tween_callback(func():
		if target_hb and is_instance_valid(target_hb):
			var enemy := target_hb.get_parent() as Enemy
			var info := DamageInfo.make(THROW_DAMAGE, _player, target_hb.global_position - origin, 0.0)
			info.tags = PackedStringArray(["hook"])
			if target_hb.receive(info):
				EventBus.damage_dealt.emit(target_hb.get_parent(), info)
				FX.spark(target_hb.global_position)
				_player.add_glow(Player.GLOW_PER_HIT * 0.5)
				EventBus.request_hitstop.emit(0.05)
			if enemy and is_instance_valid(enemy) and enemy.health.is_alive():
				var anchor := enemy.is_boss or enemy.knockback_resist >= 0.5 or aspect == "gaff_drowned"
				if anchor:
					_player.yank_to(enemy.global_position - dir * 16.0, 0.12)
					FX.text(_player.global_position, "ANCHORED", Color(0.8, 0.9, 1.0))
				else:
					enemy.pull_to(_player.global_position + dir * 18.0, 0.12)
					FX.text(enemy.global_position, "HOOKED", Color(0.8, 0.9, 1.0))
	)
	tw.tween_property(sprite, "position", Vector2(2, 0), 0.1)
	tw.tween_callback(func(): state = State.IDLE)
