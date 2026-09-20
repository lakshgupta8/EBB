class_name Tidemarks
extends RefCounted
## Per-run boons offered at altars. Data lives here; effects are applied by mutating
## the player's `mods` dictionary or run state. Families colour the UI.

const FAMILY_COLOR := {
	"salt": Palette.SALT_RED,        # offence
	"brine": Palette.VERDIGRIS,      # defence
	"current": Palette.SEA_PALE,     # mobility
	"deep": Palette.DEEP_VIOLET,     # weird
	"echo": Palette.AMBER,           # what the rescued lend you
}
const FAMILY_NAME := {"salt": "Salt", "brine": "Brine", "current": "Current", "deep": "Deep", "echo": "Echo"}
## Rarities: plain marks always; echo marks need the person (`needs`: an echo flag or a
## count of echoes freed); duos need one mark from each family in `pair`; legendaries
## turn up past depth LEGENDARY_DEPTH. Weights are the odds of each in a roll.
const RARITY_WEIGHT := {"": 1.0, "echo": 0.7, "duo": 0.6, "legendary": 0.15}
const LEGENDARY_DEPTH := 5

const ALL := [
	# salt: offence
	{"id": "salt_edge", "family": "salt", "name": "Salt Edge", "desc": "All your damage +20%."},
	{"id": "salt_weight", "family": "salt", "name": "Salt Weight", "desc": "Heavy strikes (hold the attack) deal +50%."},
	{"id": "salt_bleed", "family": "salt", "name": "Barbed Hook", "desc": "Finishing blows leave enemies bleeding for a while."},
	{"id": "salt_crit", "family": "salt", "name": "Keen Eye", "desc": "Any hit has a 12% chance to crit for double."},
	{"id": "salt_lunge", "family": "salt", "name": "Spearpoint", "desc": "The lunge out of a dash deals double."},
	{"id": "salt_wall", "family": "salt", "name": "Breaker", "desc": "Knocking an enemy into a wall deals 8 instead of 3."},
	{"id": "salt_held", "family": "salt", "name": "Cruel Barbs", "desc": "Enemies you hold (hooked, netted, on the line) take +40%."},
	{"id": "salt_ranged", "family": "salt", "name": "Long Arm", "desc": "Anything you throw or shoot deals +50%."},
	{"id": "salt_lit", "family": "salt", "name": "Kindling", "desc": "Enemies your lantern has lit take +30%."},
	{"id": "salt_execute", "family": "salt", "name": "Reaper", "desc": "Enemies under a quarter of their health take double."},
	{"id": "salt_rally", "family": "salt", "name": "Rally", "desc": "+6% damage for every kill in a room, up to +60%. Resets at the door."},
	# brine: defence
	{"id": "brine_hp", "family": "brine", "name": "Brine Heart", "desc": "+25 max health, and you are healed by that much now."},
	{"id": "brine_guard", "family": "brine", "name": "Wet Hide", "desc": "For 1 s after a dash you take 30% less damage."},
	{"id": "brine_kill_heal", "family": "brine", "name": "Drink Deep", "desc": "Every kill heals you 3."},
	{"id": "brine_shield", "family": "brine", "name": "Salt Skin", "desc": "After each room you clear, a shield absorbs the next hit."},
	{"id": "brine_thick", "family": "brine", "name": "Thick Coat", "desc": "Hits barely knock you back."},
	{"id": "brine_flare", "family": "brine", "name": "Warm Light", "desc": "The lantern flare (Q) also heals you 15."},
	{"id": "brine_regen", "family": "brine", "name": "Slow Salt", "desc": "Heal 1 every 4 s while you stand on dry ground."},
	{"id": "brine_bones", "family": "brine", "name": "Old Bones", "desc": "+40 max health, but dashes come back 20% slower."},
	{"id": "brine_last", "family": "brine", "name": "Last Light", "desc": "Under 30% health you take 25% less damage."},
	{"id": "brine_wells", "family": "brine", "name": "Deep Wells", "desc": "Fountains heal you to full."},
	# current: mobility
	{"id": "current_dash", "family": "current", "name": "Undertow", "desc": "One more dash charge."},
	{"id": "current_wake", "family": "current", "name": "Wake", "desc": "Dashing through enemies damages them."},
	{"id": "current_swift", "family": "current", "name": "Swift Foot", "desc": "+12% move speed, and water barely slows you."},
	{"id": "current_recharge", "family": "current", "name": "Quick Legs", "desc": "Dashes come back 40% faster."},
	{"id": "current_refund", "family": "current", "name": "Undertow Pull", "desc": "A riptide (a dash as a strike lands) refills every dash."},
	{"id": "current_stride", "family": "current", "name": "Long Stride", "desc": "Dashes carry you 25% further."},
	{"id": "current_slip", "family": "current", "name": "Slipstream", "desc": "You stay untouchable twice as long during a dash."},
	{"id": "current_eel", "family": "current", "name": "Eel", "desc": "Dashing while in water costs no charge."},
	{"id": "current_panic", "family": "current", "name": "Panic", "desc": "+25% move speed while under half health."},
	{"id": "current_backstep", "family": "current", "name": "Backstep", "desc": "Every riptide also heals you 4."},
	# deep: weird
	{"id": "deep_slow", "family": "deep", "name": "Held Breath", "desc": "The tide rises 25% slower."},
	{"id": "deep_salt", "family": "deep", "name": "Salt Hunger", "desc": "Enemies drop 50% more salt."},
	{"id": "deep_glow", "family": "deep", "name": "Old Oil", "desc": "The lantern charges 60% faster toward a flare."},
	{"id": "deep_riptide", "family": "deep", "name": "Riptide Soul", "desc": "Riptides last 6 s and their crits deal x2.5."},
	{"id": "deep_bargain", "family": "deep", "name": "Sea's Bargain", "desc": "If you fall, half your salt still comes home."},
	{"id": "deep_blood", "family": "deep", "name": "Brine Blood", "desc": "Deep water heals you instead of hurting."},
	{"id": "deep_surge", "family": "deep", "name": "Storm Surge", "desc": "+30% damage while you stand in water."},
	{"id": "deep_diver", "family": "deep", "name": "Pearl Diver", "desc": "Elites and bosses drop one more pearl."},
	{"id": "deep_echo", "family": "deep", "name": "Echo Chamber", "desc": "+8 max health for every echo you have brought home."},
	{"id": "deep_hunger", "family": "deep", "name": "Deep Hunger", "desc": "Kills made while standing in water heal you 5."},
	{"id": "deep_still", "family": "deep", "name": "Still Water", "desc": "The tide holds still for 12 s after an altar or a fountain."},
	# M6d: four more per family
	{"id": "salt_first", "family": "salt", "name": "First Blood", "desc": "Your first strike in each room deals triple."},
	{"id": "salt_stun", "family": "salt", "name": "Cheap Shot", "desc": "Stunned enemies take +50%."},
	{"id": "salt_wet", "family": "salt", "name": "Wet Prey", "desc": "Enemies standing in water take +25%."},
	{"id": "salt_flare", "family": "salt", "name": "Sun Flare", "desc": "The lantern flare deals triple and stuns longer."},
	{"id": "brine_salt", "family": "brine", "name": "Salt Purse", "desc": "Hits cost you 5 salt instead of health, while you have salt."},
	{"id": "brine_clear", "family": "brine", "name": "Tidewash", "desc": "Clearing a room heals you 8."},
	{"id": "brine_sweet", "family": "brine", "name": "Sweet Water", "desc": "Fountains also raise your max health by 10."},
	{"id": "brine_mend", "family": "brine", "name": "Salt Mend", "desc": "Every 10 salt you pick up heals you 1."},
	{"id": "current_kill", "family": "current", "name": "Second Breath", "desc": "Every kill gives a dash charge back."},
	{"id": "current_otter", "family": "current", "name": "Otter", "desc": "Dashes started in water carry twice as far."},
	{"id": "current_flinch", "family": "current", "name": "Flinch", "desc": "Getting hit gives one dash charge back."},
	{"id": "current_haste", "family": "current", "name": "Empty Hands", "desc": "+8% move speed for every dash charge you have spent."},
	{"id": "deep_shard", "family": "deep", "name": "Shard Hunter", "desc": "Bosses leave one more echo shard."},
	{"id": "deep_tithe", "family": "deep", "name": "Tithe", "desc": "Every third room you clear drops a pearl."},
	{"id": "deep_drown", "family": "deep", "name": "Drowning", "desc": "Enemies in deep water take 2 damage a second."},
	{"id": "deep_dry", "family": "deep", "name": "Dry Feet", "desc": "Water is dry ground to you: no slowing, no hurt."},
	# echo: what the people you brought back lend you (two families in one)
	{"id": "echo_bram", "family": "echo", "rarity": "echo", "needs": "echo_bram", "name": "Smith's Temper", "desc": "+10% damage and +15 max health."},
	{"id": "echo_wren", "family": "echo", "rarity": "echo", "needs": "echo_wren", "name": "Wren's Prayer", "desc": "Riptides heal you 2, and dashes come back 20% faster."},
	{"id": "echo_cart", "family": "echo", "rarity": "echo", "needs": "echo_cartographer", "name": "Charted Depths", "desc": "Chests hold 2 more pearls, and dashes damage what they pass through."},
	{"id": "echo_maren", "family": "echo", "rarity": "echo", "needs": "echo_maren", "name": "Keeper's Line", "desc": "+25% damage under half health, and the tide rises slower."},
	{"id": "echo_fen", "family": "echo", "rarity": "echo", "needs": "1", "name": "Fen's Shell", "desc": "One more dash charge and +10 max health."},
	{"id": "echo_chorus", "family": "echo", "rarity": "echo", "needs": "3", "name": "Chorus", "desc": "+4% damage for every tidemark you hold."},
	# duos: need a mark from each of two families
	{"id": "duo_plate", "family": "brine", "rarity": "duo", "pair": ["salt", "brine"], "name": "Barnacle Plate", "desc": "When a shield absorbs a hit, whatever hit you takes 12."},
	{"id": "duo_edge", "family": "salt", "rarity": "duo", "pair": ["current", "salt"], "name": "Riptide Edge", "desc": "Riptide crits deal x3."},
	{"id": "duo_skin", "family": "deep", "rarity": "duo", "pair": ["deep", "brine"], "name": "Drowned Skin", "desc": "Deep water heals you, and gives a shield every 4 s you stay in it."},
	{"id": "duo_eel", "family": "current", "rarity": "duo", "pair": ["deep", "current"], "name": "Eel Wake", "desc": "Dashing in water costs nothing and damages what you pass through."},
	# legendaries: deep in the night only
	{"id": "leg_glass", "family": "salt", "rarity": "legendary", "name": "Sea Glass Edge", "desc": "+50% damage, but 25 less max health."},
	{"id": "leg_coat", "family": "brine", "rarity": "legendary", "name": "Keeper's Coat", "desc": "You take 25% less damage from everything."},
	{"id": "leg_spindrift", "family": "current", "rarity": "legendary", "name": "Spindrift", "desc": "Two more dash charges, and dashes come back 50% faster."},
	{"id": "leg_slack", "family": "deep", "rarity": "legendary", "name": "Slack Water", "desc": "The tide holds still while any enemy is alive."},
	# actives: one per family, used on R. Only as many as you have slots (one; the Ledger adds one).
	{"id": "act_storm", "family": "salt", "active": 20.0, "name": "Salt Storm", "desc": "R: a burst of salt hits everything near you for 12. Ready again in 20 s."},
	{"id": "act_wall", "family": "brine", "active": 30.0, "name": "Breakwater", "desc": "R: a shield that absorbs one hit, and the tide holds 3 s. Ready again in 30 s."},
	{"id": "act_step", "family": "current", "active": 25.0, "name": "Keeper's Step", "desc": "R: every dash comes back and you are untouchable for 1 s. Ready again in 25 s."},
	{"id": "act_call", "family": "deep", "active": 45.0, "name": "Slack Call", "desc": "R: the tide holds still for 10 s. Ready again in 45 s."},
]


