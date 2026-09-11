class_name Atmosphere
extends RefCounted
## The night-at-the-shore look: a blue CanvasModulate, drifting sea spray, soft mist,
## and helpers for lights. Everything here is world-space, so the HUD stays crisp.

const GLOW := preload("res://assets/sprites/glow.png")
const NIGHT := Color(0.6, 0.68, 0.86)


static func build(parent: Node2D, size: Vector2) -> void:
	var cm := CanvasModulate.new()
	cm.name = "Night"
	cm.color = NIGHT
	parent.add_child(cm)

	var spray := CPUParticles2D.new()
	spray.name = "Spray"
	spray.amount = 46
	spray.lifetime = 7.0
	spray.preprocess = 7.0
	spray.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	spray.emission_rect_extents = size * 0.5 + Vector2(40, 40)
	spray.position = size * 0.5
	spray.direction = Vector2(1, 0.15)
	spray.spread = 12.0
	spray.gravity = Vector2.ZERO
	spray.initial_velocity_min = 10.0
	spray.initial_velocity_max = 26.0
	spray.scale_amount_min = 1.0
	spray.scale_amount_max = 1.0
	spray.color = Color(0.85, 0.93, 1.0, 0.28)
	spray.z_index = 6
	parent.add_child(spray)

	for i in 3:
		var mist := Sprite2D.new()
		mist.texture = GLOW
		mist.scale = Vector2(9, 5) * (1.0 + 0.3 * i)
		mist.modulate = Color(0.75, 0.88, 1.0, 0.05)
		mist.position = Vector2(size.x * (0.2 + 0.3 * i), size.y * (0.3 + 0.2 * (i % 2)))
		mist.z_index = 6
		parent.add_child(mist)
		var tw := parent.create_tween().set_loops()
		var drift := Vector2(40.0 + 15.0 * i, -12.0 + 8.0 * i)
		tw.tween_property(mist, "position", mist.position + drift, 9.0 + 2.0 * i).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(mist, "position", mist.position, 9.0 + 2.0 * i).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func light(parent: Node, color: Color, scale_mult: float, energy: float = 1.0, offset: Vector2 = Vector2.ZERO) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = GLOW
	l.texture_scale = scale_mult
	l.color = color
	l.energy = energy
	l.position = offset
	l.shadow_enabled = false
	parent.add_child(l)
	return l


static func breathe(l: PointLight2D, lo: float, hi: float, period: float) -> void:
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "energy", hi, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(l, "energy", lo, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
