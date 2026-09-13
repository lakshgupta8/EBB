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
var tier: int = 0        # spring tide: 0 calm, 1..8 harder, more pearls
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
var active_cd: Dictionary = {}  # active tidemark id -> seconds until it can be used again
var active_slots: int = 1       # how many active marks can be carried (the Ledger adds one)
# M7: the Ledger's new branches, Nessa's fish and the night's own ledger of what happened
var slack_start: float = 0.0    # Slack Start: the tide holds this long at each biome's start
var pearl_mult: float = 1.0     # the Keeper's Tithe, the Choir's hymn
var rerolls: int = 0            # Second Look: altar rerolls left
var legendary_early: int = 0    # Deep Memory: legendaries this many rooms sooner
var first_altar_extra: int = 0  # Wren's prayer: the first altar offers one more
var fish_cap: int = 3           # how many fish can be carried
var fish: Array = []            # consumables carried (kinds, eaten in order with F)
var stats: Dictionary = {}      # counters the contracts and the Log read (see Run.count)
var assist_mult: float = 1.0    # M8: assists trade pearls away (Settings.assist_pearl_mult)
var mode: String = "night"      # M8: night / daily / seeded / trial / neap / riptide (Modes)

## Plain fields that a rested night keeps (ended / victory / taken are never saved).
const SAVED := ["seed", "biome", "depth", "depth_total", "rooms_cleared", "kills", "salt", "pearls", "keys", "tier",
	"time", "bargain", "full_fountain", "still_water", "assist_mult"]


## Everything needed to pick the night up again, as JSON-safe values.
func to_dict() -> Dictionary:
	var d := {}
	for k in SAVED:
		d[k] = get(k)
	d["mode"] = mode
	d["tide_level"] = tide.level
	d["tide_rate"] = tide.rate_mult
	d["tidemarks"] = tidemarks.duplicate()
	d["echoes"] = echoes.duplicate()
	d["active_cd"] = active_cd.duplicate()
	d["active_slots"] = active_slots
	for k in ["slack_start", "pearl_mult", "rerolls", "legendary_early", "first_altar_extra", "fish_cap"]:
		d[k] = get(k)
	d["fish"] = fish.duplicate()
	d["stats"] = stats.duplicate()
	return d


## Bump a counter of the night (kills_gull, wet_rooms, flares...).
func count(key: String, by: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + by


## The active marks in hand, in the order they were taken.
func actives() -> Array:
	return Tidemarks.actives_in(tidemarks)


## Inverse of to_dict; JSON turns every number into a float, so types are restored here.
func from_dict(d: Dictionary) -> void:
	for k in SAVED:
		if not d.has(k):
			continue
		match typeof(get(k)):
			TYPE_INT: set(k, int(d[k]))
			TYPE_FLOAT: set(k, float(d[k]))
			TYPE_BOOL: set(k, bool(d[k]))
	mode = str(d.get("mode", "night"))
	tide.level = float(d.get("tide_level", 0.0))
	tide.rate_mult = float(d.get("tide_rate", 1.0))
	tidemarks = []
	for id in d.get("tidemarks", []):
		tidemarks.append(str(id))
	echoes = []
	for id in d.get("echoes", []):
		echoes.append(str(id))
	active_cd = {}
	for id in d.get("active_cd", {}):
		active_cd[str(id)] = float(d["active_cd"][id])
	active_slots = int(d.get("active_slots", 1))
	slack_start = float(d.get("slack_start", 0.0))
	pearl_mult = float(d.get("pearl_mult", 1.0))
	rerolls = int(d.get("rerolls", 0))
	legendary_early = int(d.get("legendary_early", 0))
	first_altar_extra = int(d.get("first_altar_extra", 0))
	fish_cap = int(d.get("fish_cap", 3))
	fish = []
	for f in d.get("fish", []):
		fish.append(str(f))
	stats = {}
	for k in d.get("stats", {}):
		var v = d["stats"][k]
		if v is String:
			stats[str(k)] = v
		else:
			stats[str(k)] = float(v) if str(k).begins_with("tide_at_boss") else int(v)


func result() -> Dictionary:
	# Salt converts to pearls at the end: half if taken by the tide, none if killed.
	var bonus := (salt / 2) if (taken or bargain) else 0
	if victory:
		bonus = salt / 2 + 5 + 10 * biome
	# The spring tide pays: +15% pearls per tier; the tithe and the hymn a little more.
	var total := int(round(float(pearls + bonus) * (1.0 + 0.15 * tier) * pearl_mult * assist_mult))
	return {
		"seed": seed, "biome": biome, "depth": depth_total, "rooms_cleared": rooms_cleared, "kills": kills,
		"salt": salt, "pearls": total, "pearls_from_salt": bonus, "tier": tier, "assist_mult": assist_mult, "mode": mode,
		"marks": tidemarks.duplicate(),
		"time": time, "victory": victory, "taken": taken, "echoes": echoes.duplicate(),
		"weapon": str(stats.get("weapon", "")), "stats": stats.duplicate(),
	}


## The night's ledger as the contracts read it: every counter plus how it ended.
func ledger() -> Dictionary:
	var s := stats.duplicate()
	s["victory"] = victory
	s["tier"] = tier
	s["salt"] = salt
	s["marks"] = tidemarks.size()
	s["kills"] = kills
	if not s.has("untouched_depth"):
		s["untouched_depth"] = depth_total + 1
	return s
