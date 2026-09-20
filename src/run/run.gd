class_name Run
extends Node2D
## One descent. Builds rooms from the graph, spawns content, drives the tide, moves
## from biome to biome past each boss, ends the run on death / taken / final boss, and
## shows results.

const SHELLBACK := preload("res://src/enemies/shellback.tscn")
const GULL := preload("res://src/enemies/gull.tscn")
const CRAB := preload("res://src/enemies/wrack_crab.tscn")
const WRECK := preload("res://src/enemies/wreck.tscn")
const CITIZEN := preload("res://src/enemies/still_citizen.tscn")
const LAMPLIGHTER := preload("res://src/enemies/lamplighter.tscn")
const RINGER := preload("res://src/enemies/bell_ringer.tscn")
const SWIMMER := preload("res://src/enemies/swimmer.tscn")
const BELL := preload("res://src/enemies/bell.tscn")
const SHADE := preload("res://src/enemies/keeper_shade.tscn")
const ANCHOR := preload("res://src/enemies/anchor.tscn")
const MAW := preload("res://src/enemies/deep_maw.tscn")
const EBB := preload("res://src/enemies/ebb.tscn")
const MOORING := preload("res://src/enemies/mooring.tscn")
const BARNACLE := preload("res://src/enemies/barnacle.tscn")
const DECKHAND := preload("res://src/enemies/deckhand.tscn")
const CHAINMOTHER := preload("res://src/enemies/chainmother.tscn")
const TIDEWISP := preload("res://src/enemies/tidewisp.tscn")
const NETTED := preload("res://src/enemies/netted.tscn")
const CHOIR := preload("res://src/enemies/choir.tscn")
const TALLOW := preload("res://src/enemies/tallow.tscn")

## The night, top to bottom. Everything that differs between biomes lives here, so nothing
## else counts indices: id, rooms directory, length (rooms before the boss), look, boss,
## echoes to find, music, codex place, the lantern's whispers, the boss's sound, the night's tint.
const BIOMES := [
	{"id": "flats", "name": "THE FLATS", "dir": "res://data/rooms/biome1/", "length": 10, "theme": Tiles.Look.FLATS,
		"boss": WRECK, "boss_name": "THE WRECK", "stir": "THE WRECK STIRS", "won": "THE WRECK IS BROKEN",
		"echoes": ["bram"], "music": "music_flats", "place": "flats", "whisper": "first_night", "boss_whisper": "wreck",
		"boss_sfx": "roar", "tint": Color(0.6, 0.68, 0.86), "wet": GULL,
		"elite": NETTED, "elite_name": "The Netted", "boss_music": "music_boss",
		"intro": "Ten rooms down, then the Wreck. The water follows you in.",
		"boss_sub": "Slams, charges, calls the flats. Break it and the way down opens."},
	{"id": "harbour", "name": "THE SUNKEN HARBOUR", "dir": "res://data/rooms/harbour/", "length": 9, "theme": Tiles.Look.HARBOUR,
		"boss": CHAINMOTHER, "boss_name": "THE CHAINMOTHER", "stir": "THE CHAINMOTHER STIRS", "won": "THE CHAINMOTHER LETS GO",
		"echoes": ["pell"], "music": "music_harbour", "place": "harbour", "whisper": "harbour", "boss_whisper": "chainmother",
		"boss_sfx": "creak", "tint": Color(0.58, 0.64, 0.82), "wet": BARNACLE,
		"elite": DECKHAND, "elite_name": "The Bosun", "boss_music": "music_boss",
		"intro": "Nine rooms down, then the Chainmother. Every ship that tried to leave is still tied up.",
		"boss_sub": "Sweeps, drops anchors, hauls you in. Break it and the way down opens."},
	{"id": "streets", "name": "THE DROWNED STREETS", "dir": "res://data/rooms/biome2/", "length": 11, "theme": Tiles.Look.STREETS,
		"boss": BELL, "boss_name": "THE BELL OF SALTMERE", "stir": "THE BELL CRACKS", "won": "THE BELL IS SILENCED",
		"echoes": ["wren", "cartographer"], "music": "music_streets", "place": "streets", "whisper": "streets", "boss_whisper": "bell",
		"boss_sfx": "bell", "tint": Color(0.56, 0.6, 0.8), "wet": SWIMMER,
		"elite": CHOIR, "elite_name": "The Choir", "boss_music": "music_deep",
		"intro": "Eleven rooms down, then the Bell. Something is still ringing.",
		"boss_sub": "It called the sea in. Silence it and the way down opens."},
	{"id": "hall", "name": "THE DEEP HALL", "dir": "res://data/rooms/biome3/", "length": 9, "theme": Tiles.Look.DEEP,
		"boss": EBB, "boss_name": "THE EBB", "stir": "THE EBB RISES", "won": "THE EBB LETS GO",
		"echoes": ["aldous"], "music": "music_hall", "place": "hall", "whisper": "hall", "boss_whisper": "ebb",
		"boss_sfx": "ebb", "tint": Color(0.56, 0.62, 0.84), "wet": ANCHOR,
		"elite": SHADE, "elite_name": "Echo of Maren", "boss_music": "music_deep",
		"intro": "Nine rooms down, then the Ebb. Every keeper before you is standing in it.",
		"boss_sub": "Maren is in there with it. Break it, and the night is yours."},
]
## The people you can bring back, and what they say when the cage opens.
const ECHOES := {
	"bram": {"name": "Bram the Drowned", "line": "A smith. Still a smith. Get me to a fire, keeper, and I will make you something that bites."},
	"wren": {"name": "Sister Wren", "line": "The tide is not cruel. It is only patient. Find me by the tower; I remember prayers that still work."},
	"cartographer": {"name": "The Cartographer", "line": "I mapped every street before the water came. Streets do not move. The water does."},
	"maren": {"name": "Maren", "line": "Tam. It let go. Take me up to the light."},
	"pell": {"name": "Pell the Diver", "line": "A keeper. Under the harbour. You have the lungs for it, then. Bring me up; there is glass down here worth the breath."},
	"aldous": {"name": "Keeper Aldous", "line": "Another keeper. I thought I was the last to come down. Take me up, and I will tell you what I wrote before I did."},
	"choir": {"name": "The Choir", "line": "It ended. You let it end. Sing for the rock, then. We will find the way up on our own."},
}
## The dock: Idris ties the boat up at the harbour for a fee, unless he likes you.
const LAUNCH_COST := 15
const SLACK_WATER := 0.25  # tide level after a boss falls
const WET_BONUS := 0.8       # the wet way starts this much deeper
const DIVE_BONUS := 1.3      # a dive is deep water from the door
const CHALLENGE_TIME := 45.0
const CHALLENGE_WAVES := 4
const CHALLENGE_BONUS := 1.5
## The spring tide: eight tiers of a harder night, chosen at Orla's Ledger once the Ebb
## has fallen. Each tier keeps the ones below it. Pearls pay +15% per tier.
const TIERS := [
	{"name": "Faster tide", "desc": "the water rises half again as fast"},
	{"name": "Crusted", "desc": "everything has a quarter more health"},
	{"name": "Second wind", "desc": "bosses are tougher and rally once at a quarter"},
	{"name": "Dry wells", "desc": "fountains heal half"},
	{"name": "Salt tax", "desc": "the merchant charges half again"},
	{"name": "Blind altars", "desc": "altars offer two marks, not three"},
	{"name": "Drowned elites", "desc": "every fight past the fourth room brings an elite"},
	{"name": "The Ebb remembers", "desc": "the last boss is far stronger; the tide answers it"},
]

var state := RunState.new()
var graph: RoomGraph
var room: Room
var room_type: int = RoomGraph.COMBAT
var room_cleared: bool = false
var boss: Enemy
var cage: Prop
var cage_echo: String = ""

