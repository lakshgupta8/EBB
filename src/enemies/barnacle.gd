extends Enemy
## Barnacle Swarm: a crust of barnacles that learned to move together. Scuttles in short
## bursts, lunges to bite, and when you break it up it is two smaller swarms.

const SHEET := preload("res://assets/sprites/barnacle.png")
## A broken swarm's half is its own sheet, not a scaled node (STYLE.md 1).
const SHEET_SMALL := preload("res://assets/sprites/barnacle_small.png")
const SCENE_PATH := "res://src/enemies/barnacle.tscn"
const BURST := 0.4
const PAUSE := 0.3
const BITE_RANGE := 34.0
const WINDUP := 0.35
const BITE := 0.2
const BITE_SPEED := 220.0
const RECOVER := 0.5

## A half of a broken swarm: smaller, weaker, and it does not split again.
var small: bool = false
var _burst_dir: Vector2 = Vector2.RIGHT


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET_SMALL if small else SHEET, 24, anims(
		{"idle": "idle", "walk": "walk", "windup": "windup", "bite": "attack", "hurt": "hurt"}, {"idle": 2, "walk": 8}))
	if small:
		health.max_hp = 3
		health.hp = 3
		salt_drop = 1
		speed *= 1.15


func _enter_state(s: StringName) -> void:
	match s:
		&"idle": play("idle")
		&"burst":
			play("walk")
			var d := to_player()
			var base := d.normalized() if d != Vector2.ZERO else _burst_dir
			_burst_dir = base.rotated(randf_range(-0.6, 0.6))
			face(_burst_dir.x)
		&"pause":
			play("idle")
			velocity = Vector2.ZERO
		&"windup":
			play("windup")
			velocity = Vector2.ZERO
		&"bite":
			play("bite")
			var d := to_player()
			_burst_dir = d.normalized() if d != Vector2.ZERO else _burst_dir
			face(_burst_dir.x)
			hitbox.activate()
			Audio.play("bite", 0.2, -8.0)
		&"recover":
			play("idle")
			hitbox.deactivate()
			velocity = Vector2.ZERO


func _exit_state(s: StringName) -> void:
	if s == &"bite":
		hitbox.deactivate()


func _tick(_delta: float) -> void:
	var d := to_player()
	match state:
		&"idle":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO and d.length() < 200.0:
				change_state(&"burst")
		&"burst":
			if d == Vector2.ZERO:
				change_state(&"idle")
				return
			velocity = _burst_dir * speed
			if d.length() < BITE_RANGE:
				change_state(&"windup")
			elif state_t >= BURST:
				change_state(&"pause")
		&"pause":
			if state_t >= PAUSE:
				change_state(&"burst")
		&"windup":
			velocity = Vector2.ZERO
			if d != Vector2.ZERO:
				face(d.x)
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"bite")
		&"bite":
			velocity = _burst_dir * BITE_SPEED
			if state_t >= BITE:
				change_state(&"recover")
		&"recover":
			if state_t >= RECOVER:
				change_state(&"burst")


func _on_hit_landed(_target: Hurtbox, _info: DamageInfo) -> void:
	change_state(&"recover")


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"burst" or state == &"pause" or state == &"idle":
		play("hurt")
		stunned = 0.12


## Broken up: two halves scatter from where it was.
func _on_died() -> void:
	if not small and get_parent() != null:
		var scene: PackedScene = load(SCENE_PATH)
		for i in 2:
			var e: Enemy = scene.instantiate()
			e.small = true
			var side := 1.0 if i == 0 else -1.0
			e.global_position = global_position + Vector2(side * 10.0, randf_range(-4.0, 4.0))
			get_parent().call_deferred("add_child", e)
			e.call_deferred("change_state", &"pause")
	super()
