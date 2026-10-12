extends Enemy
## THE TIDEWALL - the Reef's boss (map Stage 11j). A stretch of Saltmere's sea wall that stood
## up, the sea coming through the breach in its chest. It slides along its own line at the top
## of the arena, it does not come down to you. Close, its buttresses come down; at a distance
## it throws its own stones onto marked spots, or opens the breach and sends a fan of surges.
## And it turns the current: the water in the arena's channel runs one way, then, at its word,
## the other. At half health a second breach opens high on its face: a second channel starts to
## run, the turns come quicker, and two rays come through with the water.

signal phase_changed(phase: int)

const SHEET := preload("res://assets/sprites/tidewall.png")              # 48x48, boss layout
const BREACHED := preload("res://assets/sprites/tidewall_breached.png")  # the same after phase 2
const STONE_TEX := preload("res://assets/sprites/wall_stone.png")
const SURGE_TEX := preload("res://assets/sprites/surge.png")
const RAY := preload("res://src/enemies/reef_ray.tscn")

const INTRO := 1.6
const SLAM_RANGE := 72.0
const SLAM_WINDUP := [0.65, 0.5]
const SLAM := 0.2
const STONE_WINDUP := [0.6, 0.45]
const STONE_FALL := 0.5
const BREACH_WINDUP := [0.7, 0.55]
const SURGES := [3, 5]
const SURGE_FAN := 0.34
const SURGE_SPEED := 105.0
const SURGE_DAMAGE := 7
const SURGE_SHOVE := 240.0
const TURN_WINDUP := 0.9
const TURN_EVERY := [9.0, 6.0]
const RECOVER := [0.85, 0.65]
const SLIDE_LIMIT := [1.4, 1.0]

var phase: int = 0
var _last_attacks: Array = []
var _stone_targets: Array = []
var _slide_limit: float = 1.2
var _turn_t: float = 0.0
var _flow: float = 1.0        # 1: the channels run as the arena's lines are drawn; -1: turned
var _lines: Array = []        # the arena's `~` lines: the first runs from the start, the rest after the second breach

@onready var drop_box: Hitbox = $DropBox


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 48, anims(
		{"idle": "idle", "walk": "walk", "windup": "windup", "attack": "attack", "hurt": "hurt"}, {"idle": 4, "walk": 3}, true), 48)
	drop_box.source = self
	drop_box.landed.connect(_on_hit_landed)
	# The breach glows: cold, the sea's light, not a lamp (the Reef is cold only).
	var glow := Atmosphere.light(self, Atmosphere.COLD, 1.4, 0.55, Vector2(0, -22), true)
	Atmosphere.breathe(glow, 0.6, 1.0, 1.8)
	call_deferred("_take_the_water")


## The arena's channels are its own: only the first runs until the second breach opens.
func _take_the_water() -> void:
	if room == null or room.current == null:
		return
	_lines = room.template.currents.duplicate()
	_relay()


func _relay() -> void:
	if room == null or room.current == null or _lines.is_empty():
		return
	var out: Array = []
	for i in (_lines.size() if phase == 1 else 1):
		var line: PackedVector2Array = _lines[i].duplicate()
		if _flow < 0.0:
			line.reverse()
		out.append(line)
	room.current.relay(out)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle":
			play("idle")
			velocity = Vector2.ZERO
			if state_t == 0.0 and phase == 0:
				hold_frame(&"intro", 1.0)
		&"slide":
			play("walk")
			_slide_limit = randf_range(SLIDE_LIMIT[phase] * 0.7, SLIDE_LIMIT[phase])
		&"slam_windup", &"stone_windup", &"breach_windup", &"turn_windup":
			play("windup")
			velocity = Vector2.ZERO
			if s == &"stone_windup":
				_mark_stones()
			elif s == &"turn_windup":
				Audio.play("creak", 0.0, -1.0)
				FX.ring(global_position + Vector2(0, -22), Palette.SEA_PALE, 2.0)
		&"slam":
			play("attack")
			hitbox.activate()
			EventBus.request_shake.emit(0.7)
			EventBus.request_hitstop.emit(0.05)
			FX.burst(global_position + Vector2(0, 6), Color(0.6, 0.62, 0.66), 16, 90.0)
			Audio.play("heavy", 0.0, 0.0)
		&"stone":
			play("attack")
			_throw_stones()
		&"breach":
			play("attack")
			_open_breach()
		&"turn":
			play("attack")
			_turn()
		&"recover":
			play("idle")
			hitbox.deactivate()
		&"summon":
			play("windup")
			EventBus.request_shake.emit(0.4)


