extends Enemy
## THE CHAINMOTHER - the Sunken Harbour's boss. The dock crane that kept the ships from
## leaving, walking on its own legs now. She sweeps a chain round herself, drops anchors
## where you stand, hauls you in for a slam, and calls the barnacles off her hull.
## At half health she stirs: faster, two anchors at once, and she drags the tide in.

signal phase_changed(phase: int)

const SHEET := preload("res://assets/sprites/chainmother.png")
const ANCHOR_TEX := preload("res://assets/sprites/anchor_drop.png")
const BARNACLE := preload("res://src/enemies/barnacle.tscn")

const INTRO := 1.6
const SWEEP_WINDUP := [0.6, 0.45]
const SWEEP := 0.7
const SWEEP_REACH := 66.0
const DROP_WINDUP := [0.55, 0.4]
const DROP_FALL := 0.45
const HAUL_WINDUP := [0.7, 0.5]
const HAUL_TIME := 0.25
const SLAM_WINDUP := [0.45, 0.35]
const SLAM := 0.2
const RECOVER := [0.8, 0.6]
const SUMMON_TIME := 0.9
const MAX_MINIONS := 4
const HAUL_DAMAGE := 5

var phase: int = 0
var _last_attacks: Array = []
var _minions: Array = []
var _stalk_limit: float = 1.4
var _sweep_from: float = 0.0
var _drop_targets: Array = []
var _chain: Line2D

@onready var sweep_box: Hitbox = $SweepBox
@onready var drop_box: Hitbox = $DropBox
@onready var anchor_sprite: Sprite2D = $Anchor


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, {
		"idle": {"frames": [0, 1], "fps": 2},
		"walk": {"frames": [2, 3], "fps": 3},
		"windup": {"frames": [4], "fps": 1},
		"attack": {"frames": [5], "fps": 1},
		"hurt": {"frames": [6], "fps": 1},
	})
	sweep_box.source = self
	sweep_box.landed.connect(_on_hit_landed)
	drop_box.source = self
	drop_box.landed.connect(_on_hit_landed)
	anchor_sprite.visible = false
	_chain = Line2D.new()
	_chain.width = 1.0
	_chain.default_color = Color(0.8, 0.82, 0.9)
	_chain.z_index = 3
	_chain.visible = false
	add_child(_chain)
	var eye := Atmosphere.light(self, Color(1.0, 0.6, 0.25), 1.6, 0.9, Vector2(0, -8))
	Atmosphere.breathe(eye, 0.7, 1.1, 1.3)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle":
			play("idle")
			velocity = Vector2.ZERO
		&"stalk":
			play("walk")
			_stalk_limit = randf_range(0.8, 1.6)
		&"sweep_windup":
			play("windup")
			velocity = Vector2.ZERO
			var d := to_player()
			_sweep_from = d.angle() if d != Vector2.ZERO else 0.0
		&"sweep":
			play("attack")
			velocity = Vector2.ZERO
			sweep_box.rotation = _sweep_from
			sweep_box.activate()
			_chain.visible = true
			Audio.play("chain", 0.0, 0.0)
			EventBus.request_shake.emit(0.3)
		&"drop_windup":
			play("windup")
			velocity = Vector2.ZERO
			_drop_targets = []
			if player and not player.dead:
				_drop_targets.append(player.global_position)
				if phase == 1:
					_drop_targets.append(player.global_position + player.velocity * 0.45)
			Audio.play("creak", 0.0, -2.0)
		&"drop":
			play("attack")
			velocity = Vector2.ZERO
			_fall_anchor()
		&"haul_windup":
			play("windup")
			velocity = Vector2.ZERO
		&"haul":
			play("attack")
			velocity = Vector2.ZERO
			_throw_chain()
		&"slam_windup":
			play("windup")
			velocity = Vector2.ZERO
		&"slam":
			play("attack")
			velocity = Vector2.ZERO
			hitbox.activate()
			EventBus.request_shake.emit(0.7)
			EventBus.request_hitstop.emit(0.05)
			FX.burst(global_position + Vector2(0, 8), Color(0.6, 0.55, 0.45), 16, 90.0)
			Audio.play("heavy", 0.0, 0.0)
		&"recover":
			play("idle")
			hitbox.deactivate()
			sweep_box.deactivate()
			_chain.visible = false
		&"summon":
			play("windup")
			velocity = Vector2.ZERO
			EventBus.request_shake.emit(0.3)
			Audio.play("creak", 0.1, -4.0)


