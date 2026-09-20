class_name Door
extends Area2D
## An exit. A stone archway in the wall with a big icon and label showing what is
## behind it. Barred until the room opens it, then it glows and the icon bobs.
## The arch shows the water too (art Stage 10): a shut door with the tide against it is
## water-closed (grate down, water line across), an open one is flooded (dark water in the
## arch, foam on the sill), and the wet way is a low arch, barred while shut and a Sea-lit
## passage once open.

signal entered(door: Door)

const ICONS := preload("res://assets/sprites/icons.png")
const FRAME := preload("res://assets/sprites/door.png")
const GLOW := preload("res://assets/sprites/glow.png")
const DESCEND := -1  # hub door, and the way down out of a boss arena
## door.png cells.
enum Frame { SHUT, OPEN, WATER_CLOSED, FLOODED, WET_SHUT, WET_OPEN }

var room_type: int = 0
var cell: Vector2i
var is_open: bool = false
var wet: bool = false  # the flooded way at the fork
var flooded: bool = false  # the tide has reached the doorway

var _icon: Sprite2D
var _label: Label
var _glow: Sprite2D
var _frame: Sprite2D
var _room: Room
var _interior: Vector2


func setup(p_room: Room, p_cell: Vector2i, p_type: int) -> void:
	_room = p_room
	cell = p_cell
	room_type = p_type
	position = p_room.cell_to_world(p_cell)
	_interior = _room.interior_dir(p_cell)
	collision_layer = 0
	collision_mask = 2  # player
	# Trigger covers the doorway and one tile into the room, so brushing the mouth
	# of an open door is enough. Rotated so the long axis points inward.
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 30)
	shape.shape = rect
	shape.rotation = Vector2.DOWN.angle_to(_interior)
	shape.position = _interior * 7.0
	add_child(shape)

	# Archway, drawn with its opening facing the interior.
	_frame = Sprite2D.new()
	_frame.offset = Vector2(0, 2)
	_frame.rotation = Vector2.DOWN.angle_to(_interior)
	_frame.z_index = 2
	add_child(_frame)
	flooded = _room.is_flooded_at(position)
	_refresh_frame()

	_glow = Sprite2D.new()
	_glow.texture = GLOW
	_glow.position = _interior * 6.0
	_glow.modulate = Color(0.55, 0.85, 1.0, 0.0)
	_glow.z_index = 2
	add_child(_glow)

	# Hanging signboard (24px, 1:1 with the world) just inside the doorway.
	_icon = Sprite2D.new()
	_icon.z_index = 4
	if p_type >= 0:
		_icon.texture = _atlas(ICONS, RoomGraph.ICON[p_type], 24)
	_icon.modulate = Color(0.55, 0.55, 0.6)
	_icon.position = _interior * 24.0
	add_child(_icon)

	_label = UI.label((RoomGraph.NAMES[p_type] if p_type >= 0 else "Descend").to_upper(), 8,
		Color(0.95, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_label.size = Vector2(80, 10)
	_label.position = _icon.position + Vector2(-40, 12)
	_label.modulate = Color(1, 1, 1, 0.0)
	_label.z_index = 4
	add_child(_label)
	body_entered.connect(_on_body_entered)


func _atlas(tex: Texture2D, index: int, cell_size: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(index * cell_size, 0, cell_size, cell_size)
	return at


## Which arch to show: the wet way has its own pair; otherwise the tide decides.
static func frame_for(p_wet: bool, p_open: bool, p_flooded: bool) -> int:
	if p_wet:
		return Frame.WET_OPEN if p_open else Frame.WET_SHUT
	if p_flooded:
		return Frame.FLOODED if p_open else Frame.WATER_CLOSED
	return Frame.OPEN if p_open else Frame.SHUT


func _refresh_frame() -> void:
	_frame.texture = _atlas(FRAME, frame_for(wet, is_open, flooded), 32)


## The wet way: same room type, already under water, tinted so. Usually a shortcut too.
func set_wet(shortcut: bool = true) -> void:
	wet = true
	_label.text = (RoomGraph.NAMES[room_type] if room_type >= 0 else "Descend").to_upper() + (" (WET SHORTCUT)" if shortcut else " (WET)")
	_label.size = Vector2(140, 10)
	# Side doors sit on the room's edge: slide the wider label inward so it is not cut off.
	_label.position = _icon.position + Vector2(-70, 12) + Vector2(_interior.x * 50.0, 0)
	_icon.modulate = Color(0.4, 0.5, 0.65)
	_refresh_frame()


## Replace the signboard text (the hub's shore says what the night holds).
func set_label(text: String) -> void:
	_label.text = text
	_label.size = Vector2(140, 10)
	_label.position = _icon.position + Vector2(-70, 12)


func open() -> void:
	if is_open:
		return
	is_open = true
	_room.set_ground_tile(cell, Tiles.DOOR_OPEN)
	_refresh_frame()
	_icon.modulate = Color(0.65, 0.85, 1.0) if wet else Color.WHITE
	_label.modulate = Color(1, 1, 1, 1)
	# Pop, then bob forever; glow breathes.
	_icon.scale = Vector2(1.6, 1.6)
	var pop := create_tween()
	pop.tween_property(_icon, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bob := create_tween().set_loops()
	bob.tween_property(_icon, "position", _icon.position - _interior * 3.0, 0.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_icon, "position", _icon.position, 0.6).set_trans(Tween.TRANS_SINE)
	var breathe := create_tween().set_loops()
	breathe.tween_property(_glow, "modulate:a", 0.75, 0.8).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(_glow, "modulate:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	FX.burst(global_position + _interior * 8.0, Color(0.6, 0.85, 1.0), 10, 40.0)
	var l := Atmosphere.light(self, Color(0.55, 0.8, 1.0), 2.2, 0.9, _interior * 10.0)
	Atmosphere.breathe(l, 0.7, 1.1, 1.6)
	Audio.play("door", 0.05, -4.0)


func _physics_process(_delta: float) -> void:
	# The tide reaches the doorway: the arch changes with it.
	var now := _room.is_flooded_at(position)
	if now != flooded:
		flooded = now
		_refresh_frame()
	# body_entered misses a player already standing in the doorway when it opens.
	if not is_open:
		return
	for b in get_overlapping_bodies():
		_on_body_entered(b)


func _on_body_entered(body: Node) -> void:
	if is_open and body is Player and not body.dead:
		entered.emit(self)
