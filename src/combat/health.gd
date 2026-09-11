class_name Health
extends Node
## Hit points plus invulnerability windows. Emits, never decides what death looks like.

signal changed(current: int, max_hp: int)
signal damaged(info: DamageInfo)
signal died()

@export var max_hp: int = 10
@export var iframe_time: float = 0.0  # seconds of immunity after a hit

var hp: int
var invulnerable: bool = false  # external toggle (dash, cutscene)
var _iframes: float = 0.0


func _ready() -> void:
	hp = max_hp
	changed.emit(hp, max_hp)


func _process(delta: float) -> void:
	if _iframes > 0.0:
		_iframes -= delta


func is_alive() -> bool:
	return hp > 0


func can_take_damage() -> bool:
	return hp > 0 and not invulnerable and _iframes <= 0.0


func take(info: DamageInfo) -> bool:
	if not can_take_damage():
		return false
	hp = maxi(0, hp - info.amount)
	_iframes = iframe_time
	changed.emit(hp, max_hp)
	damaged.emit(info)
	if hp == 0:
		died.emit()
	return true


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	changed.emit(hp, max_hp)
