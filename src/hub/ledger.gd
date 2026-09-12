class_name Ledger
extends RefCounted
## Orla's Ledger: permanent upgrades bought with pearls. Twenty-five nodes in five branches
## (Keeper, Sea, Purse, Lantern, Memory); each node needs the one before it in its branch,
## and two branches open only once the sea has shown you something. Tiers persist in the save.

const BRANCHES := ["keeper", "sea", "purse", "lantern", "memory"]
const BRANCH_NAME := {"keeper": "Keeper", "sea": "Sea", "purse": "Purse", "lantern": "Lantern", "memory": "Memory"}
## What opens a branch: "" always, else a dialog condition.
const BRANCH_NEEDS := {"keeper": "", "sea": "", "purse": "", "lantern": "flag:echo_bram", "memory": "wins>=1"}
const BRANCH_LOCKED := {"lantern": "Bram must be on the rock", "memory": "win a night first"}

const UPGRADES := [
	# keeper: the body
	{"id": "constitution", "branch": "keeper", "name": "Keeper's Constitution", "desc": "+10 max health per tier", "costs": [10, 20, 35]},
	{"id": "fourth_dash", "branch": "keeper", "name": "Fourth Dash", "desc": "one more dash charge", "costs": [40]},
	{"id": "tether", "branch": "keeper", "name": "Keeper's Tether", "desc": "survive one killing blow a night", "costs": [60]},
	{"id": "iron_hand", "branch": "keeper", "name": "Iron Hand", "desc": "+10% damage", "costs": [45]},
	{"id": "old_salt", "branch": "keeper", "name": "Old Salt", "desc": "start each night absorbing a hit", "costs": [35]},
	# sea: the water
	{"id": "kinder_tide", "branch": "sea", "name": "Kinder Tide", "desc": "tide rises 15% slower per tier", "costs": [25, 50]},
	{"id": "sea_legs", "branch": "sea", "name": "Sea Legs", "desc": "water slows you less", "costs": [20]},
	{"id": "deep_lungs", "branch": "sea", "name": "Deep Lungs", "desc": "deep water bites half as often", "costs": [30]},
	{"id": "slack_start", "branch": "sea", "name": "Slack Start", "desc": "tide holds 20 s each new biome", "costs": [40]},
	{"id": "still_hands", "branch": "sea", "name": "Still Hands", "desc": "fountains hold the tide 6 s", "costs": [35]},
	# purse: salt and pearls
	{"id": "pockets", "branch": "purse", "name": "Salted Pockets", "desc": "+10 starting salt per tier", "costs": [15, 30]},
	{"id": "haggler", "branch": "purse", "name": "Haggler", "desc": "the merchant charges 20% less", "costs": [25]},
	{"id": "lucky_chests", "branch": "purse", "name": "Lucky Chests", "desc": "chests hold one more pearl", "costs": [30]},
	{"id": "salt_wise", "branch": "purse", "name": "Salt-wise", "desc": "enemies drop 10% more salt", "costs": [30]},
	{"id": "tithe", "branch": "purse", "name": "The Keeper's Tithe", "desc": "+5% pearls at the end of a night", "costs": [45]},
	# lantern: the light
	{"id": "bright_lantern", "branch": "lantern", "name": "Brighter Lantern", "desc": "lantern charges 50% faster", "costs": [30]},
	{"id": "wide_flare", "branch": "lantern", "name": "Wide Flare", "desc": "the flare reaches 30% further", "costs": [35]},
	{"id": "warm_flare", "branch": "lantern", "name": "Warm Flare", "desc": "the flare heals 6", "costs": [30]},
	{"id": "half_glow", "branch": "lantern", "name": "Banked Coals", "desc": "start with the lantern half full", "costs": [40]},
	{"id": "lit_path", "branch": "lantern", "name": "Lit Path", "desc": "lit enemies take +10% more", "costs": [35]},
	# memory: what carries over
	{"id": "keep_mark", "branch": "memory", "name": "Long Memory", "desc": "last night's first mark returns", "costs": [60]},
	{"id": "reroll", "branch": "memory", "name": "Second Look", "desc": "one altar reroll a night", "costs": [50]},
	{"id": "second_active", "branch": "memory", "name": "Two Hands", "desc": "carry a second active tidemark", "costs": [55]},
	{"id": "log_health", "branch": "memory", "name": "Kept Count", "desc": "+1 max health per Log milestone", "costs": [40]},
	{"id": "deep_memory", "branch": "memory", "name": "Deep Memory", "desc": "legendary marks a room earlier", "costs": [45]},
]

## Keels laid by Idris: one on the boat at a time, a trade each.
const KEELS := [
	{"id": "iron", "name": "Iron keel", "desc": "+20 max health; slower dashes", "cost": 30},
	{"id": "salt", "name": "Salt keel", "desc": "+30% salt; 10 less max health", "cost": 30},
	{"id": "lamp", "name": "Lamp keel", "desc": "faster lantern; take 10% more", "cost": 30},
	{"id": "deep", "name": "Deep keel", "desc": "water never slows you; faster tide", "cost": 30},
]


