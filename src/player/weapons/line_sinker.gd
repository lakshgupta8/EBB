class_name LineSinker
extends Weapon
## A fishing line with a lead weight on the end, used as a whip. Long, quick and mean.
##   LMB tap/hold  three cracks of the line out to nearly three tiles; the third wraps and
##                 hauls whatever it catches in to you.
##   dash + LMB    LUNGE: a snap of the line out of the dash.
##   RMB           SINKER: throw the weight to the cursor. Where it lands it hits hard and
##                 everything caught under it is weighed down (slowed) for a while.

enum State { IDLE, CRACK, LUNGE, THROW }

const ANTICIPATION := [0.05, 0.05, 0.08]
const ACTIVE := [0.06, 0.06, 0.08]
const RECOVERY := [0.14, 0.14, 0.28]
const DAMAGE := [4, 4, 6]
const KNOCKBACK := [40.0, 40.0, 0.0]
const REACH := 44.0
const CRACK_MOVE_MULT := 0.6

const LUNGE_ANTICIPATION := 0.03
const LUNGE_ACTIVE := 0.1
const LUNGE_RECOVERY := 0.14
const LUNGE_DAMAGE := 5
const LUNGE_KNOCKBACK := 100.0

const SINKER_RANGE := 6.0 * 16.0
const SINKER_RADIUS := 30.0
const SINKER_DAMAGE := 8
const SINKER_KNOCKBACK := 90.0
const SINKER_SLOW := 2.0
const SINKER_COOLDOWN := 4.0
const SINKER_MISS_COOLDOWN := 1.5

var state: State = State.IDLE
var combo := ComboTracker.new(3, 0.5)

var _step: int = 0
var _phase_t: float = 0.0
var _buffered: bool = false
var _held: bool = false
var _sinker_cd: float = 0.0
var _sinker_cd_total: float = SINKER_COOLDOWN
var _reach: float = REACH
var _finisher_bonus: int = 0
var _sinker_damage: int = SINKER_DAMAGE
var _sinker_radius: float = SINKER_RADIUS
var _sinker_slow: float = SINKER_SLOW
var _player: Player
var _crack_side: float = 1.0

@onready var pivot: Node2D = $Pivot
@onready var sprite: Sprite2D = $Pivot/Sprite
@onready var whip: Line2D = $Pivot/Whip
@onready var hitbox: Hitbox = $Pivot/Hitbox
@onready var hit_shape: CollisionShape2D = $Pivot/Hitbox/Shape
@onready var sinker: Sprite2D = $Sinker


func _ready() -> void:
	id = "line"
	_player = get_parent() as Player
	hitbox.source = _player
	hitbox.landed.connect(_on_hit_landed)
	sinker.visible = false
	_load_aspect()
	match aspect:
		"line_long":
			_reach = REACH + 12.0
			_finisher_bonus = 2
		"line_lead":
			_sinker_damage = 12
			_sinker_radius = 40.0
			_sinker_slow = 3.5
	_set_reach(_reach)
	whip.visible = false


func _set_reach(r: float) -> void:
	var rect := hit_shape.shape as RectangleShape2D
	rect.size = Vector2(r - 4.0, 10.0)
	hit_shape.position = Vector2(4.0 + (r - 4.0) * 0.5, 0)


func move_mult() -> float:
	match state:
		State.CRACK: return CRACK_MOVE_MULT
		State.LUNGE: return 0.3
		_: return 1.0


func is_busy() -> bool:
	return state != State.IDLE


func special_ready() -> bool:
	return _sinker_cd <= 0.0 and state != State.THROW


func special_cooldown_fraction() -> float:
	return clampf(1.0 - _sinker_cd / _sinker_cd_total, 0.0, 1.0)


func try_attack() -> void:
	match state:
		State.IDLE: _start_crack()
		State.CRACK: _buffered = true
		_: pass


func set_held(held: bool) -> void:
	_held = held


func try_lunge() -> void:
	if state == State.IDLE or state == State.CRACK:
		_start_lunge()


func try_special() -> void:
	if special_ready():
		_start_throw()


