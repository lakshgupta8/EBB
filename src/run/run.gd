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

## The night, top to bottom. Everything that differs between biomes lives here, so nothing
## else counts indices: id, rooms directory, length (rooms before the boss), look, boss,
## echoes to find, music, codex place, the lantern's whispers, the boss's sound, the night's tint.
const BIOMES := [
	{"id": "flats", "name": "THE FLATS", "dir": "res://data/rooms/biome1/", "length": 10, "theme": Tiles.Look.FLATS,
		"boss": WRECK, "boss_name": "THE WRECK", "stir": "THE WRECK STIRS", "won": "THE WRECK IS BROKEN",
		"echoes": ["bram"], "music": "music_flats", "place": "flats", "whisper": "first_night", "boss_whisper": "wreck",
		"boss_sfx": "roar", "tint": Color(0.6, 0.68, 0.86), "wet": GULL,
		"intro": "The tide has gone out. Saltmere waits."},
	{"id": "harbour", "name": "THE SUNKEN HARBOUR", "dir": "res://data/rooms/harbour/", "length": 9, "theme": Tiles.Look.HARBOUR,
		"boss": CHAINMOTHER, "boss_name": "THE CHAINMOTHER", "stir": "THE CHAINMOTHER STIRS", "won": "THE CHAINMOTHER LETS GO",
		"echoes": [], "music": "music_harbour", "place": "harbour", "whisper": "harbour", "boss_whisper": "chainmother",
		"boss_sfx": "creak", "tint": Color(0.58, 0.64, 0.82), "wet": BARNACLE,
		"intro": "The harbour. Every ship that tried to leave is still tied up."},
	{"id": "streets", "name": "THE DROWNED STREETS", "dir": "res://data/rooms/biome2/", "length": 11, "theme": Tiles.Look.STREETS,
		"boss": BELL, "boss_name": "THE BELL OF SALTMERE", "stir": "THE BELL CRACKS", "won": "THE BELL IS SILENCED",
		"echoes": ["wren", "cartographer"], "music": "music_streets", "place": "streets", "whisper": "streets", "boss_whisper": "bell",
		"boss_sfx": "bell", "tint": Color(0.56, 0.6, 0.8), "wet": SWIMMER,
		"intro": "Slack water. The streets of Saltmere, and something still ringing."},
	{"id": "hall", "name": "THE DEEP HALL", "dir": "res://data/rooms/biome3/", "length": 9, "theme": Tiles.Look.DEEP,
		"boss": EBB, "boss_name": "THE EBB", "stir": "THE EBB RISES", "won": "THE EBB LETS GO",
		"echoes": [], "music": "music_hall", "place": "hall", "whisper": "hall", "boss_whisper": "ebb",
		"boss_sfx": "ebb", "tint": Color(0.56, 0.62, 0.84), "wet": ANCHOR,
		"intro": "The Deep Hall. Every keeper before you is standing in it."},
]
## The people you can bring back, and what they say when the cage opens.
const ECHOES := {
	"bram": {"name": "Bram the Drowned", "line": "A smith. Still a smith. Get me to a fire, keeper, and I will make you something that bites."},
	"wren": {"name": "Sister Wren", "line": "The tide is not cruel. It is only patient. Find me by the tower; I remember prayers that still work."},
	"cartographer": {"name": "The Cartographer", "line": "I mapped every street before the water came. Streets do not move. The water does."},
	"maren": {"name": "Maren", "line": "Tam. It let go. Take me up to the light."},
}
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
var _mend_salt: int = 0          # Salt Mend: salt counted toward the next point of health
var _drown_t: float = 0.0        # Drowning: tick timer
var _water_shield_t: float = 0.0  # Drowned Skin: seconds spent in water toward a shield
var _second_wind_used: bool = false
var _deep_tick: float = 0.0
var _transitioning: bool = false
var _echo_queue: Array = []  # echo ids still to be found in this biome, in depth order

@onready var player: Player = $Player
@onready var room_holder: Node2D = $RoomHolder
@onready var content: Node2D = $Content
@onready var hud: Control = $HUD/Bars
@onready var fade: ColorRect = $HUD/Fade
@onready var results: CanvasLayer = $Results
@onready var room_label: Label = $HUD/RoomLabel
@onready var room_sub: Label = $HUD/RoomSub
@onready var banner: Label = $HUD/Banner
@onready var shop: Shop = $Shop
@onready var altar_ui: AltarUI = $AltarUI
@onready var codex_ui: CodexUI = $CodexUI
@onready var settings_ui: SettingsUI = $SettingsUI


func biome() -> Dictionary:
	return BIOMES[state.biome]


