class_name Fish
extends RefCounted
## Nessa's fish: consumables bought on the rock for pearls, carried into the night (three,
## four with her bag) and eaten in order with F. Each does one thing, once.

const ALL := {
	"eel": {"name": "Smoked eel", "desc": "heal 30", "price": 6},
	"broth": {"name": "Shell broth", "desc": "absorb the next hit", "price": 8},
	"still": {"name": "Still fish", "desc": "the tide holds 8 s", "price": 10},
	"cod": {"name": "Salt cod", "desc": "+15 max health tonight", "price": 12},
}
const ORDER := ["eel", "broth", "still", "cod"]


static func get_fish(id: String) -> Dictionary:
	return ALL.get(id, {})


static func name_of(id: String) -> String:
	return str(ALL.get(id, {}).get("name", id))


## Eat one: what it does to the keeper and the night. Returns the text to show.
static func eat(id: String, player: Player, run) -> String:
	match id:
		"eel":
			player.health.heal(30)
			return "+30"
		"broth":
			player.hurtbox.shield_count = maxi(player.hurtbox.shield_count, 1)
			return "SHELL BROTH"
		"still":
			if run:
				run.state.tide.pause(8.0)
			return "THE TIDE HOLDS"
		"cod":
			player.health.max_hp += 15
			player.health.heal(15)
			return "+15 MAX"
	return ""
