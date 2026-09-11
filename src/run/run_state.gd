class_name RunState
extends RefCounted
## Everything about the current run that is not a node.

var seed: int = 0
var depth: int = 0
var rooms_cleared: int = 0
var kills: int = 0
var salt: int = 0
var pearls: int = 0
var time: float = 0.0
var ended: bool = false
var victory: bool = false
var taken: bool = false  # ended by the tide rather than an enemy
var tide := TideSystem.new()


func result() -> Dictionary:
	# Salt converts to pearls at the end: half if taken by the tide, none if killed.
	var bonus := (salt / 2) if taken else 0
	if victory:
		bonus = salt / 2 + 5
	return {
		"seed": seed, "depth": depth, "rooms_cleared": rooms_cleared, "kills": kills,
		"salt": salt, "pearls": pearls + bonus, "pearls_from_salt": bonus,
		"time": time, "victory": victory, "taken": taken,
	}
