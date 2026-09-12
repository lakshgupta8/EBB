class_name Story
extends RefCounted
## Every line anyone says, in one place, chosen from what the profile remembers.
## Dialogue is short and dry; the truth comes out in layers (see DESIGN.md, Story).
##   - NPC lines: orla(), fen(), bram(), wren(), cartographer(), maren()
##   - Whispers: the lantern's one-time lines during a run (whisper(key) -> "" once seen)
##   - Endings: ENDINGS data, ending_available(), record_ending(), endings_seen()

## The three endings Maren can give you. `cards` are shown one at a time over black.
const ENDINGS := {
	"keep": {
		"name": "Keep the tide", "title": "KEEP THE TIDE",
		"desc": "take her place; the village sleeps",
		"cards": [
			"You go down one last time. The hall is empty and the water in it is still. You hang the lantern on the dais where Maren hung hers.",
			"The Ebb does not come. It does not need to. Something has to stand at the bottom, and you stand.",
			"Above you the sea settles over Saltmere like a sheet pulled up. The village sleeps. The tide comes in on time and goes out on time, and nobody ever finds out why.",
			"Maren keeps the light on Marrow Rock. Some nights she talks to the water. Some nights it answers.",
		],
	},
	"break": {
		"name": "Break the tide", "title": "BREAK THE TIDE",
		"desc": "break the lantern; the echoes go free",
		"cards": [
			"Bram heats the lantern until the glass sings. Wren says the words she has said for three hundred years, backwards. The Cartographer holds the map to the light so you can see where to strike.",
			"The lantern breaks. Under the sea, a long way down, something lets go of something it has held for a very long time.",
			"The tide comes in. Not the way it did, in a night; the way tides do, in an hour. The lower village goes under gently, and the people carry what they can up the hill.",
			"The echoes of Saltmere walk out of the water and past you and up the hill with them, and nobody keeps anything any more.",
		],
	},
	"walk": {
		"name": "Walk out", "title": "WALK OUT",
		"desc": "nobody anchors; the sea forgets",
		"cards": [
			"You do not go down. Nobody goes down. Maren sits on the step of the tower with the lantern between her feet and lets it go out.",
			"The tide goes out that night as far as it ever has, and the ruins are empty. No citizens. No shades. No keepers standing in the hall. The Cartographer's map has nobody on it at all.",
			"In the morning the sea comes back, and it is only the sea. It does not go out again. There was never anything under it but a city that asked for too much, and the city has walked home.",
			"The lantern hangs in the lighthouse with no oil in it. Fen asks if it is still warm. You hand it over. It is not.",
		],
	},
}
const ENDING_ORDER := ["keep", "break", "walk"]
## Everyone the sea can give back, in the order the night finds them.
const ECHO_IDS := ["bram", "pell", "wren", "cartographer", "choir", "aldous", "maren"]
const BREAK_NEEDS := 5

## Keeper Aldous's journal: nine pages the sea kept, hidden in vaults and dives. Layer
## three of the truth, in his hand, in order.
const JOURNAL := [
	"Page 1. Night one under the light. Orla's mother handed me the lantern the way you hand someone a baby you do not want. It was warm. I wrote that down because I did not believe it.",
	"Page 2. The flats at low water are the floor of a room with the roof off. I counted eleven upturned boats. Eleven keepers before me, then. Nobody told me the number. Nobody tells the number.",
	"Page 3. The Wreck is Maren's mother's boat. I have decided not to tell Maren. I have decided a great many things I will not tell Maren.",
	"Page 4. Salt-glass. I thought it was made of the drowned. It is not. It is what the sea makes when it has nothing to keep and wants to keep something anyway. Even the sea is lonely. Write that down, Aldous. Nobody will believe you.",
	"Page 5. The bell was rung on purpose. Wren rang it and Wren meant it kindly and Wren has been praying about it ever since. I do not think she should stop. I think the praying is the only thing holding the shape of her.",
	"Page 6. The Ebb spoke to me. Not in words. It showed me every keeper standing in the hall, and it showed me the light in my hand, and it asked, very politely, whether I would like to be kept. I said I would think about it.",
	"Page 7. I have worked it out. The lantern is not a light. It is a hook. The sea put it in Saltmere's hand the night the bell rang and it has been reeling us down, one keeper at a time, ever since. We call it keeping the tide. The tide keeps us.",
	"Page 8. If the hook is put down, the line goes slack. Nobody goes under. Nobody is kept. The sea forgets, because a sea cannot remember without something to remember with. I have not the nerve. Perhaps the next one.",
	"Page 9. I am going down tonight and I am not coming up, and I am leaving these pages where the sea will keep them, because the sea keeps everything. To whoever reads this: it can be put down. It only has to be put down by someone who could have carried it.",
]

