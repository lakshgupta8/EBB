class_name Prop
extends Area2D
## Interactable world object (fountain, chest, ...). Press E while inside to use it.

signal used(prop: Prop)

const PROPS := preload("res://assets/sprites/props.png")
enum Kind { FOUNTAIN, CHEST, LIGHTHOUSE }

var kind: Kind
var used_up: bool = false
var _sprite: Sprite2D
var _prompt: Label
var _player_inside: bool = false


func setup(p_kind: Kind, pos: Vector2) -> void:
	kind = p_kind
	position = pos
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = _frame({Kind.FOUNTAIN: 0, Kind.CHEST: 1, Kind.LIGHTHOUSE: 3}[kind])
	_sprite.position = Vector2(0, -4)
	add_child(_sprite)
	_prompt = Label.new()
	_prompt.text = "E"
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.position = Vector2(-3, -24)
	_prompt.visible = false
	add_child(_prompt)
	body_entered.connect(func(b): if b is Player: _player_inside = true; _prompt.visible = not used_up)
	body_exited.connect(func(b): if b is Player: _player_inside = false; _prompt.visible = false)


func _frame(i: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = PROPS
	at.region = Rect2(i * 16, 0, 16, 16)
	return at


func _process(_delta: float) -> void:
	if _player_inside and not used_up and Input.is_action_just_pressed("interact"):
		used_up = kind != Kind.LIGHTHOUSE
		_prompt.visible = false
		if kind == Kind.CHEST:
			_sprite.texture = _frame(2)
		used.emit(self)