func _exit_state(s: StringName) -> void:
	if s == &"sweep":
		sweep_box.deactivate()
		_chain.visible = false
	elif s == &"slam":
		hitbox.deactivate()
	elif s == &"haul":
		_chain.visible = false


func _tick(_delta: float) -> void:
	var d := to_player()
	var p := phase
	match state:
		&"idle":
			if state_t >= INTRO and d != Vector2.ZERO:
				_choose_attack(d)
		&"stalk":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			face(d.x)
			velocity = d.normalized() * speed
			if d.length() < 50.0 or state_t >= _stalk_limit:
				_choose_attack(d)
		&"sweep_windup":
			velocity = Vector2.ZERO
			# The chain is shown resting where the sweep will start.
			_chain.visible = true
			_chain.clear_points()
			_chain.add_point(Vector2(0, -6))
			_chain.add_point(Vector2.from_angle(_sweep_from) * SWEEP_REACH * 0.5 + Vector2(0, -6))
			_chain.default_color = Color(0.8, 0.82, 0.9, 0.4)
			if state_t >= SWEEP_WINDUP[p] - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= SWEEP_WINDUP[p]:
				_chain.default_color = Color(0.85, 0.88, 0.95, 1.0)
				change_state(&"sweep")
		&"sweep":
			velocity = Vector2.ZERO
			var ang := _sweep_from + TAU * minf(1.0, state_t / SWEEP)
			sweep_box.rotation = ang
			_chain.clear_points()
			_chain.add_point(Vector2(0, -6))
			_chain.add_point(Vector2.from_angle(ang) * SWEEP_REACH / scale.x + Vector2(0, -6))
			if state_t >= SWEEP:
				change_state(&"recover")
		&"drop_windup":
			velocity = Vector2.ZERO
			if fmod(state_t, 0.16) < 0.02:
				for t in _drop_targets:
					FX.ring(t, Color(1.0, 0.6, 0.3), 0.9)
			if state_t >= DROP_WINDUP[p] - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= DROP_WINDUP[p]:
				change_state(&"drop")
		&"drop":
			velocity = Vector2.ZERO
			if state_t >= DROP_FALL + 0.2:
				change_state(&"recover")
		&"haul_windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= HAUL_WINDUP[p] - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= HAUL_WINDUP[p]:
				change_state(&"haul")
		&"haul":
			velocity = Vector2.ZERO
			if state_t >= HAUL_TIME + 0.05:
				change_state(&"slam_windup")
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
			if state_t >= SLAM:
				change_state(&"recover")
		&"recover":
			velocity = Vector2.ZERO
			if state_t >= RECOVER[p]:
				_choose_attack(d)
		&"summon":
			velocity = Vector2.ZERO
			if state_t >= SUMMON_TIME:
				_do_summon()
				change_state(&"stalk")


