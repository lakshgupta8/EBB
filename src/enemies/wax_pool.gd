extends Area2D
## A pool of burning wax on the floor (Tallow leaves these). Hurts whoever stands in it
## every WAX_TICK seconds, cools, then fades. Owns nothing but itself.

const RADIUS := 20.0

var _life: float = 6.0
var _damage: int = 4
var _tick: float = 0.6
var _t: float = 0.0
var _source: Node2D


func setup(life: float, damage: int, tick: float, source: Node2D) -> void:
	_life = life
	_damage = damage
	_tick = tick
	_source = source
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = RADIUS
	shape.shape = c
	add_child(shape)


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		set_process(false)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.6)
		tw.tween_callback(queue_free)
		return
	# The last second it dims: it is going out, and it stops burning with it.
	modulate = Color(1, 1, 1, 1.0) if _life > 1.0 else Color(1, 1, 1, _life)
	_t += delta
	if _t < _tick:
		return
	_t = 0.0
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.dead:
		return
	if p.global_position.distance_to(global_position) > RADIUS:
		return
	var info := DamageInfo.make(_damage, _source, Vector2.ZERO, 0.0)
	info.tags = PackedStringArray(["wax", "burn"])
	info.hitstop = 0.0
	if p.hurtbox.receive(info):
		FX.burst(p.global_position, Color(1.0, 0.75, 0.4), 5, 30.0)
