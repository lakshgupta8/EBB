class_name CoopRules
extends RefCounted
## When a night with two keepers is over: only when both are down, and only once. A keeper
## who has fallen gets up again when the room is cleared. Index 0 is the host, 1 the guest.

var _down: Array = [false, false]
var _ended: bool = false


func is_down(i: int) -> bool:
	return bool(_down[i])


## A keeper fell. True exactly once: the call that makes both of them down.
func on_down(i: int) -> bool:
	_down[i] = true
	if _down[0] and _down[1] and not _ended:
		_ended = true
		return true
	return false


## The room is clear: everyone who fell stands up. Returns who.
func revive_all() -> Array:
	var out: Array = []
	for i in 2:
		if _down[i]:
			_down[i] = false
			out.append(i)
	return out
