class_name Modes
extends RefCounted
## The ways down besides the ordinary night. "The sea keeps time," Idris says: a daily
## night on a seed every keeper shares, a night on a seed you choose, and three trials.
## Each mode names what opens it (a dialog condition) and what it changes; the run
## reads `state.mode` and does the rest.

const ALL := [
	{"id": "daily", "name": "Daily Night", "desc": "one attempt a day, the same night for every keeper",
		"cond": "", "locked": "", "counts": true},
	{"id": "seeded", "name": "Seeded Night", "desc": "a night on a seed you choose; the same seed is the same night",
		"cond": "", "locked": "", "counts": false},
	{"id": "trial", "name": "Keeper's Trial", "desc": "the four bosses in a row on one rising tide",
		"cond": "flag:ebb_broken", "locked": "break the Ebb first", "counts": false},
	{"id": "neap", "name": "Neap Night", "desc": "no altars, no tidemarks; pearls pay double",
		"cond": "wins>=1", "locked": "win a night first", "counts": false},
	{"id": "riptide", "name": "Riptide", "desc": "the tide rises three times as fast; counts for the spring-tide ladder",
		"cond": "wins>=1", "locked": "win a night first", "counts": true},
]
const NAMES := {"night": "the night", "daily": "daily night", "seeded": "seeded night", "trial": "keeper's trial",
	"neap": "neap night", "riptide": "riptide"}
## The bot's pace when nothing has measured it (seconds a room); tools/balance.ps1 writes
## the measured one to data/par.json.
const PAR_SECONDS_PER_ROOM := 12.0
const PAR_PATH := "res://data/par.json"


static func get_mode(id: String) -> Dictionary:
	for m in ALL:
		if m.id == id:
			return m
	return {}


static func name_of(id: String) -> String:
	return str(NAMES.get(id, id))


## One word for a table column ("night", "daily", "trial"...).
static func short_name(id: String) -> String:
	if id == "seeded":
		return "seed"
	return id


## "" when the mode can be played, else why not.
static func locked_reason(id: String) -> String:
	var m := get_mode(id)
	if m.is_empty():
		return "unknown"
	if str(m.cond) != "" and not Dialog.check(str(m.cond)):
		return str(m.locked)
	return ""


static func available(id: String) -> bool:
	return locked_reason(id) == ""


## Today, as the daily is keyed: "YYYY-MM-DD" in local time.
static func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## The seed every keeper plays on a given day: a small hash of the date, never zero.
static func daily_seed(date: String = "") -> int:
	if date == "":
		date = today()
	var h := 2166136261
	for c in date.to_utf8_buffer():
		h = int((h ^ int(c)) * 16777619) & 0x7fffffff
	return maxi(1, h % 2147483647)


## Parse what a player typed as a seed: a number as it is, anything else hashed.
static func parse_seed(text: String) -> int:
	text = text.strip_edges()
	if text == "":
		return 0
	if text.is_valid_int():
		return maxi(1, absi(int(text)) % 2147483647)
	return daily_seed(text)


## The daily already played on `date` in this profile: its result, or {}.
static func daily_played(date: String = "") -> Dictionary:
	if date == "":
		date = today()
	for s in SaveManager.data.get("daily_scores", []):
		if str(s.get("date", "")) == date:
			return s
	return {}


## Par: how long the bot takes for this many rooms, from the balance harness when it has run.
static func par_seconds(rooms: int) -> float:
	var per := PAR_SECONDS_PER_ROOM
	if FileAccess.file_exists(PAR_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PAR_PATH))
		if parsed is Dictionary and float(parsed.get("seconds_per_room", 0.0)) > 0.0:
			per = float(parsed.seconds_per_room)
	return per * maxf(1.0, float(rooms))


static func par_info() -> Dictionary:
	if FileAccess.file_exists(PAR_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PAR_PATH))
		if parsed is Dictionary:
			return parsed
	return {}


## A run's cause of ending, in a word.
static func cause_of(result: Dictionary) -> String:
	if bool(result.get("victory", false)):
		return "won"
	if bool(result.get("taken", false)):
		return "tide"
	if bool(result.get("rested", false)):
		return "rested"
	return "deep"


static func time_text(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
