class_name Prop
extends Area2D
## Interactable world object (fountain, chest, merchant, altar, Orla...).
## Press E while inside to use it. Non-interactive kinds are just scenery.

signal used(prop: Prop)

const PROPS := preload("res://assets/sprites/props.png")
## The lighthouse beam: a light texture, not a giant pool (STYLE.md 11; art Stage 19).
const BEAM := preload("res://assets/sprites/beam.png")
enum Kind { FOUNTAIN, CHEST, LIGHTHOUSE, MERCHANT, ALTAR, ORLA, CAGE, BRAM, WREN, CARTOGRAPHER, ECHO_GHOST, MAREN, FEN, VAULT,
	NESSA, IDRIS, ALDOUS, PELL, CHOIR, LANTERN_POST, DOCK }
const FRAMES := {Kind.FOUNTAIN: 0, Kind.CHEST: 1, Kind.LIGHTHOUSE: 3, Kind.MERCHANT: 4, Kind.ALTAR: 5, Kind.ORLA: 6,
	Kind.CAGE: 7, Kind.BRAM: 9, Kind.WREN: 10, Kind.CARTOGRAPHER: 11, Kind.ECHO_GHOST: 9, Kind.MAREN: 12, Kind.FEN: 13,
	Kind.VAULT: 14, Kind.NESSA: 15, Kind.IDRIS: 16, Kind.ALDOUS: 17, Kind.PELL: 18, Kind.CHOIR: 19, Kind.LANTERN_POST: 20,
	Kind.DOCK: 20}
## Reusable props do not mark themselves used; the vault stays shut until the run opens it.
const REUSABLE := [Kind.MERCHANT, Kind.ORLA, Kind.BRAM, Kind.WREN, Kind.CARTOGRAPHER, Kind.MAREN, Kind.FEN, Kind.VAULT,
	Kind.NESSA, Kind.IDRIS, Kind.ALDOUS, Kind.PELL, Kind.CHOIR]
const SCENERY := [Kind.LIGHTHOUSE, Kind.ECHO_GHOST, Kind.LANTERN_POST, Kind.DOCK]
const PEOPLE := [Kind.ORLA, Kind.BRAM, Kind.WREN, Kind.CARTOGRAPHER, Kind.MAREN, Kind.FEN, Kind.NESSA, Kind.IDRIS,
	Kind.ALDOUS, Kind.PELL, Kind.CHOIR]
const ECHO_FRAME := {"bram": 9, "wren": 10, "cartographer": 11, "maren": 12, "pell": 18, "aldous": 17, "choir": 19}
## The portrait each person shows when they talk: a 16x16 cell of portraits.png
## (tools/gen_people.py, art Stage 19).
const PORTRAITS := preload("res://assets/sprites/portraits.png")
const PORTRAIT := {"orla": 0, "fen": 1, "nessa": 2, "idris": 3, "bram": 4, "maren": 5, "wren": 6, "cartographer": 7,
	"pell": 8, "aldous": 9, "choir": 10, "merchant": 11}
## Every person stands on a two-frame 24 px sheet of their own (STYLE.md 7, 18; art Stages
## 06 and 19): the living breathe, the drowned drip.
const NPC_SHEETS := {Kind.MAREN: preload("res://assets/sprites/npc_maren.png"),
	Kind.BRAM: preload("res://assets/sprites/npc_bram.png"),
	Kind.ORLA: preload("res://assets/sprites/npc_orla.png"),
	Kind.FEN: preload("res://assets/sprites/npc_fen.png"),
	Kind.NESSA: preload("res://assets/sprites/npc_nessa.png"),
	Kind.IDRIS: preload("res://assets/sprites/npc_idris.png"),
	Kind.WREN: preload("res://assets/sprites/npc_wren.png"),
	Kind.CARTOGRAPHER: preload("res://assets/sprites/npc_cartographer.png"),
	Kind.PELL: preload("res://assets/sprites/npc_pell.png"),
	Kind.ALDOUS: preload("res://assets/sprites/npc_aldous.png"),
	Kind.CHOIR: preload("res://assets/sprites/npc_choir.png"),
	Kind.MERCHANT: preload("res://assets/sprites/npc_merchant.png")}
const ECHO_SHEET := {"maren": Kind.MAREN, "bram": Kind.BRAM, "wren": Kind.WREN, "cartographer": Kind.CARTOGRAPHER,
	"pell": Kind.PELL, "aldous": Kind.ALDOUS, "choir": Kind.CHOIR}
## Major props drawn at the size they need (STYLE.md 1), anchored at the bottom centre:
## texture, cell size, sprite offset. The cage has two frames (shut, open).
const BIG := {
	Kind.FOUNTAIN: [preload("res://assets/sprites/prop_fountain.png"), Vector2i(32, 32), Vector2(0, -14)],
	Kind.ALTAR: [preload("res://assets/sprites/prop_altar.png"), Vector2i(24, 32), Vector2(0, -14)],
	Kind.CAGE: [preload("res://assets/sprites/prop_cage.png"), Vector2i(24, 24), Vector2(0, -10)],
	Kind.VAULT: [preload("res://assets/sprites/prop_vault.png"), Vector2i(24, 24), Vector2(0, -10)],
}

