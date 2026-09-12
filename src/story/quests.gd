class_name Quests
extends RefCounted
## Fen's shell chain: six small asks, one at a time, each checked against the profile when
## you come back to the rock. Each hands over a shell (a gift for someone) and some pearls.
## `ask` is what Fen says while it is open, `done` when it can be handed in.

const FEN := [
	{"id": "fen_1", "name": "Past the second room", "cond": "best_depth>=2", "shells": 1, "pearls": 5,
		"ask": "Go past the second room of the flats and tell me what it looks like. Nobody will tell me. Is it houses yet?",
		"done": "You went past! Is it houses? It is not houses. Boats, then. Upside-down boats. That is nearly as good. Here, I found this on the shore, it is for you."},
	{"id": "fen_2", "name": "Break the Wreck", "cond": "flag:boss_wreck_broken", "shells": 1, "pearls": 8,
		"ask": "Orla says there is a boat down there that fights. Break it. Then it is only a boat, and boats are not scary.",
		"done": "You broke the boat! I heard it from the tower. It went crunch. Was it Maren's? Do not tell me. Here, a shell. It is a good one, it is not chipped."},
	{"id": "fen_3", "name": "The wet way", "cond": "stat:wet_rooms>=1", "shells": 1, "pearls": 10,
		"ask": "Ma says the drowned come up where the water is deep. Go the wet way, on purpose, and come back, so she is wrong.",
		"done": "You went the wet way and you are not drowned. I am going to tell her. She will say it is different for keepers. It is not different. Here."},
	{"id": "fen_4", "name": "Salt-glass", "cond": "stat:glass_found>=1", "shells": 1, "pearls": 12,
		"ask": "Pell says there is glass at the bottom that the sea makes. Bring some up so I can see it. You can keep it after. I only want to look.",
		"done": "It is glass. It is really glass. It is a bit blue. Did the sea make it? Pell says the sea made it. I believe Pell. Here is a shell for the glass."},
	{"id": "fen_5", "name": "The middle of the prayer", "cond": "flag:echo_wren", "shells": 1, "pearls": 15,
		"ask": "The lady from the chapel taught me a prayer and I forgot the middle. Bring her home and she can teach me again.",
		"done": "She taught me the middle. It is about the tide being patient. I do not think it is, but I said it anyway. This is the best shell I have. Take it."},
	{"id": "fen_6", "name": "Win a night", "cond": "wins>=1", "shells": 1, "pearls": 25,
		"ask": "Go all the way down and come all the way up. Maren did it once. You can do it twice, and then you are better than Maren.",
		"done": "You did it. All the way down and up. You are better than Maren. Do not tell her I said that. Here, the last one. I have been saving it."},
]


static func fen_index() -> int:
	return int(SaveManager.data.get("fen_quest", 0))


static func fen_done() -> bool:
	return fen_index() >= FEN.size()


static func fen_current() -> Dictionary:
	return FEN[mini(fen_index(), FEN.size() - 1)]


## The open quest's condition holds: Fen can hand over the shell.
static func fen_ready() -> bool:
	return not fen_done() and Dialog.check(str(fen_current().cond))


## Hand the quest in: shells and pearls to the profile, the chain moves on. Returns the
## quest handed in, or {} when nothing was ready.
static func fen_hand_in() -> Dictionary:
	if not fen_ready():
		return {}
	var q := fen_current()
	SaveManager.data["shells"] = int(SaveManager.data.get("shells", 0)) + int(q.shells)
	SaveManager.data["pearls"] = int(SaveManager.data.pearls) + int(q.pearls)
	SaveManager.count("shells_found", int(q.shells))
	SaveManager.data["fen_quest"] = fen_index() + 1
	SaveManager.save_profile()
	return q
