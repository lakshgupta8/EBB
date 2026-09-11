class_name Codex
extends RefCounted
## What you have met so far. Four tabs: the drowned (enemies), tidemarks, people, places.
## Discoveries live in the profile under "codex": {kind: [ids]}. Entries you have not met
## show as "???" with a count, so the shape of what is left is visible.

const ENEMIES := [
	{"id": "shellback", "name": "Shellback", "desc": "slow, tanky, slams its shell",
		"lore": "A crab the size of a dog under a keeper's boat, upturned. It still rows."},
	{"id": "gull", "name": "Salt Gull", "desc": "circles, then dives at where you were",
		"lore": "The gulls never left when the city went under. They dive at anything lit."},
	{"id": "wrack_crab", "name": "Wrack Crab", "desc": "keeps its distance, then charges straight",
		"lore": "Bounces off walls and sulks. Nothing in the flats is in a hurry but this."},
	{"id": "wreck", "name": "The Wreck", "desc": "biome 1 boss: slams, charges, calls the flats",
		"lore": "Maren's boat, or one very like it, come back for the keeper it lost."},
	{"id": "still_citizen", "name": "Still Citizen", "desc": "a statue until you are close",
		"lore": "The people of Saltmere, kept exactly as they were. They move when you are not looking, and faster when you are."},
	{"id": "lamplighter", "name": "Lamplighter", "desc": "kindles the others; throws its lantern alone",
		"lore": "Lit the lamps the night the city went under. Still lighting them. The light wakes the others."},
	{"id": "bell_ringer", "name": "Bell Ringer", "desc": "long tell, shockwave, calls the drowned up",
		"lore": "Rang the small bells the night the big one rang. Rings them still, and the drowned come up to hear."},
	{"id": "swimmer", "name": "Swimmer", "desc": "fast in water, slow on stone",
		"lore": "What a citizen becomes when the water is deep enough. Fast in it, lost out of it."},
	{"id": "bell", "name": "The Bell of Saltmere", "desc": "biome 2 boss: tolls, swings, peals",
		"lore": "The bell Wren rang the night the city asked to be kept. The verger carries it. It has not stopped."},
	{"id": "keeper_shade", "name": "Keeper's Shade", "desc": "fights with a dark copy of your weapon",
		"lore": "Every keeper before you, held in the hall. They fight the way you fight. They learned it from the same lantern."},
	{"id": "anchor", "name": "Anchor", "desc": "throws a chain; dash through it or be hauled",
		"lore": "A dock hand still dragging his anchor. The Ebb's hands: chains that want you at the bottom where it can keep you."},
	{"id": "deep_maw", "name": "Deep Maw", "desc": "a mouth in the floor; open is vulnerable",
		"lore": "Mouths in the hall floor. The Ebb tasting what comes down."},
	{"id": "ebb", "name": "The Ebb", "desc": "the last boss: waves, hauls, shades, surges",
		"lore": "The thing under the sea that Saltmere asked to keep it safe forever. It did. It is not cruel. It is only patient."},
]

const PEOPLE := [
	{"id": "orla", "name": "Elder Orla", "desc": "keeps the Ledger by the tower",
		"lore": "Blunt and guilty. She handed you the lantern and knew exactly what it was."},
	{"id": "fen", "name": "Fen", "desc": "village kid; thinks you are a hero",
		"lore": "Held the lantern once, when Maren let them. Says it was warm."},
	{"id": "bram", "name": "Bram the Drowned", "desc": "Saltmere's smith; the forge",
		"lore": "Three hundred years under and still a smith. Get him to a fire and he makes things that bite."},
	{"id": "wren", "name": "Sister Wren", "desc": "Saltmere's priestess; blessings",
		"lore": "She rang the bell that asked the sea to keep them, and meant it kindly. She is still praying."},
	{"id": "cartographer", "name": "The Cartographer", "desc": "nameless; charts a room",
		"lore": "Mapped every street before the water came, and every keeper's name under the hall, in order."},
	{"id": "maren", "name": "Maren", "desc": "the old keeper; the endings",
		"lore": "Went down to take Saltmere's place at the bottom. Came back up because you carried her."},
]

const PLACES := [
	{"id": "rock", "name": "Marrow Rock", "desc": "the lighthouse; home",
		"lore": "A lighthouse island off a cold coast. Forty people and a light that was never for ships."},
	{"id": "flats", "name": "The Flats", "desc": "biome 1: sand, pools, the Wreck",
		"lore": "The sea's floor between the rock and the city, bare for a few hours a night. Keepers' boats lie upturned on it."},
	{"id": "streets", "name": "The Drowned Streets", "desc": "biome 2: Saltmere, the Bell",
		"lore": "Saltmere as it was the night it asked to be kept. The lamps are still lit and the people are still standing."},
	{"id": "hall", "name": "The Deep Hall", "desc": "biome 3: under the city, the Ebb",
		"lore": "Under the city. Every keeper who ever went down stands here, held, and the Ebb holds them."},
]

const FAMILY_LORE := {
	"salt": "Salt: the sea's offence, taken into the blood.",
	"brine": "Brine: what the drowned are pickled in. It keeps.",
	"current": "Current: the pull under the surface. Move with it.",
	"deep": "Deep: things the bottom of the sea knows and should not.",
}

const TABS := ["enemy", "mark", "people", "place"]
const TAB_NAMES := {"enemy": "The Drowned", "mark": "Tidemarks", "people": "People", "place": "Places"}


static func _store() -> Dictionary:
	if not SaveManager.data.has("codex") or not (SaveManager.data["codex"] is Dictionary):
		SaveManager.data["codex"] = {}
	return SaveManager.data["codex"]


## Mark `id` of `kind` as met. Returns true the first time.
static func discover(kind: String, id: String) -> bool:
	var s := _store()
	if not s.has(kind):
		s[kind] = []
	if id in s[kind]:
		return false
	s[kind].append(id)
	SaveManager.save_profile()
	return true


static func found(kind: String, id: String) -> bool:
	match kind:
		"people":
			return id in ["orla", "fen"] or SaveManager.flag("echo_" + id)
		"place":
			return id == "rock" or id in _store().get("place", [])
		_:
			return id in _store().get(kind, [])


## Codex id of an enemy node: its scene's file name (shellback, bell, ebb...).
static func enemy_id(e: Node) -> String:
	return e.scene_file_path.get_file().get_basename()


## Rows for a tab: [{name, desc, lore, found}], in a fixed order.
static func entries(kind: String) -> Array:
	var out: Array = []
	match kind:
		"enemy":
			for e in ENEMIES:
				out.append({"name": e.name, "desc": e.desc, "lore": e.lore, "found": found(kind, e.id)})
		"mark":
			for m in Tidemarks.ALL:
				out.append({"name": m.name, "desc": m.desc, "lore": FAMILY_LORE[m.family], "found": found(kind, m.id),
					"color": Tidemarks.FAMILY_COLOR[m.family]})
		"people":
			for p in PEOPLE:
				out.append({"name": p.name, "desc": p.desc, "lore": p.lore, "found": found(kind, p.id)})
		"place":
			for p in PLACES:
				out.append({"name": p.name, "desc": p.desc, "lore": p.lore, "found": found(kind, p.id)})
	return out


static func count(kind: String) -> Vector2i:
	var n := 0
	var rows := entries(kind)
	for r in rows:
		if r.found:
			n += 1
	return Vector2i(n, rows.size())
