class_name RoomGraph
extends RefCounted
## Decides which room types are offered at each depth. Deterministic per seed.
## Depth 0 is the first room; depth == biome_length is the boss.

enum { COMBAT, ELITE, FOUNTAIN, TREASURE, BOSS, SHOP, ALTAR, ECHO, CHALLENGE, VAULT, DIVE }
const NAMES := {COMBAT: "Combat", ELITE: "Elite", FOUNTAIN: "Fountain", TREASURE: "Treasure",
	BOSS: "Boss", SHOP: "Merchant", ALTAR: "Altar", ECHO: "Echo", CHALLENGE: "Challenge", VAULT: "Vault", DIVE: "Dive"}
const ICON := {COMBAT: 0, ELITE: 1, FOUNTAIN: 2, TREASURE: 3, BOSS: 4, SHOP: 5, ALTAR: 6, ECHO: 7,
	CHALLENGE: 8, VAULT: 9, DIVE: 10}
## Types that never repeat back to back.
const NO_REPEAT := [SHOP, ALTAR, FOUNTAIN, TREASURE, ECHO, CHALLENGE, VAULT, DIVE]
## Where echo cages are placed when one, or two, echoes are still lost in a biome.
const ECHO_DEPTHS := [[3], [3, 6]]
## The Cartographer can promise one of these at depth 2.
const CHARTABLE := [FOUNTAIN, TREASURE, SHOP]

var biome_length: int = 8
var echo_depths: Array = []
var charted: int = -1
var _rng := RandomNumberGenerator.new()
var _cache: Dictionary = {}


func _init(p_seed: int, p_length: int = 8, p_echo_depths: Array = [], p_charted: int = -1) -> void:
	_rng.seed = p_seed
	biome_length = p_length
	echo_depths = p_echo_depths
	charted = p_charted
	for d in biome_length + 1:
		_cache[d] = _generate(d)


func options_for(depth: int) -> Array:
	return _cache.get(depth, [BOSS])


func is_boss_depth(depth: int) -> bool:
	return depth >= biome_length


## Halfway down every biome the second door is the wet way: already flooded, the
## drowned in it, more salt, a pearl for clearing it.
func fork_depth() -> int:
	return biome_length / 2


func is_wet(depth: int, index: int) -> bool:
	if depth != fork_depth() or index != 1:
		return false
	var opts: Array = options_for(depth)
	return opts.size() == 2 and opts[1] in [COMBAT, ELITE]


func _generate(depth: int) -> Array:
	if depth == 0:
		return [COMBAT]
	if depth >= biome_length:
		return [BOSS]
	if depth == biome_length - 1:
		return [FOUNTAIN, _weighted(depth, [FOUNTAIN])]
	var count := 2 if _rng.randf() < 0.8 else 1
	var picked: Array = []
	for i in count:
		picked.append(_weighted(depth, picked))
	# Guarantees: an altar is offered at depth 1, a merchant at depth 4, the charted
	# room at depth 2, and an echo cage where one is still lost.
	if depth == 1 and not ALTAR in picked:
		picked[0] = ALTAR
	if depth == 4 and not SHOP in picked:
		picked[0] = SHOP
	if depth == 2 and charted in CHARTABLE and not charted in picked:
		picked[0] = charted
	if depth in echo_depths and not ECHO in picked:
		picked[picked.size() - 1] = ECHO
		if picked.size() > 1 and picked[0] == ECHO:
			picked[0] = COMBAT
	elif depth == fork_depth():
		if picked.size() < 2:
			picked.append(COMBAT)
		if not picked[1] in [COMBAT, ELITE]:
			picked[1] = ELITE if (depth >= 3 and _rng.randf() < 0.4) else COMBAT
	return picked


func _weighted(depth: int, exclude: Array) -> int:
	var weights := {COMBAT: 5.0, ELITE: 0.0, FOUNTAIN: 0.0, TREASURE: 1.5, SHOP: 0.0, ALTAR: 2.5,
		CHALLENGE: 0.0, VAULT: 0.0, DIVE: 0.0}
	if depth >= 3:
		weights[ELITE] = 2.0
		weights[CHALLENGE] = 1.0
		weights[VAULT] = 1.2
	if depth >= 2:
		weights[FOUNTAIN] = 1.5
		weights[SHOP] = 1.5
		weights[DIVE] = 1.0
	var prev: Array = _cache.get(depth - 1, [])
	for t in NO_REPEAT:
		if t in prev:
			weights[t] = 0.0
	for e in exclude:
		weights[e] = 0.0
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := _rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return COMBAT