static func get_mark(id: String) -> Dictionary:
	for m in ALL:
		if m.id == id:
			return m
	return {}


static func color_of(id: String) -> Color:
	var m := get_mark(id)
	return FAMILY_COLOR.get(m.get("family", "salt"), Color.WHITE)


## Whether a mark may be offered now: echoes need their person, duos need both families
## in hand, legendaries need depth.
static func eligible(m: Dictionary, depth: int = 0, held: Array = []) -> bool:
	match str(m.get("rarity", "")):
		"echo":
			var need := str(m.get("needs", ""))
			if need.begins_with("echo_"):
				return SaveManager.flag(need)
			return int(SaveManager.data.get("echoes", 0)) >= int(need)
		"duo":
			for f in m.get("pair", []):
				if not f in held:
					return false
			return true
		"legendary":
			return depth >= LEGENDARY_DEPTH
	return true


static func rarity_of(id: String) -> String:
	return str(get_mark(id).get("rarity", ""))


## Actives are used on R and come back after their cooldown (seconds), else 0.
static func cooldown_of(id: String) -> float:
	return float(get_mark(id).get("active", 0.0))


static func is_active(id: String) -> bool:
	return get_mark(id).has("active")


static func actives_in(owned: Array) -> Array:
	var out: Array = []
	for id in owned:
		if is_active(id):
			out.append(id)
	return out


