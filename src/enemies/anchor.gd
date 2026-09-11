extends Enemy
## Anchor: a drowned dock hand still dragging his anchor. Slow, heavy, and from a way off
## it throws the chain: if you are not dashing when it lands you are hauled in, and the
## anchor comes down on you next. Dash through the chain and it finds nothing.

const SHEET := preload("res://assets/sprites/anchor.png")
const CHAIN_RANGE := 150.0
const CHAIN_MIN := 40.0
const CHAIN_WINDUP := 0.7
const HAUL_TIME := 0.25
const SLAM_WINDUP := 0.5
const SLAM := 0.2
const RECOVER := 1.3
const CHAIN_DAMAGE := 6

var _chain: Line2D


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, {
		"idle": {"frames": [0, 1], "fps": 2},
		"walk": {"frames": [2, 3], "fps": 4},
		"windup": {"frames": [4], "fps": 1},
		"slam": {"frames": [5], "fps": 1},
		"hurt": {"frames": [6], "fps": 1},
	})
	_chain = Line2D.new()
	_chain.width = 1.0
	_chain.default_color = Color(0.75, 0.8, 0.85)
	_chain.z_index = 3
	_chain.visible = false
	add_child(_chain)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle": play("idle")
		&"walk": play("walk")
		&"chain_windup":
			play("windup")
			velocity = Vector2.ZERO
		&"haul":
			play("slam")
			velocity = Vector2.ZERO
			_throw_chain()
		&"slam_windup":
			play("windup")
			velocity = Vector2.ZERO
		&"slam":
			play("slam")
			velocity = Vector2.ZERO
			hitbox.activate()
			EventBus.request_shake.emit(0.5)
			FX.burst(global_position + Vector2(10, 6), Color(0.6, 0.62, 0.7), 12, 60.0)
			Audio.play("heavy", 0.1, -2.0)
		&"recover":
			play("idle")
			hitbox.deactivate()
			_chain.visible = false


func _exit_state(s: StringName) -> void:
	if s == &"slam":
		hitbox.deactivate()
	if s == &"haul":
		_chain.visible = false


func _throw_chain() -> void:
	var d := to_player()
	if d == Vector2.ZERO:
		return
	face(d.x)
	_chain.clear_points()
	_chain.add_point(Vector2(0, -6))
	_chain.add_point(to_local(player.global_position) + Vector2(0, -6))
	_chain.visible = true
	Audio.play("hook", 0.1, -2.0)
	if player.is_dashing() or player.is_yanked():
		FX.text(player.global_position, "SLIPPED", Color(0.7, 0.95, 1.0))
		return
	var info := DamageInfo.make(CHAIN_DAMAGE, self, d, 0.0)
	info.tags = PackedStringArray(["chain"])
	info.hitstop = 0.03
	if player.hurtbox.receive(info):
		player.yank_to(global_position + d.normalized() * 22.0, HAUL_TIME)
		FX.text(player.global_position, "HAULED", Color(0.9, 0.7, 0.6))


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
			var dist := d.length()
			velocity = d.normalized() * speed if dist > CHAIN_MIN else Vector2.ZERO
			if dist < CHAIN_RANGE and dist > CHAIN_MIN and state_t >= 0.8:
				change_state(&"chain_windup")
			elif dist <= CHAIN_MIN and state_t >= 0.4:
				change_state(&"slam_windup")
		&"chain_windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= CHAIN_WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= CHAIN_WINDUP:
				change_state(&"haul")
		&"haul":
			velocity = Vector2.ZERO
			if state_t >= HAUL_TIME + 0.05:
				change_state(&"slam_windup")
		&"slam_windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= SLAM_WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= SLAM_WINDUP:
				change_state(&"slam")
		&"slam":
			velocity = Vector2.ZERO
			if state_t >= SLAM:
				change_state(&"recover")
		&"recover":
			velocity = Vector2.ZERO
			if state_t >= RECOVER:
				change_state(&"walk")


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"walk" or state == &"idle":
		play("hurt")
		stunned = 0.15