func _choose_attack(d: Vector2) -> void:
	var dist := d.length()
	var weights := {}
	if dist > 140.0:
		weights = {&"drop_windup": 5.0, &"haul_windup": 3.0, &"summon": 2.0, &"stalk": 3.0}
	elif dist > 70.0:
		weights = {&"drop_windup": 3.0, &"haul_windup": 3.0, &"sweep_windup": 2.0, &"stalk": 3.0, &"summon": 1.0}
	else:
		weights = {&"sweep_windup": 6.0, &"drop_windup": 1.5, &"stalk": 1.0}
	if _alive_minions() >= MAX_MINIONS:
		weights.erase(&"summon")
	if _last_attacks.size() >= 2 and _last_attacks[-1] == _last_attacks[-2]:
		weights.erase(_last_attacks[-1])
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := randf() * total
	var pick: StringName = &"stalk"
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			pick = k
			break
	if pick != &"stalk":
		_last_attacks.append(pick)
	change_state(pick)


## The anchor falls from above onto each marked spot; the box lands with it.
func _fall_anchor() -> void:
	var content := get_parent()
	for t in _drop_targets:
		var a := Sprite2D.new()
		a.texture = ANCHOR_TEX
		a.z_index = 6
		a.global_position = t + Vector2(0, -90)
		content.add_child(a)
		var tw := a.create_tween()
		tw.tween_property(a, "global_position", t, DROP_FALL).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(_land_anchor.bind(t, a))


func _land_anchor(at: Vector2, a: Sprite2D) -> void:
	if not is_inside_tree():
		return
	drop_box.global_position = at
	drop_box.activate()
	EventBus.request_shake.emit(0.6)
	FX.burst(at, Color(0.7, 0.6, 0.5), 14, 80.0)
	FX.ring(at, Color(1.0, 0.7, 0.4), 1.2)
	Audio.play("heavy", 0.1, 0.0)
	var tw := a.create_tween()
	tw.tween_interval(0.15)
	tw.tween_callback(drop_box.deactivate)
	tw.tween_property(a, "modulate:a", 0.0, 0.5)
	tw.tween_callback(a.queue_free)


func _throw_chain() -> void:
	var d := to_player()
	if d == Vector2.ZERO:
		return
	face(d.x)
	_chain.default_color = Color(0.85, 0.88, 0.95, 1.0)
	_chain.clear_points()
	_chain.add_point(Vector2(0, -6))
	_chain.add_point(to_local(player.global_position))
	_chain.visible = true
	Audio.play("chain", 0.1, -2.0)
	if player.is_dashing() or player.is_yanked():
		FX.text(player.global_position, "SLIPPED", Color(0.7, 0.95, 1.0))
		return
	var info := DamageInfo.make(HAUL_DAMAGE, self, d, 0.0)
	info.tags = PackedStringArray(["chain"])
	info.hitstop = 0.03
	if player.hurtbox.receive(info):
		player.yank_to(global_position + d.normalized() * 30.0, HAUL_TIME)
		FX.text(player.global_position, "HAULED", Color(0.9, 0.7, 0.6))


func _alive_minions() -> int:
	_minions = _minions.filter(func(m): return is_instance_valid(m))
	return _minions.size()


func _do_summon() -> void:
	var content := get_parent()
	for i in (2 if phase == 0 else 3):
		if _alive_minions() >= MAX_MINIONS:
			break
		var e: Enemy = BARNACLE.instantiate()
		var ang := TAU * i / 3.0 + randf_range(-0.4, 0.4)
		e.global_position = global_position + Vector2.from_angle(ang) * 44.0
		content.add_child(e)
		e.salt_drop = 1
		_minions.append(e)
		FX.burst(e.global_position, Color(0.85, 0.86, 0.82), 8, 50.0)


func _on_hurt_extra(_info: DamageInfo) -> void:
	if phase == 0 and health.hp <= health.max_hp / 2:
		phase = 1
		speed *= 1.25
		sprite.modulate = Color(1.0, 0.8, 0.7)
		EventBus.request_shake.emit(1.0)
		EventBus.request_hitstop.emit(0.15)
		FX.burst(global_position, Color(1.0, 0.6, 0.3), 24, 120.0)
		phase_changed.emit(phase)
		if state != &"sweep" and state != &"drop":
			change_state(&"summon")
