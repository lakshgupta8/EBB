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
	{"id": "wreck", "name": "The Wreck", "desc": "flats boss: slams, charges, calls the flats",
		"lore": "Maren's boat, or one very like it, come back for the keeper it lost."},
	{"id": "tidewisp", "name": "Tidewisp", "desc": "hangs back, throws cold light, runs when you close",
		"lore": "A light over the place a keeper went under. It has kept its distance from everything ever since."},
	{"id": "netted", "name": "The Netted", "desc": "flats elite: throws a net that roots you",
		"lore": "He went over the side and came back up inside his own net. He has been throwing it at whatever passes for three hundred years."},
	{"id": "mooring", "name": "Mooring", "desc": "lashes a chain where he faced; sidestep it",
		"lore": "A harbour hand with the mooring line still round his arm. He held the ship to the quay the night it tried to leave, and he is holding it still."},
	{"id": "barnacle", "name": "Barnacle Swarm", "desc": "scuttles and bites; breaks into two",
		"lore": "Barnacles off the hulls, moving together the way the citizens do. Break one up and the halves keep coming."},
	{"id": "deckhand", "name": "Deckhand", "desc": "shield turns front hits; open after the swing",
		"lore": "Saltmere's sailors, drilled to hold a line. The shield does not know the ship is gone. Get behind it, or wait for the swing."},
	{"id": "chainmother", "name": "The Chainmother", "desc": "harbour boss: sweeps, drops anchors, hauls",
		"lore": "The dock crane. It was told to hold the ships, so it held them under, and it has legs now."},
	{"id": "coral_crab", "name": "Coral Crab", "desc": "hides as coral; bursts out to pinch",
		"lore": "It grew a dead coral head for a shell and sits among the others. Hidden, it hardly feels a blow. Walk close and it comes up to meet you."},
	{"id": "reef_ray", "name": "Reef Ray", "desc": "circles, then glides through you",
		"lore": "It rides what is left of the current. With the water behind it, it glides far; against it, barely. Step aside, not back."},
	{"id": "tidewall", "name": "The Tidewall", "desc": "reef boss: throws stones, surges, turns the water",
		"lore": "A stretch of Saltmere's sea wall, stood up. The sea comes through its breach, and the water in the channels runs whichever way it says."},
	{"id": "reefwarden", "name": "The Reefwarden", "desc": "reef elite: a maul, and a surge that shoves",
		"lore": "One of the divers who kept Saltmere's sea wall. The current cannot move him; his boots are lead. Neither, it turns out, could three hundred years."},
	{"id": "polyp_swarm", "name": "Polyp Swarm", "desc": "puffs spores; sinks and comes up elsewhere",
		"lore": "Polyps grown out of the living coral, the only new thing on the reef in three hundred years. Close on it and it goes under, and up again on another living patch."},
	{"id": "choir", "name": "The Choir", "desc": "streets elite: a note that wakes the street",
		"lore": "They were singing in the chapel when the city asked. They were told they would be kept exactly as they were, and they are: mid-note."},
	{"id": "still_citizen", "name": "Still Citizen", "desc": "a statue until you are close",
		"lore": "The people of Saltmere, kept exactly as they were. They move when you are not looking, and faster when you are."},
	{"id": "lamplighter", "name": "Lamplighter", "desc": "kindles the others; throws its lantern alone",
		"lore": "Lit the lamps the night the city went under. Still lighting them. The light wakes the others."},
	{"id": "bell_ringer", "name": "Bell Ringer", "desc": "long tell, shockwave, calls the drowned up",
		"lore": "Rang the small bells the night the big one rang. Rings them still, and the drowned come up to hear."},
	{"id": "swimmer", "name": "Swimmer", "desc": "fast in water, slow on stone",
		"lore": "What a citizen becomes when the water is deep enough. Fast in it, lost out of it."},
	{"id": "bell", "name": "The Bell of Saltmere", "desc": "streets boss: tolls, swings, peals",
		"lore": "The bell Wren rang the night the city asked to be kept. The verger carries it. It has not stopped."},
	{"id": "keeper_shade", "name": "Keeper's Shade", "desc": "fights with a dark copy of your weapon",
		"lore": "Every keeper before you, held in the hall. They fight the way you fight. They learned it from the same lantern."},
	{"id": "tallow", "name": "Tallow", "desc": "pours burning wax on the floor; do not stand in it",
		"lore": "A keeper who stood in the hall until the candle on his head ran down over him. He is still holding the light up, technically."},
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
	{"id": "nessa", "name": "Nessa the Fisher", "desc": "contracts and smoked fish",
		"lore": "Fished the flats before the tide went strange and fishes them still. Pays in pearls, on time."},
	{"id": "bram", "name": "Bram the Drowned", "desc": "Saltmere's smith; the forge",
		"lore": "Three hundred years under and still a smith. Get him to a fire and he makes things that bite."},
	{"id": "pell", "name": "Pell the Diver", "desc": "echo from the harbour; salt-glass",
		"lore": "Dived the harbour for the crane's chains, before. Dives now for what the sea has made of them."},
	{"id": "mason", "name": "Hale the Mason", "desc": "echo from the reef; the breakwater",
		"lore": "Laid stone on Saltmere's sea wall, and kept pointing it under the sea. Would like, for once, to build something the water is on the outside of."},
	{"id": "wren", "name": "Sister Wren", "desc": "Saltmere's priestess; blessings",
		"lore": "She rang the bell that asked the sea to keep them, and meant it kindly. She is still praying."},
	{"id": "cartographer", "name": "The Cartographer", "desc": "nameless; charts a room",
		"lore": "Mapped every street before the water came, and every keeper's name under the hall, in order."},
	{"id": "choir", "name": "The Choir", "desc": "spared in the streets; hymns",
		"lore": "Nine singers on one breath for three hundred years. Somebody let the note end. They sing for the rock now."},
	{"id": "idris", "name": "Idris the Harbourmaster", "desc": "the dock: keels, launches",
		"lore": "Held the ships to the quay the night the crane took them. Has not forgiven the crane or himself."},
	{"id": "aldous", "name": "Keeper Aldous", "desc": "echo from the hall; the journal",
		"lore": "Kept the light before Maren. Wrote nine pages about what the lantern is, and went down anyway."},
	{"id": "maren", "name": "Maren", "desc": "the old keeper; the endings",
		"lore": "Went down to take Saltmere's place at the bottom. Came back up because you carried her."},
]