## The families of the marks in hand (for duos).
static func families_of(owned: Array) -> Array:
	var out: Array = []
	for id in owned:
		var f := str(get_mark(id).get("family", ""))
		if f != "" and f != "echo" and not f in out:
			out.append(f)
	return out


## `count` distinct marks the player does not own, chosen with the run rng, weighted by
## rarity. With a blessed family (Sister Wren), one of the offers is always from it when
## any remain. `depth` and `held` gate the rarer marks (see eligible).
static func roll(rng: RandomNumberGenerator, owned: Array, count: int = 3, blessed: String = "", depth: int = 0, held: Array = [], active_slots: int = 1) -> Array:
	var pool: Array = []
	var weights: Array = []
	var blessed_pool: Array = []
	var slots_full: bool = actives_in(owned).size() >= active_slots
	for m in ALL:
		if m.id in owned or not eligible(m, depth, held):
			continue
		if m.has("active") and slots_full:
			continue
		pool.append(m.id)
		weights.append(float(RARITY_WEIGHT.get(str(m.get("rarity", "")), 1.0)))
		if m.family == blessed:
			blessed_pool.append(m.id)
	var out: Array = []
	if blessed_pool.size() > 0 and count > 0:
		var b: String = blessed_pool[rng.randi() % blessed_pool.size()]
		out.append(b)
		var k := pool.find(b)
		pool.remove_at(k)
		weights.remove_at(k)
	while out.size() < count and pool.size() > 0:
		var total := 0.0
		for w in weights:
			total += w
		var r := rng.randf() * total
		var pick := pool.size() - 1
		for k in pool.size():
			r -= weights[k]
			if r <= 0.0:
				pick = k
				break
		out.append(pool[pick])
		pool.remove_at(pick)
		weights.remove_at(pick)
	# Shuffle on the run's own stream, not the global one: the same seed must deal the
	# same cards in the same order, on anybody's machine (the daily depends on it).
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


