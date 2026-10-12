extends Enemy
## Coral Crab (the Reef, map Stage 11h): a crab that grew a dead coral head for a shell. It
## sits hidden as one more coral head, and hidden it is hard to hurt. Come close and it bursts
## up, rears and pinches, then scuttles off to hide somewhere else. Left alone too long it
## creeps nearer under its head, so a room cannot end with one sulking out of reach.

const SHEET := preload("res://assets/sprites/coral_crab.png")
const AMBUSH := 64.0         # it bursts out at this range
const HIDDEN_ARMOUR := 0.35  # hidden, a blow does a third (a heavy crack still doubles it)
const WINDUP := 0.45
const PINCH_TIME := 0.22
const PINCH_SPEED := 210.0
const RECOVER := 0.45
const CREEP_AFTER := 4.0     # seconds hidden out of reach before it creeps
const CREEP_TIME := 1.1

var _hidden: bool = false
var _scuttle_t: float = 1.4
var _pinch_dir: Vector2 = Vector2.RIGHT


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, anims(
		{"hidden": "idle", "walk": "walk", "windup": "windup", "pinch": "attack", "hurt": "hurt"}, {"hidden": 2, "walk": 12}))


func _enter_state(s: StringName) -> void:
	_set_hidden(s == &"idle" or s == &"hidden")
	match s:
		&"idle", &"hidden":
			play("hidden")
			velocity = Vector2.ZERO
		&"scuttle", &"creep":
			play("walk")
			_scuttle_t = randf_range(1.1, 1.7)
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
			FX.burst(global_position + Vector2(0, -6), Color(0.85, 0.82, 0.78, 0.9), 6, 45.0)
		&"pinch":
			play("pinch")
			var d := to_player()
			_pinch_dir = d.normalized() if d != Vector2.ZERO else _pinch_dir
			face(_pinch_dir.x)
			hitbox.activate()
		&"recover":
			play("walk")
			hitbox.deactivate()


func _exit_state(s: StringName) -> void:
	if s == &"pinch":
		hitbox.deactivate()


## Hidden under its head: the armour goes on; out, it comes off (an elite's crust stays).
func _set_hidden(on: bool) -> void:
	if on == _hidden:
		return
	_hidden = on
	armour = armour * HIDDEN_ARMOUR if on else armour / HIDDEN_ARMOUR
	_refresh_mult()


func _tick(_delta: float) -> void:
	var d := to_player()
	var dist := d.length() if d != Vector2.ZERO else INF
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if dist < 900.0:
				change_state(&"hidden")
		&"hidden":
			velocity = Vector2.ZERO
			if dist < AMBUSH and state_t > 0.5:
				change_state(&"windup")
			elif state_t > CREEP_AFTER and dist > AMBUSH * 2.0 and dist < 900.0:
				change_state(&"creep")
		&"creep":
			# Toward the keeper under its head, then down again.
			velocity = d.normalized() * speed * 0.6 if d != Vector2.ZERO else Vector2.ZERO
			face(d.x)
			if dist < AMBUSH:
				change_state(&"windup")
			elif state_t >= CREEP_TIME:
				change_state(&"hidden")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"pinch")
		&"pinch":
			velocity = _pinch_dir * PINCH_SPEED
			if is_on_wall() or state_t >= PINCH_TIME:
				change_state(&"recover")
		&"recover":
			velocity = Vector2.ZERO
			if state_t >= RECOVER:
				change_state(&"scuttle")
		&"scuttle":
			# Away and sideways, to hide somewhere new.
			if d != Vector2.ZERO:
				velocity = (-d.normalized() + d.normalized().orthogonal() * 0.6).normalized() * speed
				face(-d.x)
			if is_on_wall() or state_t >= _scuttle_t:
				change_state(&"hidden")


func _on_hurt_extra(_info: DamageInfo) -> void:
	if _hidden:
		# The head takes it; a chip of coral flies.
		FX.burst(global_position + Vector2(0, -8), Color(0.85, 0.82, 0.78), 3, 35.0)
		return
	if state == &"scuttle" or state == &"recover":
		play("hurt")
		stunned = 0.12


func _on_hit_landed(_target: Hurtbox, _info: DamageInfo) -> void:
	change_state(&"recover")