## What Bram says when you are carrying a weapon that remembers someone.
const ASPECT_LINES := {
	"gaff_maren": "That is her hook, near enough. She wound it back the same way and she never once let go early.",
	"gaff_drowned": "The old crews hooked themselves to the hull in a blow. That is all this is. It will not lose you.",
	"net_wren": "Wren blessed a knife for me once. I laughed at her. It has not gone blunt since.",
	"net_cart": "He drew the net as a map: every knot a street. Throw it and see how much it covers now.",
	"harpoon_bosun": "The bosun kept five in the rack and counted them twice. Two more than anyone needs, he said, is one enough.",
	"harpoon_chain": "That is her chain in the line. Whatever you tie to it will feel what the ships felt.",
	"lantern_orla": "Orla's oil. She has been burning it in that window since before you were born, waiting for the wrong boat.",
	"lantern_fen": "The boy polished the glass for a week. It throws further than anything I have made. Do not tell him that.",
	"bell_keeper": "The keepers rang before they went down, so the village knew. Ring it and see what stops to listen.",
	"bell_sunken": "That bell sat on the seabed a long time. Everything it says now, it says to the floor as well.",
	"line_long": "More line than you need is the only kind worth having. Ask any fisher who has run out.",
	"line_lead": "A proper lead sinker. It goes where you put it and it stays there, and so does what it lands on.",
}

## The lantern's lines: shown once each, as a quiet banner, at the moment they fit.
const WHISPERS := {
	"first_night": "Keep the tide, Orla said. The lantern is warm in your hand. Lanterns are not warm.",
	"wreck": "A keeper's boat, upturned, with something living under it. The lantern pulls toward it like a compass needle.",
	"harbour": "The ships are all still here. Nobody left. Something on the quay made sure of that.",
	"challenge": "No door. The sea wants to see what you do when there is no door.",
	"tide_1": "The water is coming in faster tonight. You asked it to.",
	"tide_2": "Everything down here is thicker-skinned tonight. The sea has been feeding them.",
	"tide_3": "The big ones will not go down the first time. Nothing here ever did.",
	"tide_4": "The fountains are brackish. What is sweet in this place, the sea took first.",
	"tide_5": "Even the merchant is afraid tonight. He has raised his prices.",
	"tide_6": "The altars are quieter. They offer less because they are keeping more.",
	"tide_7": "The drowned have sent their captains. Every room has one now.",
	"tide_8": "It remembers you. It has been remembering you all this time, and now it is awake for it.",
	"dive": "Under the water the lantern burns brighter, not dimmer. It was made for down here.",
	"chainmother": "The crane was asked to hold the ships. Everything in Saltmere does exactly what it was asked, forever.",
	"harbour_ships": "Every hull is still tied up and every rope is still good. They did not fail to leave. They were not let.",
	"harbour_hands": "The hands are still on the quay, still holding the lines. Nobody told them the sailing was cancelled.",
	"netted": "He is wearing the net he drowned in. Down here nothing is ever taken off you; it is only kept on.",
	"choir": "That note has not stopped since the night it started. They are only louder now that the water is out of the way.",
	"death": "The water closed over you and the lantern pulled, hard, upward. You are at the foot of the tower and the tide is out again. That is what the lantern is for.",
	"taken": "The tide took you and the lantern brought you back, and half your salt came with you. The sea is patient, not cruel.",
	"cage": "The cage is not iron. It is a promise, kept too well. Open it and the promise fails a little.",
	"streets": "Nobody drowned in Saltmere. Look at their faces. They were kept, exactly as they were, and they are still waiting.",
	"bell": "That bell called the sea in. Someone rang it on purpose, and meant it kindly.",
	"hall": "Every keeper before you is standing in the hall. Not dead. Held. The lantern hums like it knows them by name.",
	"ebb": "It is not cruel. It was asked to keep them safe forever and it is still doing it. Maren is in there with it, mid-bargain.",
	"page": "A page in a keeper's hand, dry, in a place where nothing is dry. The sea kept it the way it keeps everything.",
	"glass": "Salt-glass. The sea made this out of nothing, because it wanted to keep something that was not a person.",
	"pell": "Someone is diving, down here, where there is nothing left to dive for. The lantern knows a diver's lungs when it hears them.",
	"aldous": "A keeper's cage, in the hall, with a keeper still in it. The lantern goes quiet. It knew him.",
	"choir_falter": "The note is failing. It could end here, if you let it. Nobody has ever let it.",
	"choir_spared": "It ended. Three hundred years on one breath, and you stood there and let it finish. The street is quiet for the first time.",
	"shortcut": "The water is going where you are going. For once, let it carry you.",
	"launch": "The dock. Idris tied the knot himself. The flats are behind you before the night has begun.",
}