func _exit_state(s: StringName) -> void:
	if s == &"slam":
		hitbox.deactivate()


func _tick(delta: float) -> void:
	var d := to_player()
	var p := phase
	_turn_t += delta
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if state_t >= INTRO and d != Vector2.ZERO:
				_choose_attack(d)
		&"slide":
			# Along its own line only: it keeps to the top of the arena.
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			velocity = Vector2(signf(d.x) * speed if absf(d.x) > 8.0 else 0.0, 0.0)
			face(d.x)
			if state_t >= _slide_limit:
				_choose_attack(d)
		&"slam_windup":
			if state_t >= SLAM_WINDUP[p] - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= SLAM_WINDUP[p]:
				change_state(&"slam")
		&"slam":
			if state_t >= SLAM:
				change_state(&"recover")
		&"stone_windup":
			if fmod(state_t, 0.16) < 0.02:
				for t in _stone_targets:
					FX.ring(t, Palette.SALT_RED, 0.9)
			if state_t >= STONE_WINDUP[p] - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= STONE_WINDUP[p]:
				change_state(&"stone")
		&"stone":
			if state_t >= STONE_FALL + 0.25:
				change_state(&"recover")
		&"breach_windup":
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= BREACH_WINDUP[p] - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= BREACH_WINDUP[p]:
				change_state(&"breach")
		&"breach":
			if state_t >= 0.35:
				change_state(&"recover")
		&"turn_windup":
			if state_t >= TURN_WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= TURN_WINDUP:
				change_state(&"turn")
		&"turn":
			if state_t >= 0.4:
				change_state(&"recover")
		&"recover":
			velocity = Vector2.ZERO
			if state_t >= RECOVER[p]:
				_choose_attack(d)
		&"summon":
			velocity = Vector2.ZERO
			if state_t >= 0.9:
				_do_summon()
				change_state(&"recover")


func _choose_attack(d: Vector2) -> void:
	if d == Vector2.ZERO:
		change_state(&"idle")
		return
	# The turn comes on its own clock, ahead of everything else.
	if _turn_t >= TURN_EVERY[phase] and not _lines.is_empty():
		_turn_t = 0.0
		change_state(&"turn_windup")
		return
	var dist := d.length()
	var weights := {}
	if dist < SLAM_RANGE:
		weights = {&"slam_windup": 6.0, &"breach_windup": 1.5, &"slide": 1.0}
	elif dist < 160.0:
		weights = {&"stone_windup": 3.0, &"breach_windup": 3.0, &"slide": 2.0}
	else:
		weights = {&"stone_windup": 4.0, &"breach_windup": 2.0, &"slide": 3.0}
	if _last_attacks.size() >= 2 and _last_attacks[-1] == _last_attacks[-2]:
		weights.erase(_last_attacks[-1])
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := randf() * total
	var pick: StringName = &"slide"
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			pick = k
			break
	if pick != &"slide":
		_last_attacks.append(pick)
	change_state(pick)


func _mark_stones() -> void:
	_stone_targets = []
	if player == null or player.dead:
		return
	_stone_targets.append(player.global_position)
	if phase == 1:
		_stone_targets.append(player.global_position + player.velocity * 0.5)
		_stone_targets.append(player.global_position + Vector2(randf_range(-40, 40), randf_range(-30, 30)))
	Audio.play("creak", 0.1, -3.0)


