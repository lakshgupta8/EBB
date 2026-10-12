class_name KeeperLog
extends RefCounted
## The Keeper's Log: forty-four milestones, claimed on the rock the moment they hold. Each pays
## pearls or shards; a few open a lantern colour. Conditions use the dialog grammar so the
## same test lints them.

const ALL := [
	{"id": "first_night", "name": "First night", "desc": "go down once", "cond": "runs>=1", "pearls": 5},
	{"id": "ten_kills", "name": "Ten of them", "desc": "10 kills", "cond": "stat:kills>=10", "pearls": 5},
	{"id": "third_room", "name": "The third room", "desc": "reach the third room", "cond": "best_depth>=2", "pearls": 5},
	{"id": "wreck", "name": "Only a boat", "desc": "break the Wreck", "cond": "flag:boss_wreck_broken", "pearls": 10},
	{"id": "bram", "name": "A smith on the rock", "desc": "bring Bram home", "cond": "flag:echo_bram", "shards": 1},
	{"id": "chainmother", "name": "The crane lets go", "desc": "break the Chainmother", "cond": "flag:boss_chainmother_broken", "pearls": 15},
	{"id": "bell", "name": "Quiet", "desc": "silence the Bell", "cond": "flag:boss_bell_broken", "pearls": 20},
	{"id": "first_win", "name": "All the way down", "desc": "win a night", "cond": "wins>=1", "pearls": 30, "cosmetic": "cold"},
	{"id": "three_wins", "name": "Three nights", "desc": "win three nights", "cond": "wins>=3", "pearls": 30},
	{"id": "ten_wins", "name": "A keeper", "desc": "win ten nights", "cond": "wins>=10", "pearls": 60, "cosmetic": "white"},
	{"id": "kills_100", "name": "A hundred", "desc": "100 kills", "cond": "stat:kills>=100", "pearls": 10},
	{"id": "kills_500", "name": "Five hundred", "desc": "500 kills", "cond": "stat:kills>=500", "pearls": 25},
	{"id": "kills_2000", "name": "The drowned thinned", "desc": "2000 kills", "cond": "stat:kills>=2000", "pearls": 60},
	{"id": "vault_1", "name": "The strongroom", "desc": "open a vault", "cond": "stat:vaults>=1", "pearls": 8},
	{"id": "vault_10", "name": "Locksmith", "desc": "open ten vaults", "cond": "stat:vaults>=10", "pearls": 25},
	{"id": "challenge_1", "name": "Held", "desc": "hold a challenge", "cond": "stat:challenges>=1", "pearls": 8},
	{"id": "challenge_10", "name": "Breakwater", "desc": "hold ten challenges", "cond": "stat:challenges>=10", "pearls": 25, "cosmetic": "green"},
	{"id": "dive_1", "name": "Under", "desc": "take a dive's altar", "cond": "stat:dives>=1", "pearls": 8},
	{"id": "dive_10", "name": "Diver", "desc": "ten dives", "cond": "stat:dives>=10", "pearls": 25},
	{"id": "wet_5", "name": "Wet feet", "desc": "clear five wet rooms", "cond": "stat:wet_rooms>=5", "pearls": 15},
	{"id": "elites_25", "name": "The big ones", "desc": "kill 25 elites", "cond": "stat:elites>=25", "pearls": 20},
	{"id": "named_4", "name": "By name", "desc": "kill every named elite", "cond": "stat:named_elites>=4", "shards": 2},
	{"id": "echoes_5", "name": "Five home", "desc": "five echoes on the rock", "cond": "echoes>=5", "pearls": 20},
	{"id": "echoes_all", "name": "Everyone home", "desc": "every echo on the rock", "cond": "echoes>=8", "pearls": 40, "cosmetic": "violet"},
	{"id": "journals_3", "name": "His hand", "desc": "three journal pages", "cond": "journals>=3", "pearls": 10},
	{"id": "journals_9", "name": "The whole journal", "desc": "all nine pages", "cond": "journals>=9", "pearls": 30},
	{"id": "contracts_5", "name": "Odd jobs", "desc": "five contracts", "cond": "contracts>=5", "pearls": 15},
	{"id": "contracts_15", "name": "Regular", "desc": "fifteen contracts", "cond": "contracts>=15", "pearls": 30},
	{"id": "contracts_30", "name": "Nessa's keeper", "desc": "thirty contracts", "cond": "contracts>=30", "pearls": 50},
	{"id": "fen", "name": "Fen's shells", "desc": "finish Fen's chain", "cond": "fen>=6", "pearls": 20},
	{"id": "gifts_3", "name": "Three gifts", "desc": "give three gifts", "cond": "stat:gifts>=3", "pearls": 10},
	{"id": "gifts_all", "name": "Everyone knows you", "desc": "every affinity chain", "cond": "stat:gifts>=33", "pearls": 60},
	{"id": "tide_1", "name": "Faster water", "desc": "win at spring tide 1", "cond": "stat:wins_tier_1>=1", "pearls": 20},
	{"id": "tide_4", "name": "Dry wells", "desc": "win at spring tide 4", "cond": "stat:wins_tier_4>=1", "pearls": 40},
	{"id": "tide_8", "name": "Riptide", "desc": "win at spring tide 8", "cond": "stat:wins_tier_8>=1", "pearls": 80},
	{"id": "ending_1", "name": "A choice", "desc": "see an ending", "cond": "any_ending", "pearls": 25},
	{"id": "endings_3", "name": "Every choice", "desc": "see all three endings", "cond": "endings>=3", "pearls": 50},
	{"id": "rests_3", "name": "Sleep on it", "desc": "rest three nights", "cond": "stat:rests>=3", "pearls": 10},
	{"id": "fish_10", "name": "Fed", "desc": "eat ten fish", "cond": "stat:fish_eaten>=10", "pearls": 10},
	{"id": "weapons_all", "name": "Every blade", "desc": "win with all six weapons", "cond": "stat:weapons_won>=6", "pearls": 50},
	# M8: the sea keeps time
	{"id": "daily_1", "name": "The sea keeps time", "desc": "play a daily night", "cond": "stat:dailies>=1", "pearls": 10},
	{"id": "trial_win", "name": "Four in one tide", "desc": "win the Keeper's Trial", "cond": "stat:wins_trial>=1", "pearls": 60},
	{"id": "neap_win", "name": "Bare stone", "desc": "win a neap night", "cond": "stat:wins_neap>=1", "pearls": 40},
	{"id": "riptide_win", "name": "Against the current", "desc": "win a riptide", "cond": "stat:wins_riptide>=1", "pearls": 40},
]

