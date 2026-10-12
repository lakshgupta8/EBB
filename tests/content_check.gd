extends Node
## What the game asks for against what is on disk: sounds, music, sprites, dialog, rooms.
## Run it with tools\content.ps1 (or godot --headless --path . tools/content_check.tscn).
## Exits 1 when something is missing, so it can sit in a check before a build.

const SRC_DIRS := ["res://src/", "res://tests/"]
## This file is full of the names of things as regex literals; it would only find itself.
const SKIP_FILE := "content_check.gd"
## The people on the rock, as the hub places them (hub.gd is a scene script, not a class).
const PEOPLE := ["orla", "fen", "bram", "wren", "cartographer", "maren", "nessa", "idris", "aldous", "pell", "choir", "mason"]
const AUDIO_DIR := "res://assets/audio/"
const SPRITE_DIR := "res://assets/sprites/"

var missing: Array = []   # [what, where]
var notes: Array = []     # counted, not missing


func _ready() -> void:
	# Never the player's own profile: anything here that reads through SaveManager (and a
	# one-shot line like Story.whisper writes as it reads) works on a scratch file.
	SaveManager.use_path("user://content_check.json")
	var sounds := {}
	var music := {}
	var whispers := {}
	_scan_source(sounds, music, whispers)
	_check_sounds(sounds)
	_check_music(music)
	_check_whispers(whispers)
	_check_sprites()
	_check_dialog()
	_check_rooms()
	_check_tables()
	print("")
	for n in notes:
		print("  %s" % n)
	print("")
	if missing.is_empty():
		print("content: nothing missing")
		get_tree().quit(0)
		return
	for m in missing:
		printerr("MISSING %-28s  asked for by %s" % [m[0], m[1]])
	print("content: %d missing" % missing.size())
	get_tree().quit(1)


## Every literal Audio.play("x") / Audio.music("x") / Audio.ambient("x") / Story.whisper("x")
## in the source, with the file that asked for it.
func _scan_source(sounds: Dictionary, music: Dictionary, whispers: Dictionary) -> void:
	var play := RegEx.create_from_string('Audio\\.play\\("([a-z0-9_]+)"')
	var mus := RegEx.create_from_string('Audio\\.(?:music|ambient)\\("([a-z0-9_]+)"')
	var whis := RegEx.create_from_string('_whisper\\("([a-z0-9_]+)"')
	for dir in SRC_DIRS:
		for path in _files(dir, ".gd"):
			if path.ends_with(SKIP_FILE):
				continue
			var text := FileAccess.get_file_as_string(path)
			var short: String = path.trim_prefix("res://")
			for m in play.search_all(text):
				sounds[m.get_string(1)] = short
			for m in mus.search_all(text):
				music[m.get_string(1)] = short
			for m in whis.search_all(text):
				whispers[m.get_string(1)] = short


func _files(dir: String, suffix: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(suffix):
			out.append(dir + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir + d + "/", suffix))
	return out


func _has_clip(name: String) -> bool:
	if ResourceLoader.exists(AUDIO_DIR + name + ".wav"):
		return true
	return ResourceLoader.exists(AUDIO_DIR + name + "_0.wav")  # a clip with variants


func _check_sounds(sounds: Dictionary) -> void:
	var n := 0
	for name in sounds:
		if _has_clip(name):
			n += 1
		else:
			missing.append(["sound %s.wav" % name, sounds[name]])
	notes.append("%d sound effects, all present" % n if missing.is_empty() else "%d of %d sound effects present" % [n, sounds.size()])


func _check_music(music: Dictionary) -> void:
	# The biomes name their own loops in a table, not as literals in a call.
	for b in Run.BIOMES:
		music[str(b.music)] = "Run.BIOMES"
		music[str(b.boss_music)] = "Run.BIOMES"
	var n := 0
	for name in music:
		if _has_clip(name):
			n += 1
		else:
			missing.append(["music %s.wav" % name, music[name]])
	# The other way round: a loop on disk nothing ever plays.
	for f in DirAccess.get_files_at(AUDIO_DIR):
		if f.begins_with("music_") and f.ends_with(".wav") and not music.has(f.trim_suffix(".wav")):
			notes.append("%s is on disk but nothing plays it" % f)
	notes.append("%d music and ambient loops" % n)


