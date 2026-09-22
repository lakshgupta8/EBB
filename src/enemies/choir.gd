extends Enemy
## THE CHOIR - the Drowned Streets' named elite. One of the singers who were in the chapel
## when the city asked to be kept. It does not chase and it does not strike. It sings: a
## ring that opens out of it, hurting what it passes and waking every other drowned thing
## in the room. Kill it first or fight the whole street.
## Or: bring it low and let it finish. Under a third of its health the note falters; stand close and
## press E, and the Choir is spared (an echo, home to the rock) instead of killed.

const SHEET := preload("res://assets/sprites/choir.png")
const KEEP_DISTANCE := 100.0
const SING_EVERY := 3.4
const WINDUP := 0.8
const NOTE := 0.55
const RECOVER := 1.1
const RING_MAX := 130.0
const RING_DAMAGE := 8
const KINDLE_TIME := 5.0
const SPARE_RANGE := 40.0

var _drift_dir: float = 1.0
var _sing_t: float = 0.0
var _hit_this_note: bool = false
var _prompt: Label
var spared: bool = false


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, anims(
		{"idle": "idle", "walk": "walk", "windup": "windup", "sing": "attack", "hurt": "hurt"}, {"idle": 2, "walk": 5}))
	_drift_dir = 1.0 if randf() < 0.5 else -1.0
	_sing_t = randf_range(0.8, 2.0)
	var glow := Atmosphere.light(self, Palette.VIOLET_LIGHT, 1.6, 0.35, Vector2(0, -10))
	Atmosphere.breathe(glow, 0.4, 0.8, 2.2)
	_prompt = UI.label("", 8, Color(0.95, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.size = Vector2(120, 10)
	_prompt.position = Vector2(-60, -30)
	_prompt.visible = false
	_prompt.z_index = 5
	add_child(_prompt)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle": play("idle")
		&"drift":
			play("walk")
			if randf() < 0.3:
				_drift_dir = -_drift_dir
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
			FX.burst(global_position + Vector2(0, -12), Color(0.85, 0.75, 1.0, 0.8), 6, 30.0)
		&"sing":
			play("sing")
			velocity = Vector2.ZERO
			_hit_this_note = false
			EventBus.request_shake.emit(0.35)
			FX.ring(global_position, Color(0.85, 0.75, 1.0), 2.6)
			Audio.play("bell", 0.0, -6.0)
			Audio.play("ebb", 0.05, -14.0)
			_kindle_the_street()
		&"recover":
			play("idle")
			velocity = Vector2.ZERO
		&"falter":
			# The note fails: it stands, the ring fades, and it can be let go.
			play("hurt")
			velocity = Vector2.ZERO
			FX.text(global_position + Vector2(0, -20), "THE NOTE FALTERS", Color(0.85, 0.75, 1.0))
			if hitbox and hitbox.active:
				hitbox.deactivate()


func _tick(delta: float) -> void:
	var d := to_player()
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO and d.length() < 240.0:
				change_state(&"drift")
		&"drift":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			var dist := d.length()
			var radial := d.normalized() * (1.0 if dist > KEEP_DISTANCE + 16.0 else (-1.0 if dist < KEEP_DISTANCE - 16.0 else 0.0))
			var tangent := d.normalized().orthogonal() * _drift_dir
			velocity = (radial * 0.8 + tangent * 0.6).normalized() * speed
			face(d.x)
			if is_on_wall():
				_drift_dir = -_drift_dir
			_sing_t += delta
			if _sing_t >= SING_EVERY:
				_sing_t = 0.0
				change_state(&"windup")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"sing")
		&"sing":
			velocity = Vector2.ZERO
			_tick_note()
			if state_t >= NOTE:
				change_state(&"recover")
		&"recover":
			velocity = Vector2.ZERO
			if state_t >= RECOVER:
				change_state(&"drift")
		&"falter":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			var near := d != Vector2.ZERO and d.length() < SPARE_RANGE
			_prompt.visible = near
			_prompt.text = UI.hint("interact") + " let it finish"
			if near and Input.is_action_just_pressed("interact"):
				_spare()


## The note is a ring that opens out of it: it catches you once, as it passes.
func _tick_note() -> void:
	var r := RING_MAX * (state_t / NOTE)
	if _hit_this_note or player == null or player.dead:
		return
	var dist := player.global_position.distance_to(global_position)
	if dist <= r and dist >= r - 26.0:
		_hit_this_note = true
		var info := DamageInfo.make(RING_DAMAGE, self, player.global_position - global_position, 140.0)
		info.tags = PackedStringArray(["song"])
		info.hitstop = 0.06
		if player.hurtbox.receive(info):
			FX.text(player.global_position, "THE NOTE", Color(0.85, 0.75, 1.0))


## Everything else in the room hears it and comes on faster.
func _kindle_the_street() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not (e is Enemy) or not is_instance_valid(e):
			continue
		e.kindle(KINDLE_TIME)
		if e.has_method("wake"):
			e.wake()


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"falter":
		return
	if health.hp * 10 <= health.max_hp * 3 and health.hp > 0 and is_elite and affix == "":
		change_state(&"falter")
		return
	if state == &"drift" or state == &"idle":
		play("hurt")
		stunned = 0.1


## Let go alive: leaves the fight without dying. The run treats it as the room clearing.
func _spare() -> void:
	if spared:
		return
	spared = true
	_prompt.visible = false
	remove_from_group("enemies")
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	FX.burst(global_position, Color(0.85, 0.8, 1.0), 18, 80.0)
	EventBus.enemy_spared.emit(self)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 1.2)
	tw.parallel().tween_property(sprite, "position:y", sprite.position.y - 18.0, 1.2)
	tw.tween_callback(queue_free)
	set_physics_process(false)