# --- profile shorthand -------------------------------------------------------------
static func runs() -> int:
	return int(SaveManager.data.get("runs", 0))


static func wins() -> int:
	return int(SaveManager.data.get("wins", 0))


static func ebb_broken() -> bool:
	return SaveManager.flag("ebb_broken")


static func echo(id: String) -> bool:
	return SaveManager.flag("echo_" + id)


static func echoes_home() -> int:
	var n := 0
	for id in ECHO_IDS:
		if echo(id):
			n += 1
	return n


static func all_echoes_home() -> bool:
	return echoes_home() >= ECHO_IDS.size()


## Affinity with an NPC: 0..3, one level per gift.
static func affinity(npc: String) -> int:
	return int(SaveManager.data.get("affinity", {}).get(npc, 0))


static func perk(npc: String) -> bool:
	return SaveManager.flag("perk_" + npc)


static func gifts_in_hand() -> int:
	return int(SaveManager.data.get("glass", 0)) + int(SaveManager.data.get("shells", 0))


## A gift to `npc`: spends a piece of salt-glass (else a shell), raises affinity a level,
## pays the level's reward. Returns {lines, got, seen_before}, or {} when it cannot be given
## (nothing in hand, or nothing left to say).
static func give_gift(npc: String) -> Dictionary:
	var level := affinity(npc)
	var chain := Dialog.chain(npc, level + 1)
	if chain.is_empty() or gifts_in_hand() <= 0:
		return {}
	if int(SaveManager.data.get("glass", 0)) > 0:
		SaveManager.data["glass"] = int(SaveManager.data.glass) - 1
	else:
		SaveManager.data["shells"] = int(SaveManager.data.shells) - 1
	SaveManager.data["affinity"][npc] = level + 1
	SaveManager.count("gifts")
	var reward: Dictionary = chain.get("reward", {})
	var lines: Array = chain.get("lines", []).duplicate()
	var got: Array = []
	if int(reward.get("pearls", 0)) > 0:
		SaveManager.data["pearls"] = int(SaveManager.data.pearls) + int(reward.pearls)
		got.append("%d pearls" % int(reward.pearls))
	if int(reward.get("shards", 0)) > 0:
		SaveManager.data["shards"] = int(SaveManager.data.get("shards", 0)) + int(reward.shards)
		got.append("%d shards" % int(reward.shards))
	if reward.has("fish"):
		SaveManager.data["fish"].append(str(reward.fish))
		got.append(Fish.name_of(str(reward.fish)).to_lower())
	if reward.has("perk"):
		SaveManager.data["flags"]["perk_" + str(reward.perk)] = true
		got.append(str(reward.get("text", "a keepsake")))
	if reward.has("cosmetic"):
		KeeperLog.unlock_cosmetic(str(reward.cosmetic))
		got.append("a coat")
	var key := "%s_%d" % [npc, level + 1]
	var seen: Array = SaveManager.data.get("chains_seen", [])
	var seen_before := key in seen
	if not seen_before:
		seen.append(key)
	SaveManager.data["chains_seen"] = seen
	SaveManager.save_profile()
	if got.size() > 0:
		lines.append("(" + ", ".join(got) + ")")
	return {"lines": lines, "got": got, "seen_before": seen_before}