func _check_whispers(whispers: Dictionary) -> void:
	for key in whispers:
		if key.begins_with("tide_") or key in Run.ECHOES:
			continue  # tide_1..8 and the echo lines are built from tables
		# Story.whisper() is one-shot (it goes quiet once heard), so ask the table itself.
		if not Story.WHISPERS.has(key):
			missing.append(["whisper \"%s\"" % key, whispers[key]])
	notes.append("%d lantern whispers" % Story.WHISPERS.size())


func _check_sprites() -> void:
	# Every enemy in the codex has a scene, and every scene is in the codex.
	var scenes := {}
	for f in _files("res://src/enemies/", ".tscn"):
		scenes[f.get_file().get_basename()] = f
	for e in Codex.ENEMIES:
		if not scenes.has(e.id):
			missing.append(["enemy scene %s.tscn" % e.id, "Codex.ENEMIES"])
		if not Codex.ENEMY_MORE.has(e.id):
			missing.append(["second paragraph for %s" % e.id, "Codex.ENEMY_MORE"])
	for id in scenes:
		var found := false
		for e in Codex.ENEMIES:
			if e.id == id:
				found = true
		if not found:
			notes.append("%s.tscn is not in the codex" % id)
	for w in Weapon.ALL:
		if not ResourceLoader.exists(str(Weapon.ALL[w].scene)):
			missing.append(["weapon scene %s" % w, "Weapon.ALL"])
	for c in KeeperLog.COATS:
		if not ResourceLoader.exists(str(KeeperLog.COATS[c].sheet)):
			missing.append(["coat sheet %s" % c, "KeeperLog.COATS"])
	notes.append("%d enemies, %d weapons, %d coats" % [Codex.ENEMIES.size(), Weapon.ALL.size(), KeeperLog.COATS.size()])


func _check_dialog() -> void:
	var npcs := Dialog.load_file("npcs")
	var chains := Dialog.load_file("affinity")
	for id in PEOPLE:
		# The six older people still keep their lines in story.gd; the rest are in the JSON.
		if not npcs.has(id) and not id in ["orla", "fen", "bram", "wren", "cartographer", "maren"]:
			missing.append(["dialog for %s" % id, "data/dialog/npcs.json"])
		if not chains.has(id) or chains[id].is_empty():
			missing.append(["affinity chains for %s" % id, "data/dialog/affinity.json"])
	for id in Story.ECHO_IDS:
		if not Run.ECHOES.has(id):
			missing.append(["cage line for %s" % id, "Run.ECHOES"])
	notes.append("%d people, %d affinity chains" % [PEOPLE.size(), _count_chains(chains)])


func _count_chains(chains: Dictionary) -> int:
	var n := 0
	for id in chains:
		n += chains[id].size()
	return n


func _check_rooms() -> void:
	var types := [["combat", RoomGraph.COMBAT], ["fountain", RoomGraph.FOUNTAIN], ["shop", RoomGraph.SHOP],
		["altar", RoomGraph.ALTAR], ["treasure", RoomGraph.TREASURE], ["boss", RoomGraph.BOSS],
		["echo", RoomGraph.ECHO], ["challenge", RoomGraph.CHALLENGE], ["vault", RoomGraph.VAULT], ["dive", RoomGraph.DIVE]]
	for b in Run.BIOMES:
		var files := DirAccess.get_files_at(str(b.dir))
		var counts := {}
		for f in files:
			if not f.ends_with(".txt"):
				continue
			var kind := "combat"
			for t in types:
				if f.begins_with(str(t[0])):
					kind = str(t[0])
			counts[kind] = int(counts.get(kind, 0)) + 1
		for t in types:
			if int(counts.get(str(t[0]), 0)) == 0:
				missing.append(["%s room in %s" % [t[0], b.id], "Run.BIOMES"])
		notes.append("%s: %d rooms (%d fighting)" % [b.id, files.size(), int(counts.get("combat", 0))])


func _check_tables() -> void:
	notes.append("%d tidemarks, %d contracts, %d Log milestones, %d modes" % [
		Tidemarks.ALL.size(), Contracts.ALL.size(), KeeperLog.ALL.size(), Modes.ALL.size()])
	for m in Tidemarks.ALL:
		if str(m.get("desc", "")) == "":
			missing.append(["description for %s" % m.id, "Tidemarks.ALL"])
	for c in Contracts.ALL:
		if str(c.get("desc", "")) == "":
			missing.append(["description for contract %s" % c.id, "Contracts.ALL"])
	for f in Fish.ALL:
		if not Fish.ORDER.has(f):
			notes.append("fish %s is not on Nessa's list" % f)
