extends Enemy
## Tallow: a keeper who stood in the hall so long the candle on his head ran down over
## him. Slow, heavy, and it does not want to touch you: it pours a sheet of hot wax on
## the floor and the pool keeps burning. The hall fills up with them if you let it.

const SHEET := preload("res://assets/sprites/tallow.png")
const WAX_TEX := preload("res://assets/sprites/wax.png")
const POOL_SCRIPT := preload("res://src/enemies/wax_pool.gd")
const POUR_RANGE := 90.0
const POUR_MIN := 26.0
const WINDUP := 0.7
const POUR := 0.3
const RECOVER := 1.2
const WAX_TIME := 6.0
const WAX_DAMAGE := 4
const WAX_TICK := 0.6
const MAX_POOLS := 3

var _pools: Array = []


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, {
		"idle": {"frames": [0, 1], "fps": 2},
		"walk": {"frames": [2, 3], "fps": 4},
		"windup": {"frames": [4], "fps": 1},
		"pour": {"frames": [5], "fps": 1},
		"hurt": {"frames": [6], "fps": 1},
	})
	var flame := Atmosphere.light(self, Color(1.0, 0.75, 0.4), 2.4, 0.9, Vector2(0, -18))
	Atmosphere.breathe(flame, 0.7, 1.1, 1.1)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle": play("idle")
		&"advance": play("walk")
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
		&"pour":
			play("pour")
			velocity = Vector2.ZERO
			_pour_wax()
		&"recover":
			play("idle")
			velocity = Vector2.ZERO


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
			var dist := d.length()
			# It keeps a little back: the wax does the work.
			velocity = d.normalized() * speed * (1.0 if dist > POUR_MIN else -0.6)
			if dist < POUR_RANGE and state_t >= 0.7:
				change_state(&"windup")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"pour")
		&"pour":
			velocity = Vector2.ZERO
			if state_t >= POUR:
				change_state(&"recover")
		&"recover":
			velocity = Vector2.ZERO
			if state_t >= RECOVER:
				change_state(&"advance")


## A pool of burning wax where you were standing. It burns for a while and it hurts.
func _pour_wax() -> void:
	if player == null or player.dead or get_parent() == null:
		return
	_pools = _pools.filter(func(p): return is_instance_valid(p))
	if _pools.size() >= MAX_POOLS:
		var oldest = _pools.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var at := player.global_position
	var pool := Area2D.new()
	pool.collision_layer = 0
	pool.collision_mask = 0
	pool.global_position = at
	pool.z_index = 1
	var s := Sprite2D.new()
	s.texture = WAX_TEX
	s.scale = Vector2(1.6, 1.6)
	pool.add_child(s)
	get_parent().add_child(pool)
	_pools.append(pool)
	Atmosphere.light(pool, Color(1.0, 0.7, 0.35), 2.6, 0.8)
	FX.burst(at, Color(1.0, 0.75, 0.4), 10, 50.0)
	Audio.play("kindle", 0.1, -2.0)
	# It burns whoever stands in it, cools, and fades. The pool looks after itself.
	pool.set_script(POOL_SCRIPT)
	pool.setup(WAX_TIME, WAX_DAMAGE, WAX_TICK, self)


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"advance" or state == &"idle":
		play("hurt")
		stunned = 0.1