func cancel() -> void:
	if state in [State.CRACK, State.LUNGE]:
		hitbox.deactivate()
		whip.visible = false
		state = State.IDLE
		_buffered = false


func _process(delta: float) -> void:
	_sinker_cd = maxf(0.0, _sinker_cd - delta)
	match state:
		State.IDLE:
			pivot.rotation = _player.aim.angle()
			sprite.flip_v = _player.aim.x < 0.0
			if _held:
				_start_crack()
		State.CRACK:
			_tick_crack(delta)
		State.LUNGE:
			_tick_lunge(delta)
		State.THROW:
			pivot.rotation = _player.aim.angle()


# --- cracks ------------------------------------------------------------------------------
func _start_crack() -> void:
	_step = combo.next_step(Time.get_ticks_msec() / 1000.0)
	var i := _step - 1
	state = State.CRACK
	_phase_t = 0.0
	_buffered = false
	_crack_side = -_crack_side
	var finisher := combo.is_finisher(_step)
	hitbox.damage = DAMAGE[i] + (_finisher_bonus if finisher else 0)
	hitbox.knockback = KNOCKBACK[i]
	hitbox.pull = finisher
	hitbox.hitstop = 0.04 if not finisher else 0.09
	hitbox.tags = PackedStringArray(["melee", "line", "third_hit", "finisher"] if finisher else ["melee", "line"])
	pivot.rotation = _player.aim.angle() + (0.0 if finisher else _crack_side * 0.12)
	sprite.flip_v = _player.aim.x < 0.0


func _tick_crack(delta: float) -> void:
	var i := _step - 1
	_phase_t += delta
	var t0: float = ANTICIPATION[i]
	var t1: float = t0 + ACTIVE[i]
	var t_end: float = t1 + RECOVERY[i]
	if _phase_t >= t0 and _phase_t < t1:
		if not hitbox.active:
			_arm_and_activate(false)
		_draw_whip(minf(1.0, (_phase_t - t0) / ACTIVE[i]))
	elif hitbox.active:
		hitbox.deactivate()
	if _phase_t >= t1:
		whip.modulate.a = maxf(0.0, 1.0 - (_phase_t - t1) / 0.1)
	var finisher := combo.is_finisher(_step)
	if not finisher and _phase_t >= t1 and (_buffered or _held):
		_start_crack()
		return
	if _phase_t >= t_end:
		state = State.IDLE
		whip.visible = false
		if _buffered or _held:
			_start_crack()


## The line as it uncoils: a little wave that straightens as it reaches.
func _draw_whip(t: float) -> void:
	whip.visible = true
	whip.modulate = Color(1, 1, 1, 1)
	whip.clear_points()
	var n := 8
	for k in n + 1:
		var f := float(k) / n
		var x := f * _reach * t
		var y := sin(f * PI * 2.0 + t * 6.0) * 3.0 * (1.0 - t) * _crack_side
		whip.add_point(Vector2(x, y))
	# The weight at the tip.
	whip.add_point(Vector2(_reach * t + 2.0, 0))


# --- lunge -------------------------------------------------------------------------------
func _start_lunge() -> void:
	state = State.LUNGE
	_phase_t = 0.0
	_buffered = false
	hitbox.damage = LUNGE_DAMAGE
	hitbox.knockback = LUNGE_KNOCKBACK
	hitbox.pull = false
	hitbox.hitstop = 0.06
	hitbox.tags = PackedStringArray(["melee", "line", "lunge"])
	pivot.rotation = _player.aim.angle()
	sprite.flip_v = _player.aim.x < 0.0
	_player.lunge(_player.aim)
	FX.burst(global_position, Color(0.9, 0.9, 1.0, 0.8), 5, 40.0)


func _tick_lunge(delta: float) -> void:
	_phase_t += delta
	if _phase_t >= LUNGE_ANTICIPATION and _phase_t < LUNGE_ANTICIPATION + LUNGE_ACTIVE:
		if not hitbox.active:
			_arm_and_activate(true)
		_draw_whip(1.0)
	elif hitbox.active:
		hitbox.deactivate()
	if _phase_t >= LUNGE_ANTICIPATION + LUNGE_ACTIVE + LUNGE_RECOVERY:
		whip.visible = false
		state = State.IDLE


