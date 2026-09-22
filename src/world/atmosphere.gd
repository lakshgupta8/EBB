class_name Atmosphere
extends RefCounted
## The night-at-the-shore look (STYLE.md 11, 13): a near-neutral CanvasModulate (the art is
## painted for night), drifting salt haze and the light helpers (spray rises from the shore
## in Room, art Stage 15). Everything here
## is world-space, so the HUD stays crisp.

## PointLight2D textures: a two-zone falloff (flat core, steep edge) so pools read as lantern
## light with an edge, not fog. The small one is for candles, eyes and pickups.
const GLOW := preload("res://assets/sprites/glow.png")
const GLOW_SMALL := preload("res://assets/sprites/glow_small.png")
## A soft sprite for haze and the glow sprites under doors and altars.
const HAZE := preload("res://assets/sprites/haze.png")
## The night tint. Runs use Palette.NIGHT_TINT_RUN (run.gd); the hub and title this.
const NIGHT := Palette.NIGHT_TINT_HUB
## The three light colours (STYLE.md 11). Warm sources: Tam plus at most three on screen.
const WARM := Color(0.9702, 0.8690, 0.6220)   # Warm yellow, 60 % toward Pale cream
const FLAME := Color(0.9059, 0.6725, 0.2980)  # Amber, halfway to Warm yellow: open flames
const COLD := Palette.SEA_PALE                # doors, fountains, altars, cages, the drowned


static func build(parent: Node2D, size: Vector2, tint: Color = NIGHT) -> void:
	var cm := CanvasModulate.new()
	cm.name = "Night"
	cm.color = tint
	parent.add_child(cm)

	var haze := Node2D.new()
	haze.name = "Haze"
	haze.z_index = 6
	parent.add_child(haze)
	for i in 3:
		var mist := Sprite2D.new()
		mist.texture = HAZE
		mist.scale = Vector2(3.5, 2.0) * (1.0 + 0.3 * i)
		mist.modulate = Color(Palette.SALT_WHITE, 0.05)
		mist.position = Vector2(size.x * (0.2 + 0.3 * i), size.y * (0.3 + 0.2 * (i % 2)))
		haze.add_child(mist)
		var tw := parent.create_tween().set_loops()
		var drift := Vector2(40.0 + 15.0 * i, -12.0 + 8.0 * i)
		tw.tween_property(mist, "position", mist.position + drift, 9.0 + 2.0 * i).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(mist, "position", mist.position, 9.0 + 2.0 * i).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Salt haze per place (STYLE.md 13): the Flats and the hub have three in Salt white, the
## Streets none (enclosed), the Hall a single lower, colder one in Sea.
static func set_haze(parent: Node, look: int) -> void:
	var haze := parent.get_node_or_null("Haze")
	if haze == null:
		return
	var i := 0
	for mist in haze.get_children():
		match look:
			Tiles.Look.STREETS:
				mist.visible = false
			Tiles.Look.DEEP:
				mist.visible = i == 2
				mist.modulate = Color(Palette.SEA, 0.04)
			_:
				mist.visible = true
				mist.modulate = Color(Palette.SALT_WHITE, 0.05)
		i += 1


static func light(parent: Node, color: Color, scale_mult: float, energy: float = 1.0, offset: Vector2 = Vector2.ZERO,
		small: bool = false) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = GLOW_SMALL if small else GLOW
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
