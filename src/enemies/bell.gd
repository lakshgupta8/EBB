extends Enemy
## THE BELL OF SALTMERE - biome 2 boss. The old verger, still carrying the church bell
## on his back through the drowned square. He tolls it (a ring of sound and a call to the
## drowned), swings it at you, or peals it three times in a row. At half health the
## bell cracks: he is faster, the statues in the square wake, and the tide comes in.

signal phase_changed(phase: int)

const SHEET := preload("res://assets/sprites/bell.png")  # 48x72 native (art Stage 08)
const TOLL := preload("res://assets/sprites/toll.png")
const CITIZEN := preload("res://src/enemies/still_citizen.tscn")
const SWIMMER := preload("res://src/enemies/swimmer.tscn")

const INTRO := 1.6
const TOLL_WINDUP := [0.9, 0.7]
const TOLL_ACTIVE := 0.3
const TOLL_RECOVER := [0.9, 0.7]
const SWING_WINDUP := [0.5, 0.4]
const SWING_TIME := 0.6
const SWING_SPEED := [240.0, 300.0]
const SWING_STAGGER := 0.8
const PEAL_WINDUP := 0.6
const PEAL_GAP := 0.5
const PEAL_PULSES := 3
const PEAL_PULSE_ACTIVE := 0.15
const MAX_MINIONS := 3

var phase: int = 0
var _swing_dir: Vector2 = Vector2.RIGHT
var _last_attacks: Array = []
var _minions: Array = []
var _chase_limit: float = 1.4

@onready var swing_box: Hitbox = $SwingBox


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 48, {
		"idle": {"frames": [0, 1], "fps": 2},
		"walk": {"frames": [2, 3], "fps": 4},
		"windup": {"frames": [4], "fps": 1},
		"ring": {"frames": [5], "fps": 1},
		"hurt": {"frames": [6], "fps": 1},
	}, 72)
	swing_box.source = self
	swing_box.landed.connect(_on_hit_landed)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle":
			play("idle")
			velocity = Vector2.ZERO
		&"chase":
			play("walk")
			_chase_limit = randf_range(0.8, 1.4)
		&"toll_windup", &"swing_windup", &"peal_windup":
			play("windup")
			velocity = Vector2.ZERO
		&"toll":
			play("ring")
			velocity = Vector2.ZERO
			EventBus.request_shake.emit(0.7)
			EventBus.request_hitstop.emit(0.05)
			Audio.play("bell", 0.0, 2.0)
			FX.ring(global_position, Color(0.95, 0.85, 0.6), 2.6)
			_throw_toll(14 if phase == 0 else 18)
			_summon()
		&"toll_recover", &"peal_recover":
			play("idle")
			hitbox.deactivate()
		&"swing":
			play("ring")
			var d := to_player()
			_swing_dir = d.normalized() if d != Vector2.ZERO else _swing_dir
			face(_swing_dir.x)
			swing_box.activate()
			Audio.play("heavy", 0.1, 2.0)
		&"stagger":
			play("hurt")
			swing_box.deactivate()
			velocity = Vector2.ZERO
			EventBus.request_shake.emit(0.8)
			FX.burst(global_position, Color(0.8, 0.75, 0.6), 14, 80.0)
		&"peal":
			play("ring")
			velocity = Vector2.ZERO


func _exit_state(s: StringName) -> void:
	if s == &"swing":
		swing_box.deactivate()
	elif s == &"peal" or s == &"toll":
		hitbox.deactivate()


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
			if d.length() < 50.0 or state_t >= _chase_limit:
				_choose_attack(d)
		&"toll_windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			sprite.position.y = -33.0 - 2.0 * sin(state_t / TOLL_WINDUP[p] * PI)
			if state_t >= TOLL_WINDUP[p] - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= TOLL_WINDUP[p]:
				sprite.position.y = -33.0
				change_state(&"toll")
		&"toll":
			velocity = Vector2.ZERO
			if state_t >= TOLL_ACTIVE:
				change_state(&"toll_recover")
		&"toll_recover":
			velocity = Vector2.ZERO
			if state_t >= TOLL_RECOVER[p]:
				_choose_attack(d)
		&"swing_windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			sprite.position.x = -3.0 * sin(state_t / SWING_WINDUP[p] * PI) * signf(d.x if d != Vector2.ZERO else _swing_dir.x)
			if state_t >= SWING_WINDUP[p] - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= SWING_WINDUP[p]:
				sprite.position.x = 0.0
				change_state(&"swing")
		&"swing":
			velocity = _swing_dir * SWING_SPEED[p]
			if is_on_wall():
				change_state(&"stagger")
			elif state_t >= SWING_TIME:
				change_state(&"toll_recover")
		&"stagger":
			if state_t >= SWING_STAGGER:
				_choose_attack(d)
		&"peal_windup":
			velocity = Vector2.ZERO
			if state_t >= PEAL_WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= PEAL_WINDUP:
				change_state(&"peal")
		&"peal":
			velocity = Vector2.ZERO
			_tick_peal()
		&"peal_recover":
			velocity = Vector2.ZERO
			if state_t >= 0.8:
				_choose_attack(d)