func _ready() -> void:
	state.seed = Game.run_seed if Game.run_seed != 0 else randi()
	_rng.seed = state.seed
	hud.bind(self)
	shop.setup(self)
	challenge_label = UI.label("", 14, Color(0.8, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	challenge_label.position = Vector2(220, 44)
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
	EventBus.player_died.connect(_on_player_died)
	EventBus.pickup_collected.connect(_on_pickup)
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
	var rested := Game.take_resume()
	if not rested.is_empty():
		_resume(rested)
	else:
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
		if start_biome > 0:
			state.tide.level = SLACK_WATER
		_start_biome(start_biome, "--boss" in OS.get_cmdline_user_args())
	_handle_screenshot_arg()


func _process(delta: float) -> void:
	if state.ended:
		return
	state.time += delta
	state.tide.advance(delta)
	room.set_tide(state.tide.level)
	EventBus.tide_changed.emit(state.tide.level)
	_apply_water(delta)
	_tick_challenge(delta)
	_tick_marks(delta)


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
		if _deep_tick >= TideSystem.DEEP_TICK:
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
	_show_banner(b.intro, 3.0, Color(0.8, 0.9, 1.0), 12)
	_whisper(b.whisper, 3.6)
	if state.tier > 0 and index == 0:
		_whisper("tide_%d" % state.tier, 7.5)


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
	Audio.music(b.music, -11.0)
	Codex.discover("place", b.place)


## Past a boss: the tide slackens, the next biome begins.
func _next_biome() -> void:
	state.tide.level = SLACK_WATER
	_start_biome(state.biome + 1)


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
	var template := _pick_template(type)
	_room_seed = _rng.randi()
	room.build(template, _room_seed, biome().theme)
	room.tide_bonus = _room_bonus(type, wet)
	player.global_position = room.cell_to_world(room.template.player_spawn)
	player.velocity = Vector2.ZERO
	player.rally = 0.0
	state.tide.room_entered()
	room.set_tide(state.tide.level)

	var next_depth := state.depth + 1
	_place_doors(type, next_depth)

	match type:
		RoomGraph.COMBAT:
			_spawn_enemies(2 + state.depth / 2 + state.biome, state.tier >= 7 and state.depth >= 4)
		RoomGraph.ELITE:
			_spawn_enemies(1 + state.depth / 3 + state.biome, true)
		RoomGraph.FOUNTAIN:
			for cell in room.template.marker_cells("F"):
				_add_room_prop(Prop.Kind.FOUNTAIN, cell)
			_set_cleared()
		RoomGraph.TREASURE:
			for cell in room.template.marker_cells("T"):
				_add_room_prop(Prop.Kind.CHEST, cell)
			_set_cleared()
		RoomGraph.ALTAR:
			for cell in room.template.marker_cells("A"):
				_add_room_prop(Prop.Kind.ALTAR, cell)
			_set_cleared()
		RoomGraph.SHOP:
			shop.restock()
			for cell in room.template.marker_cells("M"):
				_add_room_prop(Prop.Kind.MERCHANT, cell)
			_set_cleared()
		RoomGraph.CHALLENGE:
			_start_challenge()
		RoomGraph.VAULT:
			for cell in room.template.marker_cells("T"):
				_add_room_prop(Prop.Kind.VAULT, cell)
			_set_cleared()
		RoomGraph.DIVE:
			for cell in room.template.marker_cells("A"):
				_add_room_prop(Prop.Kind.ALTAR, cell)
			for cell in room.template.marker_cells("T"):
				_add_room_prop(Prop.Kind.CHEST, cell)
			_whisper("dive", 1.2)
			_set_cleared()
		RoomGraph.ECHO:
			_spawn_echo_room()
		RoomGraph.BOSS:
			_spawn_boss()
			Audio.music("music_boss", -9.0)
			_show_banner(biome().boss_name, 2.2, Color(0.95, 0.75, 0.6), 20)
			EventBus.request_shake.emit(0.6)
			Audio.play(biome().boss_sfx)
			_whisper(biome().boss_whisper, 2.8)

	_show_room_label(biome().name, "%d / %d   %s%s%s" % [state.depth + 1, biome().length + 1, RoomGraph.NAMES[type],
		"  (wet)" if wet else "", "   spring tide %d" % state.tier if state.tier > 0 else ""])
	EventBus.room_entered.emit(room)
	var fade_tw := create_tween()
	fade_tw.tween_property(fade, "color:a", 0.0, 0.25)
	fade_tw.tween_callback(func(): _transitioning = false)


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
				room.doors[i].set_wet()
	for d in room.doors:
		d.entered.connect(_on_door_entered)


# --- the challenge: no way out until the tide turns ---------------------------------
func _start_challenge() -> void:
	_challenge_t = 0.0
	_challenge_wave = 0
	_show_banner("HOLD UNTIL THE TIDE TURNS", 2.2, Color(0.75, 0.9, 1.0), 12)
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
	_show_banner("THE TIDE TURNS", 2.0, Color(0.75, 0.9, 1.0), 14)
	Audio.play("clear", 0.0, -2.0)
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
	FX.burst(p.global_position, Color(0.95, 0.85, 0.5), 20, 90.0)
	Audio.play("altar")
	var offers := Tidemarks.roll(_rng, state.tidemarks, 3, str(SaveManager.data.get("blessed_family", "")),
		state.depth_total, Tidemarks.families_of(state.tidemarks))
	for id in offers:
		Codex.discover("mark", id)
	altar_ui.open(offers)


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
				var offers := Tidemarks.roll(_rng, state.tidemarks, 2 if state.tier >= 6 else 3, blessed,
					state.depth_total, Tidemarks.families_of(state.tidemarks))
				for id in offers:
					Codex.discover("mark", id)
				altar_ui.open(offers))
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
			return SHELLBACK if r < 0.4 else (GULL if r < 0.7 else CRAB)
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
			# The hall: the old keepers, the dock hands, and the mouths in the floor.
			if r < 0.45:
				return SHADE
			if r < 0.75:
				return ANCHOR
			return MAW
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
	var spawns: Array = room.template.enemy_spawns.duplicate()
	spawns.shuffle()
	for i in count:
		var cell: Vector2i = spawns[i % spawns.size()]
		var scene := _enemy_scene()
		if _wet_room and _rng.randf() < 0.4:
			scene = biome().wet
		var named: bool = with_elite and i == 0 and biome().id in ["hall", "harbour"]
		if named and biome().id == "hall":
			scene = SHADE
		elif named:
			scene = DECKHAND
		var e: Enemy = _spawn(scene, room.cell_to_world(cell))
		if with_elite and i == 0:
			e.make_elite("" if named else Enemy.AFFIXES[_rng.randi() % Enemy.AFFIXES.size()])
			if biome().id == "hall":
				e.display_name = "Echo of Maren"
			elif biome().id == "harbour":
				e.display_name = "The Bosun"
				e.pearl_drop += 1


func _spawn_echo_room() -> void:
	cage_echo = _echo_queue.pop_front() if _echo_queue.size() > 0 else ""
	_spawn_enemies(2 + state.depth / 2 + state.biome, false)
	for cell in room.template.marker_cells("E"):
		cage = room.add_prop(Prop.Kind.CAGE, cell)
		cage.used.connect(_on_cage_opened)
	if cage_echo != "":
		_show_banner("SOMEONE IS STILL HERE", 2.0, Color(0.75, 0.9, 1.0), 12)
		_whisper("cage", 2.6)


func _spawn_boss() -> void:
	var spawns: Array = room.template.enemy_spawns
	boss = _spawn(biome().boss, room.cell_to_world(spawns[0]))
	_second_wind_used = false
	var last := state.biome + 1 >= BIOMES.size()
	if state.tier >= 3:
		boss.call_deferred("_apply_stat_mult", 1.6 if (state.tier >= 8 and last) else 1.3, 1.0)
		boss.health.changed.connect(_boss_second_wind)
	boss.phase_changed.connect(func(_p):
		_show_banner(biome().stir, 1.6, Color(0.95, 0.5, 0.45), 16)
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
	_show_banner("SECOND WIND", 1.4, Color(0.95, 0.6, 0.5), 14)
	FX.ring(boss.global_position, Color(1.0, 0.5, 0.4), 2.0)
	Audio.play(biome().boss_sfx, 0.0, -2.0)


# --- tidemark hooks that live in the run ------------------------------------------------
## Salt Purse: a hit costs salt instead of health while there is salt to pay with.
func _on_player_hit(info: DamageInfo) -> void:
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


## The lantern's one-time lines, a moment after whatever they comment on.
func _whisper(key: String, delay: float) -> void:
	var text := Story.whisper(key)
	if text == "":
		return
	await get_tree().create_timer(delay).timeout
	if state.ended:
		return
	_show_banner("\"" + text + "\"", 5.5, Color(0.85, 0.85, 0.95), 8)


func _show_banner(text: String, duration: float, color: Color, size: int = 14) -> void:
	banner.text = text
	banner.add_theme_font_size_override("font_size", size)
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if size <= 8 else TextServer.AUTOWRAP_OFF
	banner.vertical_alignment = VERTICAL_ALIGNMENT_TOP if size <= 8 else VERTICAL_ALIGNMENT_CENTER
	banner.modulate = Color(color.r, color.g, color.b, 0.0)
	banner.visible = true
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.15)
	tw.tween_interval(duration)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): banner.visible = false)


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
		_show_banner("THE CAGE CAN BE OPENED", 1.4, Color(0.75, 0.9, 1.0), 12)
		Audio.play("clear", 0.0, -4.0)
		EventBus.room_cleared.emit(room)
		return
	room.open_doors()
	if room_type in [RoomGraph.COMBAT, RoomGraph.ELITE, RoomGraph.ECHO]:
		_show_banner("THE WAY OPENS", 1.2, Color(0.7, 0.9, 1.0), 12)
		Audio.play("clear", 0.0, -4.0)
		if _wet_room and not player.dead:
			Pickup.spawn(content, player.global_position + Vector2(0, -12), Pickup.Kind.PEARL)
	elif room_type == RoomGraph.BOSS:
		_show_banner("THE WAY DOWN OPENS", 2.0, Color(0.7, 0.9, 1.0), 14)
		Audio.play("door", 0.0, 0.0)
	EventBus.room_cleared.emit(room)