var kind: Kind
var used_up: bool = false
var interactive: bool = true
var _sprite: Sprite2D
## A person's two-frame idle (the living breathe at 1.5 fps, the drowned drip slower).
var _anim: AnimatedSprite2D
## The lighthouse's beam, turning.
var _beam: PointLight2D
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
	if kind in BIG:
		_sprite.texture = _big_frame(0)
		_sprite.position = BIG[kind][2]
	if kind in NPC_SHEETS:
		_sprite.visible = false
		var drowned := kind in [Kind.BRAM, Kind.WREN, Kind.CARTOGRAPHER, Kind.PELL, Kind.ALDOUS, Kind.CHOIR, Kind.MERCHANT]
		_anim = AnimatedSprite2D.new()
		_anim.sprite_frames = SheetFrames.build(NPC_SHEETS[kind], 24, {"idle": {"frames": [0, 1], "fps": 0.8 if drowned else 1.5}})
		_anim.position = Vector2(0, -8)
		_anim.frame = randi() % 2
		_anim.play("idle")
		add_child(_anim)
	if kind == Kind.LIGHTHOUSE:
		_sprite.texture = preload("res://assets/sprites/lighthouse.png")
		# Sprite is 48 tall; its rock base (rows 35-43) should sit on the footprint centre.
		_sprite.position = Vector2(0, -14)
		_sprite.z_index = 3
		var lamp := Atmosphere.light(self, Atmosphere.WARM, 2.4, 0.6, Vector2(0, -36))
		Atmosphere.breathe(lamp, 0.54, 0.66, 3.0)
		_beam = PointLight2D.new()
		_beam.texture = BEAM
		_beam.offset = Vector2(128, 0)
		_beam.color = Atmosphere.WARM
		_beam.energy = 1.0
		_beam.position = Vector2(0, -36)
		_beam.rotation = 0.6
		_beam.shadow_enabled = false
		add_child(_beam)
	elif kind == Kind.FOUNTAIN:
		Atmosphere.light(self, Atmosphere.COLD, 1.6, 0.4, Vector2(0, -6))
	elif kind == Kind.VAULT:
		Atmosphere.light(self, Atmosphere.COLD, 1.4, 0.4, Vector2(0, -6))
	elif kind == Kind.DOCK:
		_sprite.texture = preload("res://assets/sprites/dock.png")
		_sprite.position = Vector2(16, -2)
		_sprite.z_index = 1
	elif kind == Kind.LANTERN_POST:
		_sprite.z_index = 3
		var pl := Atmosphere.light(self, Atmosphere.WARM, 2.0, 0.5, Vector2(0, -12))
		Atmosphere.breathe(pl, 0.46, 0.54, 2.6)
	elif kind == Kind.FEN:
		# Fen's lamp: the one warm light among the people (STYLE.md 11).
		Atmosphere.light(self, Atmosphere.WARM, 1.6, 0.4, Vector2(0, -8))
	elif kind == Kind.WREN or kind == Kind.CHOIR:
		Atmosphere.light(self, Atmosphere.COLD, 1.4, 0.3, Vector2(0, -8))
	elif kind == Kind.CARTOGRAPHER or kind == Kind.PELL:
		Atmosphere.light(self, Atmosphere.COLD, 1.2, 0.3, Vector2(0, -8))
	elif kind == Kind.CAGE:
		interactive = false  # the run opens it once the guards are dead
		var cl := Atmosphere.light(self, Atmosphere.COLD, 1.4, 0.35, Vector2(0, -8))
		Atmosphere.breathe(cl, 0.25, 0.4, 1.6)
	if kind == Kind.MERCHANT:
		var ml := Atmosphere.light(self, Atmosphere.COLD, 1.6, 0.4, Vector2(0, -8))
		Atmosphere.breathe(ml, 0.32, 0.45, 2.0)
		# The drowned pedlar: preserved, not floating (STYLE.md 18); the cold light says the rest.
		var body: Node2D = _anim if _anim else _sprite
		body.modulate = Color(1, 1, 1, 0.92)
	elif kind == Kind.ALTAR:
		var glow := Sprite2D.new()
		glow.texture = Atmosphere.HAZE
		glow.position = Vector2(0, -12)
		glow.scale = Vector2(0.5, 0.5)
		glow.modulate = Color(Atmosphere.COLD, 0.5)
		glow.z_index = -1
		add_child(glow)
		var breathe := create_tween().set_loops()
		breathe.tween_property(glow, "modulate:a", 0.8, 1.0).set_trans(Tween.TRANS_SINE)
		breathe.tween_property(glow, "modulate:a", 0.4, 1.0).set_trans(Tween.TRANS_SINE)
		var al := Atmosphere.light(self, Atmosphere.COLD, 2.0, 0.5, Vector2(0, -10))
		Atmosphere.breathe(al, 0.42, 0.55, 2.0)
	_prompt = UI.label(UI.hint("interact"), 8, Color(0.95, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
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


func _big_frame(i: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = BIG[kind][0]
	var c: Vector2i = BIG[kind][1]
	at.region = Rect2(i * c.x, 0, c.x, c.y)
	return at


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
	elif kind == Kind.VAULT:
		_sprite.texture = _big_frame(1)
	elif kind == Kind.ALTAR:
		_sprite.modulate = Color(0.7, 0.7, 0.75)
	elif kind == Kind.CAGE:
		_sprite.texture = _big_frame(1)


## The cage can be opened now (guards dead): show the prompt if the player is already here.
func unlock() -> void:
	interactive = true
	if _player_inside and not used_up:
		_prompt.visible = true


## Show a rescued echo standing free for a moment, then fading toward the surface.
func show_echo(echo_id: String) -> void:
	if echo_id in ECHO_SHEET:
		var at := AtlasTexture.new()
		at.atlas = NPC_SHEETS[ECHO_SHEET[echo_id]]
		at.region = Rect2(0, 0, 24, 24)
		_sprite.texture = at
		_sprite.position = Vector2(0, -8)
	else:
		_sprite.texture = _frame(ECHO_FRAME.get(echo_id, 9))
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_sprite, "modulate:a", 0.0, 1.4)
	tw.parallel().tween_property(_sprite, "position:y", -22.0, 1.4)


func _process(delta: float) -> void:
	if _beam:
		_beam.rotation += delta * 0.42
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
