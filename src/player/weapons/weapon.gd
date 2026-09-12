class_name Weapon
extends Node2D
## What the player expects from any weapon. Each weapon scene overrides the parts it
## uses; the defaults are "nothing happens" so a half-built weapon never crashes the run.

const ALL := {
	"gaff": {"name": "Gaff Hook", "scene": "res://src/player/weapons/gaff_hook.tscn",
		"desc": "3-hit combo, heavy sweep, hook throw"},
	"net": {"name": "Net & Knife", "scene": "res://src/player/weapons/net_knife.tscn",
		"desc": "fast bleeding stabs, a net that roots"},
	"harpoon": {"name": "Harpoon Gun", "scene": "res://src/player/weapons/harpoon_gun.tscn",
		"desc": "piercing bolts, a tether that drags"},
	"lantern": {"name": "Storm Lantern", "scene": "res://src/player/weapons/storm_lantern.tscn",
		"desc": "arcs of light that mark, a beacon"},
	"bell": {"name": "Keeper's Bell", "scene": "res://src/player/weapons/keepers_bell.tscn",
		"desc": "slow swing, stunning slam, parry toll"},
	"line": {"name": "Line & Sinker", "scene": "res://src/player/weapons/line_sinker.tscn",
		"desc": "long cracks, the third hauls; a weight"},
}
const DEFAULT := "gaff"

## Aspects: every weapon can remember someone. Bram sets one for echo shards; the weapon
## reads its own from the profile (`aspects[id]`) and adjusts itself in _ready.
const ASPECT_COST := 4
const ASPECTS := {
	"gaff": [
		{"id": "gaff_maren", "name": "Maren's Gaff", "desc": "fast charge; heavies crack bosses"},
		{"id": "gaff_drowned", "name": "Drowned Gaff", "desc": "throws carry you; third hit +2"},
	],
	"net": [
		{"id": "net_wren", "name": "Wren's Knife", "desc": "stabs +1; finisher bleeds longer"},
		{"id": "net_cart", "name": "Cartographer's Net", "desc": "wider net that holds 3 s"},
	],
	"harpoon": [
		{"id": "harpoon_bosun", "name": "Bosun's Gun", "desc": "five bolts, faster reload"},
		{"id": "harpoon_chain", "name": "Chainmother's Line", "desc": "tethered things take +40%"},
	],
	"lantern": [
		{"id": "lantern_orla", "name": "Orla's Lantern", "desc": "arcs +1; lit lasts 5.5 s"},
		{"id": "lantern_fen", "name": "Fen's Lantern", "desc": "wider beacon, burns longer"},
	],
	"bell": [
		{"id": "bell_keeper", "name": "Keeper's Toll", "desc": "longer toll; parries stun 3 s"},
		{"id": "bell_sunken", "name": "Sunken Bell", "desc": "wider slam ring, +3 damage"},
	],
	"line": [
		{"id": "line_long", "name": "Long Line", "desc": "longer reach; third hit +2"},
		{"id": "line_lead", "name": "Lead Sinker", "desc": "sinker 12 dmg, wider, slows longer"},
	],
}

var id: String = "weapon"
var aspect: String = ""


## The aspect set for a weapon in the profile, or "" when it is plain.
static func aspect_of(p_id: String) -> String:
	var a = SaveManager.data.get("aspects", {})
	return str(a.get(p_id, "")) if a is Dictionary else ""


static func aspect_entry(aspect_id: String) -> Dictionary:
	for w in ASPECTS:
		for a in ASPECTS[w]:
			if a.id == aspect_id:
				return a
	return {}


func _load_aspect() -> void:
	aspect = aspect_of(id)


static func scene_for(p_id: String) -> PackedScene:
	var entry: Dictionary = ALL.get(p_id, ALL[DEFAULT])
	return load(entry.scene)


static func name_of(p_id: String) -> String:
	return ALL.get(p_id, ALL[DEFAULT]).name


## Movement speed multiplier while attacking.
func move_mult() -> float:
	return 1.0


func is_busy() -> bool:
	return false


func special_ready() -> bool:
	return true


## 0..1, 1 = ready. Drawn by the HUD.
func special_cooldown_fraction() -> float:
	return 1.0


## 0..1 while charging a heavy, else 0.
func charge_fraction() -> float:
	return 0.0


func is_charging() -> bool:
	return false


## Attack button pressed.
func try_attack() -> void:
	pass


## Attack button state every frame.
func set_held(_held: bool) -> void:
	pass


## Attack pressed during / right after a dash.
func try_lunge() -> void:
	pass


## Special button pressed.
func try_special() -> void:
	pass


## Dash / hurt cancels whatever is happening.
func cancel() -> void:
	pass


## The player dashed in `dir` (tethers, wakes...).
func on_dash(_dir: Vector2) -> void:
	pass


## Short text next to the special bar ("2/3", "reloading"), or nothing.
func ammo_text() -> String:
	return ""


## Shared damage multiplier for a hit going live: stat mods, water surge, riptide crit.
func arm_mult(player: Player, heavy: bool, lunge: bool, crit: bool, ranged: bool = false) -> float:
	var m: Dictionary = player.mods
	var mult := float(m.damage) * (1.0 + player.rally)
	if ranged:
		mult *= float(m.ranged_mult)
	if heavy:
		mult *= float(m.heavy_damage)
	if lunge:
		mult *= float(m.lunge_mult)
	if crit:
		mult *= float(m.riptide_crit)
	if player.in_water:
		mult *= float(m.water_damage)
	return mult
