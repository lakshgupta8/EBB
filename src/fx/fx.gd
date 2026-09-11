extends Node
## One-shot visual effects. Everything spawns into the current scene and frees itself.

const SLASH := preload("res://assets/sprites/fx_slash.png")
const SPARK := preload("res://assets/sprites/fx_spark.png")
const RING := preload("res://assets/sprites/fx_ring.png")

var _flash_layer: CanvasLayer
var _flash_rect: ColorRect


func ring(pos: Vector2, color: Color, scale_mult: float = 1.0) -> void:
	var s := _one_shot(RING, 48, 3, 24.0, pos, 0.0, Vector2.ONE * scale_mult)
	s.modulate = color


## Floating world text that rises and fades (RIPTIDE, CRACK...).
func text(pos: Vector2, msg: String, color: Color, size: int = 8) -> void:
	var l := UI.label(msg, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.size = Vector2(80, 10)
	l.position = pos + Vector2(-40, -20)
	l.z_index = 10
	_root().add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 14.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.tween_callback(l.queue_free)


## Full-screen colour flash.
func flash_screen(color: Color, duration: float = 0.25) -> void:
	if _flash_layer == null:
		_flash_layer = CanvasLayer.new()
		_flash_layer.layer = 4
		add_child(_flash_layer)
		_flash_rect = ColorRect.new()
		_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_layer.add_child(_flash_rect)
	_flash_rect.color = color
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, duration)


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
