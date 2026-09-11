class_name Hurtbox
extends Area2D
## Receives hits. Sits on layer player_hurtbox or enemy_hurtbox, masks nothing.
## Expects a sibling Health node unless health_path is set.

signal hit(info: DamageInfo)
## A hit arrived while the owner was invulnerable (dash i-frames): a dodge.
signal dodged(info: DamageInfo)

@export var health_path: NodePath = ^"../Health"

var health: Health
var damage_mult: float = 1.0  # cracked shells, exposed bosses...


func _ready() -> void:
	health = get_node_or_null(health_path) as Health
	monitoring = false
	monitorable = true


func receive(info: DamageInfo) -> bool:
	if health == null:
		return false
	if health.invulnerable and health.is_alive():
		dodged.emit(info)
		return false
	if damage_mult != 1.0:
		info.amount = maxi(1, int(round(info.amount * damage_mult)))
	if not health.take(info):
		return false
	hit.emit(info)
	return true
