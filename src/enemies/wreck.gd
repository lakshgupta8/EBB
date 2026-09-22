extends Enemy
## THE WRECK - biome 1 boss. A hulking barnacled shellback that slams (debris ring),
## charges across the arena, and calls the flats to its aid. At half health it stirs:
## faster, and it drags the tide in.

signal phase_changed(phase: int)

const SHEET := preload("res://assets/sprites/wreck.png")  # 72x48 native (art Stage 08)
const DEBRIS := preload("res://assets/sprites/debris.png")
const GULL := preload("res://src/enemies/gull.tscn")
const CRAB := preload("res://src/enemies/wrack_crab.tscn")

const INTRO := 1.6
const SLAM_WINDUP := [0.65, 0.45]
const SLAM_ACTIVE := 0.2
const SLAM_RECOVER := [0.8, 0.6]
const CHARGE_WINDUP := [0.55, 0.4]
const CHARGE_TIME := 0.7
const CHARGE_SPEED := [250.0, 320.0]
const CHARGE_STAGGER := 0.9
const SUMMON_TIME := 0.9
const MAX_MINIONS := 3

var phase: int = 0
var _charge_dir: Vector2 = Vector2.RIGHT
var _last_attacks: Array = []
var _minions: Array = []
var _chase_limit: float = 1.6

@onready var charge_box: Hitbox = $ChargeBox


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 72, anims(
		{"idle": "idle", "walk": "walk", "windup": "windup", "slam": "attack", "hurt": "hurt"}, {"idle": 2, "walk": 5}, true), 48)
	hold_frame.call_deferred(&"intro", INTRO)
	charge_box.source = self
	charge_box.landed.connect(_on_hit_landed)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle":
			play("idle")
			velocity = Vector2.ZERO
		&"chase":
			play("walk")
			_chase_limit = randf_range(0.8, 1.6)
		&"slam_windup":
			play("windup")
			velocity = Vector2.ZERO
		&"slam":
			play("slam")
			hitbox.activate()
			EventBus.request_shake.emit(0.7)
			EventBus.request_hitstop.emit(0.05)
			FX.burst(global_position + Vector2(0, 8), Color(0.75, 0.68, 0.5), 18, 90.0)
			_throw_debris(8 if phase == 0 else 12)
		&"slam_recover":
			play("idle")
			hitbox.deactivate()
		&"charge_windup":
			play("windup")
			velocity = Vector2.ZERO
		&"charge":
			play("slam")
			var d := to_player()
			_charge_dir = d.normalized() if d != Vector2.ZERO else _charge_dir
			face(_charge_dir.x)
			charge_box.activate()
		&"stagger":
			play("hurt")
			charge_box.deactivate()
			velocity = Vector2.ZERO
			EventBus.request_shake.emit(0.8)
			FX.burst(global_position, Color(0.8, 0.75, 0.6), 14, 80.0)
		&"summon":
			play("windup")
			velocity = Vector2.ZERO
			EventBus.request_shake.emit(0.3)


func _exit_state(s: StringName) -> void:
	if s == &"slam":
		hitbox.deactivate()
	elif s == &"charge":
		charge_box.deactivate()


func _tick(_delta: float) -> void:
	var d := to_player()
	var p := phase
	match state:
		&"idle":
			if state_t >= INTRO and d != Vector2.ZERO:
				_choose_attack(d)
		&"chase":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			face(d.x)
			velocity = d.normalized() * speed
			if d.length() < 46.0 or state_t >= _chase_limit:
				_choose_attack(d)
		&"slam_windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= SLAM_WINDUP[p] - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= SLAM_WINDUP[p]:
				change_state(&"slam")
		&"slam":
			velocity = Vector2.ZERO
			if state_t >= SLAM_ACTIVE:
				change_state(&"slam_recover")
		&"slam_recover":
			velocity = Vector2.ZERO
			if state_t >= SLAM_RECOVER[p]:
				_choose_attack(d)
		&"charge_windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			# Telegraph: rear back slightly.
			sprite.position.x = -3.0 * sin(state_t / CHARGE_WINDUP[p] * PI) * signf(_charge_dir.x if d == Vector2.ZERO else d.x)
			if state_t >= CHARGE_WINDUP[p] - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= CHARGE_WINDUP[p]:
				sprite.position.x = 0.0
				change_state(&"charge")
		&"charge":
			velocity = _charge_dir * CHARGE_SPEED[p]
			if is_on_wall():
				change_state(&"stagger")
			elif state_t >= CHARGE_TIME:
				change_state(&"slam_recover")
		&"stagger":
			if state_t >= CHARGE_STAGGER:
				_choose_attack(d)
		&"summon":
			velocity = Vector2.ZERO
			if state_t >= SUMMON_TIME:
				_do_summon()
				change_state(&"chase")


func _choose_attack(d: Vector2) -> void:
	var dist := d.length()
	var weights := {}
	if dist > 130.0:
		weights = {&"charge_windup": 5.0, &"summon": 2.5, &"chase": 3.0}
	elif dist > 60.0:
		weights = {&"charge_windup": 3.0, &"slam_windup": 2.0, &"chase": 4.0, &"summon": 1.0}
	else:
		weights = {&"slam_windup": 6.0, &"charge_windup": 2.0, &"chase": 1.0}
	if _alive_minions() >= MAX_MINIONS:
		weights.erase(&"summon")
	# Never the same attack three times running.
	if _last_attacks.size() >= 2 and _last_attacks[-1] == _last_attacks[-2]:
		weights.erase(_last_attacks[-1])
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := randf() * total
	var pick: StringName = &"chase"
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			pick = k
			break
	if pick != &"chase":
		_last_attacks.append(pick)
	change_state(pick)


func _throw_debris(count: int) -> void:
	var content := get_parent()
	for i in count:
		var ang := TAU * i / count + randf_range(-0.15, 0.15)
		var vel := Vector2.from_angle(ang) * randf_range(110.0, 150.0)
		var pr := Projectile.spawn(content, global_position + Vector2.from_angle(ang) * 20.0, vel, 8, DEBRIS, self, 64, 1.1)
		pr.spin = randf_range(-8.0, 8.0)


func _alive_minions() -> int:
	_minions = _minions.filter(func(m): return is_instance_valid(m))
	return _minions.size()


func _do_summon() -> void:
	var scene := GULL if phase == 0 else CRAB
	var content := get_parent()
	for i in 2:
		if _alive_minions() >= MAX_MINIONS:
			break
		var e: Enemy = scene.instantiate()
		var side := 1.0 if i == 0 else -1.0
		e.global_position = global_position + Vector2(side * 70.0, randf_range(-40.0, 40.0))
		content.add_child(e)
		e.salt_drop = 1
		_minions.append(e)
		FX.burst(e.global_position, Color(0.6, 0.8, 0.9), 8, 50.0)


func _on_hurt_extra(_info: DamageInfo) -> void:
	if phase == 0 and health.hp <= health.max_hp / 2:
		phase = 1
		speed *= 1.3
		sprite.modulate = PHASE_TINT
		EventBus.request_shake.emit(1.0)
		EventBus.request_hitstop.emit(0.15)
		FX.burst(global_position, Color(0.9, 0.4, 0.35), 24, 120.0)
		phase_changed.emit(phase)
		if state != &"charge":
			change_state(&"summon")
		hold_frame(&"phase", 0.7)