## The hub stays the way the last ending left it.
static func epilogue() -> String:
	return str(SaveManager.data.get("epilogue", ""))


static func endings_seen() -> Array:
	return SaveManager.data.get("endings", [])


static func seen(ending: String) -> bool:
	return ending in endings_seen()


static func record_ending(id: String) -> void:
	var list: Array = endings_seen()
	if not id in list:
		list.append(id)
	SaveManager.data["endings"] = list
	SaveManager.data["epilogue"] = id
	SaveManager.save_profile()


## "" when the ending can be chosen, else what is still missing.
static func ending_locked_reason(id: String) -> String:
	match id:
		"keep":
			return ""
		"break":
			if not (echo("bram") and echo("wren") and echo("cartographer")):
				return "needs Bram, Wren and the Cartographer on the rock"
			return "" if echoes_home() >= BREAK_NEEDS else "needs five echoes home (%d so far)" % echoes_home()
		"walk":
			if not all_echoes_home():
				return "needs every echo home (%d of %d)" % [echoes_home(), ECHO_IDS.size()]
			return "" if wins() >= 3 else "needs three nights won (%d so far)" % wins()
	return "unknown"


static func ending_available(id: String) -> bool:
	return ending_locked_reason(id) == ""


## The secret ending only shows on the list once everyone is home.
static func ending_visible(id: String) -> bool:
	return id != "walk" or all_echoes_home()


# --- whispers ---------------------------------------------------------------------
## The line for `key` the first time it is asked for; "" ever after.
static func whisper(key: String) -> String:
	if not WHISPERS.has(key) or SaveManager.flag("whisper_" + key):
		return ""
	SaveManager.set_flag("whisper_" + key)
	return WHISPERS[key]


# --- the people ---------------------------------------------------------------------
static func orla() -> String:
	if seen("walk"):
		return "The sea came in this morning and it was only the sea. I keep waiting for it to go out. It does not. I do not know what to do with my evenings."
	if seen("break"):
		return "The lower village is under. Gently, mind. Everyone got up the hill. Bram carried the anvil. I have never seen that man laugh before."
	if seen("keep"):
		return "Maren says you are standing at the bottom of it. You are also standing in front of me. Do not explain it. I would rather not know."
	if ebb_broken():
		return "The sea came back in last night. All the way in, gentle as anything. Maren is standing on my rock, Tam. Go and talk to her."
	if int(SaveManager.data.get("tide_unlocked", 0)) > 0 and int(SaveManager.data.get("tide_tier", 0)) == 0:
		return "You beat it once. The sea noticed. There is a gauge in the Ledger now; turn it if you want the tide to come in harder. I would not. But I am old."
	if wins() > 0:
		return "The bell is quiet. I heard it stop from here. Whatever is under the streets heard it too."
	if echo("cartographer"):
		return "The one with the maps does not eat, does not sleep, does not blink. Neither did Maren, near the end."
	if echo("wren"):
		return "Wren was praying in the chapel the night it went under. She is still praying. Maybe it works."
	if echo("bram"):
		return "Bram. Bram is standing on my rock. He drowned before you were born, Tam. Ask him what he remembers."
	if int(SaveManager.data.best_depth) >= 9:
		return "You broke the Wreck. Past the flats the water hides streets, Tam. Saltmere's streets."
	match runs():
		0: return "Maren walked into the ruins with that lantern and did not come back. Keep the tide, Tam. Whatever that means."
		1, 2: return "You came back. The lantern brought you back. They say it always does."
		3, 4, 5: return "Every keeper before Maren went down there too. Nobody in the village talks about that."
		_: return "The sea goes out further each night. I don't think it is leaving. I think it is showing us something."