## Its own stones, prised off the wall, fall on the marked spots; the box lands with each.
func _throw_stones() -> void:
	var content := get_parent()
	for t in _stone_targets:
		var s := Sprite2D.new()
		s.texture = STONE_TEX
		s.z_index = 6
		s.global_position = t + Vector2(0, -100)
		content.add_child(s)
		var tw := s.create_tween()
		tw.tween_property(s, "global_position", t, STONE_FALL).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(_land_stone.bind(t, s))


func _land_stone(at: Vector2, s: Sprite2D) -> void:
	if not is_inside_tree():
		return
	drop_box.global_position = at
	drop_box.activate()
	EventBus.request_shake.emit(0.5)
	FX.burst(at, Color(0.62, 0.64, 0.68), 12, 75.0)
	FX.ring(at, Palette.SALT_WHITE, 1.1)
	Audio.play("heavy", 0.15, -2.0)
	var tw := s.create_tween()
	tw.tween_interval(0.15)
	tw.tween_callback(drop_box.deactivate)
	tw.tween_property(s, "modulate:a", 0.0, 0.5)
	tw.tween_callback(s.queue_free)


## The breach opens and the sea comes through it: a fan of surges.
func _open_breach() -> void:
	var d := to_player()
	var aim := d.normalized() if d != Vector2.ZERO else Vector2.DOWN
	var from := global_position + Vector2(0, -16)
	var n: int = SURGES[phase]
	for i in n:
		var dir := aim.rotated((i - (n - 1) / 2.0) * SURGE_FAN)
		var p := Projectile.spawn(get_parent(), from + dir * 18.0, dir * SURGE_SPEED, SURGE_DAMAGE, SURGE_TEX, self, 64, 2.6)
		p.knockback = SURGE_SHOVE
		p.tags = PackedStringArray(["projectile", "surge"])
		for c in p.get_children():
			if c is CollisionShape2D and c.shape is CircleShape2D:
				(c.shape as CircleShape2D).radius = 8.0
	FX.burst(from, Color(0.75, 0.9, 0.95, 0.9), 16, 80.0)
	EventBus.request_shake.emit(0.4)
	Audio.play("splash", 0.0, 2.0)


## The water in the channels turns and runs the other way.
func _turn() -> void:
	_flow = -_flow
	_relay()
	EventBus.request_shake.emit(0.5)
	FX.burst(global_position + Vector2(0, -16), Color(0.75, 0.9, 0.95, 0.9), 20, 100.0)
	Audio.play("splash", 0.05, 0.0)
	if player and not player.dead:
		FX.text(player.global_position + Vector2(0, -20), "THE WATER TURNS", Palette.SEA_PALE)


func _do_summon() -> void:
	var content := get_parent()
	for i in 2:
		var e: Enemy = RAY.instantiate()
		e.global_position = global_position + Vector2(-40.0 if i == 0 else 40.0, 30.0)
		content.add_child(e)
		e.salt_drop = 1
		FX.burst(e.global_position, Color(0.6, 0.85, 0.9), 8, 50.0)


func _on_hurt_extra(_info: DamageInfo) -> void:
	if phase == 0 and health.hp <= health.max_hp / 2:
		phase = 1
		speed *= 1.2
		sprite.modulate = PHASE_TINT
		_swap_sheet(BREACHED)
		EventBus.request_shake.emit(1.0)
		EventBus.request_hitstop.emit(0.15)
		FX.burst(global_position + Vector2(0, -26), Color(0.75, 0.9, 0.95), 28, 130.0)
		hold_frame(&"phase", 0.6)
		_turn_t = 0.0
		_relay()        # the second channel starts to run
		phase_changed.emit(phase)
		if state != &"stone" and state != &"breach":
			change_state(&"summon")


## The second breach is drawn on its own sheet: every frame swaps to it, as an elite's costume does.
func _swap_sheet(tex: Texture2D) -> void:
	var sf := sprite.sprite_frames
	for anim in sf.get_animation_names():
		for i in sf.get_frame_count(anim):
			var at := sf.get_frame_texture(anim, i)
			if at is AtlasTexture:
				(at as AtlasTexture).atlas = tex