var _pulse_index: int = -1


func _tick_peal() -> void:
	var k := int(state_t / PEAL_GAP)
	var local := state_t - k * PEAL_GAP
	if k >= PEAL_PULSES:
		_pulse_index = -1
		change_state(&"peal_recover")
		return
	if local < PEAL_PULSE_ACTIVE:
		if _pulse_index != k:
			_pulse_index = k
			_pulse()
	else:
		if hitbox.active:
			hitbox.deactivate()
		# Cue the next pulse so each one can be dodged on the flash.
		if k < PEAL_PULSES - 1 and local >= PEAL_GAP - STRIKE_CUE_LEAD:
			strike_cue()


func _pulse() -> void:
	_cued = false
	hitbox.activate()
	FX.ring(global_position, Color(1.0, 0.95, 0.8), 1.5)
	EventBus.request_shake.emit(0.4)
	Audio.play("bell", 0.15, -4.0)


func _choose_attack(d: Vector2) -> void:
	var dist := d.length()
	var weights := {}
	if dist > 140.0:
		weights = {&"toll_windup": 4.0, &"swing_windup": 4.0, &"chase": 2.0}
	elif dist > 64.0:
		weights = {&"swing_windup": 3.0, &"peal_windup": 2.0, &"toll_windup": 2.0, &"chase": 3.0}
	else:
		weights = {&"peal_windup": 6.0, &"swing_windup": 2.0, &"toll_windup": 1.0}
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


func _throw_toll(count: int) -> void:
	var content := get_parent()
	var spd := 120.0 if phase == 0 else 145.0
	var offset := randf() * TAU
	for i in count:
		var ang := offset + TAU * i / count
		var vel := Vector2.from_angle(ang) * spd
		var pr := Projectile.spawn(content, global_position + Vector2.from_angle(ang) * 22.0, vel, 8, TOLL, self, 64, 1.5)
		pr.rotation = ang
		pr.knockback = 140.0


func _alive_minions() -> int:
	_minions = _minions.filter(func(m): return is_instance_valid(m))
	return _minions.size()


func _summon() -> void:
	var content := get_parent()
	var wet := room != null and room.has_water()
	for i in 2:
		if _alive_minions() >= MAX_MINIONS:
			break
		var e: Enemy = (SWIMMER if wet else CITIZEN).instantiate()
		var side := 1.0 if i == 0 else -1.0
		var at := global_position + Vector2(side * 80.0, randf_range(-40.0, 40.0))
		e.global_position = room.clamp_inside(at) if room else at
		content.add_child(e)
		e.salt_drop = 1
		if not wet:
			e.call_deferred("wake")
		_minions.append(e)
		FX.burst(e.global_position, Color(0.6, 0.8, 0.9), 8, 50.0)


func _on_hurt_extra(_info: DamageInfo) -> void:
	if phase == 0 and health.hp <= health.max_hp / 2:
		phase = 1
		speed *= 1.25
		sprite.modulate = Color(0.95, 0.8, 0.7)
		EventBus.request_shake.emit(1.0)
		EventBus.request_hitstop.emit(0.15)
		FX.burst(global_position, Color(0.95, 0.85, 0.5), 24, 120.0)
		Audio.play("bell", 0.0, 4.0)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and e is Enemy and "dormant" in e and e.dormant:
				e.wake()
		phase_changed.emit(phase)
		if state != &"swing":
			change_state(&"toll_windup")
