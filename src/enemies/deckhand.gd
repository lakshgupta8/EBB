extends Enemy
## Deckhand: shield up, comes on slowly. The shield turns anything from the front; get
## behind him, or wait for the swing: the cutlass comes down hard and leaves him open.

const SHEET := preload("res://assets/sprites/deckhand.png")
const REACH := 30.0
const WINDUP := 0.5
const SWING := 0.2
const OPEN := 1.1

var guarding: bool = false


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, anims(
		{"idle": "idle", "walk": "walk", "windup": "windup", "swing": "attack", "hurt": "hurt"}, {"idle": 2, "walk": 5}))
	hurtbox.shielded.connect(_on_shielded)


func _set_guard(on: bool) -> void:
	guarding = on
	hurtbox.shield_count = 999 if on else 0


func _enter_state(s: StringName) -> void:
	match s:
		&"idle":
			play("idle")
			_set_guard(true)
		&"advance":
			play("walk")
			_set_guard(true)
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
		&"swing":
			play("swing")
			_set_guard(false)
			hitbox.activate()
			Audio.play("swing", 0.15, -4.0)
		&"open":
			play("hurt")
			hitbox.deactivate()
			velocity = Vector2.ZERO
			_set_guard(false)
			FX.text(global_position + Vector2(0, -20), "OPEN", Color(1.0, 0.85, 0.6))


func _exit_state(s: StringName) -> void:
	if s == &"swing":
		hitbox.deactivate()


func _tick(_delta: float) -> void:
	var d := to_player()
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO and d.length() < 220.0:
				change_state(&"advance")
		&"advance":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			face(d.x)
			velocity = d.normalized() * speed
			if d.length() < REACH:
				change_state(&"windup")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"swing")
		&"swing":
			velocity = Vector2.ZERO
			if state_t >= SWING:
				change_state(&"open")
		&"open":
			if state_t >= OPEN:
				change_state(&"advance")


## The shield only covers the front: a hit travelling the way he faces came from behind.
func _on_shielded(info: DamageInfo) -> void:
	var facing := Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	if info.direction.dot(facing) > 0.2:
		hurtbox.shield_count = 0
		hurtbox.receive(info)
		if guarding and health.is_alive():
			hurtbox.shield_count = 999
		return
	FX.spark(global_position + facing * 10.0 + Vector2(0, -6))
	FX.text(global_position + Vector2(0, -20), "BLOCKED", Color(0.8, 0.85, 0.95))
	Audio.play("reload", 0.1, -8.0)


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"advance" or state == &"idle":
		play("hurt")
		stunned = 0.12