static func get_upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}


static func in_branch(branch: String) -> Array:
	var out: Array = []
	for u in UPGRADES:
		if u.branch == branch:
			out.append(u)
	return out


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


static func branch_open(branch: String) -> bool:
	var need := str(BRANCH_NEEDS.get(branch, ""))
	return need == "" or Dialog.check(need)


## The node before this one in its branch (by list order), or "" for the root.
static func prerequisite(id: String) -> String:
	var u := get_upgrade(id)
	var prev := ""
	for n in in_branch(str(u.get("branch", ""))):
		if n.id == id:
			return prev
		prev = n.id
	return ""


## "" when the node can be bought into, else why not.
static func locked_reason(id: String) -> String:
	var u := get_upgrade(id)
	if u.is_empty():
		return "unknown"
	if not branch_open(u.branch):
		return str(BRANCH_LOCKED.get(u.branch, "locked"))
	var pre := prerequisite(id)
	if pre != "" and tier(pre) == 0:
		return "needs " + get_upgrade(pre).name
	return ""


static func can_buy(id: String) -> bool:
	var c := next_cost(id)
	return c >= 0 and locked_reason(id) == "" and int(SaveManager.data.pearls) >= c


static func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	SaveManager.data.pearls -= next_cost(id)
	SaveManager.data.ledger[id] = tier(id) + 1
	SaveManager.save_profile()
	return true


static func keel() -> Dictionary:
	var id := str(SaveManager.data.get("keel", ""))
	for k in KEELS:
		if k.id == id:
			return k
	return {}


## Apply every owned tier, the keel and the village's perks to a fresh run.
static func apply(player: Player, run) -> void:
	var m: Dictionary = player.mods
	var t := tier("constitution")
	var hp := 10 * t
	if Story.perk("orla"):
		hp += 5
	if tier("log_health") > 0:
		hp += KeeperLog.claimed().size()
	if tier("fourth_dash") > 0:
		player.max_dash += 1
		player.dash_charges = player.max_dash
	if tier("tether") > 0:
		m.second_chance = true
	if tier("iron_hand") > 0:
		m.damage *= 1.1
	if Story.perk("aldous"):
		m.damage *= 1.08
	if tier("old_salt") > 0:
		player.hurtbox.shield_count = 1
	if tier("sea_legs") > 0:
		m.water_speed = maxf(float(m.water_speed), 0.85)
	if tier("deep_lungs") > 0:
		m.deep_tick_mult *= 2.0
	if Story.perk("pell"):
		m.deep_tick_mult *= 2.0
	if tier("still_hands") > 0:
		m.fountain_hold += 6.0
	if tier("haggler") > 0:
		m.shop_mult *= 0.8
	if tier("lucky_chests") > 0:
		m.chest_bonus += 1
	if Story.perk("cartographer"):
		m.chest_bonus += 1
	if tier("salt_wise") > 0:
		m.salt_mult *= 1.1
	if tier("bright_lantern") > 0:
		m.glow_mult *= 1.5
	if tier("wide_flare") > 0:
		m.flare_radius *= 1.3
	if tier("warm_flare") > 0:
		m.flare_heal += 6
	if tier("half_glow") > 0 or Story.perk("bram"):
		player.glow = maxf(player.glow, Player.GLOW_MAX * 0.5)
	if tier("lit_path") > 0:
		m.lit_bonus += 0.1
	if Story.perk("maren"):
		m.riptide_window += 1.0
	# The keel: a trade laid into the boat by Idris.
	match str(keel().get("id", "")):
		"iron":
			hp += 20
			m.dash_recharge *= 1.15
		"salt":
			m.salt_mult *= 1.3
			hp -= 10
		"lamp":
			m.glow_mult *= 1.3
			m.armour *= 1.1
		"deep":
			m.water_speed = 1.0
	if hp != 0:
		player.health.max_hp = maxi(30, player.health.max_hp + hp)
		player.health.hp = clampi(player.health.hp + hp, 1, player.health.max_hp)
		player.health.changed.emit(player.health.hp, player.health.max_hp)
	if run == null:
		return
	t = tier("pockets")
	var salt := 10 * t + (10 if Story.perk("fen") else 0)
	if salt > 0:
		run.state.salt += salt
		EventBus.salt_changed.emit(run.state.salt)
	t = tier("kinder_tide")
	if t > 0:
		run.state.tide.rate_mult *= pow(0.85, t)
	if str(keel().get("id", "")) == "deep":
		run.state.tide.rate_mult *= 1.1
	if tier("slack_start") > 0:
		run.state.slack_start = 20.0
	if tier("tithe") > 0:
		run.state.pearl_mult += 0.05
	if Story.perk("choir"):
		run.state.pearl_mult += 0.05
	if tier("reroll") > 0:
		run.state.rerolls = 1
	if tier("second_active") > 0:
		run.state.active_slots = 2
	if tier("deep_memory") > 0:
		run.state.legendary_early = 1
	if Story.perk("wren"):
		run.state.first_altar_extra = 1
	if Story.perk("nessa"):
		run.state.fish_cap = 4
