class_name Pickup
extends Area2D
## Salt (run currency) and pearls (meta currency). Pops out a short way, settles,
## then magnets to the player. Never leaves the room.

const SHEET := preload("res://assets/sprites/pickups.png")
enum Kind { SALT, PEARL }
const MAGNET_RANGE := 48.0
const MAGNET_SPEED := 220.0
const POP_DECEL := 320.0

var kind: Kind = Kind.SALT
var value: int = 1
var _vel: Vector2
var _age: float = 0.0
var _player: Player
var _room: Room


static func spawn(parent: Node, pos: Vector2, p_kind: Kind, p_value: int = 1) -> Pickup:
	var p := Pickup.new()
	p.kind = p_kind
	p.value = p_value
	p.position = pos
	parent.add_child(p)
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 6.0
	shape.shape = c
	add_child(shape)
	var s := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = SHEET
	at.region = Rect2(int(kind) * 8, 0, 8, 8)
	s.texture = at
	s.z_index = 2
	add_child(s)
	_vel = Vector2.from_angle(randf() * TAU) * randf_range(40.0, 80.0)
	_player = get_tree().get_first_node_in_group("player") as Player
	_room = get_tree().get_first_node_in_group("room") as Room
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	var magnet := false
	if _age > 0.3 and _player and is_instance_valid(_player) and not _player.dead:
		var to := _player.global_position - global_position
		if to.length() < MAGNET_RANGE:
			_vel = to.normalized() * MAGNET_SPEED
			magnet = true
	if not magnet:
		_vel = _vel.move_toward(Vector2.ZERO, POP_DECEL * delta)
	position += _vel * delta
	if _room:
		position = _room.clamp_inside(position)


func _on_body_entered(body: Node) -> void:
	if body is Player and _age > 0.15:
		EventBus.pickup_collected.emit(kind, value)
		FX.burst(global_position, Color(0.98, 0.85, 0.45) if kind == Kind.SALT else Color(0.9, 0.9, 0.95), 5, 30.0)
		Audio.play("pickup" if kind == Kind.SALT else "pearl", 0.12, -6.0, 60)
		queue_free()
