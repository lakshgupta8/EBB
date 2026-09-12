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
var keys: int = 0        # vault keys, dropped by elites
var shards: int = 0      # echo shards found this night (already banked in the profile)
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

## Plain fields that a rested night keeps (ended / victory / taken are never saved).
const SAVED := ["seed", "biome", "depth", "depth_total", "rooms_cleared", "kills", "salt", "pearls", "keys",
	"time", "bargain", "full_fountain", "still_water"]


## Everything needed to pick the night up again, as JSON-safe values.
func to_dict() -> Dictionary:
	var d := {}
	for k in SAVED:
		d[k] = get(k)
	d["tide_level"] = tide.level
	d["tide_rate"] = tide.rate_mult
	d["tidemarks"] = tidemarks.duplicate()
	d["echoes"] = echoes.duplicate()
	return d


## Inverse of to_dict; JSON turns every number into a float, so types are restored here.
func from_dict(d: Dictionary) -> void:
	for k in SAVED:
		if not d.has(k):
			continue
		match typeof(get(k)):
			TYPE_INT: set(k, int(d[k]))
			TYPE_FLOAT: set(k, float(d[k]))
			TYPE_BOOL: set(k, bool(d[k]))
	tide.level = float(d.get("tide_level", 0.0))
	tide.rate_mult = float(d.get("tide_rate", 1.0))
	tidemarks = []
	for id in d.get("tidemarks", []):
		tidemarks.append(str(id))
	echoes = []
	for id in d.get("echoes", []):
		echoes.append(str(id))


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
