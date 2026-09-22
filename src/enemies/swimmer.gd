extends Enemy
## Swimmer: one of the drowned that never left the water. Fast where the streets are
## flooded, slow and clumsy on dry stone. Winds up and darts at you with its jaw open.

const SHEET := preload("res://assets/sprites/swimmer.png")
const BITE_RANGE := 36.0
const WINDUP := 0.35
const DART_TIME := 0.28
const DART_SPEED := 250.0
const RECOVER := 0.7

var _dart_dir: Vector2 = Vector2.RIGHT


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, anims(
		{"swim": "idle", "crawl": "walk", "windup": "windup", "bite": "attack", "hurt": "hurt"}, {"swim": 6, "crawl": 5}))


func _enter_state(s: StringName) -> void:
	match s:
		&"idle", &"chase":
			play("swim")
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
		&"bite":
			play("bite")
			var d := to_player()
			_dart_dir = d.normalized() if d != Vector2.ZERO else _dart_dir
			face(_dart_dir.x)
			hitbox.activate()
			FX.burst(global_position + Vector2(0, 4), Color(0.6, 0.85, 0.9, 0.8), 6, 40.0)
		&"recover":
			play("swim")
			hitbox.deactivate()


func _exit_state(s: StringName) -> void:
	if s == &"bite":
		hitbox.deactivate()


func _tick(_delta: float) -> void:
	var d := to_player()
	var wet := room != null and room.is_flooded_at(global_position)
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				change_state(&"chase")
		&"chase":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			play("swim" if wet else "crawl")
			face(d.x)
			velocity = d.normalized() * speed
			if d.length() < BITE_RANGE:
				change_state(&"windup")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"bite")
		&"bite":
			velocity = _dart_dir * DART_SPEED
			if state_t >= DART_TIME or is_on_wall():
				change_state(&"recover")
		&"recover":
			velocity = (-_dart_dir) * speed * 0.4
			if state_t >= RECOVER:
				change_state(&"chase")


func _on_hurt_extra(_info: DamageInfo) -> void:
	play("hurt")
	if state == &"windup":
		change_state(&"recover")
	stunned = 0.2


func _on_hit_landed(_target: Hurtbox, _info: DamageInfo) -> void:
	change_state(&"recover")
