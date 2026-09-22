extends Enemy
## Bell Ringer: slow and heavy, carries a hand bell. Walks up, lifts the bell (long tell),
## and rings it: a shockwave around itself that also calls two of the drowned up
## from the water (or wakes citizens when the streets are dry).

const SHEET := preload("res://assets/sprites/bell_ringer.png")
const CITIZEN := preload("res://src/enemies/still_citizen.tscn")
const SWIMMER := preload("res://src/enemies/swimmer.tscn")
const RING_RANGE := 72.0
const CALL_RANGE := 120.0
const WINDUP := 1.0
const RING := 0.25
const RECOVER := 1.5
const WALK_LIMIT := 2.8
const MAX_MINIONS := 2

var _minions: Array = []


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, anims(
		{"idle": "idle", "walk": "walk", "windup": "windup", "ring": "attack", "hurt": "hurt"}, {"idle": 2, "walk": 5}))


func _enter_state(s: StringName) -> void:
	match s:
		&"idle": play("idle")
		&"walk": play("walk")
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
		&"ring":
			play("ring")
			velocity = Vector2.ZERO
			hitbox.activate()
			EventBus.request_shake.emit(0.45)
			FX.ring(global_position, Color(0.95, 0.85, 0.6), 1.6)
			FX.ring(global_position, Color(1.0, 0.95, 0.8), 0.8)
			Audio.play("bell", 0.08, -3.0)
			_summon()
		&"recover":
			play("idle")
			hitbox.deactivate()


func _exit_state(s: StringName) -> void:
	if s == &"ring":
		hitbox.deactivate()


func _tick(_delta: float) -> void:
	var d := to_player()
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO and d.length() < 220.0:
				change_state(&"walk")
		&"walk":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			face(d.x)
			velocity = d.normalized() * speed
			if d.length() < RING_RANGE or (state_t >= WALK_LIMIT and d.length() < CALL_RANGE):
				change_state(&"windup")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"ring")
		&"ring":
			velocity = Vector2.ZERO
			if state_t >= RING:
				change_state(&"recover")
		&"recover":
			velocity = Vector2.ZERO
			if state_t >= RECOVER:
				change_state(&"walk")


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
		var at := global_position + Vector2(side * 36.0, randf_range(-24.0, 24.0))
		e.global_position = room.clamp_inside(at) if room else at
		content.add_child(e)
		e.salt_drop = 1
		if not wet:
			e.call_deferred("wake")
		_minions.append(e)
		FX.burst(e.global_position, Color(0.5, 0.75, 0.85), 8, 50.0)


func _on_hurt_extra(_info: DamageInfo) -> void:
	# Heavy: the windup is not interrupted. Walking is.
	if state == &"walk" or state == &"idle":
		play("hurt")
		stunned = 0.2