func _on_cage_opened(p: Prop) -> void:
	var id := cage_echo
	cage_echo = ""
	var info: Dictionary = ECHOES[id]
	state.echoes.append(id)
	SaveManager.set_flag("echo_" + id)
	SaveManager.data["echoes"] = int(SaveManager.data.get("echoes", 0)) + 1
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
	_show_banner(info.name.to_upper() + " IS FREE", 2.0, Color(0.8, 0.92, 1.0), 16)
	await get_tree().create_timer(2.4).timeout
	if state.ended:
		return
	_show_banner("\"" + info.line + "\"", 4.0, Color(0.85, 0.85, 0.95), 8)
	room.open_doors()
	Audio.play("door", 0.05, -4.0)


func _on_enemy_died(enemy: Node) -> void:
	state.kills += 1
	if enemy is Enemy:
		Codex.discover("enemy", Codex.enemy_id(enemy))
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
		SaveManager.data["echoes"] = int(SaveManager.data.get("echoes", 0)) + 1
		_give_shards(3, boss.global_position + Vector2(0, -20))
	SaveManager.set_flag("ebb_broken")
	state.echoes.append("maren")
	var p := room.add_prop(Prop.Kind.ECHO_GHOST, room.world_to_cell(boss.global_position))
	p.show_echo("maren")
	FX.flash_screen(Color(0.8, 0.9, 1.0, 0.6), 0.8)
	Audio.play("rescue")
	_show_banner("\"" + ECHOES.maren.line + "\"", 3.0, Color(0.85, 0.85, 0.95), 8)


