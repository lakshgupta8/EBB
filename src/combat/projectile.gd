class_name Projectile
extends Area2D
## Straight-line projectile. Hits the first hurtbox on its mask, dies on walls or timeout.

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 1.5
var damage: int = 5
var knockback: float = 80.0
var source: Node2D
var spin: float = 0.0
var _sprite: Sprite2D


static func spawn(parent: Node, pos: Vector2, vel: Vector2, p_damage: int, tex: Texture2D,
		p_source: Node2D, target_mask: int = 64, p_lifetime: float = 1.5) -> Projectile:
	var p := Projectile.new()
	p.position = pos
	p.velocity = vel
	p.damage = p_damage
	p.source = p_source
	p.lifetime = p_lifetime
	p.collision_layer = 0
	p.collision_mask = target_mask | 1  # target hurtboxes + world
	p._sprite = Sprite2D.new()
	p._sprite.texture = tex
	p.add_child(p._sprite)
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 4.0
	shape.shape = c
	p.add_child(shape)
	p.z_index = 3
	parent.add_child(p)
	return p


func _ready() -> void:
	area_entered.connect(_on_area)
	body_entered.connect(func(_b): _die())


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_sprite.rotation += spin * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_die()


func _on_area(area: Area2D) -> void:
	var hb := area as Hurtbox
	if hb == null:
		return
	var info := DamageInfo.make(damage, source, velocity, knockback)
	info.tags = PackedStringArray(["projectile"])
	if hb.receive(info):
		_die()


func _die() -> void:
	FX.burst(global_position, Color(0.7, 0.68, 0.6), 4, 30.0)
	queue_free()
