extends Node
## One-shot visual effects. Everything spawns into the current scene and frees itself.

const SLASH := preload("res://assets/sprites/fx_slash.png")
const SPARK := preload("res://assets/sprites/fx_spark.png")


func _root() -> Node:
	return get_tree().current_scene


func slash(pos: Vector2, angle: float, mirror: bool = false, scale_mult: float = 1.0) -> void:
	# Sheet pivot is at (4, 24) of a 48px cell; offset so the pivot sits on `pos`.
	var s := _one_shot(SLASH, 48, 4, 36.0, pos, angle, Vector2(1, -1 if mirror else 1) * scale_mult)
	s.offset = Vector2(20, 0)


func spark(pos: Vector2) -> void:
	_one_shot(SPARK, 12, 3, 24.0, pos, randf() * TAU, Vector2.ONE)


func burst(pos: Vector2, color: Color, amount: int = 12, speed: float = 60.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = 80.0
	p.damping_max = 120.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.emitting = true
	_root().add_child(p)
	get_tree().create_timer(p.lifetime + 0.1).timeout.connect(p.queue_free)


func _one_shot(tex: Texture2D, cell: int, frames: int, fps: float, pos: Vector2, angle: float, scl: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	var idx := range(frames)
	s.sprite_frames = SheetFrames.build(tex, cell, {"play": {"frames": idx, "fps": fps, "loop": false}})
	s.position = pos
	s.rotation = angle
	s.scale = scl
	s.z_index = 5
	s.animation_finished.connect(s.queue_free)
	_root().add_child(s)
	s.play("play")
	return s
