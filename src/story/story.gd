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
	"death": "The water closed over you and the lantern pulled, hard, upward. You are at the foot of the tower and the tide is out again. That is what the lantern is for.",
	"taken": "The tide took you and the lantern brought you back, and half your salt came with you. The sea is patient, not cruel.",
	"cage": "The cage is not iron. It is a promise, kept too well. Open it and the promise fails a little.",
	"streets": "Nobody drowned in Saltmere. Look at their faces. They were kept, exactly as they were, and they are still waiting.",
	"bell": "That bell called the sea in. Someone rang it on purpose, and meant it kindly.",
	"hall": "Every keeper before you is standing in the hall. Not dead. Held. The lantern hums like it knows them by name.",
	"ebb": "It is not cruel. It was asked to keep them safe forever and it is still doing it. Maren is in there with it, mid-bargain.",
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


static func all_echoes_home() -> bool:
	for id in ["bram", "wren", "cartographer", "maren"]:
		if not echo(id):
			return false
	return true


static func endings_seen() -> Array:
	return SaveManager.data.get("endings", [])


static func seen(ending: String) -> bool:
	return ending in endings_seen()


static func record_ending(id: String) -> void:
	var list: Array = endings_seen()
	if not id in list:
		list.append(id)
	SaveManager.data["endings"] = list
	SaveManager.save_profile()


## "" when the ending can be chosen, else what is still missing.
static func ending_locked_reason(id: String) -> String:
	match id:
		"keep":
			return ""
		"break":
			return "" if (echo("bram") and echo("wren") and echo("cartographer")) else "needs Bram, Wren and the Cartographer on the rock"
		"walk":
			if not all_echoes_home():
				return "needs every echo home"
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
	return "Are you the keeper now? Maren let me hold the lantern once. It was warm. Is it still warm?"


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
		return "Everyone is home. Bram, Wren, the one with the maps, me. Walk the hall a few more nights and I will tell you the third way. For now there are two."
	return "Tam. You went all the way down and came back with me. Nobody has done that. The lantern is yours now, properly. It can be hung at the bottom, or broken. I will not choose for you."