## The second paragraph of an enemy's entry, earned after twenty of them.
const ENEMY_MORE := {
	"tidewall": "The masons laid it to stand three hundred years. It has, to the day. Nobody asked it to stand for the sea's side.",
	"reefwarden": "The wardens' guild met at the breach every spring tide to see what the sea had taken. He is still waiting for the others.",
	"coral_crab": "The head is not its own. It took the coral from something that died standing, and the coral did not mind.",
	"reef_ray": "It is the only thing out here that was glad when the water moved again.",
	"polyp_swarm": "Where it grows, the reef is alive. Every one you break is a little more of it dead. The Ebb does not mind which.",
	"shellback": "Turn it over and the keel is a boat's keel. The claws grew later.",
	"gull": "They dive at the lantern, not at you. Put the light down and they circle, lost.",
	"wrack_crab": "It charges in a straight line because it cannot see corners. Nothing under the sea can.",
	"wreck": "There is a name on the transom, under the barnacles. Maren has never read it.",
	"tidewisp": "Each one hangs over the spot a keeper drowned. Count them and you have the number Orla will not say.",
	"netted": "The net was his own. He was proud of it. He mended it the morning he drowned in it.",
	"mooring": "The rope is not tied to anything any more. He holds it because holding it is what he is.",
	"barnacle": "They move as one because the hull did. Break the hull's memory and the halves forget each other.",
	"deckhand": "The drill was: shield up, hold the line, wait for the order. The order never came.",
	"chainmother": "It was built to lift ships out of the water. It found a way to lift them in.",
	"choir": "Nine voices. Kill one and the other eight sing on inside it. Let it finish and all nine stop.",
	"still_citizen": "They were kept exactly as they were, which was: afraid, and looking at the door.",
	"lamplighter": "The lamps he lights are the ones the city put out on purpose, the night it hid.",
	"bell_ringer": "Small bells answer the big one. He rings them so the drowned know it is still tolling.",
	"swimmer": "A citizen who stopped waiting by the door and went out to meet the water. It went well, for a while.",
	"bell": "The Bell of Saltmere was cast with a name in it. Wren's. She was six.",
	"keeper_shade": "It does not copy your weapon. It remembers its own, and every keeper had the same one.",
	"tallow": "The candle is the lantern, as it looks after long enough. Nobody told him to put it down.",
	"anchor": "Its chain runs to the Ebb. Everything in the hall is on a chain that runs to the Ebb.",
	"deep_maw": "Not mouths. Ears. It is listening for the lantern, and the lantern is always talking.",
	"ebb": "It has a name too. Nobody has said it in three hundred years, which is how it likes it.",
}
const MORE_KILLS := 20

