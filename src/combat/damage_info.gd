class_name DamageInfo
extends RefCounted
## Everything a hit carries. Passed from Hitbox to Hurtbox.

var amount: int = 1
var source: Node = null
var direction: Vector2 = Vector2.ZERO  # normalised, from attacker toward target
var knockback: float = 0.0
var hitstop: float = 0.06
var tags: PackedStringArray = []  # e.g. "melee", "water", "third_hit"


static func make(p_amount: int, p_source: Node, p_direction: Vector2, p_knockback: float = 60.0) -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = p_amount
	d.source = p_source
	d.direction = p_direction.normalized()
	d.knockback = p_knockback
	return d
