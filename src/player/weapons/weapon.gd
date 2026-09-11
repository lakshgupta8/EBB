class_name Weapon
extends Node2D
## What the player expects from any weapon. Each weapon scene overrides the parts it
## uses; the defaults are "nothing happens" so a half-built weapon never crashes the run.

const ALL := {
	"gaff": {"name": "Gaff Hook", "scene": "res://src/player/weapons/gaff_hook.tscn",
		"desc": "3-hit combo, heavy sweep, hook throw"},
	"net": {"name": "Net & Knife", "scene": "res://src/player/weapons/net_knife.tscn",
		"desc": "fast bleeding stabs, a net that roots"},
}
const DEFAULT := "gaff"

var id: String = "weapon"


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


## Shared damage multiplier for a hit going live: stat mods, water surge, riptide crit.
func arm_mult(player: Player, heavy: bool, lunge: bool, crit: bool) -> float:
	var m: Dictionary = player.mods
	var mult := float(m.damage)
	if heavy:
		mult *= float(m.heavy_damage)
	if lunge:
		mult *= float(m.lunge_mult)
	if crit:
		mult *= float(m.riptide_crit)
	if player.in_water:
		mult *= float(m.water_damage)
	return mult
