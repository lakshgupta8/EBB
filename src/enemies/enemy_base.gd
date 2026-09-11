class_name Enemy
extends CharacterBody2D
## Shared enemy plumbing: health, hurt reaction, knockback, flash, death, facing.
## Subclasses implement _setup_animations() and _tick(delta) and drive `state`.

const FLASH_SHADER := preload("res://src/combat/hit_flash.gdshader")

@export var display_name: String = "Enemy"
@export var speed: float = 32.0
@export var knockback_resist: float = 0.0  # 0..1
@export var death_color: Color = Color(0.6, 0.7, 0.5)

var state: StringName = &"idle"
var state_t: float = 0.0  # seconds in current state
var player: Player
var stunned: float = 0.0
var _knockback: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = get_node_or_null("Hitbox")


func _ready() -> void:
	add_to_group("enemies")
	sprite.material = ShaderMaterial.new()
	sprite.material.shader = FLASH_SHADER
	_setup_animations()
	hurtbox.hit.connect(_on_hurt)
	health.died.connect(_on_died)
	if hitbox:
		hitbox.source = self
		hitbox.landed.connect(_on_hit_landed)
	player = get_tree().get_first_node_in_group("player") as Player
	_enter_state(&"idle")


func _setup_animations() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func change_state(new_state: StringName) -> void:
	if new_state == state:
		return
	_exit_state(state)
	state = new_state
	state_t = 0.0
	_enter_state(new_state)


func _enter_state(_s: StringName) -> void:
	pass


func _exit_state(_s: StringName) -> void:
	pass


func to_player() -> Vector2:
	if player == null or player.dead:
		return Vector2.ZERO
	return player.global_position - global_position


func face(dir_x: float) -> void:
	if absf(dir_x) > 0.1:
		sprite.flip_h = dir_x < 0.0
		if hitbox:
			hitbox.scale.x = -1.0 if dir_x < 0.0 else 1.0


func play(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


func _physics_process(delta: float) -> void:
	state_t += delta
	if stunned > 0.0:
		stunned -= delta
		velocity = _knockback
	else:
		_tick(delta)
		velocity += _knockback
	_knockback = _knockback.lerp(Vector2.ZERO, 12.0 * delta)
	move_and_slide()


func _on_hurt(info: DamageInfo) -> void:
	_knockback = info.direction * info.knockback * (1.0 - knockback_resist)
	stunned = maxf(stunned, 0.12)
	sprite.material.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_property(sprite.material, "shader_parameter/flash", 0.0, 0.15)
	_on_hurt_extra(info)


func _on_hurt_extra(_info: DamageInfo) -> void:
	pass


func _on_hit_landed(_target: Hurtbox, _info: DamageInfo) -> void:
	pass


func _on_died() -> void:
	FX.burst(global_position, death_color, 16, 90.0)
	FX.burst(global_position, Color.WHITE, 6, 50.0)
	EventBus.request_hitstop.emit(0.1)
	EventBus.request_shake.emit(0.3)
	EventBus.enemy_died.emit(self)
	queue_free()
