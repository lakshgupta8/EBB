extends Enemy
## Shellback: slow, tanky, telegraphs a shell slam. The tutorial enemy.

const SHEET := preload("res://assets/sprites/shellback.png")
const ATTACK_RANGE := 24.0
const WINDUP := 0.55
const SLAM := 0.15
const RECOVER := 0.7


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, {
		"idle": {"frames": [0, 1], "fps": 2},
		"walk": {"frames": [2, 3], "fps": 5},
		"windup": {"frames": [4], "fps": 1},
		"slam": {"frames": [5], "fps": 1},
		"hurt": {"frames": [6], "fps": 1},
	})


func _enter_state(s: StringName) -> void:
	match s:
		&"idle": play("idle")
		&"chase": play("walk")
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
		&"slam":
			play("slam")
			hitbox.activate()
			EventBus.request_shake.emit(0.15)
			FX.burst(global_position + Vector2(0, 6), Color(0.75, 0.68, 0.5, 0.9), 8, 40.0)
		&"recover":
			play("idle")


func _exit_state(s: StringName) -> void:
	if s == &"slam":
		hitbox.deactivate()


func _tick(_delta: float) -> void:
	var d := to_player()
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO and d.length() < 160.0:
				change_state(&"chase")
		&"chase":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			face(d.x)
			velocity = d.normalized() * speed
			if d.length() < ATTACK_RANGE:
				change_state(&"windup")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= WINDUP:
				change_state(&"slam")
		&"slam":
			velocity = Vector2.ZERO
			if state_t >= SLAM:
				change_state(&"recover")
		&"recover":
			velocity = Vector2.ZERO
			if state_t >= RECOVER:
				change_state(&"chase")


func _on_hurt_extra(_info: DamageInfo) -> void:
	# Windup is not interrupted (it is a tank), but chasing is.
	if state == &"chase" or state == &"idle":
		play("hurt")
		stunned = 0.2
