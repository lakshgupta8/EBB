extends Node
## One-shot visual effects. Everything spawns into the current scene and frees itself.
## One effects language (art Stage 15, STYLE.md 14): every sheet is 2-3 palette colours with
## no outline, drawn at the size it plays at and never scaled or turned off the pixel grid
## (only the melee arc and the stab turn, with the aim). Bursts snap their colour to the
## palette and are capped, so no event is a fireworks show.

const SLASH := preload("res://assets/sprites/fx_slash.png")            # Salt white / Pale slate
const SLASH_WARM := preload("res://assets/sprites/fx_slash_warm.png")  # the lantern: Warm yellow / Amber
const STAB := preload("res://assets/sprites/fx_stab.png")
const SPARK := preload("res://assets/sprites/fx_spark.png")
const CRACK := preload("res://assets/sprites/fx_crack.png")
const RING16 := preload("res://assets/sprites/fx_ring16.png")
const RING32 := preload("res://assets/sprites/fx_ring32.png")
const RING96 := preload("res://assets/sprites/fx_ring96.png")
const LIT := preload("res://assets/sprites/fx_lit.png")
const STUN := preload("res://assets/sprites/fx_stun.png")
const BLEED := preload("res://assets/sprites/fx_bleed.png")
# Water (art Stage 10, STYLE.md 12): a splash on entering water, a ripple ring under wading
# feet, a bubble rising from deep water.
const SPLASH := preload("res://assets/sprites/fx_splash.png")
const RIPPLE := preload("res://assets/sprites/fx_ripple.png")
const BUBBLE := preload("res://assets/sprites/fx_bubble.png")

## Rings are drawn Salt white and tinted to one of these: cold, the flare, the strike cue,
## the Choir and the Deep, and a plain pale one.
const RING_TINTS: Array[Color] = [Palette.SEA_PALE, Palette.WARM_YELLOW, Palette.SALT_RED, Palette.VIOLET_LIGHT, Palette.PALE_SLATE]
## Bursts: at most this many 1-2 px specks, and never faster than this.
const BURST_MAX := 12
const BURST_SPEED_MAX := 90.0

## One SpriteFrames per sheet: one-shots are asked for many times a second.
var _frames_cache: Dictionary = {}

## Effects roll on their own stream: they are asked for things per frame, and the night
## must be the same night at any frame rate.
var _rng := RandomNumberGenerator.new()

var _flash_layer: CanvasLayer
var _flash_rect: ColorRect

## The palette, for snapping a colour literal to its nearest paint.
var _palette: Array[Color] = []


## A ring at one of three native sizes. `scale_mult` is the old 48 px multiplier, kept so
## every caller reads the same: under 0.75 the 16 px cue ring, under 1.5 the 32 px ring,
## otherwise the 96 px flare ring. The colour snaps to RING_TINTS.
func ring(pos: Vector2, color: Color, scale_mult: float = 1.0) -> void:
	var size := ring_size(scale_mult)
	var tex: Texture2D = RING16 if size == 16 else (RING32 if size == 32 else RING96)
	var s := _one_shot(tex, size, 3, 18.0, pos, 0.0, Vector2.ONE)
	s.modulate = ring_tint(color)


func ring_size(scale_mult: float) -> int:
	return 16 if scale_mult < 0.75 else (32 if scale_mult < 1.5 else 96)


func ring_tint(color: Color) -> Color:
	return nearest(color, RING_TINTS)


## The palette colour nearest to `color`: compared by hue and chroma first (the colour with
## its brightest channel at 1), then by value, so a pale cold blue stays cold rather than
## going grey. Alpha is kept.
func nearest(color: Color, candidates: Array[Color]) -> Color:
	var best := color
	var best_d := INF
	for c in candidates:
		var d := _norm(color).distance_to(_norm(c)) + 0.5 * absf(_value(color) - _value(c))
		if d < best_d:
			best_d = d
			best = c
	best.a = color.a
	return best


func _value(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b))


func _norm(c: Color) -> Vector3:
	var v := _value(c)
	return Vector3(c.r, c.g, c.b) / (v if v > 0.001 else 1.0)


func palette_colour(color: Color) -> Color:
	if _palette.is_empty():
		for name in Palette.BY_NAME:
			_palette.append(Palette.BY_NAME[name])
	return nearest(color, _palette)


## Floating world text that rises and fades (RIPTIDE, CRACK...).
func text(pos: Vector2, msg: String, color: Color, size: int = 8) -> void:
	# The colour snaps to the palette like a burst's (art Stage 22: a hundred call sites
	# pass literals, and the word over the world is a palette colour or it is wrong).
	var l := UI.label(msg, size, palette_colour(color), HORIZONTAL_ALIGNMENT_CENTER)
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
	if not Settings.flashes():
		return
	# STYLE.md 11: flashes stay, at most 0.4 alpha and 0.25 s.
	color.a = minf(color.a, 0.4)
	duration = minf(duration, 0.25)
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


