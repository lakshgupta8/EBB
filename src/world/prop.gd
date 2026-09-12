class_name Prop
extends Area2D
## Interactable world object (fountain, chest, merchant, altar, Orla...).
## Press E while inside to use it. Non-interactive kinds are just scenery.

signal used(prop: Prop)

const PROPS := preload("res://assets/sprites/props.png")
enum Kind { FOUNTAIN, CHEST, LIGHTHOUSE, MERCHANT, ALTAR, ORLA, CAGE, BRAM, WREN, CARTOGRAPHER, ECHO_GHOST, MAREN, FEN, VAULT }
const FRAMES := {Kind.FOUNTAIN: 0, Kind.CHEST: 1, Kind.LIGHTHOUSE: 3, Kind.MERCHANT: 4, Kind.ALTAR: 5, Kind.ORLA: 6,
	Kind.CAGE: 7, Kind.BRAM: 9, Kind.WREN: 10, Kind.CARTOGRAPHER: 11, Kind.ECHO_GHOST: 9, Kind.MAREN: 12, Kind.FEN: 13,
	Kind.VAULT: 14}
## Reusable props do not mark themselves used; the vault stays shut until the run opens it.
const REUSABLE := [Kind.MERCHANT, Kind.ORLA, Kind.BRAM, Kind.WREN, Kind.CARTOGRAPHER, Kind.MAREN, Kind.FEN, Kind.VAULT]
const SCENERY := [Kind.LIGHTHOUSE, Kind.ECHO_GHOST]
const ECHO_FRAME := {"bram": 9, "wren": 10, "cartographer": 11, "maren": 12}

var kind: Kind
var used_up: bool = false
var interactive: bool = true
var _sprite: Sprite2D
var _prompt: Label
var _player_inside: bool = false
## Blocks the same E press that closed a menu from re-opening it (the tree is paused
## while the menu is up, so this only counts down afterwards).
var _cooldown: float = 0.0


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
	if kind == Kind.LIGHTHOUSE:
		_sprite.texture = preload("res://assets/sprites/lighthouse.png")
		# Sprite is 48 tall; its rock base (rows 35-43) should sit on the footprint centre.
		_sprite.position = Vector2(0, -14)
		_sprite.z_index = 3
		var lamp := Atmosphere.light(self, Color(1.0, 0.85, 0.55), 7.0, 1.6, Vector2(0, -36))
		Atmosphere.breathe(lamp, 1.3, 1.9, 3.0)
	elif kind == Kind.FOUNTAIN:
		Atmosphere.light(self, Color(0.55, 0.8, 1.0), 2.5, 0.8, Vector2(0, -6))
	elif kind == Kind.VAULT:
		Atmosphere.light(self, Color(0.95, 0.85, 0.5), 2.0, 0.6, Vector2(0, -6))
	elif kind == Kind.ORLA or kind == Kind.BRAM or kind == Kind.MAREN or kind == Kind.FEN:
		Atmosphere.light(self, Color(1.0, 0.85, 0.65), 2.0, 0.6, Vector2(0, -8))
	elif kind == Kind.WREN:
		Atmosphere.light(self, Color(0.8, 0.9, 1.0), 2.0, 0.6, Vector2(0, -8))
	elif kind == Kind.CARTOGRAPHER:
		Atmosphere.light(self, Color(0.7, 0.8, 1.0), 1.6, 0.5, Vector2(0, -8))
	elif kind == Kind.CAGE:
		interactive = false  # the run opens it once the guards are dead
		var cl := Atmosphere.light(self, Color(0.7, 0.85, 1.0), 2.0, 0.5, Vector2(0, -8))
		Atmosphere.breathe(cl, 0.3, 0.7, 1.6)
	if kind == Kind.MERCHANT:
		var ml := Atmosphere.light(self, Color(0.5, 0.9, 0.9), 2.5, 0.8, Vector2(0, -8))
		Atmosphere.breathe(ml, 0.6, 1.0, 2.0)
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
		var al := Atmosphere.light(self, Color(0.8, 0.9, 1.0), 3.0, 1.0, Vector2(0, -10))
		Atmosphere.breathe(al, 0.8, 1.3, 2.0)
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
		_prompt.text = UI.hint("interact")
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
	if kind == Kind.CHEST or kind == Kind.VAULT:
		_sprite.texture = _frame(2)
	elif kind == Kind.ALTAR:
		_sprite.modulate = Color(0.7, 0.7, 0.75)
	elif kind == Kind.CAGE:
		_sprite.texture = _frame(8)


## The cage can be opened now (guards dead): show the prompt if the player is already here.
func unlock() -> void:
	interactive = true
	if _player_inside and not used_up:
		_prompt.visible = true


## Show a rescued echo standing free for a moment, then fading toward the surface.
func show_echo(echo_id: String) -> void:
	_sprite.texture = _frame(ECHO_FRAME.get(echo_id, 9))
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_sprite, "modulate:a", 0.0, 1.4)
	tw.parallel().tween_property(_sprite, "position:y", -22.0, 1.4)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0 and _player_inside and interactive and not used_up:
			_prompt.visible = true
		return
	if interactive and _player_inside and not used_up and Input.is_action_just_pressed("interact"):
		_cooldown = 0.25
		if not (kind in REUSABLE):
			mark_used()
		else:
			_prompt.visible = false
		Audio.play("ui", 0.0, -6.0)
		used.emit(self)
