class_name Tidemarks
extends RefCounted
## Per-run boons offered at altars. Data lives here; effects are applied by mutating
## the player's `mods` dictionary or run state. Families colour the UI.

const FAMILY_COLOR := {
	"salt": Color(0.92, 0.42, 0.36),      # offence
	"brine": Color(0.42, 0.62, 0.92),     # defence
	"current": Color(0.55, 0.92, 0.95),   # mobility
	"deep": Color(0.72, 0.52, 0.92),      # weird
}

const ALL := [
	{"id": "salt_edge", "family": "salt", "name": "Salt Edge", "desc": "all damage +20%"},
	{"id": "salt_weight", "family": "salt", "name": "Salt Weight", "desc": "heavy sweeps deal +50%"},
	{"id": "salt_bleed", "family": "salt", "name": "Barbed Hook", "desc": "the third hit makes enemies bleed"},
	{"id": "salt_crit", "family": "salt", "name": "Keen Eye", "desc": "12% chance any hit is a crit"},
	{"id": "brine_hp", "family": "brine", "name": "Brine Heart", "desc": "+25 max health, healed now"},
	{"id": "brine_guard", "family": "brine", "name": "Wet Hide", "desc": "take 30% less damage for 1 s after a dash"},
	{"id": "brine_kill_heal", "family": "brine", "name": "Drink Deep", "desc": "heal 3 on every kill"},
	{"id": "current_dash", "family": "current", "name": "Undertow", "desc": "+1 dash charge"},
	{"id": "current_wake", "family": "current", "name": "Wake", "desc": "dashing damages what you pass through"},
	{"id": "current_swift", "family": "current", "name": "Swift Foot", "desc": "+12% speed, water barely slows you"},
	{"id": "deep_slow", "family": "deep", "name": "Held Breath", "desc": "the tide rises 25% slower"},
	{"id": "deep_salt", "family": "deep", "name": "Salt Hunger", "desc": "enemies drop 50% more salt"},
	{"id": "deep_glow", "family": "deep", "name": "Old Oil", "desc": "the lantern charges 60% faster"},
	{"id": "deep_riptide", "family": "deep", "name": "Riptide Soul", "desc": "riptide lasts 6 s and crits for x2.5"},
]


static func get_mark(id: String) -> Dictionary:
	for m in ALL:
		if m.id == id:
			return m
	return {}


static func color_of(id: String) -> Color:
	var m := get_mark(id)
	return FAMILY_COLOR.get(m.get("family", "salt"), Color.WHITE)


## `count` distinct marks the player does not own, chosen with the run rng.
static func roll(rng: RandomNumberGenerator, owned: Array, count: int = 3) -> Array:
	var pool: Array = []
	for m in ALL:
		if not m.id in owned:
			pool.append(m.id)
	var out: Array = []
	while out.size() < count and pool.size() > 0:
		var i := rng.randi() % pool.size()
		out.append(pool[i])
		pool.remove_at(i)
	return out


static func apply(id: String, player: Player, run) -> void:
	var m: Dictionary = player.mods
	match id:
		"salt_edge": m.damage *= 1.2
		"salt_weight": m.heavy_damage *= 1.5
		"salt_bleed": m.bleed = true
		"salt_crit": m.crit_chance += 0.12
		"brine_hp":
			player.health.max_hp += 25
			player.health.heal(25)
		"brine_guard": m.dash_guard = true
		"brine_kill_heal": m.kill_heal += 3
		"current_dash":
			player.max_dash += 1
			player.dash_charges = player.max_dash
		"current_wake": m.dash_wake = true
		"current_swift":
			m.speed *= 1.12
			m.water_speed = 0.92
		"deep_slow":
			if run:
				run.state.tide.rate_mult *= 0.75
		"deep_salt": m.salt_mult *= 1.5
		"deep_glow": m.glow_mult *= 1.6
		"deep_riptide":
			m.riptide_window = 6.0
			m.riptide_crit = 2.5
