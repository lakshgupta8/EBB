extends Enemy
## Deep Maw: a mouth in the floor of the hall. It does not move. Walk near it and it opens
## (the floor shudders first), then snaps shut on everything above it. While it hangs open
## afterwards it can be hurt badly.

const SHEET := preload("res://assets/sprites/deep_maw.png")
const WAKE_RANGE := 58.0
const WINDUP := 0.6
const BITE := 0.2
const OPEN := 1.6
const CLOSED_TINT := Color(0.75, 0.78, 0.85, 0.9)


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, {
		"closed": {"frames": [0], "fps": 1},
		"windup": {"frames": [4], "fps": 1},
		"bite": {"frames": [5], "fps": 1},
		"open": {"frames": [6], "fps": 1},
	})
	sprite.position = Vector2(0, 0)
	sprite.modulate = CLOSED_TINT
	z_index = -1  # in the floor


func _enter_state(s: StringName) -> void:
	match s:
		&"idle":
			play("closed")
			sprite.modulate = CLOSED_TINT
			_refresh_mult()
		&"windup":
			play("windup")
			sprite.modulate = Color.WHITE
			FX.burst(global_position, Color(0.5, 0.52, 0.6), 8, 40.0)
			EventBus.request_shake.emit(0.2)
			Audio.play("wake", 0.2, -8.0)
		&"bite":
			play("bite")
			hitbox.activate()
			EventBus.request_shake.emit(0.5)
			Audio.play("bite", 0.1)
			FX.burst(global_position, Color(0.3, 0.25, 0.3), 12, 60.0)
		&"open":
			play("open")
			hitbox.deactivate()
			_refresh_mult()


func _exit_state(s: StringName) -> void:
	if s == &"bite":
		hitbox.deactivate()


## Hangs open after a bite: double damage until it shuts.
func _refresh_mult() -> void:
	super()
	if state == &"open":
		hurtbox.damage_mult *= 2.0


func _tick(_delta: float) -> void:
	velocity = Vector2.ZERO
	var d := to_player()
	match state:
		&"idle":
			if d != Vector2.ZERO and d.length() < WAKE_RANGE:
				change_state(&"windup")
		&"windup":
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"bite")
		&"bite":
			if state_t >= BITE:
				change_state(&"open")
		&"open":
			if state_t >= OPEN:
				change_state(&"idle")


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"idle":
		change_state(&"windup")
