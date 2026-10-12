extends Enemy
## THE REEFWARDEN - the Reef's named elite (map Stage 11i). One of the divers who kept
## Saltmere's sea wall, still in his suit: lead boots, so the current cannot move him, and a
## mason's maul. Close, he brings it down where you stand. At a distance he strikes the floor
## and sends a surge rolling at you that shoves you hard, into the channel or onto the coral.
## Get behind the surge's line, or dash through it.

const SHEET := preload("res://assets/sprites/reefwarden.png")
const SURGE := preload("res://assets/sprites/surge.png")
const REACH := 32.0
const SLAM_WINDUP := 0.55
const SLAM := 0.18
const SLAM_RECOVER := 0.75
const SURGE_MIN := 60.0
const SURGE_RANGE := 210.0
const SURGE_WINDUP := 0.75
const SURGE_EVERY := 4.5
const SURGE_SPEED := 115.0
const SURGE_DAMAGE := 6
const SURGE_SHOVE := 260.0
const SURGE_RADIUS := 8.0

var _surge_t: float = 0.0


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, anims(
		{"idle": "idle", "walk": "walk", "windup": "windup", "slam": "attack", "hurt": "hurt"}, {"idle": 2, "walk": 4}))
	_surge_t = randf_range(1.5, 3.0)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle": play("idle")
		&"advance": play("walk")
		&"windup", &"surge_windup":
			play("windup")
			velocity = Vector2.ZERO
		&"slam":
			play("slam")
			velocity = Vector2.ZERO
			hitbox.activate()
			EventBus.request_shake.emit(0.15)
			Audio.play("swing", 0.1, -1.0)
		&"surge":
			play("slam")
			velocity = Vector2.ZERO
			_send_surge()
		&"recover":
			play("idle")
			hitbox.deactivate()
			velocity = Vector2.ZERO


func _exit_state(s: StringName) -> void:
	if s == &"slam":
		hitbox.deactivate()


func _tick(delta: float) -> void:
	var d := to_player()
	_surge_t += delta
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO and d.length() < 240.0:
				change_state(&"advance")
		&"advance":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			face(d.x)
			velocity = d.normalized() * speed
			var dist := d.length()
			if dist < REACH:
				change_state(&"windup")
			elif _surge_t >= SURGE_EVERY and dist > SURGE_MIN and dist < SURGE_RANGE:
				_surge_t = 0.0
				change_state(&"surge_windup")
		&"windup", &"surge_windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			var wind := SLAM_WINDUP if state == &"windup" else SURGE_WINDUP
			if state_t >= wind - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= wind:
				change_state(&"slam" if state == &"windup" else &"surge")
		&"slam":
			velocity = Vector2.ZERO
			if state_t >= SLAM:
				change_state(&"recover")
		&"surge":
			velocity = Vector2.ZERO
			if state_t >= 0.35:
				change_state(&"advance")
		&"recover":
			velocity = Vector2.ZERO
			if state_t >= SLAM_RECOVER:
				change_state(&"advance")


## The maul strikes the floor in front of him and a surge rolls out toward where you are.
func _send_surge() -> void:
	var d := to_player()
	var dir := d.normalized() if d != Vector2.ZERO else Vector2.RIGHT
	var at := global_position + dir * 14.0
	var p := Projectile.spawn(get_parent(), at, dir * SURGE_SPEED, SURGE_DAMAGE, SURGE, self, 64, 2.2)
	p.knockback = SURGE_SHOVE
	p.tags = PackedStringArray(["projectile", "surge"])
	for c in p.get_children():
		if c is CollisionShape2D and c.shape is CircleShape2D:
			(c.shape as CircleShape2D).radius = SURGE_RADIUS
	FX.burst(at, Color(0.75, 0.9, 0.95, 0.9), 10, 55.0)
	FX.ring(at, Palette.FOAM_WHITE, 0.6)
	EventBus.request_shake.emit(0.2)
	Audio.play("splash", 0.1, -2.0)


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"advance" or state == &"idle":
		play("hurt")
		stunned = 0.1
