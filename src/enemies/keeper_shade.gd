extends Enemy
## Keeper's Shade: what is left of the keepers who came before you. It fights the way you
## do: whatever weapon you carry, it carries a dark copy. It circles, strikes in your own
## rhythm, then slips away like a dash.

const SHEET := preload("res://assets/sprites/keeper_shade.png")
## Tam's bolt in the Night ramp (art Stage 19): the Shade's own, not Tam's colours.
const BOLT := preload("res://assets/sprites/shade_bolt.png")
const CIRCLE_DISTANCE := 58.0
const RANGED_DISTANCE := 96.0
const STRIKE_EVERY := 1.6
const WINDUP := 0.35
const SLIP_TIME := 0.16
const SLIP_SPEED := 250.0

var _mode: String = "gaff"
var _strafe_dir: float = 1.0
var _act_t: float = 0.0
var _hits_left: int = 0
var _hit_t: float = 0.0
var _strike_dir: Vector2 = Vector2.RIGHT


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, anims(
		{"idle": "idle", "walk": "walk", "windup": "windup", "strike": "attack", "hurt": "hurt"}, {"idle": 3, "walk": 9}))
	_mode = Game.weapon_id()
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	_act_t = randf_range(0.4, 1.0)
	var eyes := Atmosphere.light(self, Atmosphere.COLD, 1.0, 0.4, Vector2(0, -12), true)
	Atmosphere.breathe(eyes, 0.4, 0.8, 1.2)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle": play("idle")
		&"circle": play("walk")
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
		&"strike":
			play("strike")
			var d := to_player()
			_strike_dir = d.normalized() if d != Vector2.ZERO else _strike_dir
			face(_strike_dir.x)
			match _mode:
				"net": _hits_left = 3
				"gaff": _hits_left = 2
				_: _hits_left = 1
			_hit_t = 0.0
			_do_hit()
		&"slip":
			play("walk")
			hitbox.deactivate()
			velocity = (-_strike_dir).rotated(_strafe_dir * 0.8) * SLIP_SPEED
			FX.burst(global_position + Vector2(0, 4), Color(0.4, 0.6, 0.8, 0.8), 6, 30.0)
			Audio.play("dash", 0.2, -10.0)


func _exit_state(s: StringName) -> void:
	if s == &"strike":
		hitbox.deactivate()


func _do_hit() -> void:
	_hits_left -= 1
	match _mode:
		"harpoon":
			var p := Projectile.spawn(get_parent(), global_position + Vector2(0, -6) + _strike_dir * 12.0, _strike_dir * 380.0, 9, BOLT, self, 64, 0.45)
			p.rotation = _strike_dir.angle()
			p.knockback = 90.0
			Audio.play("harpoon", 0.2, -6.0)
		_:
			hitbox.deactivate()
			hitbox.activate()
			FX.slash(global_position + Vector2(0, -6), _strike_dir.angle(), _hits_left % 2 == 0, _mode == "lantern")
			Audio.play("swing", 0.2, -6.0)


func _tick(delta: float) -> void:
	var d := to_player()
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO and d.length() < 240.0:
				change_state(&"circle")
		&"circle":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			var dist := d.length()
			var keep := RANGED_DISTANCE if _mode == "harpoon" else CIRCLE_DISTANCE
			var radial := d.normalized() * (1.0 if dist > keep + 10.0 else (-1.0 if dist < keep - 10.0 else 0.0))
			var tangent := d.normalized().orthogonal() * _strafe_dir
			velocity = (radial + tangent * 0.7).normalized() * speed
			face(d.x)
			if is_on_wall():
				_strafe_dir = -_strafe_dir
			_act_t += delta
			if _act_t >= STRIKE_EVERY and dist < keep + 40.0:
				_act_t = 0.0
				change_state(&"windup")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"strike")
		&"strike":
			velocity = _strike_dir * (60.0 if _mode != "harpoon" else 0.0)
			_hit_t += delta
			if _hits_left > 0 and _hit_t >= (0.14 if _mode == "net" else 0.25):
				_hit_t = 0.0
				_do_hit()
			elif _hits_left <= 0 and _hit_t >= 0.16:
				change_state(&"slip")
		&"slip":
			if state_t >= SLIP_TIME:
				velocity = Vector2.ZERO
				change_state(&"circle")


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"circle" or state == &"idle":
		play("hurt")
		stunned = 0.15


func _on_hit_landed(_target: Hurtbox, _info: DamageInfo) -> void:
	if _hits_left <= 0:
		change_state(&"slip")