## Lantern colours the Log can open. "warm" is the keeper's own.
const LANTERNS := {
	"warm": {"name": "Warm", "color": Atmosphere.LANTERN},
	"cold": {"name": "Cold", "color": Color(0.75, 0.9, 1.0)},
	"green": {"name": "Sea green", "color": Color(0.75, 1.0, 0.82)},
	"violet": {"name": "Violet", "color": Color(0.9, 0.8, 1.0)},
	"white": {"name": "White", "color": Color(1.0, 1.0, 1.0)},
}
## Coats: the keeper's, and three given by people who like you.
const COATS := {
	"keeper": {"name": "Keeper's coat", "sheet": "res://assets/sprites/player.png"},
	"fisher": {"name": "Fisher's oilskin", "sheet": "res://assets/sprites/player_fisher.png"},
	"verger": {"name": "Verger's robe", "sheet": "res://assets/sprites/player_verger.png"},
	"harbour": {"name": "Harbour blue", "sheet": "res://assets/sprites/player_harbour.png"},
}


static func get_milestone(id: String) -> Dictionary:
	for m in ALL:
		if m.id == id:
			return m
	return {}


static func claimed() -> Array:
	return SaveManager.data.get("log", [])


static func is_claimed(id: String) -> bool:
	return id in claimed()


static func holds(m: Dictionary) -> bool:
	return Dialog.check(str(m.cond))


## Claim every milestone that holds and is not yet claimed. Returns them, in order.
static func claim_all() -> Array:
	var out: Array = []
	var list: Array = claimed()
	for m in ALL:
		if m.id in list or not holds(m):
			continue
		list.append(m.id)
		out.append(m)
		SaveManager.data["pearls"] = int(SaveManager.data.pearls) + int(m.get("pearls", 0))
		SaveManager.data["shards"] = int(SaveManager.data.get("shards", 0)) + int(m.get("shards", 0))
		if m.has("cosmetic"):
			unlock_cosmetic(str(m.cosmetic))
	SaveManager.data["log"] = list
	SaveManager.save_profile()
	return out


static func unlock_cosmetic(id: String) -> void:
	var owned: Array = SaveManager.data.get("cosmetics_owned", [])
	if not id in owned:
		owned.append(id)
	SaveManager.data["cosmetics_owned"] = owned


static func owns_cosmetic(id: String) -> bool:
	return id in SaveManager.data.get("cosmetics_owned", ["warm", "keeper"])


static func lantern_color() -> Color:
	var id := str(SaveManager.data.get("cosmetics", {}).get("lantern", "warm"))
	return LANTERNS.get(id, LANTERNS.warm).color


static func coat_sheet() -> String:
	var id := str(SaveManager.data.get("cosmetics", {}).get("coat", "keeper"))
	return COATS.get(id, COATS.keeper).sheet
