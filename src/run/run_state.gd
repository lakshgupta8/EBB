class_name RunState
extends RefCounted
## Everything about the current run that is not a node.

var seed: int = 0
var biome: int = 0          # index into Run.BIOMES
var depth: int = 0          # within the biome
var depth_total: int = 0    # across the whole night
var rooms_cleared: int = 0
var kills: int = 0
var salt: int = 0
var pearls: int = 0
var time: float = 0.0
var ended: bool = false
var victory: bool = false
var taken: bool = false  # ended by the tide rather than an enemy
var bargain: bool = false  # Sea's Bargain: salt converts even when killed
var full_fountain: bool = false  # Deep Wells
var still_water: bool = false    # Still Water
var tide := TideSystem.new()
var tidemarks: Array = []  # ids, in the order they were taken
var echoes: Array = []     # echo ids rescued this run


func result() -> Dictionary:
	# Salt converts to pearls at the end: half if taken by the tide, none if killed.
	var bonus := (salt / 2) if (taken or bargain) else 0
	if victory:
		bonus = salt / 2 + 5 + 10 * biome
	return {
		"seed": seed, "biome": biome, "depth": depth_total, "rooms_cleared": rooms_cleared, "kills": kills,
		"salt": salt, "pearls": pearls + bonus, "pearls_from_salt": bonus,
		"time": time, "victory": victory, "taken": taken, "echoes": echoes.duplicate(),
	}