var _rng := RandomNumberGenerator.new()
var _templates: Dictionary = {}  # type -> Array[RoomTemplate]
var _room_seed: int = 0          # decor seed of the current room (kept when the night rests)
var _echo_depths: Array = []     # where this biome's cages sit (kept so a rested graph matches)
var resumed: bool = false        # this run was picked up from the shore
var _wet_room: bool = false      # the flooded way: drowned enemies, more salt, a pearl
var _challenge_t: float = -1.0   # seconds into the challenge, or -1 outside one
var _challenge_wave: int = 0
var challenge_label: Label
## Dev aids: `--first=challenge|vault|dive|elite|combat` and `--wet` shape the first room.
var _dev_first: int = -1
var _dev_wet: bool = false
var _dev_tide: float = -1.0      # `--tide=1.5`: start the first room at that water level
var _dev_named: bool = false     # --named: elites are the biome's named one wherever they spawn
var _mend_salt: int = 0          # Salt Mend: salt counted toward the next point of health
var _drown_t: float = 0.0        # Drowning: tick timer
var _water_shield_t: float = 0.0  # Drowned Skin: seconds spent in water toward a shield
var _second_wind_used: bool = false
var _deep_tick: float = 0.0
var _transitioning: bool = false
var _echo_queue: Array = []  # echo ids still to be found in this biome, in depth order
var _skip: int = 0           # the wet way is a shortcut: its door goes this many rooms further
## M8: the night's inputs (written to user://replays/ at the end), a replay being played
## back (`--replay=<file>`), and the faint ghost of the last night on this seed.
var input_log := InputLog.new()
var _replay: InputLog
var _ghost_log: InputLog
var _ghost: AnimatedSprite2D
var _tick: int = 0
var _room_tick: int = 0

@onready var player: Player = $Player
@onready var room_holder: Node2D = $RoomHolder
@onready var content: Node2D = $Content
@onready var hud: Control = $HUD/Bars
@onready var fade: ColorRect = $HUD/Fade
@onready var results: CanvasLayer = $Results
@onready var room_label: Label = $HUD/RoomLabel
@onready var room_sub: Label = $HUD/RoomSub
@onready var announcer: Announcer = $Announcer
@onready var shop: Shop = $Shop
@onready var altar_ui: AltarUI = $AltarUI
@onready var codex_ui: CodexUI = $CodexUI
@onready var settings_ui: SettingsUI = $SettingsUI


func biome() -> Dictionary:
	return BIOMES[state.biome]


