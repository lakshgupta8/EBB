class_name Hurtbox
extends Area2D
## Receives hits. Sits on layer player_hurtbox or enemy_hurtbox, masks nothing.
## Expects a sibling Health node unless health_path is set.

signal hit(info: DamageInfo)

@export var health_path: NodePath = ^"../Health"

var health: Health


func _ready() -> void:
	health = get_node_or_null(health_path) as Health
	monitoring = false
	monitorable = true


func receive(info: DamageInfo) -> bool:
	if health == null or not health.take(info):
		return false
	hit.emit(info)
	return true
