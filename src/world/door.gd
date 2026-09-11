class_name Door
extends Area2D
## An exit. Shows the icon of the room type behind it; passable once the room opens it.

signal entered(door: Door)

const ICONS := preload("res://assets/sprites/icons.png")
const DESCEND := -1  # hub-only door type

var room_type: int = 0
var cell: Vector2i
var is_open: bool = false

var _icon: Sprite2D
var _room: Room


func setup(p_room: Room, p_cell: Vector2i, p_type: int) -> void:
	_room = p_room
	cell = p_cell
	room_type = p_type
	position = p_room.cell_to_world(p_cell)
	collision_layer = 0
	collision_mask = 2  # player
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	shape.shape = rect
	add_child(shape)
	_icon = Sprite2D.new()
	_icon.z_index = 3
	if p_type >= 0:
		var at := AtlasTexture.new()
		at.atlas = ICONS
		at.region = Rect2(RoomGraph.ICON[p_type] * 12, 0, 12, 12)
		_icon.texture = at
	_icon.modulate = Color(0.5, 0.5, 0.55)
	# Push the icon toward the room interior so it is not hidden by the wall.
	var interior := _room.interior_dir(p_cell)
	_icon.position = interior * 14.0
	add_child(_icon)
	body_entered.connect(_on_body_entered)


func open() -> void:
	if is_open:
		return
	is_open = true
	_room.set_ground_tile(cell, Tiles.DOOR_OPEN)
	_icon.modulate = Color.WHITE
	var tw := create_tween().set_loops()
	tw.tween_property(_icon, "position:y", _icon.position.y - 2.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_icon, "position:y", _icon.position.y, 0.6).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node) -> void:
	if is_open and body is Player and not body.dead:
		entered.emit(self)
