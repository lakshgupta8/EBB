class_name ComboTracker
extends RefCounted
## Pure logic for N-step melee combos: which swing comes next, and when the chain resets.

var max_steps: int = 3
var reset_after: float = 0.5  # seconds of no attack before the chain resets

var step: int = 0  # last swing performed, 0 = none
var _last_time: float = -1000.0


func _init(p_max_steps: int = 3, p_reset_after: float = 0.5) -> void:
	max_steps = p_max_steps
	reset_after = p_reset_after


## Returns the swing index (1..max_steps) to perform now.
func next_step(now: float) -> int:
	if now - _last_time > reset_after or step >= max_steps:
		step = 0
	step += 1
	_last_time = now
	return step


func reset() -> void:
	step = 0
	_last_time = -1000.0


func is_finisher(s: int) -> bool:
	return s == max_steps