func _ready() -> void:
	# Dev aid: `-- --seed=N` plays a chosen night without going through the menus.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			Game.run_seed = int(a.trim_prefix("--seed="))
	state.seed = Game.run_seed if Game.run_seed != 0 else randi()
	_rng.seed = state.seed
	seed(state.seed)  # enemies roll on the global RNG: the same seed is the same night
	hud.bind(self)
	shop.setup(self)
	_tide_step = int(floor(state.tide.level))
	EventBus.pickup_collected.connect(_hint_pickup)
	EventBus.riptided.connect(func(): announcer.hint("riptide"); announcer.pulse(Announcer.SEA_PALE, 0.45, 0.6))
	EventBus.player_health_changed.connect(_watch_health)
	challenge_label = UI.label("", 14, Color(0.8, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	challenge_label.position = Vector2(220, 84)
	challenge_label.size = Vector2(200, 16)
	challenge_label.visible = false
	$HUD.add_child(challenge_label)
	altar_ui.chosen.connect(_on_tidemark_chosen)
	Ledger.apply(player, self)
	state.tier = clampi(int(SaveManager.data.get("tide_tier", 0)), 0, TIERS.size())
	if state.tier >= 1:
		state.tide.rate_mult *= 1.5
	player.hurtbox.hit.connect(_on_player_hit)
	player.hurtbox.shielded.connect(_on_player_shielded)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.enemy_spared.connect(_on_enemy_spared)
	EventBus.player_died.connect(_on_player_died)
	EventBus.pickup_collected.connect(_on_pickup)
	EventBus.flared.connect(func(): state.count("flares"); SaveManager.count("flares"))
	EventBus.riptided.connect(func(): state.count("riptides"); SaveManager.count("riptides"))
	altar_ui.rerolled.connect(_on_altar_reroll)
	state.stats["weapon"] = player.weapon.id
	EventBus.run_started.emit(state.seed)
	fade.color.a = 1.0
	Atmosphere.build(self, Vector2(640, 368))
	Audio.ambient("ambient_sea", -14.0)
	Audio.gulls_enabled = true
	# Dev / playtest aids: `-- --biome=1` starts in the streets, `--boss` at its boss,
	# `--sim-save` keeps the real profile out of it.
	if "--sim-save" in OS.get_cmdline_user_args():
		SaveManager.use_path("user://sim_save.json")
	if "--continue" in OS.get_cmdline_user_args():
		Game.load_suspended()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			Game.mode = a.trim_prefix("--mode=")
	_load_replay_arg()
	var rested := Game.take_resume()
	if not rested.is_empty():
		_resume(rested)
	else:
		state.mode = Game.mode if Modes.get_mode(Game.mode).size() > 0 else "night"
		# Assists are a trade: a slower tide now, fewer pearls at the end.
		state.tide.rate_mult *= Settings.assist_tide()
		state.assist_mult = Settings.assist_pearl_mult()
		_apply_mode()
		var start_biome := 0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--biome="):
				start_biome = clampi(int(a.trim_prefix("--biome=")), 0, BIOMES.size() - 1)
			elif a.begins_with("--first="):
				for k in RoomGraph.NAMES:
					if str(RoomGraph.NAMES[k]).to_lower() == a.trim_prefix("--first="):
						_dev_first = k
			elif a == "--wet":
				_dev_wet = true
			elif a.begins_with("--tide="):
				_dev_tide = float(a.trim_prefix("--tide="))
			elif a == "--named":
				_dev_named = true
		# Nessa's fish come down with you; Long Memory brings one mark from last night.
		state.fish = []
		for f in SaveManager.data.get("fish", []):
			state.fish.append(str(f))
		SaveManager.data["fish"] = []
		var kept := str(SaveManager.data.get("kept_mark", ""))
		if Ledger.tier("keep_mark") > 0 and kept != "" and Tidemarks.get_mark(kept).size() > 0 and state.mode != "neap":
			_on_tidemark_chosen(kept)
		# Idris's dock: the night starts at the harbour, for a fee. Not on a shared seed:
		# the daily and a seeded night start where every keeper starts.
		if start_biome == 0 and state.mode == "night" and bool(SaveManager.data.get("launch_harbour", false)) and SaveManager.flag("boss_chainmother_broken"):
			var cost := 0 if Story.perk("idris") else LAUNCH_COST
			if int(SaveManager.data.pearls) >= cost:
				SaveManager.data["pearls"] = int(SaveManager.data.pearls) - cost
				SaveManager.count("launches")
				start_biome = 1
				_whisper("launch", 4.5)
		SaveManager.save_profile()
		if start_biome > 0:
			state.tide.level = SLACK_WATER
		_start_biome(start_biome, "--boss" in OS.get_cmdline_user_args() or state.mode == "trial")
	input_log.seed_value = state.seed
	input_log.mode = state.mode
	input_log.weapon = player.weapon.id
	input_log.tier = state.tier
	_ghost_log = InputLog.latest_for_seed(state.seed) if (_replay == null and Settings.ghost()) else null
	_handle_screenshot_arg()


## `--replay=<file>` (or `--replay` for the newest) plays a night back from its input log.
## The seed, weapon and tier come from the file; the profile is left alone.
func _load_replay_arg() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--replay" or a.begins_with("--replay="):
			var path := a.trim_prefix("--replay=").trim_prefix("--replay")
			if path == "":
				path = InputLog.latest()
			_replay = InputLog.load_file(path)
			if _replay == null:
				push_warning("no replay at " + path)
				return
			state.seed = _replay.seed_value
			_rng.seed = state.seed
			seed(state.seed)
			if Weapon.ALL.has(_replay.weapon) and _replay.weapon != player.weapon.id:
				player._equip(_replay.weapon)
			SaveManager.data["tide_tier"] = _replay.tier
			print("replay: %s (%d ticks, seed %d, %s)" % [path, _replay.ticks.size(), state.seed, _replay.weapon])


## The ghost: where the last keeper on this seed stood, this many ticks into this room.
func _tick_ghost() -> void:
	if _ghost_log == null or room == null:
		return
	var at := _ghost_log.position_at(state.depth_total, _room_tick)
	_room_tick += 1
	if at == Vector2.INF:
		if _ghost:
			_ghost.visible = false
		return
	if _ghost == null:
		_ghost = AnimatedSprite2D.new()
		_ghost.sprite_frames = player.sprite.sprite_frames
		_ghost.modulate = Color(0.7, 0.85, 1.0, 0.28)
		_ghost.z_index = 1
		_ghost.play("idle")
		content.add_child(_ghost)
	_ghost.visible = true
	if absf(at.x - _ghost.global_position.x) > 0.5:
		_ghost.flip_h = at.x < _ghost.global_position.x
	_ghost.global_position = at


## The run's clock ticks with the physics step, so a night is the same night at any frame
## rate and a replay lands on the same ticks.
func _physics_process(delta: float) -> void:
	if state.ended or room == null:
		return
	if _replay and not get_tree().paused and not _transitioning:
		_replay.play_tick(player)
	state.time += delta
	state.tide.advance(delta)
	room.set_tide(state.tide.level)
	EventBus.tide_changed.emit(state.tide.level)
	_watch_tide()
	if player.glow_full():
		announcer.hint("flare")
	_apply_water(delta)
	_tick_challenge(delta)
	_tick_marks(delta)
	_tick_actives(delta)
	if Input.is_action_just_pressed("consume") and not player.dead and not get_tree().paused:
		eat_fish()
	if not get_tree().paused:
		_tick += 1
		if _replay == null:
			input_log.record(player, state.depth_total)
		_tick_ghost()


func _apply_water(delta: float) -> void:
	if player.dead:
		return
	if player.mods.dry_feet:
		player.in_water = false
		_deep_tick = 0.0
		return
	# The room's own water (a wet way, a dive, the challenge) counts, not just the run's tide.
	player.in_water = room.is_flooded_at(player.global_position)
	if room.is_deep_at(player.global_position):
		_deep_tick += delta
		if _deep_tick >= TideSystem.DEEP_TICK * float(player.mods.deep_tick_mult):
			_deep_tick = 0.0
			var info := DamageInfo.make(TideSystem.DEEP_DAMAGE, null, Vector2.ZERO, 0.0)
			info.tags = PackedStringArray(["tide"])
			info.hitstop = 0.0
			player.take_tide_damage(info)
	else:
		_deep_tick = 0.0


# --- biomes ------------------------------------------------------------------------
func _start_biome(index: int, at_boss: bool = false) -> void:
	state.biome = index
	state.depth = 0
	var b := biome()
	_echo_queue = []
	for id in b.echoes:
		if not SaveManager.flag("echo_" + id):
			_echo_queue.append(id)
	var echo_depths: Array = RoomGraph.ECHO_DEPTHS[mini(_echo_queue.size(), 2) - 1] if _echo_queue.size() > 0 else []
	_setup_biome(index, echo_depths)
	if at_boss:
		state.depth = b.length
		_enter_room(RoomGraph.BOSS)
		return
	_enter_room(_dev_first if _dev_first >= 0 else RoomGraph.COMBAT, _dev_wet)
	_dev_first = -1
	_dev_wet = false
	if _dev_tide >= 0.0:
		state.tide.level = minf(TideSystem.MAX_LEVEL, _dev_tide)
		room.set_tide(state.tide.level)
		_dev_tide = -1.0
	if state.slack_start > 0.0:
		state.tide.pause(state.slack_start)
	announcer.card(str(b.name), str(b.intro), 3.0)
	if index == 0:
		announcer.hint("move")
		announcer.hint("goal")
	_whisper(b.whisper, 3.6)
	if state.tier > 0 and index == 0:
		_whisper("tide_%d" % state.tier, 7.5)
	if b.id == "harbour":
		_whisper("harbour_ships", 9.0)
		_whisper("harbour_hands", 14.0)


## The parts of a biome that do not depend on where in it you are: graph, templates, light, music.
func _setup_biome(index: int, echo_depths: Array) -> void:
	var b := biome()
	_echo_depths = echo_depths
	graph = RoomGraph.new(state.seed + index * 7919, b.length, echo_depths, int(SaveManager.data.get("charted_room", -1)))
	_load_templates(b.dir)
	# Rooms and the boss add up to the same rise whatever the biome's length.
	state.tide.room_step = 1.44 / float(b.length + 1)
	var night := get_node_or_null("Night") as CanvasModulate
	if night:
		night.color = b.tint
	Audio.gulls_enabled = b.id in ["flats", "harbour"]
	Audio.layer("amb_" + str(b.id), -15.0)  # what this place sounds like under the sea
	Audio.music(b.music, -11.0)
	Codex.discover("place", b.place)


## Past a boss: the tide slackens, the next biome begins. On the trial it never slackens:
## the next boss stands in the same water, and it keeps rising.
func _next_biome() -> void:
	if state.mode != "trial":
		state.tide.level = SLACK_WATER
	_start_biome(state.biome + 1, state.mode == "trial")


## What the way down changes about the night (Modes.ALL says what each one is).
func _apply_mode() -> void:
	match state.mode:
		"riptide":
			state.tide.rate_mult *= 3.0
		"neap":
			state.pearl_mult *= 2.0
		"trial":
			state.tide.level = SLACK_WATER
	if state.mode != "night":
		var m := Modes.get_mode(state.mode)
		announcer.card(str(m.name).to_upper(), str(m.desc).capitalize() + ".", 3.0, Color(0.7, 0.85, 1.0))
		if state.mode in ["daily", "seeded"]:
			announcer.toast("seed %d" % state.seed, Announcer.SEA_PALE, 4.0)


## Neap: no marks are ever offered. Every altar is bare stone with a chest left on it,
## so the room is the room it always was and the night still pays.
func _neap() -> bool:
	return state.mode == "neap"


# --- rooms -----------------------------------------------------------------------
func _load_templates(dir: String) -> void:
	_templates = {RoomGraph.COMBAT: [], RoomGraph.ELITE: [], RoomGraph.FOUNTAIN: [], RoomGraph.TREASURE: [],
		RoomGraph.BOSS: [], RoomGraph.SHOP: [], RoomGraph.ALTAR: [], RoomGraph.ECHO: [],
		RoomGraph.CHALLENGE: [], RoomGraph.VAULT: [], RoomGraph.DIVE: []}
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".txt"):
			continue
		var t := RoomTemplate.load_file(dir + f)
		if f.begins_with("fountain"):
			_templates[RoomGraph.FOUNTAIN].append(t)
		elif f.begins_with("shop"):
			_templates[RoomGraph.SHOP].append(t)
		elif f.begins_with("altar"):
			_templates[RoomGraph.ALTAR].append(t)
		elif f.begins_with("treasure"):
			_templates[RoomGraph.TREASURE].append(t)
		elif f.begins_with("boss"):
			_templates[RoomGraph.BOSS].append(t)
		elif f.begins_with("echo"):
			_templates[RoomGraph.ECHO].append(t)
		elif f.begins_with("challenge"):
			_templates[RoomGraph.CHALLENGE].append(t)
		elif f.begins_with("vault"):
			_templates[RoomGraph.VAULT].append(t)
		elif f.begins_with("dive"):
			_templates[RoomGraph.DIVE].append(t)
		else:
			_templates[RoomGraph.COMBAT].append(t)
			_templates[RoomGraph.ELITE].append(t)


var _last_template: String = ""


func _pick_template(type: int) -> RoomTemplate:
	var list: Array = _templates[type]
	if list.is_empty():
		# Never a black room: a fighting room stands in, and the log says which biome is short.
		push_warning("no %s template in %s; a fighting room stands in" % [RoomGraph.NAMES[type], biome().dir])
		list = _templates[RoomGraph.COMBAT]
	var t: RoomTemplate = list[_rng.randi() % list.size()]
	if list.size() > 1 and t.name == _last_template:
		t = list[(list.find(t) + 1 + _rng.randi() % (list.size() - 1)) % list.size()]
	_last_template = t.name
	return t


func _enter_room(type: int, wet: bool = false) -> void:
	room_type = type
	room_cleared = false
	boss = null
	cage = null
	_wet_room = wet
	_challenge_t = -1.0
	if challenge_label:
		challenge_label.visible = false
	for c in content.get_children():
		c.queue_free()
	if room:
		room.queue_free()
	room = Room.new()
	room_holder.add_child(room)
	_room_tick = 0
	var template := _pick_template(type)
	_room_seed = _rng.randi()
	room.build(template, _room_seed, biome().theme)
	room.tide_bonus = _room_bonus(type, wet)
	player.global_position = room.cell_to_world(room.template.player_spawn)
	player.velocity = Vector2.ZERO
	player.rally = 0.0
	state.tide.room_entered()
	room.set_tide(state.tide.level)

	_skip = 1 if _shortcut(wet) else 0
	var next_depth := state.depth + 1 + _skip
	_place_doors(type, next_depth)

	match type:
		RoomGraph.COMBAT:
			_spawn_enemies(2 + state.depth / 2 + state.biome, state.tier >= 7 and state.depth >= 4)
		RoomGraph.ELITE:
			_spawn_enemies(1 + state.depth / 3 + state.biome, true)
			announcer.hint("elite")
		RoomGraph.FOUNTAIN:
			announcer.hint("fountain")
			for cell in room.template.marker_cells("F"):
				_add_room_prop(Prop.Kind.FOUNTAIN, cell)
			_set_cleared()
		RoomGraph.TREASURE:
			for cell in room.template.marker_cells("T"):
				_add_room_prop(Prop.Kind.CHEST, cell)
			_set_cleared()
		RoomGraph.ALTAR:
			if _neap():
				announcer.toast("bare stone: a chest where the altar was", Announcer.SALT, 3.0)
			else:
				announcer.hint("altar")
			for cell in room.template.marker_cells("A"):
				_add_room_prop(Prop.Kind.CHEST if _neap() else Prop.Kind.ALTAR, cell)
			_set_cleared()
		RoomGraph.SHOP:
			announcer.hint("shop")
			shop.restock()
			for cell in room.template.marker_cells("M"):
				_add_room_prop(Prop.Kind.MERCHANT, cell)
			_set_cleared()
		RoomGraph.CHALLENGE:
			_start_challenge()
		RoomGraph.VAULT:
			announcer.hint("vault")
			for cell in room.template.marker_cells("T"):
				_add_room_prop(Prop.Kind.VAULT, cell)
			_set_cleared()
		RoomGraph.DIVE:
			for cell in room.template.marker_cells("A"):
				_add_room_prop(Prop.Kind.CHEST if _neap() else Prop.Kind.ALTAR, cell)
			for cell in room.template.marker_cells("T"):
				_add_room_prop(Prop.Kind.CHEST, cell)
			announcer.hint("dive")
			_whisper("dive", 1.2)
			_set_cleared()
		RoomGraph.ECHO:
			_spawn_echo_room()
		RoomGraph.BOSS:
			_spawn_boss()
			Audio.music(str(biome().boss_music), -9.0)
			_boss_intro()
			EventBus.request_shake.emit(0.6)
			Audio.play(biome().boss_sfx)
			_whisper(biome().boss_whisper, 2.8)

	_show_room_label(biome().name, "room %d of %d   %s%s%s%s" % [state.depth + 1, biome().length + 1, RoomGraph.NAMES[type],
		"  (wet)" if wet else "", "   spring tide %d" % state.tier if state.tier > 0 else "",
		"   " + Modes.name_of(state.mode) if state.mode != "night" else ""])
	EventBus.room_entered.emit(room)
	var fade_tw := create_tween()
	fade_tw.tween_property(fade, "color:a", 0.0, 0.25)
	fade_tw.tween_callback(func(): _transitioning = false)


## The wet way is a shortcut: the water carries you a room further, unless that would skip
## a cage or land past the boss.
func _shortcut(wet: bool) -> bool:
	return wet and state.depth + 2 <= biome().length and not (state.depth + 1 in _echo_depths)


## How much deeper this room sits than the run's tide.
func _room_bonus(type: int, wet: bool) -> float:
	if type == RoomGraph.DIVE:
		return DIVE_BONUS
	return WET_BONUS if wet else 0.0


## Doors for the rooms offered next; the boss room's single way down; the wet mark at the fork.
func _place_doors(type: int, next_depth: int) -> void:
	if type == RoomGraph.BOSS:
		# The way down opens when the boss is dead; the last biome has no way down.
		room.place_doors([Door.DESCEND] if state.biome + 1 < BIOMES.size() else [])
	else:
		room.place_doors(graph.options_for(next_depth))
		for i in room.doors.size():
			if graph.is_wet(next_depth, i):
				# The door leads to next_depth; the shortcut is judged from there.
				room.doors[i].set_wet(next_depth + 2 <= biome().length and not (next_depth + 1 in _echo_depths))
	for d in room.doors:
		d.entered.connect(_on_door_entered)


# --- the challenge: no way out until the tide turns ---------------------------------
func _start_challenge() -> void:
	_challenge_t = 0.0
	_challenge_wave = 0
	announcer.card("HOLD UNTIL THE TIDE TURNS", "No way out. Survive three waves and the sea drains, and pays.", 2.6)
	announcer.hint("challenge")
	_whisper("challenge", 2.6)
	_spawn_wave()


func _spawn_wave() -> void:
	_challenge_wave += 1
	_spawn_enemies(maxi(2, 1 + state.depth / 3 + state.biome), _challenge_wave == CHALLENGE_WAVES)
	Audio.play("wave", 0.0, -4.0)
	FX.flash_screen(Color(0.5, 0.7, 1.0, 0.18), 0.3)


func _tick_challenge(delta: float) -> void:
	if _challenge_t < 0.0 or state.ended:
		return
	_challenge_t += delta
	room.tide_bonus = CHALLENGE_BONUS * minf(1.0, _challenge_t / CHALLENGE_TIME)
	var wave_at := float(_challenge_wave) * CHALLENGE_TIME / CHALLENGE_WAVES
	if _challenge_wave < CHALLENGE_WAVES and _challenge_t >= wave_at:
		_spawn_wave()
	challenge_label.text = "HOLD   %d" % int(ceil(CHALLENGE_TIME - _challenge_t))
	challenge_label.visible = true
	if _challenge_t >= CHALLENGE_TIME:
		_end_challenge()


## The tide turns: whatever is still standing drowns, the water drains, the chests are yours.
func _end_challenge() -> void:
	_challenge_t = -1.0
	challenge_label.visible = false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and is_instance_valid(e):
			var info := DamageInfo.make(9999, null, Vector2.ZERO, 0.0)
			info.tags = PackedStringArray(["tide"])
			e.health.take(info, true)
	var tw := create_tween()
	tw.tween_property(room, "tide_bonus", 0.0, 3.0)
	for cell in room.template.marker_cells("T"):
		_add_room_prop(Prop.Kind.CHEST, cell)
	announcer.card("THE TIDE TURNS", "The water drains. The chests are yours.", 2.0)
	Audio.play("clear", 0.0, -2.0)
	state.count("challenges")
	SaveManager.count("challenges")
	_set_cleared()


## The vault: a key (elites carry them) opens it for pearls, salt and a tidemark.
func _on_vault(p: Prop) -> void:
	if state.keys <= 0:
		FX.text(p.global_position + Vector2(0, -16), "LOCKED: NO KEY", Color(0.9, 0.8, 0.6))
		Audio.play("reload", 0.0, -6.0)
		return
	state.keys -= 1
	EventBus.keys_changed.emit(state.keys)
	p.mark_used()
	for i in 5:
		Pickup.spawn(content, p.global_position + Vector2(0, 8), Pickup.Kind.PEARL)
	for i in 25:
		Pickup.spawn(content, p.global_position + Vector2(0, 8), Pickup.Kind.SALT)
	_drop_page(p.global_position + Vector2(0, 8))
	state.count("vaults")
	SaveManager.count("vaults")
	FX.burst(p.global_position, Color(0.95, 0.85, 0.5), 20, 90.0)
	Audio.play("altar")
	_offer_marks(3, str(SaveManager.data.get("blessed_family", "")))


## Aldous's journal: the next page the sea still holds, from a vault or a dive.
func _drop_page(at: Vector2) -> void:
	var have: Array = SaveManager.data.get("journals", [])
	for n in range(1, Story.JOURNAL.size() + 1):
		if not n in have:
			Pickup.spawn(content, at, Pickup.Kind.PAGE, n)
			return


## Roll an altar's offers and open it. The first altar of the night can offer one more
## (Wren's prayer); Deep Memory lets legendaries in a room early.
var _altar_blessed: String = ""
var _altar_count: int = 3


func _offer_marks(count: int, blessed: String) -> void:
	if _neap():
		# Nothing is offered; what would have been a mark is pearls instead.
		for i in 4:
			Pickup.spawn(content, player.global_position + Vector2(0, -10), Pickup.Kind.PEARL)
		return
	if state.first_altar_extra > 0 and int(state.stats.get("altars", 0)) == 0:
		count += state.first_altar_extra
	state.count("altars")
	_altar_blessed = blessed
	_altar_count = count
	var offers := Tidemarks.roll(_rng, state.tidemarks, count, blessed,
		state.depth_total + state.legendary_early, Tidemarks.families_of(state.tidemarks), state.active_slots)
	for id in offers:
		Codex.discover("mark", id)
	altar_ui.open(offers, state.rerolls)


func _on_altar_reroll() -> void:
	if state.rerolls <= 0:
		return
	state.rerolls -= 1
	var offers := Tidemarks.roll(_rng, state.tidemarks, _altar_count, _altar_blessed,
		state.depth_total + state.legendary_early, Tidemarks.families_of(state.tidemarks), state.active_slots)
	for id in offers:
		Codex.discover("mark", id)
	altar_ui.set_offers(offers, state.rerolls)


## A usable prop with its handler: fountains heal, chests spill, altars offer, merchants trade.
func _add_room_prop(kind: Prop.Kind, cell: Vector2i) -> Prop:
	var p := room.add_prop(kind, cell)
	match kind:
		Prop.Kind.FOUNTAIN:
			p.used.connect(_on_fountain)
		Prop.Kind.CHEST:
			p.used.connect(_on_chest)
		Prop.Kind.ALTAR:
			p.used.connect(func(_p):
				# A dive's altar always has something from the Deep in it.
				var blessed := "deep" if room_type == RoomGraph.DIVE else str(SaveManager.data.get("blessed_family", ""))
				if room_type == RoomGraph.DIVE:
					state.count("dives")
					SaveManager.count("dives")
				_offer_marks(2 if state.tier >= 6 else 3, blessed))
		Prop.Kind.MERCHANT:
			p.used.connect(func(_p): shop.open())
		Prop.Kind.VAULT:
			p.used.connect(_on_vault)
	return p


## Area name slides in from the left with a punch, holds 4 s, fades.
func _show_room_label(title: String, sub: String) -> void:
	room_label.text = title
	room_sub.text = sub
	for l in [room_label, room_sub]:
		l.visible = true
		l.modulate = Color(1, 1, 1, 1)
	var x0 := 10.0
	room_label.position.x = -220.0
	room_sub.position.x = -220.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(room_label, "position:x", x0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(room_sub, "position:x", x0 + 2.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08)
	tw.chain().tween_interval(4.0)
	tw.chain().tween_property(room_label, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(room_sub, "modulate:a", 0.0, 0.6)


func _enemy_scene() -> PackedScene:
	var r := _rng.randf()
	match biome().id:
		"flats":
			if state.depth < 2:
				return SHELLBACK if r < 0.6 else GULL
			if r < 0.34:
				return SHELLBACK
			if r < 0.58:
				return GULL
			if r < 0.82:
				return CRAB
			return TIDEWISP
		"harbour":
			# Hands and crews first; the barnacles come off the hulls once you are in deep.
			if state.depth < 2:
				return MOORING if r < 0.5 else (GULL if r < 0.75 else DECKHAND)
			if r < 0.3:
				return MOORING
			if r < 0.55:
				return DECKHAND
			if r < 0.85:
				return BARNACLE
			return GULL
		"hall":
			# The hall: the old keepers, the dock hands, the mouths in the floor, and the
			# ones who stood so long the candles ran down over them.
			if r < 0.36:
				return SHADE
			if r < 0.62:
				return ANCHOR
			if r < 0.82:
				return MAW
			return TALLOW
	# The streets: statues everywhere, a lamplighter or a ringer among them, and the
	# drowned themselves once there is water to come out of.
	var wet := state.tide.level > 0.5
	if r < 0.42:
		return CITIZEN
	if r < 0.62:
		return LAMPLIGHTER
	if r < 0.78:
		return RINGER
	return SWIMMER if wet else CITIZEN


func _spawn_enemies(count: int, with_elite: bool) -> void:
	var spawns: Array[Vector2i] = room.template.spawn_cells(count, _rng)
	for i in count:
		var cell: Vector2i = spawns[i]
		var scene := _enemy_scene()
		if _wet_room and _rng.randf() < 0.4:
			scene = biome().wet
		# The biome's named elite holds the deeper half; nearer the top it is an ordinary
		# thing with an affix. Only the named ones leave an echo shard.
		var named: bool = with_elite and i == 0 and (_dev_named or state.depth * 2 >= biome().length)
		if named:
			scene = biome().elite
		var e: Enemy = _spawn(scene, room.cell_to_world(cell))
		if with_elite and i == 0:
			e.make_elite("" if named else Enemy.AFFIXES[_rng.randi() % Enemy.AFFIXES.size()])
			if named:
				e.display_name = str(biome().elite_name)
				announcer.card(str(biome().elite_name).to_upper(), "A named one. Break it for an echo shard.", 2.0, Color(0.95, 0.8, 0.5))
				if biome().id == "flats":
					_whisper("netted", 2.4)
				elif biome().id == "streets":
					_whisper("choir", 2.4)
				e.pearl_drop += 1


func _spawn_echo_room() -> void:
	cage_echo = _echo_queue.pop_front() if _echo_queue.size() > 0 else ""
	_spawn_enemies(2 + state.depth / 2 + state.biome, false)
	for cell in room.template.marker_cells("E"):
		cage = room.add_prop(Prop.Kind.CAGE, cell)
		cage.used.connect(_on_cage_opened)
	if cage_echo != "":
		announcer.card("SOMEONE IS STILL HERE", "Clear the room, then open the cage.", 2.2)
		announcer.hint("echo")
		_whisper("cage", 2.6)
		if Story.WHISPERS.has(cage_echo):
			_whisper(cage_echo, 8.5)


func _spawn_boss() -> void:
	var spawns: Array = room.template.enemy_spawns
	boss = _spawn(biome().boss, room.cell_to_world(spawns[0]))
	_second_wind_used = false
	state.stats["tide_at_boss_%d" % state.biome] = state.tide.level
	var last := state.biome + 1 >= BIOMES.size()
	if state.tier >= 3:
		boss.call_deferred("_apply_stat_mult", 1.6 if (state.tier >= 8 and last) else 1.3, 1.0)
		boss.health.changed.connect(_boss_second_wind)
	boss.phase_changed.connect(func(_p):
		announcer.card(str(biome().stir), "It is hurt, and angrier. The tide jumps.", 1.8, Announcer.STIR_COLOR)
		announcer.pulse(Announcer.STIR_COLOR, 0.5, 0.9)
		Audio.play("stinger_phase", 0.0, -3.0)
		Audio.play(biome().boss_sfx, 0.0, 2.0)
		state.tide.level = minf(TideSystem.MAX_LEVEL, state.tide.level + (0.7 if state.tier >= 8 else 0.35))
	)
	hud.set_boss(boss)
	# The square's statues: dormant until the bell cracks.
	if biome().id == "streets":
		for i in range(1, spawns.size()):
			var c: Enemy = _spawn(CITIZEN, room.cell_to_world(spawns[i]))
			c.dormant = true
			c.salt_drop = 1


## Spring tide 3+: a boss rallies once when it is nearly done.
func _boss_second_wind(current: int, max_hp: int) -> void:
	if _second_wind_used or boss == null or not is_instance_valid(boss) or current <= 0 or current * 4 > max_hp:
		return
	_second_wind_used = true
	boss.health.heal(int(max_hp * 0.2))
	announcer.card("SECOND WIND", "It healed a fifth of itself. Finish it.", 1.6, Color(0.95, 0.6, 0.5))
	Audio.play("stinger_phase", 0.0, -6.0)
	FX.ring(boss.global_position, Color(1.0, 0.5, 0.4), 2.0)
	Audio.play(biome().boss_sfx, 0.0, -2.0)


# --- tidemark hooks that live in the run ------------------------------------------------
## Salt Purse: a hit costs salt instead of health while there is salt to pay with.
func _on_player_hit(info: DamageInfo) -> void:
	# The night's ledger: how far you got before the first hit, and how much landed.
	if not info.tags.has("tide"):
		if not state.stats.has("untouched_depth"):
			state.stats["untouched_depth"] = state.depth_total
		state.count("damage_taken", info.amount)
		SaveManager.count("damage_taken", info.amount)
	if player.dead or not player.mods.salt_shield or info.tags.has("tide") or state.salt < 5:
		return
	state.salt -= 5
	EventBus.salt_changed.emit(state.salt)
	player.health.heal(info.amount)
	FX.text(player.global_position + Vector2(0, -18), "-5 SALT", Color(0.98, 0.9, 0.6))


## Barnacle Plate: an absorbed hit bites back.
func _on_player_shielded(info: DamageInfo) -> void:
	var enemy := info.source as Enemy
	if int(player.mods.thorns) <= 0 or enemy == null or not is_instance_valid(enemy):
		return
	var back := DamageInfo.make(int(player.mods.thorns), player, enemy.global_position - player.global_position, 90.0)
	back.tags = PackedStringArray(["thorns"])
	if enemy.hurtbox.receive(back):
		EventBus.damage_dealt.emit(enemy, back)
		FX.spark(enemy.global_position)


## Slack Water, Drowning, Drowned Skin: things that happen every frame.
func _tick_marks(delta: float) -> void:
	if player.dead or room == null:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	if player.mods.slack and not enemies.is_empty():
		state.tide.pause(0.05)
	if int(player.mods.drown) > 0:
		_drown_t += delta
		if _drown_t >= 0.5:
			_drown_t = 0.0
			for e in enemies:
				if e is Enemy and not e.flying and is_instance_valid(e) and room.is_deep_at(e.global_position):
					var info := DamageInfo.make(maxi(1, int(player.mods.drown) / 2), null, Vector2.ZERO, 0.0)
					info.tags = PackedStringArray(["tide"])
					info.hitstop = 0.0
					if e.hurtbox.receive(info):
						EventBus.damage_dealt.emit(e, info)
	if player.mods.water_shield and player.in_water:
		_water_shield_t += delta
		if _water_shield_t >= 4.0:
			_water_shield_t = 0.0
			if player.hurtbox.shield_count < 1:
				player.hurtbox.shield_count = 1
				FX.text(player.global_position + Vector2(0, -16), "SKIN", Color(0.6, 0.8, 1.0))


## Active tidemarks: R fires the first one that is ready, in the order they were taken.
func _tick_actives(delta: float) -> void:
	for id in state.active_cd.keys():
		state.active_cd[id] = maxf(0.0, float(state.active_cd[id]) - delta)
	if Input.is_action_just_pressed("active") and not player.dead and not get_tree().paused:
		for id in state.actives():
			if float(state.active_cd.get(id, 0.0)) <= 0.0:
				_use_active(id)
				return


func _use_active(id: String) -> void:
	state.active_cd[id] = Tidemarks.cooldown_of(id)
	state.count("actives_used")
	SaveManager.count("actives_used")
	var col := Tidemarks.color_of(id)
	var at := player.global_position
	match id:
		"act_storm":
			for e in get_tree().get_nodes_in_group("enemies"):
				if not (e is Enemy) or e.global_position.distance_to(at) > 70.0:
					continue
				var info := DamageInfo.make(int(12 * float(player.mods.damage)), player, e.global_position - at, 160.0)
				info.tags = PackedStringArray(["storm", "melee"])
				if e.hurtbox.receive(info):
					EventBus.damage_dealt.emit(e, info)
					FX.spark(e.global_position)
			EventBus.request_shake.emit(0.5)
			Audio.play("heavy", 0.1)
		"act_wall":
			player.hurtbox.shield_count = maxi(player.hurtbox.shield_count, 1)
			state.tide.pause(3.0)
			Audio.play("splash", 0.1, -4.0)
		"act_step":
			player.dash_charges = player.max_dash
			player.health._iframes = maxf(player.health._iframes, 1.0)
			Audio.play("riptide", 0.05, -4.0)
		"act_call":
			state.tide.pause(10.0)
			Audio.play("altar", 0.0, -2.0)
	FX.ring(at, col, 1.8)
	FX.burst(at, col, 14, 70.0)
	FX.text(at + Vector2(0, -18), Tidemarks.get_mark(id).name.to_upper(), col)


## The lantern's one-time lines, a moment after whatever they comment on.
func _whisper(key: String, delay: float) -> void:
	var text := Story.whisper(key)
	if text == "":
		return
	await get_tree().create_timer(delay).timeout
	if state.ended:
		return
	announcer.whisper(text)


## The boss walks on: bars, a breath of slow time, its name and what it does.
func _boss_intro() -> void:
	announcer.letterbox(true)
	announcer.hint("boss")
	Juice.slowmo(0.5, 0.8)
	announcer.card(str(biome().boss_name), str(biome().boss_sub), 2.4, Announcer.BOSS_COLOR, true)
	await get_tree().create_timer(3.4, false).timeout
	if not state.ended and is_instance_valid(announcer):
		announcer.letterbox(false)


## What the water just covered: a flash on the staff, a pulse at the edge, a word.
var _tide_step: int = 0


func _watch_tide() -> void:
	var step := int(floor(state.tide.level))
	if step <= _tide_step:
		return
	_tide_step = step
	hud.flash_tide()
	announcer.pulse(Announcer.SEA_PALE, 0.55, 1.0)
	Audio.play("wave", 0.0, -10.0)
	var words := ["", "the tide is over the low ground", "the tide is over the floor", "the tide is over everything"]
	announcer.toast(words[mini(step, 3)], Announcer.SEA_PALE, 2.8)
	announcer.hint("tide" if step == 1 else "tide2")


func _hint_pickup(kind: int, _value: int) -> void:
	match kind:
		Pickup.Kind.SALT: announcer.hint("salt")
		Pickup.Kind.PEARL: announcer.hint("pearl")
		Pickup.Kind.KEY: announcer.hint("key")


func _watch_health(current: int, max_hp: int) -> void:
	var low := current > 0 and current * 10 < max_hp * 3
	announcer.low_health(low)
	if low:
		announcer.hint("low")


func _spawn(scene: PackedScene, at: Vector2) -> Enemy:
	var e: Enemy = scene.instantiate()
	e.global_position = at
	content.add_child(e)
	if state.tier >= 2 and scene != biome().boss:
		e.call_deferred("_apply_stat_mult", 1.25, 1.0)
	Codex.discover("enemy", Codex.enemy_id(e))
	return e


func _set_cleared() -> void:
	if room_cleared:
		return
	room_cleared = true
	state.rooms_cleared += 1
	if int(player.mods.clear_heal) > 0 and not player.dead:
		player.health.heal(int(player.mods.clear_heal))
	if player.mods.tithe and state.rooms_cleared % 3 == 0 and not player.dead:
		Pickup.spawn(content, player.global_position + Vector2(0, -12), Pickup.Kind.PEARL)
	if room_type == RoomGraph.ECHO and cage and cage_echo != "":
		# Doors wait: the cage opens first.
		cage.unlock()
		announcer.toast("the cage can be opened   " + UI.hint("interact"), Announcer.SEA_PALE)
		Audio.play("clear", 0.0, -4.0)
		EventBus.room_cleared.emit(room)
		return
	room.open_doors()
	if room_type in [RoomGraph.COMBAT, RoomGraph.ELITE, RoomGraph.ECHO]:
		announcer.toast("the water carries you: two rooms down" if _skip > 0 else "the doors are open", Announcer.SEA_PALE)
		for d in room.doors:
			if d.wet:
				announcer.hint("fork")
		Audio.play("clear", 0.0, -4.0)
		if _wet_room and not player.dead:
			Pickup.spawn(content, player.global_position + Vector2(0, -12), Pickup.Kind.PEARL)
			state.count("wet_rooms")
			SaveManager.count("wet_rooms")
			if _skip > 0:
				state.count("shortcuts")
				SaveManager.count("shortcuts")
				_whisper("shortcut", 1.6)
	elif room_type == RoomGraph.BOSS:
		FX.flash_screen(Color(1.0, 0.95, 0.85, 0.7), 0.5)
		Juice.slowmo(0.3, 0.9)
		announcer.letterbox(false)
		announcer.card(str(biome().won), "The way down opens.", 2.8, Announcer.WON_COLOR, true)
		Audio.play("door", 0.0, 0.0)
	EventBus.room_cleared.emit(room)


func _on_cage_opened(p: Prop) -> void:
	var id := cage_echo
	cage_echo = ""
	var info: Dictionary = ECHOES[id]
	state.echoes.append(id)
	SaveManager.set_flag("echo_" + id)
	SaveManager.data["echoes"] = Story.echoes_home()
	SaveManager.count("cages")
	SaveManager.save_profile()
	p.show_echo(id)
	_give_shards(3, p.global_position + Vector2(0, -20))
	for i in 3:
		Pickup.spawn(content, p.global_position + Vector2(0, 8), Pickup.Kind.PEARL)
	Juice.slowmo(0.3, 0.4)
	FX.flash_screen(Color(0.8, 0.9, 1.0, 0.45), 0.5)
	FX.ring(p.global_position, Color(0.75, 0.9, 1.0), 2.4)
	FX.burst(p.global_position, Color(0.8, 0.92, 1.0), 20, 90.0)
	Audio.play("rescue")
	Audio.play("stinger_rescue", 0.0, -4.0)
	announcer.card(info.name.to_upper() + " IS FREE", "They go home to the lighthouse tonight.", 2.2)
	await get_tree().create_timer(2.4).timeout
	if state.ended:
		return
	announcer.whisper(str(info.line), str(info.name))
	room.open_doors()
	Audio.play("door", 0.05, -4.0)


func _on_enemy_died(enemy: Node) -> void:
	state.kills += 1
	SaveManager.count("kills")
	if enemy is Enemy:
		var eid := Codex.enemy_id(enemy)
		Codex.discover("enemy", eid)
		state.count("kills_" + eid)
		SaveManager.data["kills_by"][eid] = int(SaveManager.data["kills_by"].get(eid, 0)) + 1
		if enemy.is_boss:
			state.count("bosses")
			state.count("boss_" + eid)
			SaveManager.count("bosses")
			SaveManager.set_flag("boss_%s_broken" % eid)
		elif enemy.is_elite:
			state.count("elites")
			SaveManager.count("elites")
			if enemy.affix == "":
				state.count("named_elites")
				SaveManager.count("named_elites")
		var pos: Vector2 = enemy.global_position
		for i in int(round(enemy.salt_drop * player.mods.salt_mult * (1.5 if _wet_room else 1.0))):
			Pickup.spawn(content, pos, Pickup.Kind.SALT)
		var pearls: int = enemy.pearl_drop + (int(player.mods.pearl_bonus) if (enemy.is_elite or enemy.is_boss) else 0)
		for i in pearls:
			Pickup.spawn(content, pos, Pickup.Kind.PEARL)
		if enemy.is_elite and not enemy.is_boss:
			Pickup.spawn(content, pos, Pickup.Kind.KEY)
		# Named elites (no affix) and bosses leave an echo shard behind.
		if enemy.is_boss or (enemy.is_elite and enemy.affix == ""):
			_give_shards(1 + (int(player.mods.shard_bonus) if enemy.is_boss else 0), pos)
		if enemy == boss:
			_on_boss_died()
			return
	await get_tree().process_frame
	if state.ended or _challenge_t >= 0.0:
		return
	if get_tree().get_nodes_in_group("enemies").is_empty():
		_set_cleared()


## The Choir let go alive: it counts as the room's clearing, not as a kill, and it comes
## home like any echo.
func _on_enemy_spared(enemy: Node) -> void:
	if not (enemy is Enemy):
		return
	var pos: Vector2 = enemy.global_position
	state.count("spared")
	SaveManager.count("spared")
	if not SaveManager.flag("echo_choir"):
		SaveManager.set_flag("echo_choir")
		SaveManager.data["echoes"] = Story.echoes_home()
		SaveManager.save_profile()
		state.echoes.append("choir")
		_give_shards(3, pos + Vector2(0, -20))
		var p := room.add_prop(Prop.Kind.ECHO_GHOST, room.world_to_cell(pos))
		p.show_echo("choir")
		Juice.slowmo(0.3, 0.4)
		FX.flash_screen(Color(0.85, 0.8, 1.0, 0.45), 0.5)
		FX.ring(pos, Color(0.85, 0.75, 1.0), 2.4)
		Audio.play("rescue")
		Audio.play("stinger_rescue", 0.0, -4.0)
		announcer.card("THE CHOIR IS FREE", "You let the note end. It goes home.", 2.2, Color(0.85, 0.8, 1.0))
		_whisper("choir_spared", 2.4)
	else:
		announcer.card("THE NOTE ENDS", "", 1.6, Color(0.85, 0.8, 1.0))
		Pickup.spawn(content, pos, Pickup.Kind.PEARL)
	await get_tree().process_frame
	if state.ended or _challenge_t >= 0.0:
		return
	if get_tree().get_nodes_in_group("enemies").is_empty():
		_set_cleared()


func _on_boss_died() -> void:
	# The boss's summons die with it.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e != boss and is_instance_valid(e):
			e.health.take(DamageInfo.make(9999, null, Vector2.ZERO, 0.0), true)
	if state.biome + 1 >= BIOMES.size():
		_free_maren()
		_win()
		return
	await get_tree().process_frame
	if state.ended:
		return
	_set_cleared()


## Echo shards go straight to the profile: they are the one thing the tide cannot take.
func _give_shards(n: int, at: Vector2) -> void:
	SaveManager.data["shards"] = int(SaveManager.data.get("shards", 0)) + n
	SaveManager.save_profile()
	state.shards += n
	FX.text(at, "+%d ECHO SHARD%s" % [n, "S" if n > 1 else ""], Color(0.95, 0.85, 0.55))
	Audio.play("pearl", 0.0, -2.0)


## The Ebb is gone: Maren steps out of the water where it stood.
func _free_maren() -> void:
	if not SaveManager.flag("echo_maren"):
		SaveManager.set_flag("echo_maren")
		SaveManager.data["echoes"] = Story.echoes_home()
		_give_shards(3, boss.global_position + Vector2(0, -20))
	SaveManager.set_flag("ebb_broken")
	state.echoes.append("maren")
	var p := room.add_prop(Prop.Kind.ECHO_GHOST, room.world_to_cell(boss.global_position))
	p.show_echo("maren")
	FX.flash_screen(Color(0.8, 0.9, 1.0, 0.6), 0.8)
	Audio.play("rescue")
	Audio.play("stinger_rescue", 0.0, -2.0)
	announcer.whisper(str(ECHOES.maren.line), "Maren")


func _on_door_entered(door: Door) -> void:
	if _transitioning or state.ended or not room_cleared:
		return
	_transitioning = true
	state.depth += 1 + _skip
	state.depth_total += 1 + _skip
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.2)
	if door.room_type == Door.DESCEND:
		tw.tween_callback(_next_biome)
	else:
		tw.tween_callback(_enter_room.bind(door.room_type, door.wet))


func _on_tidemark_chosen(id: String) -> void:
	state.tidemarks.append(id)
	Tidemarks.apply(id, player, self)
	player.mods.mark_count = state.tidemarks.size()
	if state.still_water:
		state.tide.pause(12.0)
	var m := Tidemarks.get_mark(id)
	FX.ring(player.global_position, Tidemarks.color_of(id), 1.6)
	FX.burst(player.global_position, Tidemarks.color_of(id), 16, 70.0)
	announcer.toast("%s: %s" % [m.name.to_upper(), m.desc], Tidemarks.color_of(id), 3.2)
	Audio.play("altar")


func _on_fountain(_p: Prop) -> void:
	var amount := player.health.max_hp if state.full_fountain else 35
	if state.tier >= 4:
		amount = amount / 2
	if int(player.mods.fountain_max) > 0:
		player.health.max_hp += int(player.mods.fountain_max)
	player.health.heal(amount)
	if state.still_water:
		state.tide.pause(12.0)
	if float(player.mods.fountain_hold) > 0.0:
		state.tide.pause(float(player.mods.fountain_hold))
	FX.burst(player.global_position, Color(0.5, 0.8, 0.95), 14, 60.0)


func _on_chest(p: Prop) -> void:
	for i in 3 + int(player.mods.chest_bonus):
		Pickup.spawn(content, p.global_position + Vector2(0, 8), Pickup.Kind.PEARL)
	for i in 10:
		Pickup.spawn(content, p.global_position + Vector2(0, 8), Pickup.Kind.SALT)
	# A dive's chest holds what the sea made down there: salt-glass, and a page when one is left.
	if room_type == RoomGraph.DIVE:
		Pickup.spawn(content, p.global_position + Vector2(0, 8), Pickup.Kind.GLASS)
		if _rng.randf() < 0.5:
			_drop_page(p.global_position + Vector2(0, 8))


func _on_pickup(kind: int, value: int) -> void:
	match kind:
		Pickup.Kind.SALT:
			state.salt += value
			EventBus.salt_changed.emit(state.salt)
			SaveManager.count("salt_collected", value)
			if player.mods.salt_mend:
				_mend_salt += value
				while _mend_salt >= 10:
					_mend_salt -= 10
					player.health.heal(1)
		Pickup.Kind.KEY:
			state.keys += value
			EventBus.keys_changed.emit(state.keys)
		Pickup.Kind.PAGE:
			# Straight into the profile: the sea keeps everything, and so do you now.
			var have: Array = SaveManager.data.get("journals", [])
			if not value in have:
				have.append(value)
				SaveManager.data["journals"] = have
				SaveManager.count("pages")
				state.count("pages")
				SaveManager.save_profile()
				announcer.toast("journal page %d of %d: read it in the codex" % [value, Story.JOURNAL.size()], Color(0.95, 0.92, 0.8), 3.0)
				_whisper("page", 2.4)
		Pickup.Kind.GLASS:
			SaveManager.data["glass"] = int(SaveManager.data.get("glass", 0)) + value
			SaveManager.count("glass_found", value)
			state.count("glass", value)
			SaveManager.save_profile()
			_whisper("glass", 0.8)
		Pickup.Kind.SHELL:
			SaveManager.data["shells"] = int(SaveManager.data.get("shells", 0)) + value
			SaveManager.count("shells_found", value)
			SaveManager.save_profile()
		_:
			state.pearls += value
			EventBus.pearls_changed.emit(state.pearls)


## F: eat the first fish carried.
func eat_fish() -> void:
	if state.fish.is_empty():
		return
	var id: String = state.fish.pop_front()
	var text := Fish.eat(id, player, self)
	state.count("fish_eaten")
	SaveManager.count("fish_eaten")
	FX.burst(player.global_position, Color(0.95, 0.8, 0.6), 10, 50.0)
	FX.text(player.global_position + Vector2(0, -18), text, Color(0.95, 0.85, 0.6))
	Audio.play("bite", 0.1, -4.0)


# --- resting -----------------------------------------------------------------------
## A cleared room with every door open can be left for another day.
func can_rest() -> bool:
	if state.ended or _transitioning or not room_cleared or room == null:
		return false
	for d in room.doors:
		if not d.is_open:
			return false
	return true


## Everything the shore needs to hand the night back: run state, the keeper, the room.
func snapshot() -> Dictionary:
	var d := state.to_dict()
	d["weapon"] = player.weapon.id
	d["hp"] = player.health.hp
	d["max_hp"] = player.health.max_hp
	d["max_dash"] = player.max_dash
	d["glow"] = player.glow
	d["room_type"] = room_type
	d["template"] = room.template.name
	d["room_seed"] = _room_seed
	d["rng_state"] = str(_rng.state)  # int64: a JSON float would round it
	d["echo_depths"] = _echo_depths.duplicate()
	d["echo_queue"] = _echo_queue.duplicate()
	d["last_template"] = _last_template
	d["wet"] = _wet_room
	# Props still waiting to be used come back with the room; used ones stay used.
	var props: Array = []
	for p in room.props:
		if is_instance_valid(p) and not p.used_up and p.kind in [Prop.Kind.FOUNTAIN, Prop.Kind.CHEST, Prop.Kind.ALTAR, Prop.Kind.MERCHANT, Prop.Kind.VAULT]:
			props.append({"kind": int(p.kind), "cell": [room.world_to_cell(p.global_position).x, room.world_to_cell(p.global_position).y]})
	d["props"] = props
	return d


## Save the night where it stands and stop the clock. The caller leaves the scene; the
## shore continues it, once: Game.load_suspended lifts it out of the profile.
func rest() -> bool:
	if not can_rest():
		return false
	state.count("rested")
	SaveManager.count("rests")
	SaveManager.data["suspended"] = snapshot()
	SaveManager.save_profile()
	state.ended = true
	if _replay == null and input_log.ticks.size() > 0:
		input_log.save()
	Audio.stop_music()
	announcer.low_health(false)
	if not state.victory:
		announcer.card("TAKEN BY THE TIDE" if state.taken else "TAKEN BY THE DEEP",
			"The water rose over you. Half your salt still comes home as pearls." if state.taken
			else "Your health ran out. The salt is lost; pearls and echoes come home.",
			1.6, Color(0.6, 0.8, 0.95) if state.taken else Color(0.85, 0.5, 0.5), true)
		announcer.pulse(Color(0.6, 0.8, 0.95) if state.taken else Announcer.RED, 0.6, 1.2)
		Juice.slowmo(0.35, 0.7)
	return true


## Pick a rested night up: same seed, graph, tidemarks, health, salt and room, doors open.
func _resume(d: Dictionary) -> void:
	resumed = true
	state.from_dict(d)
	Game.mode = state.mode
	_rng.state = str(d.get("rng_state", "0")).to_int()
	var wid := str(d.get("weapon", player.weapon.id))
	if wid != player.weapon.id and Weapon.ALL.has(wid):
		player._equip(wid)
	for id in state.tidemarks:
		Tidemarks.apply(id, player, self)
	player.mods.mark_count = state.tidemarks.size()
	# Tidemarks and the Ledger have just re-applied their bonuses; the saved totals win.
	state.tide.rate_mult = float(d.get("tide_rate", state.tide.rate_mult))
	player.max_dash = int(d.get("max_dash", player.max_dash))
	player.dash_charges = player.max_dash
	player.health.max_hp = int(d.get("max_hp", player.health.max_hp))
	player.health.hp = clampi(int(d.get("hp", player.health.max_hp)), 1, player.health.max_hp)
	player.health.changed.emit(player.health.hp, player.health.max_hp)
	player.glow = float(d.get("glow", 0.0))
	EventBus.salt_changed.emit(state.salt)
	EventBus.pearls_changed.emit(state.pearls)
	_echo_queue = []
	for id in d.get("echo_queue", []):
		_echo_queue.append(str(id))
	_setup_biome(state.biome, Array(d.get("echo_depths", [])))
	_last_template = str(d.get("last_template", ""))
	_enter_rested_room(int(d.get("room_type", RoomGraph.COMBAT)), str(d.get("template", "")), int(d.get("room_seed", 0)),
		Array(d.get("props", [])), bool(d.get("wet", false)))
	EventBus.keys_changed.emit(state.keys)


## Rebuild the room the night was left in: cleared, doors open, nothing left to fight,
## and whatever was still unused (an altar, a fountain, the merchant) waiting where it was.
func _enter_rested_room(type: int, template_name: String, room_seed: int, props: Array, wet: bool = false) -> void:
	room_type = type
	boss = null
	cage = null
	_wet_room = wet
	_challenge_t = -1.0
	var t: RoomTemplate = null
	for cand in _templates.get(type, []):
		if cand.name == template_name:
			t = cand
	if t == null:
		t = _pick_template(type)
	room = Room.new()
	room_holder.add_child(room)
	_room_seed = room_seed
	room.build(t, room_seed, biome().theme)
	room.tide_bonus = _room_bonus(type, wet)
	player.global_position = room.cell_to_world(room.template.player_spawn)
	player.velocity = Vector2.ZERO
	room.set_tide(state.tide.level)
	_skip = 1 if _shortcut(wet) else 0
	_place_doors(type, state.depth + 1 + _skip)
	if type == RoomGraph.SHOP:
		shop.restock()
	for pd in props:
		var cell: Array = pd.get("cell", [0, 0])
		var kind := int(pd.get("kind", 0))
		if _neap() and kind == int(Prop.Kind.ALTAR):
			kind = int(Prop.Kind.CHEST)
		_add_room_prop(kind as Prop.Kind, Vector2i(int(cell[0]), int(cell[1])))
	room_cleared = true
	room.open_doors()
	_show_room_label(biome().name, "%d / %d   %s%s" % [state.depth + 1, biome().length + 1, RoomGraph.NAMES[type],
		"   spring tide %d" % state.tier if state.tier > 0 else ""])
	announcer.card("THE NIGHT GOES ON", "Your rest is over. The tide waits for no one.", 2.4)
	EventBus.room_entered.emit(room)
	var fade_tw := create_tween()
	fade_tw.tween_property(fade, "color:a", 0.0, 0.6)
	fade_tw.tween_callback(func(): _transitioning = false)


# --- ending ------------------------------------------------------------------------
func _on_player_died() -> void:
	if state.ended:
		return
	state.taken = player.last_hit_tags.has("tide")
	_end_run()


func _win() -> void:
	if state.ended:
		return
	state.victory = true
	if state.tier > 0:
		_give_shards(maxi(1, state.tier / 2), player.global_position + Vector2(0, -20))
	_end_run()


## From the pause menu: abandon the run (counts as taken by the deep, salt lost).
func give_up() -> void:
	if state.ended:
		return
	player.dead = true
	_end_run()


func _end_run() -> void:
	state.ended = true
	Audio.stop_music()
	Audio.stop_layer()
	# The night's inputs go to disk first: a crash in the results still leaves the file.
	var replay_path := ""
	if _replay == null and input_log.ticks.size() > 0:
		replay_path = input_log.save()
	# Let the last drops get collected before the ledger is written.
	await get_tree().create_timer(1.2).timeout
	var result := state.result()
	if replay_path != "":
		result["replay"] = replay_path
	if state.victory:
		if not SaveManager.flag("won_" + player.weapon.id):
			SaveManager.set_flag("won_" + player.weapon.id)
			SaveManager.count("weapons_won")
	# Long Memory: the first mark of this night waits for the next one.
	SaveManager.data["kept_mark"] = str(state.tidemarks[0]) if state.tidemarks.size() > 0 else ""
	# Nessa's board is judged before the run number moves on.
	result["contracts"] = Contracts.settle(state.ledger())
	Game.run_finished(result)
	results.show_result(result)


## Dev aid: run with `-- --screenshot` to save .shots/latest.png after a few frames and quit.
func _handle_screenshot_arg() -> void:
	if not "--screenshot" in OS.get_cmdline_user_args():
		return
	var frames := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wait="):
			frames = int(a.trim_prefix("--wait="))
	for i in frames:
		await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	print("screenshot -> %s/latest.png (%s)" % [dir, error_string(img.save_png(dir + "/latest.png"))])
	get_tree().quit()
