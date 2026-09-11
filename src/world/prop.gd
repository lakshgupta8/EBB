class_name Prop
extends Area2D
## Interactable world object (fountain, chest, merchant, altar, Orla...).
## Press E while inside to use it. Non-interactive kinds are just scenery.

signal used(prop: Prop)

const PROPS := preload("res://assets/sprites/props.png")
enum Kind { FOUNTAIN, CHEST, LIGHTHOUSE, MERCHANT, ALTAR, ORLA }
const FRAMES := {Kind.FOUNTAIN: 0, Kind.CHEST: 1, Kind.LIGHTHOUSE: 3, Kind.MERCHANT: 4, Kind.ALTAR: 5, Kind.ORLA: 6}
const REUSABLE := [Kind.MERCHANT, Kind.ORLA]
const SCENERY := [Kind.LIGHTHOUSE]

var kind: Kind
var used_up: bool = false
var interactive: bool = true
var _sprite: Sprite2D
var _prompt: Label
var _player_inside: bool = false


func setup(p_kind: Kind, pos: Vector2) -> void:
	kind = p_kind
	position = pos
	interactive = not (kind in SCENERY)
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = _frame(FRAMES[kind])
	_sprite.position = Vector2(0, -4)
	add_child(_sprite)
	if kind == Kind.MERCHANT:
		_sprite.modulate = Color(1, 1, 1, 0.85)
		var bob := create_tween().set_loops()
		bob.tween_property(_sprite, "position:y", -6.0, 1.2).set_trans(Tween.TRANS_SINE)
		bob.tween_property(_sprite, "position:y", -4.0, 1.2).set_trans(Tween.TRANS_SINE)
	elif kind == Kind.ALTAR:
		var glow := Sprite2D.new()
		glow.texture = preload("res://assets/sprites/glow.png")
		glow.position = Vector2(0, -12)
		glow.modulate = Color(0.8, 0.9, 1.0, 0.5)
		glow.z_index = -1
		add_child(glow)
		var breathe := create_tween().set_loops()
		breathe.tween_property(glow, "modulate:a", 0.8, 1.0).set_trans(Tween.TRANS_SINE)
		breathe.tween_property(glow, "modulate:a", 0.4, 1.0).set_trans(Tween.TRANS_SINE)
	_prompt = UI.label("[E]", 8, Color(0.95, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.size = Vector2(24, 10)
	_prompt.position = Vector2(-12, -26)
	_prompt.visible = false
	add_child(_prompt)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(b: Node) -> void:
	if b is Player:
		_player_inside = true
		_prompt.visible = interactive and not used_up


func _on_body_exited(b: Node) -> void:
	if b is Player:
		_player_inside = false
		_prompt.visible = false


func _frame(i: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = PROPS
	at.region = Rect2(i * 16, 0, 16, 16)
	return at


func mark_used() -> void:
	used_up = true
	_prompt.visible = false
	if kind == Kind.CHEST:
		_sprite.texture = _frame(2)
	elif kind == Kind.ALTAR:
		_sprite.modulate = Color(0.7, 0.7, 0.75)


func _process(_delta: float) -> void:
	if interactive and _player_inside and not used_up and Input.is_action_just_pressed("interact"):
		if not (kind in REUSABLE):
			mark_used()
		else:
			_prompt.visible = false
		used.emit(self)