const PLACES := [
	{"id": "rock", "name": "Marrow Rock", "desc": "the lighthouse; home",
		"lore": "A lighthouse island off a cold coast. Forty people and a light that was never for ships."},
	{"id": "flats", "name": "The Flats", "desc": "sand, pools, the Wreck",
		"lore": "The sea's floor between the rock and the city, bare for a few hours a night. Keepers' boats lie upturned on it."},
	{"id": "harbour", "name": "The Sunken Harbour", "desc": "hulls, the drydock, the Chainmother",
		"lore": "Where Saltmere's ships tried to leave, the night it drowned. The crane held them. It is still holding them."},
	{"id": "reef", "name": "The Reef", "desc": "the sea wall, the currents, coral",
		"lore": "Outside Saltmere's sea wall. Held still three hundred years, the coral died standing; where the water runs again, it grows."},
	{"id": "streets", "name": "The Drowned Streets", "desc": "Saltmere, the Bell",
		"lore": "Saltmere as it was the night it asked to be kept. The lamps are still lit and the people are still standing."},
	{"id": "hall", "name": "The Deep Hall", "desc": "under the city, the Ebb",
		"lore": "Under the city. Every keeper who ever went down stands here, held, and the Ebb holds them."},
]

const FAMILY_LORE := {
	"salt": "Salt: the sea's offence, taken into the blood.",
	"brine": "Brine: what the drowned are pickled in. It keeps.",
	"current": "Current: the pull under the surface. Move with it.",
	"deep": "Deep: things the bottom of the sea knows and should not.",
	"echo": "Echo: what the people you brought back remember, lent to the living.",
}

const TABS := ["enemy", "mark", "people", "place", "weapon", "journal", "contract"]
const TAB_NAMES := {"enemy": "Drowned", "mark": "Marks", "people": "People", "place": "Places",
	"weapon": "Weapons", "journal": "Journal", "contract": "Contracts"}


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
			if id in ["orla", "fen"]:
				return true
			if id == "nessa":
				return int(SaveManager.data.get("runs", 0)) >= 2
			if id == "idris":
				return SaveManager.flag("boss_chainmother_broken")
			return SaveManager.flag("echo_" + id)
		"place":
			return id == "rock" or id in _store().get("place", [])
		"weapon":
			return id in SaveManager.data.get("weapons", ["gaff", "net"])
		"journal":
			return int(id) in SaveManager.data.get("journals", [])
		"contract":
			return id in SaveManager.data.get("contracts_done", [])
		_:
			return id in _store().get(kind, [])


## How many of an enemy you have killed, ever.
static func kills_of(id: String) -> int:
	return int(SaveManager.data.get("kills_by", {}).get(id, 0))


## Codex id of an enemy node: its scene's file name (shellback, bell, ebb...).
static func enemy_id(e: Node) -> String:
	return e.scene_file_path.get_file().get_basename()


## Rows for a tab: [{name, desc, lore, found}], in a fixed order.
## The held sprite each weapon shows in its codex slot (art Stage 16).
const WEAPON_SHEET := {"gaff": "gaff_hook", "net": "knife", "harpoon": "harpoon_gun", "lantern": "storm_lantern",
	"bell": "keepers_bell", "line": "line_handle"}


static func entries(kind: String) -> Array:
	var out: Array = []
	match kind:
		"enemy":
			for e in ENEMIES:
				var lore: String = e.lore
				var n := kills_of(e.id)
				if n >= MORE_KILLS and ENEMY_MORE.has(e.id):
					lore += "  " + str(ENEMY_MORE[e.id])
				elif found(kind, e.id):
					lore += "  (%d of %d killed for more)" % [n, MORE_KILLS]
				out.append({"name": e.name, "desc": e.desc, "lore": lore, "found": found(kind, e.id),
					"sprite": "res://assets/sprites/%s.png" % e.id})
		"weapon":
			for id in Weapon.ALL:
				var w: Dictionary = Weapon.ALL[id]
				var lore := ""
				for a in Weapon.ASPECTS.get(id, []):
					lore += "%s: %s.  " % [a.name, a.desc]
				out.append({"name": w.name, "desc": w.desc, "lore": lore.strip_edges(), "found": found(kind, id),
					"sprite": "res://assets/sprites/%s.png" % WEAPON_SHEET.get(id, id)})
		"journal":
			for i in Story.JOURNAL.size():
				var id := str(i + 1)
				out.append({"name": "Page %d" % (i + 1), "desc": "Keeper Aldous", "lore": Story.JOURNAL[i], "found": found(kind, id)})
		"contract":
			for c in Contracts.ALL:
				out.append({"name": c.name, "desc": c.desc, "lore": "Nessa paid: " + LogUI._reward_text(c), "found": found(kind, c.id)})
		"mark":
			for m in Tidemarks.ALL:
				out.append({"name": m.name, "desc": m.desc, "lore": FAMILY_LORE[m.family], "found": found(kind, m.id),
					"color": Tidemarks.FAMILY_COLOR[m.family], "family": m.family})
		"people":
			for p in PEOPLE:
				out.append({"name": p.name, "desc": p.desc, "lore": p.lore, "found": found(kind, p.id),
					"sprite": "res://assets/sprites/npc_%s.png" % p.id})
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