func _arm_and_activate(lunge: bool) -> void:
	var m: Dictionary = _player.mods
	var crit: bool = _player.consume_riptide() or randf() < float(m.crit_chance)
	hitbox.crit = crit
	hitbox.damage_mult = arm_mult(_player, false, lunge, crit)
	hitbox.activate()
	Audio.play("swing", 0.3, -6.0)
	Audio.play("stab", 0.4, -8.0)


func _on_hit_landed(target: Hurtbox, info: DamageInfo) -> void:
	FX.spark(target.global_position)
	_player.add_glow(Player.GLOW_PER_HIT * 0.8)
	var crit := info.tags.has("crit")
	var finisher := info.tags.has("finisher")
	EventBus.request_shake.emit(0.3 if finisher else 0.12)
	EventBus.request_hitstop.emit(info.hitstop * (1.6 if crit else 1.0))
	var enemy := target.get_parent() as Enemy
	if crit:
		FX.text(target.global_position, "CRIT", Color(1.0, 0.95, 0.6))
		Audio.play("crit", 0.05)
	else:
		Audio.play("hit", 0.2, -3.0)
	if enemy and finisher and not enemy.is_boss and enemy.knockback_resist < 0.9:
		enemy.pull_to(_player.global_position + _player.aim * 18.0, 0.12)
		FX.text(enemy.global_position, "HAULED", Color(0.8, 0.9, 1.0))
	if enemy and info.tags.has("third_hit") and _player.mods.bleed:
		enemy.apply_bleed(3)


# --- the sinker ---------------------------------------------------------------------------
func _start_throw() -> void:
	state = State.THROW
	var origin := _player.global_position
	var dir := _player.aim
	var dist := minf(SINKER_RANGE, _player.aim_distance())
	var target := origin + dir * dist
	var ray := PhysicsRayQueryParameters2D.create(origin, target, 1)
	var wall := get_world_2d().direct_space_state.intersect_ray(ray)
	if wall:
		target = wall.position - dir * 6.0
	Audio.play("hook", 0.1, -4.0)
	sinker.visible = true
	sinker.modulate = Color(1, 1, 1, 1)
	sinker.global_position = origin + Vector2(0, -8)
	sinker.scale = Vector2(1, 1)
	var fly := clampf(origin.distance_to(target) / 400.0, 0.1, 0.3)
	var tw := create_tween()
	tw.tween_property(sinker, "global_position", target, fly).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_land_sinker.bind(target))
	tw.tween_interval(0.4)
	tw.tween_property(sinker, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): sinker.visible = false)


func _land_sinker(at: Vector2) -> void:
	state = State.IDLE
	var caught := 0
	var m: Dictionary = _player.mods
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.global_position.distance_to(at) > _sinker_radius:
			continue
		var info := DamageInfo.make(int(round(_sinker_damage * float(m.damage) * float(m.ranged_mult))), _player, e.global_position - at, SINKER_KNOCKBACK)
		info.tags = PackedStringArray(["ranged", "sinker"])
		info.hitstop = 0.05
		if e.hurtbox.receive(info):
			EventBus.damage_dealt.emit(e, info)
		e.slow(_sinker_slow)
		caught += 1
	_sinker_cd_total = SINKER_COOLDOWN if caught > 0 else SINKER_MISS_COOLDOWN
	_sinker_cd = _sinker_cd_total
	FX.ring(at, Color(0.7, 0.75, 0.85), _sinker_radius / 30.0)
	FX.burst(at, Color(0.6, 0.65, 0.75, 0.9), 10, 60.0)
	EventBus.request_shake.emit(0.35)
	Audio.play("heavy", 0.1, -6.0)
	if caught > 0:
		FX.text(at + Vector2(0, -14), "SUNK" if caught == 1 else "SUNK x%d" % caught, Color(0.8, 0.85, 0.95))
		EventBus.request_hitstop.emit(0.05)
		_player.add_glow(Player.GLOW_PER_HIT * 0.6 * caught)