static func apply(id: String, player: Player, run) -> void:
	var m: Dictionary = player.mods
	match id:
		"salt_edge": m.damage *= 1.2
		"salt_weight": m.heavy_damage *= 1.5
		"salt_bleed": m.bleed = true
		"salt_crit": m.crit_chance += 0.12
		"salt_lunge": m.lunge_mult *= 2.0
		"salt_wall": m.wall_damage = 8
		"salt_held": m.held_bonus += 0.4
		"salt_ranged": m.ranged_mult *= 1.5
		"salt_lit": m.lit_bonus += 0.3
		"salt_execute": m.execute = true
		"salt_rally": m.rally_per += 0.06
		"brine_hp":
			player.health.max_hp += 25
			player.health.heal(25)
		"brine_guard": m.dash_guard = true
		"brine_kill_heal": m.kill_heal += 3
		"brine_shield":
			m.room_shield = true
			player.hurtbox.shield_count = 1
		"brine_thick": m.knockback_taken = 0.35
		"brine_flare": m.flare_heal += 15
		"brine_regen": m.regen = true
		"brine_bones":
			player.health.max_hp += 40
			player.health.heal(40)
			m.dash_recharge *= 1.2
		"brine_last": m.low_guard = true
		"brine_wells":
			if run:
				run.state.full_fountain = true
		"current_dash":
			player.max_dash += 1
			player.dash_charges = player.max_dash
		"current_wake": m.dash_wake = true
		"current_swift":
			m.speed *= 1.12
			m.water_speed = 0.92
		"current_recharge": m.dash_recharge *= 0.6
		"current_refund": m.riptide_refund = true
		"current_stride": m.dash_dist *= 1.25
		"current_slip": m.dash_grace = 0.14
		"current_eel": m.free_water_dash = true
		"current_panic": m.panic_speed = 1.25
		"current_backstep": m.riptide_heal += 4
		"deep_slow":
			if run:
				run.state.tide.rate_mult *= 0.75
		"deep_salt": m.salt_mult *= 1.5
		"deep_glow": m.glow_mult *= 1.6
		"deep_riptide":
			m.riptide_window = 6.0
			m.riptide_crit = 2.5
		"deep_bargain":
			if run:
				run.state.bargain = true
		"deep_blood": m.tide_heals = true
		"deep_surge": m.water_damage *= 1.3
		"deep_diver": m.pearl_bonus += 1
		"deep_echo":
			var n := int(SaveManager.data.get("echoes", 0))
			if n > 0:
				player.health.max_hp += 8 * n
				player.health.heal(8 * n)
		"deep_hunger": m.water_kill_heal += 5
		"deep_still":
			if run:
				run.state.still_water = true
		# --- M6d ---
		"salt_first": m.first_strike = true
		"salt_stun": m.stun_bonus += 0.5
		"salt_wet": m.wet_bonus += 0.25
		"salt_flare": m.flare_mult *= 3.0
		"brine_salt": m.salt_shield = true
		"brine_clear": m.clear_heal += 8
		"brine_sweet": m.fountain_max += 10
		"brine_mend": m.salt_mend = true
		"current_kill": m.kill_dash = true
		"current_otter": m.wet_stride = true
		"current_flinch": m.hurt_dash = true
		"current_haste": m.haste_per += 0.08
		"deep_shard": m.shard_bonus += 1
		"deep_tithe": m.tithe = true
		"deep_drown": m.drown += 2
		"deep_dry": m.dry_feet = true
		"echo_bram":
			m.damage *= 1.1
			player.health.max_hp += 15
			player.health.heal(15)
		"echo_wren":
			m.riptide_heal += 2
			m.dash_recharge *= 0.8
		"echo_cart":
			m.chest_bonus += 2
			m.dash_wake = true
		"echo_maren":
			m.low_damage += 0.25
			if run:
				run.state.tide.rate_mult *= 0.85
		"echo_fen":
			player.max_dash += 1
			player.dash_charges = player.max_dash
			player.health.max_hp += 10
			player.health.heal(10)
		"echo_chorus": m.per_mark += 0.04
		"duo_plate": m.thorns += 12
		"duo_edge": m.riptide_crit = 3.0
		"duo_skin":
			m.tide_heals = true
			m.water_shield = true
		"duo_eel":
			m.free_water_dash = true
			m.dash_wake = true
		"leg_glass":
			m.damage *= 1.5
			player.health.max_hp = maxi(30, player.health.max_hp - 25)
			player.health.hp = mini(player.health.hp, player.health.max_hp)
			player.health.changed.emit(player.health.hp, player.health.max_hp)
		"leg_coat": m.armour *= 0.75
		"leg_spindrift":
			player.max_dash += 2
			player.dash_charges = player.max_dash
			m.dash_recharge *= 0.5
		"leg_slack": m.slack = true