static func fen() -> String:
	# The shell chain comes first: a quest waiting to be handed in, or the one in hand.
	if Quests.fen_ready():
		return Quests.fen_current().done
	if seen("walk"):
		return "The lantern is not warm any more. I checked. Is that good? You look like it is good."
	if seen("break"):
		return "Ma says we have to move up the hill. I want to see the sea come in. Can I watch from the tower?"
	if seen("keep"):
		return "Maren says you are down there and up here at the same time. I think she is making it up. Are you making it up?"
	if ebb_broken():
		return "Maren is back! She does not look at the sea any more. She looks at you."
	if echo("wren"):
		return "The lady from the chapel taught me a prayer. It is very long. I forgot the middle."
	if echo("bram"):
		return "The big man from the water gave me a nail. He said it is three hundred years old. It is just a nail."
	if wins() > 0:
		return "Everyone says the bell stopped. I never heard it start."
	if runs() >= 3:
		return "Do you see the city when you go down? Is it all there? Are the houses still standing up?"
	if runs() >= 1 and not Quests.fen_done():
		return Quests.fen_current().ask
	return "Are you the keeper now? Maren let me hold the lantern once. It was warm. Is it still warm?"


# --- the village (M7): lines live in data/dialog/npcs.json ----------------------------
static func nessa() -> String:
	return Dialog.line("nessa")


static func idris() -> String:
	return Dialog.line("idris")


static func aldous() -> String:
	return Dialog.line("aldous")


static func pell() -> String:
	return Dialog.line("pell")


static func choir() -> String:
	return Dialog.line("choir")


static func bram() -> String:
	if not endings_seen().is_empty():
		return "You chose. Whatever you chose, I am still here and the fire is still lit. Come and pick."
	if ebb_broken():
		return "Maren is up. I did not think the lantern could carry two. Go and hear what she wants of you; the forge will keep."
	if wins() > 0:
		return "The bell is down. Wren's bell. She will tell you it was her doing and she will be right, and it was still the sea that answered."
	var all_forged: bool = SaveManager.data.get("weapons", []).size() >= Weapon.ALL.size()
	if all_forged:
		return "That is everything I know how to make. The rest is in how you hold it."
	var aspect := Weapon.aspect_of(str(SaveManager.data.get("weapon", "gaff")))
	if aspect != "" and ASPECT_LINES.has(aspect):
		return str(ASPECT_LINES[aspect])
	if int(SaveManager.data.get("shards", 0)) >= Weapon.ASPECT_COST and SaveManager.data.get("aspects_owned", []).is_empty():
		return "Those shards. That is what the sea leaves of a person. Give me enough and a blade can remember them."
	if runs() > 6:
		return "You keep coming back with the same weapon. Or a different one. Either way you come back. Good."
	return "I made every blade in Saltmere. The water took the rest. Take what suits your hands."


static func wren() -> String:
	if not endings_seen().is_empty():
		return "I do not know what to pray for now. I have started asking the sea what it wants. It has not said."
	if ebb_broken():
		return "We asked to be kept and we were kept. Maren went down to keep the keeping going. And you carried her back up. What shall we ask for, keeper?"
	if wins() > 0:
		return "The bell stopped. I heard it from here. That was my bell, keeper; I rang it the night we asked the sea to keep us. I am sorry. What shall we ask for?"
	return "A prayer is only asking the same thing every night until the sea gets tired of hearing it. What shall we ask for?"


static func cartographer() -> String:
	if seen("walk"):
		return "I have drawn an empty room. It took all night. There is nothing to put in it and I keep looking for something."
	if ebb_broken():
		return "The map is wrong now. There is nobody at the bottom. I have never drawn an empty room before. Two turnings down is still true."
	if wins() > 0:
		return "Every keeper's name is on my map. Under the hall. In order. Maren's is the last, and yours is not on it yet."
	return "The streets do not move. I can tell you what is two turnings down, every night. Not more. The water changes the rest."


static func maren() -> String:
	if not endings_seen().is_empty():
		return "It happened. It also has not, yet; the tide went out again tonight. Nights are like that here. Choose again, if you like. I will be here either way."
	if all_echoes_home() and wins() >= 3:
		return "Everyone is home and you have walked the hall three times. There is a third way, Tam. Nobody goes down. Nobody keeps anything. I do not know if the sea will allow it. Ask me."
	if all_echoes_home():
		return "Everyone is home. All seven of us. Walk the hall a few more nights and I will tell you the third way. For now there are two."
	if echoes_home() >= BREAK_NEEDS:
		return "Five of us on the rock. Enough hands to break the thing, if you want it broken. There are still people down there, though. I would bring them up first."
	return "Tam. You went all the way down and came back with me. Nobody has done that. The lantern is yours now, properly. It can be hung at the bottom, or broken. I will not choose for you."
