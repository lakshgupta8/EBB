class_name RoomGraph
extends RefCounted
## Decides which room types are offered at each depth. Deterministic per seed.
## Depth 0 is the first room; depth == biome_length is the boss.

enum { COMBAT, ELITE, FOUNTAIN, TREASURE, BOSS, SHOP, ALTAR }
const NAMES := {COMBAT: "Combat", ELITE: "Elite", FOUNTAIN: "Fountain", TREASURE: "Treasure",
	BOSS: "Boss", SHOP: "Merchant", ALTAR: "Altar"}
const ICON := {COMBAT: 0, ELITE: 1, FOUNTAIN: 2, TREASURE: 3, BOSS: 4, SHOP: 5, ALTAR: 6}
## Types that never repeat back to back.
const NO_REPEAT := [SHOP, ALTAR, FOUNTAIN, TREASURE]

var biome_length: int = 8
var _rng := RandomNumberGenerator.new()
var _cache: Dictionary = {}


func _init(p_seed: int, p_length: int = 8) -> void:
	_rng.seed = p_seed
	biome_length = p_length
	for d in biome_length + 1:
		_cache[d] = _generate(d)


func options_for(depth: int) -> Array:
	return _cache.get(depth, [BOSS])


func is_boss_depth(depth: int) -> bool:
	return depth >= biome_length


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
	# Guarantees: an altar is offered at depth 1, a merchant at depth 4.
	if depth == 1 and not ALTAR in picked:
		picked[0] = ALTAR
	if depth == 4 and not SHOP in picked:
		picked[0] = SHOP
	return picked


func _weighted(depth: int, exclude: Array) -> int:
	var weights := {COMBAT: 5.0, ELITE: 0.0, FOUNTAIN: 0.0, TREASURE: 1.5, SHOP: 0.0, ALTAR: 2.5}
	if depth >= 3:
		weights[ELITE] = 2.0
	if depth >= 2:
		weights[FOUNTAIN] = 1.5
		weights[SHOP] = 1.5
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
