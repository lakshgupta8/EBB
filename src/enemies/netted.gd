extends Enemy
## THE NETTED - the Flats' named elite. A fisherman who went over the side and came back
## up inside his own net. He walks you down, and when there is room he throws the net:
## stand in it and you are rooted where you stand while he closes. Cut the net with a
## dash, or do not be there.

const SHEET := preload("res://assets/sprites/netted.png")
const THROWN_NET := preload("res://assets/sprites/net_thrown.png")  # 2 x 16x16: gathered, spread
const REACH := 30.0
const SWING_WINDUP := 0.45
const SWING := 0.18
const SWING_RECOVER := 0.7
const THROW_RANGE := 170.0
const THROW_MIN := 50.0
const THROW_WINDUP := 0.65
const THROW_EVERY := 4.0
const NET_RADIUS := 30.0
const NET_ROOT := 1.1
const NET_DAMAGE := 5

var _throw_t: float = 0.0
var _net: Sprite2D


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, anims(
		{"idle": "idle", "walk": "walk", "windup": "windup", "throw": "attack", "hurt": "hurt"}, {"idle": 2, "walk": 5}))
	_throw_t = randf_range(1.0, 2.5)
	_net = Sprite2D.new()
	_net.texture = THROWN_NET
	_net.hframes = 2
	_net.z_index = 4
	_net.top_level = true
	_net.visible = false
	add_child(_net)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle": play("idle")
		&"advance": play("walk")
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
		&"swing":
			play("throw")
			velocity = Vector2.ZERO
			hitbox.activate()
			Audio.play("swing", 0.15, -2.0)
		&"throw_windup":
			play("windup")
			velocity = Vector2.ZERO
		&"throw":
			play("throw")
			velocity = Vector2.ZERO
			_throw_net()
		&"recover":
			play("idle")
			hitbox.deactivate()
			velocity = Vector2.ZERO


func _exit_state(s: StringName) -> void:
	if s == &"swing":
		hitbox.deactivate()


func _tick(delta: float) -> void:
	var d := to_player()
	_throw_t += delta
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO and d.length() < 230.0:
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
			elif _throw_t >= THROW_EVERY and dist > THROW_MIN and dist < THROW_RANGE:
				_throw_t = 0.0
				change_state(&"throw_windup")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= SWING_WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= SWING_WINDUP:
				change_state(&"swing")
		&"swing":
			velocity = Vector2.ZERO
			if state_t >= SWING:
				change_state(&"recover")
		&"throw_windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= THROW_WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= THROW_WINDUP:
				change_state(&"throw")
		&"throw":
			velocity = Vector2.ZERO
			if state_t >= 0.3:
				change_state(&"advance")
		&"recover":
			velocity = Vector2.ZERO
			if state_t >= SWING_RECOVER:
				change_state(&"advance")


## The net flies to where you were and lands. Rooted, you cannot walk; a dash tears free.
func _throw_net() -> void:
	if player == null or player.dead:
		return
	var at := player.global_position
	_net.visible = true
	_net.modulate = Color(1, 1, 1, 0.95)
	_net.global_position = global_position + Vector2(0, -8)
	_net.frame = 0   # gathered in the hand; it opens where it lands (no scale, no turn: STYLE.md 1)
	Audio.play("net", 0.1, -2.0)
	var tw := create_tween()
	tw.tween_property(_net, "global_position", at, 0.22)
	tw.tween_callback(_land_net.bind(at))
	tw.tween_interval(NET_ROOT)
	tw.tween_property(_net, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): _net.visible = false)


func _land_net(at: Vector2) -> void:
	_net.frame = 1
	FX.burst(at, Color(0.85, 0.75, 0.55, 0.9), 8, 45.0)
	if player == null or player.dead:
		return
	if player.global_position.distance_to(at) > NET_RADIUS:
		return
	if player.is_dashing() or player.is_yanked():
		FX.text(player.global_position, "CUT FREE", Color(0.7, 0.95, 1.0))
		return
	var info := DamageInfo.make(NET_DAMAGE, self, player.global_position - at, 0.0)
	info.tags = PackedStringArray(["net"])
	info.hitstop = 0.04
	if player.hurtbox.receive(info):
		player.root(NET_ROOT)
		FX.text(player.global_position, "NETTED", Color(0.95, 0.85, 0.6))


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"advance" or state == &"idle":
		play("hurt")
		stunned = 0.12
