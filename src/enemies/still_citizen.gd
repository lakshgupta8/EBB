extends Enemy
## Still Citizen: a drowned townsperson frozen mid-step. Stands like a statue until you
## come close (or hit it), then comes at you fast, stabs, and freezes again where it stands.

const SHEET := preload("res://assets/sprites/still_citizen.png")
const WAKE_RANGE := 84.0
const STAB_RANGE := 24.0
const WINDUP := 0.32
const STAB := 0.12
const FREEZE := 1.1
const LOSE_RANGE := 220.0
const STATUE_TINT := Color(0.62, 0.66, 0.72)

## Boss-arena statues: only wake() wakes them, never proximity.
var dormant: bool = false
var _stab_dir: Vector2 = Vector2.RIGHT


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, anims(
		{"statue": "idle", "run": "walk", "windup": "windup", "stab": "attack", "hurt": "hurt"}, {"statue": 1, "run": 10}))
	sprite.modulate = STATUE_TINT


func _enter_state(s: StringName) -> void:
	match s:
		&"idle", &"freeze":
			play("statue")
			velocity = Vector2.ZERO
			sprite.modulate = STATUE_TINT
			if hitbox.active:
				hitbox.deactivate()
		&"chase":
			play("run")
			sprite.modulate = Color.WHITE
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
		&"stab":
			play("stab")
			var d := to_player()
			_stab_dir = d.normalized() if d != Vector2.ZERO else _stab_dir
			face(_stab_dir.x)
			hitbox.activate()
			FX.burst(global_position + Vector2(0, -4), Color(0.8, 0.85, 0.9, 0.8), 4, 30.0)


func _exit_state(s: StringName) -> void:
	if s == &"stab":
		hitbox.deactivate()


func wake() -> void:
	if state != &"idle" and state != &"freeze":
		return
	dormant = false
	FX.burst(global_position + Vector2(0, -6), Color(0.7, 0.72, 0.75), 10, 55.0)
	FX.ring(global_position, Color(0.8, 0.82, 0.9), 0.8)
	Audio.play("wake", 0.15, -4.0)
	change_state(&"chase")


func _tick(_delta: float) -> void:
	var d := to_player()
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if not dormant and d != Vector2.ZERO and d.length() < WAKE_RANGE:
				wake()
		&"chase":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			face(d.x)
			velocity = d.normalized() * speed
			if d.length() < STAB_RANGE:
				change_state(&"windup")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"stab")
		&"stab":
			velocity = _stab_dir * 70.0
			if state_t >= STAB:
				change_state(&"freeze")
		&"freeze":
			velocity = Vector2.ZERO
			if state_t >= FREEZE:
				if d != Vector2.ZERO and d.length() < LOSE_RANGE:
					change_state(&"chase")
				else:
					change_state(&"idle")


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"idle" or state == &"freeze":
		wake()
	elif state == &"chase":
		play("hurt")
		stunned = 0.15