## The melee arc: a 48 px crescent whose pivot (4, 24) sits on `pos`, turned to `angle`;
## `mirror` flips it for the return swing; `warm` is the lantern's arc. 4 frames at 30 fps.
func slash(pos: Vector2, angle: float, mirror: bool = false, warm: bool = false) -> void:
	var s := _one_shot(SLASH_WARM if warm else SLASH, 48, 4, 30.0, pos, angle, Vector2.ONE)
	s.offset = Vector2(20, 0)
	s.flip_v = mirror


## The knife: a 24x8 line with a bright tip, its left-centre on `pos`.
func stab(pos: Vector2, angle: float, mirror: bool = false) -> void:
	var s := _one_shot(STAB, 24, 3, 30.0, pos, angle, Vector2.ONE, 8)
	s.offset = Vector2(12, 0)
	s.flip_v = mirror


## Impact: a four-point cross that becomes four dots. Never turned.
func spark(pos: Vector2) -> void:
	_one_shot(SPARK, 12, 3, 24.0, pos, 0.0, Vector2.ONE)


## Heavy impact: a ring of six shards flying out.
func crack(pos: Vector2) -> void:
	_one_shot(CRACK, 24, 4, 24.0, pos, 0.0, Vector2.ONE)


## A bleed tick: two drops that fall 3 px and vanish.
func bleed(pos: Vector2) -> void:
	_one_shot(BLEED, 8, 2, 8.0, pos, 0.0, Vector2.ONE)


## A looping status overlay (LIT flames, STUN spray) for an enemy to keep and show or hide.
func overlay(kind: StringName, parent: Node, offset: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	var tex: Texture2D = LIT if kind == &"lit" else STUN
	var cell := 24 if kind == &"lit" else 16
	var cell_h := 24 if kind == &"lit" else 8
	var key := [tex, cell, 2, 6.0, cell_h]
	if not _frames_cache.has(key):
		_frames_cache[key] = SheetFrames.build(tex, cell, {"play": {"frames": [0, 1], "fps": 6.0 if kind == &"lit" else 4.0, "loop": true}}, cell_h)
	s.sprite_frames = _frames_cache[key]
	s.position = offset
	s.z_index = 5
	parent.add_child(s)
	s.play("play")
	return s


## A few 1-2 px specks. The colour snaps to the palette; the count and speed are capped
## (STYLE.md 14: no giant particle explosions).
func burst(pos: Vector2, color: Color, amount: int = 12, speed: float = 60.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = mini(amount, BURST_MAX)
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	p.direction = Vector2.ZERO
	p.spread = 180.0
	speed = minf(speed, BURST_SPEED_MAX)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = 80.0
	p.damping_max = 120.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = palette_colour(color)
	p.z_index = 5
	p.emitting = true
	_root().add_child(p)
	get_tree().create_timer(p.lifetime + 0.1).timeout.connect(p.queue_free)


## A single 1 px Sea pale drop falling from a wall top (the Streets and the Hall).
func drip(pos: Vector2, parent: Node) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 1
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.4
	p.direction = Vector2(0, 1)
	p.spread = 0.0
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 12.0
	p.gravity = Vector2(0, 60)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	p.color = Palette.SEA_PALE
	p.z_index = 2
	p.emitting = true
	parent.add_child(p)
	get_tree().create_timer(p.lifetime + 0.1).timeout.connect(p.queue_free)


## Entering water, or dashing through it: Salt white drops, no outline.
func splash(pos: Vector2) -> void:
	_one_shot(SPLASH, 16, 3, 12.0, pos + Vector2(0, -6), 0.0, Vector2.ONE)


## A ring under wading feet. Spawned into `parent` (the room) so it sits on the water and
## under the body: everything at z 0 draws in tree order.
func ripple(pos: Vector2, parent: Node = null) -> void:
	_one_shot(RIPPLE, 16, 3, 6.0, pos, 0.0, Vector2.ONE, 8, 0, parent)


## A bubble from deep water: rises 6 px and is gone.
func bubble(pos: Vector2, parent: Node = null) -> void:
	var s := _one_shot(BUBBLE, 4, 2, 3.0, pos, 0.0, Vector2.ONE, 4, 0, parent)
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", pos.y - 6.0, 0.66).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.66).set_delay(0.3)


func _one_shot(tex: Texture2D, cell: int, frames: int, fps: float, pos: Vector2, angle: float, scl: Vector2,
		cell_h: int = -1, z: int = 5, parent: Node = null) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	var key := [tex, cell, frames, fps, cell_h]
	if not _frames_cache.has(key):
		var idx := range(frames)
		_frames_cache[key] = SheetFrames.build(tex, cell, {"play": {"frames": idx, "fps": fps, "loop": false}}, cell_h)
	s.sprite_frames = _frames_cache[key]
	s.position = pos.round()
	s.rotation = angle
	s.scale = scl
	s.z_index = z
	s.animation_finished.connect(s.queue_free)
	(parent if parent != null else _root()).add_child(s)
	s.play("play")
	return s
