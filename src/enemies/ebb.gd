extends Enemy
## THE EBB - the last boss. The thing that holds Saltmere under. A keeper's shape made of
## water, carrying Maren's lantern. It sends walls of water with one gap in them, hauls you
## in and comes down on you, and calls the shades of the old keepers. At 60% and 30% it
## rises: the hall floods further and everything comes faster.

signal phase_changed(phase: int)

const SHEET := preload("res://assets/sprites/ebb.png")
const TOLL := preload("res://assets/sprites/toll.png")
const SHADE := preload("res://src/enemies/keeper_shade.tscn")

const INTRO := 2.0
const WAVE_WINDUP := [0.9, 0.75, 0.6]
const WAVE_COUNT := [1, 2, 3]
const WAVE_SPEED := [140.0, 165.0, 190.0]
const WAVE_GAP_TIME := 0.45
const PULL_WINDUP := 0.6
const HAUL_TIME := 0.3
const SLAM_WINDUP := 0.45
const SLAM := 0.2
const RECOVER := [1.0, 0.8, 0.6]
const SUMMON_TIME := 0.8
const MAX_SHADES := [1, 2, 2]
const SURGE_COUNT := [12, 16, 20]

var phase: int = 0
var _last_attacks: Array = []
var _shades: Array = []
var _waves_left: int = 0
var _wave_t: float = 0.0
var _chase_limit: float = 1.2


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 72, anims(
		{"idle": "idle", "walk": "walk", "windup": "windup", "cast": "attack", "hurt": "hurt"}, {"idle": 2, "walk": 5}, true), 72)
	hold_frame.call_deferred(&"intro", INTRO)
	var l := Atmosphere.light(self, Atmosphere.COLD, 4.0, 0.6, Vector2(0, -10))
	Atmosphere.breathe(l, 1.0, 1.8, 2.6)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle":
			play("idle")
			velocity = Vector2.ZERO
		&"chase":
			play("walk")
			_chase_limit = randf_range(0.7, 1.2)
		&"wave_windup", &"pull_windup", &"slam_windup", &"summon", &"surge_windup":
			play("windup")
			velocity = Vector2.ZERO
		&"wave":
			play("cast")
			velocity = Vector2.ZERO
			_waves_left = WAVE_COUNT[phase]
			_wave_t = WAVE_GAP_TIME
		&"haul":
			play("cast")
			velocity = Vector2.ZERO
			_haul()
		&"slam":
			play("cast")
			velocity = Vector2.ZERO
			hitbox.activate()
			EventBus.request_shake.emit(0.8)
			EventBus.request_hitstop.emit(0.05)
			FX.ring(global_position, Color(0.6, 0.85, 1.0), 2.2)
			FX.burst(global_position, Color(0.5, 0.75, 0.95), 20, 100.0)
			Audio.play("splash", 0.0, 4.0)
		&"surge":
			play("cast")
			velocity = Vector2.ZERO
			_surge()
		&"recover":
			play("idle")
			hitbox.deactivate()


func _exit_state(s: StringName) -> void:
	if s == &"slam":
		hitbox.deactivate()


func _tick(delta: float) -> void:
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
			if d.length() < 56.0 or state_t >= _chase_limit:
				_choose_attack(d)
		&"wave_windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			sprite.position.y = -33.0 - 3.0 * sin(state_t / WAVE_WINDUP[p] * PI)
			if state_t >= WAVE_WINDUP[p] - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WAVE_WINDUP[p]:
				sprite.position.y = -33.0
				change_state(&"wave")
		&"wave":
			velocity = Vector2.ZERO
			_wave_t += delta
			if _waves_left > 0 and _wave_t >= WAVE_GAP_TIME:
				_wave_t = 0.0
				_waves_left -= 1
				_send_wave(d)
			elif _waves_left <= 0 and _wave_t >= 0.4:
				change_state(&"recover")
		&"pull_windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= PULL_WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= PULL_WINDUP:
				change_state(&"haul")
		&"haul":
			velocity = Vector2.ZERO
			if state_t >= HAUL_TIME + 0.05:
				change_state(&"slam_windup")
		&"slam_windup":
			velocity = Vector2.ZERO
			if state_t >= SLAM_WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= SLAM_WINDUP:
				change_state(&"slam")
		&"slam":
			velocity = Vector2.ZERO
			if state_t >= SLAM:
				change_state(&"recover")
		&"summon":
			velocity = Vector2.ZERO
			if state_t >= SUMMON_TIME:
				_summon()
				change_state(&"chase")
		&"surge_windup":
			velocity = Vector2.ZERO
			if state_t >= 0.7 - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= 0.7:
				change_state(&"surge")
		&"surge":
			velocity = Vector2.ZERO
			if state_t >= 0.3:
				change_state(&"recover")
		&"recover":
			velocity = Vector2.ZERO
			if state_t >= RECOVER[p]:
				_choose_attack(d)