func _on_door_entered(door: Door) -> void:
	if _transitioning or state.ended or not room_cleared:
		return
	_transitioning = true
	state.depth += 1
	state.depth_total += 1
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
	_show_banner(m.name.to_upper(), 1.4, Tidemarks.color_of(id), 14)
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
	FX.burst(player.global_position, Color(0.5, 0.8, 0.95), 14, 60.0)


func _on_chest(p: Prop) -> void:
	for i in 3 + int(player.mods.chest_bonus):
		Pickup.spawn(content, p.global_position + Vector2(0, 8), Pickup.Kind.PEARL)
	for i in 10:
		Pickup.spawn(content, p.global_position + Vector2(0, 8), Pickup.Kind.SALT)


func _on_pickup(kind: int, value: int) -> void:
	if kind == Pickup.Kind.SALT:
		state.salt += value
		EventBus.salt_changed.emit(state.salt)
		if player.mods.salt_mend:
			_mend_salt += value
			while _mend_salt >= 10:
				_mend_salt -= 10
				player.health.heal(1)
	elif kind == Pickup.Kind.KEY:
		state.keys += value
		EventBus.keys_changed.emit(state.keys)
	else:
		state.pearls += value
		EventBus.pearls_changed.emit(state.pearls)


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
	SaveManager.data["suspended"] = snapshot()
	SaveManager.save_profile()
	state.ended = true
	Audio.stop_music()
	return true


## Pick a rested night up: same seed, graph, tidemarks, health, salt and room, doors open.
func _resume(d: Dictionary) -> void:
	resumed = true
	state.from_dict(d)
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
	_place_doors(type, state.depth + 1)
	if type == RoomGraph.SHOP:
		shop.restock()
	for pd in props:
		var cell: Array = pd.get("cell", [0, 0])
		_add_room_prop(int(pd.get("kind", 0)) as Prop.Kind, Vector2i(int(cell[0]), int(cell[1])))
	room_cleared = true
	room.open_doors()
	_show_room_label(biome().name, "%d / %d   %s%s" % [state.depth + 1, biome().length + 1, RoomGraph.NAMES[type],
		"   spring tide %d" % state.tier if state.tier > 0 else ""])
	_show_banner("THE NIGHT GOES ON", 2.4, Color(0.8, 0.9, 1.0), 12)
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
	# Let the last drops get collected before the ledger is written.
	await get_tree().create_timer(1.2).timeout
	var result := state.result()
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
