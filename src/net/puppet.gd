class_name Puppet
extends Node2D
## What the guest sees of something the host owns. It looks like the real thing (an enemy's own
## scene with its logic switched off, a keeper's sheet, a pickup's sprite) and does only what
## the host says: it sits where the interpolation buffer puts it and plays the animation the
## snapshot names.

const SHEET := preload("res://assets/sprites/player.png")
const ENEMY_FALLBACK := Color(0.72, 0.36, 0.34)

var net_id: int = 0
var scene_key: String = ""
var kind: int = 0
var buffer := InterpBuffer.new()
var visual: Node
var sprite: AnimatedSprite2D

var _last_anim: int = -1
var _flash: float = 0.0


static func make(p_id: int, p_kind: int, scene_key: String, at: Vector2) -> Puppet:
	var p := Puppet.new()
	p.net_id = p_id
	p.kind = p_kind
	p.scene_key = scene_key
	p.position = at
	p.visual = _build(p_kind, scene_key)
	p.add_child(p.visual)
	if p.visual is AnimatedSprite2D:
		p.sprite = p.visual
	return p


static func _build(p_kind: int, scene_key: String) -> Node:
	match p_kind:
		NetReplicator.Kind.PLAYER_HOST, NetReplicator.Kind.PLAYER_GUEST:
			var s := AnimatedSprite2D.new()
			s.sprite_frames = SheetFrames.build(SHEET, 24, Player.ANIMS)
			s.position = Vector2(0, -9)
			s.play("idle")
			return s
		NetReplicator.Kind.PROJECTILE:
			return _blob(Color(1.0, 0.9, 0.5), 3.0)
		NetReplicator.Kind.PICKUP:
			var sp := Sprite2D.new()
			var at := AtlasTexture.new()
			at.atlas = Pickup.SHEET
			at.region = Rect2(0, 0, 8, 8)
			sp.texture = at
			return sp
	var path := "res://src/%s.tscn" % scene_key
	if scene_key != "" and ResourceLoader.exists(path):
		var inst: Node = (load(path) as PackedScene).instantiate()
		_neutralise(inst)
		return inst
	return _blob(ENEMY_FALLBACK, 6.0)


## An enemy scene with its brain off: no thinking, no hitting, nothing to bump into.
static func _neutralise(n: Node) -> void:
	n.set_process(false)
	n.set_physics_process(false)
	if n is CollisionObject2D:
		n.collision_layer = 0
		n.collision_mask = 0
	for c in n.get_children():
		if c is Area2D:
			c.monitoring = false
			c.monitorable = false
			c.collision_layer = 0
			c.collision_mask = 0


static func _blob(color: Color, radius: float) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(Vector2.from_angle(TAU * float(i) / 10.0) * radius)
	poly.polygon = pts
	poly.color = color
	return poly


func flash() -> void:
	_flash = 0.12


## Where it is and what it is doing at `render_t_ms` on the host's clock.
func apply(render_t_ms: int) -> void:
	var s := buffer.sample(render_t_ms)
	if not bool(s.valid):
		return
	position = s.pos
	if sprite == null and visual != null:
		sprite = visual.get("sprite") as AnimatedSprite2D
	var anim := int(s.anim)
	if anim == _last_anim:
		return
	_last_anim = anim
	if sprite != null and sprite.sprite_frames != null:
		var nm: String = NetReplicator.ANIM_NAMES[clampi(anim, 0, NetReplicator.ANIM_NAMES.size() - 1)]
		if sprite.sprite_frames.has_animation(nm):
			sprite.play(nm)
	elif kind == NetReplicator.Kind.PICKUP and visual is Sprite2D:
		((visual as Sprite2D).texture as AtlasTexture).region = Rect2(anim * 8, 0, 8, 8)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
	var item: CanvasItem = sprite if sprite != null else (visual as CanvasItem)
	if item != null:
		item.modulate = Color.WHITE.lerp(Color(2.0, 2.0, 2.0), clampf(_flash / 0.12, 0.0, 1.0))
