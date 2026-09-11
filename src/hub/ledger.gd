class_name Ledger
extends RefCounted
## Orla's Ledger: permanent upgrades bought with pearls. Tiers persist in the save.

const UPGRADES := [
	{"id": "constitution", "name": "Keeper's Constitution", "desc": "+10 max health per tier", "costs": [10, 20, 35]},
	{"id": "fourth_dash", "name": "Fourth Dash", "desc": "one more dash charge", "costs": [40]},
	{"id": "pockets", "name": "Salted Pockets", "desc": "+10 starting salt per tier", "costs": [15, 30]},
	{"id": "kinder_tide", "name": "Kinder Tide", "desc": "tide rises 15% slower per tier", "costs": [25, 50]},
	{"id": "bright_lantern", "name": "Brighter Lantern", "desc": "lantern charges 50% faster", "costs": [30]},
	{"id": "tether", "name": "Keeper's Tether", "desc": "survive one killing blow a night", "costs": [60]},
]


static func get_upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}


static func tier(id: String) -> int:
	return int(SaveManager.data.ledger.get(id, 0))


static func max_tier(id: String) -> int:
	return get_upgrade(id).costs.size()


## Pearl cost of the next tier, or -1 when maxed.
static func next_cost(id: String) -> int:
	var t := tier(id)
	var u := get_upgrade(id)
	if t >= u.costs.size():
		return -1
	return int(u.costs[t])


static func can_buy(id: String) -> bool:
	var c := next_cost(id)
	return c >= 0 and int(SaveManager.data.pearls) >= c


static func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	SaveManager.data.pearls -= next_cost(id)
	SaveManager.data.ledger[id] = tier(id) + 1
	SaveManager.save_profile()
	return true


## Apply every owned tier to a fresh run.
static func apply(player: Player, run) -> void:
	var t := tier("constitution")
	if t > 0:
		player.health.max_hp += 10 * t
		player.health.heal(10 * t)
	if tier("fourth_dash") > 0:
		player.max_dash += 1
		player.dash_charges = player.max_dash
	t = tier("pockets")
	if t > 0 and run:
		run.state.salt += 10 * t
		EventBus.salt_changed.emit(run.state.salt)
	t = tier("kinder_tide")
	if t > 0 and run:
		run.state.tide.rate_mult *= pow(0.85, t)
	if tier("bright_lantern") > 0:
		player.mods.glow_mult *= 1.5
	if tier("tether") > 0:
		player.mods.second_chance = true