func _choose_attack(d: Vector2) -> void:
	var dist := d.length()
	var weights := {}
	if dist > 150.0:
		weights = {&"wave_windup": 5.0, &"pull_windup": 3.0, &"chase": 2.0, &"summon": 1.5}
	elif dist > 70.0:
		weights = {&"wave_windup": 3.0, &"pull_windup": 3.0, &"chase": 2.0, &"summon": 1.0, &"surge_windup": 1.5}
	else:
		weights = {&"slam_windup": 5.0, &"surge_windup": 3.0, &"wave_windup": 1.0}
	if phase == 0:
		weights.erase(&"surge_windup")
	if _alive_shades() >= MAX_SHADES[phase]:
		weights.erase(&"summon")
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


## A wall of water toward the player with one gap in it. Later waves shift the gap.
func _send_wave(d: Vector2) -> void:
	var dir := d.normalized() if d != Vector2.ZERO else Vector2.RIGHT
	var side := dir.orthogonal()
	var n := 9
	var gap := randi_range(2, n - 3)
	var content := get_parent()
	for i in n:
		if i == gap or i == gap + 1:
			continue
		var off := side * (i - (n - 1) * 0.5) * 18.0
		var pr := Projectile.spawn(content, global_position + Vector2(0, -6) + dir * 26.0 + off, dir * WAVE_SPEED[phase], 7, TOLL, self, 64, 2.2)
		pr.rotation = dir.angle()
		pr.knockback = 150.0
		pr.tags = PackedStringArray(["projectile", "wave"])
	FX.ring(global_position + dir * 20.0, Color(0.6, 0.85, 1.0), 1.4)
	Audio.play("wave", 0.1)
	EventBus.request_shake.emit(0.3)


func _haul() -> void:
	var d := to_player()
	if d == Vector2.ZERO:
		return
	face(d.x)
	FX.ring(player.global_position, Color(0.6, 0.85, 1.0), 1.0)
	Audio.play("hook", 0.0, 2.0)
	if player.is_dashing() or player.is_yanked():
		FX.text(player.global_position, "SLIPPED", Color(0.7, 0.95, 1.0))
		return
	var info := DamageInfo.make(5, self, d, 0.0)
	info.tags = PackedStringArray(["pull"])
	info.hitstop = 0.03
	if player.hurtbox.receive(info):
		player.yank_to(global_position + d.normalized() * 34.0, HAUL_TIME)
		FX.text(player.global_position, "HAULED", Color(0.9, 0.7, 0.6))


func _surge() -> void:
	var content := get_parent()
	var count: int = SURGE_COUNT[phase]
	var offset := randf() * TAU
	for i in count:
		var ang := offset + TAU * i / count
		var pr := Projectile.spawn(content, global_position + Vector2.from_angle(ang) * 24.0, Vector2.from_angle(ang) * 130.0, 8, TOLL, self, 64, 1.6)
		pr.rotation = ang
		pr.knockback = 140.0
	FX.ring(global_position, Color(0.6, 0.85, 1.0), 2.6)
	Audio.play("wave", 0.0, 2.0)
	EventBus.request_shake.emit(0.5)


func _alive_shades() -> int:
	_shades = _shades.filter(func(m): return is_instance_valid(m))
	return _shades.size()


func _summon() -> void:
	var content := get_parent()
	for i in 2:
		if _alive_shades() >= MAX_SHADES[phase]:
			break
		var e: Enemy = SHADE.instantiate()
		var side := 1.0 if i == 0 else -1.0
		var at := global_position + Vector2(side * 70.0, randf_range(-30.0, 30.0))
		e.global_position = room.clamp_inside(at) if room else at
		content.add_child(e)
		e.salt_drop = 1
		_shades.append(e)
		FX.burst(e.global_position, Color(0.4, 0.6, 0.9), 10, 60.0)


func _on_hurt_extra(_info: DamageInfo) -> void:
	var f := float(health.hp) / float(health.max_hp)
	var new_phase := 2 if f <= 0.3 else (1 if f <= 0.6 else 0)
	if new_phase > phase:
		phase = new_phase
		speed *= 1.2
		sprite.modulate = PHASE_TINT if phase == 1 else PHASE_TINT_2
		EventBus.request_shake.emit(1.0)
		EventBus.request_hitstop.emit(0.15)
		FX.burst(global_position, Color(0.5, 0.8, 1.0), 30, 140.0)
		Audio.play("ebb", 0.0, 2.0)
		phase_changed.emit(phase)
		if state != &"haul" and state != &"slam":
			change_state(&"surge_windup")
		hold_frame(&"phase", 0.7)
