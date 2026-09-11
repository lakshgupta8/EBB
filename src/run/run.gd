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

const BIOMES := [
	{"name": "THE FLATS", "dir": "res://data/rooms/biome1/", "length": 8, "theme": Tiles.Look.FLATS,
		"boss": WRECK, "boss_name": "THE WRECK", "stir": "THE WRECK STIRS", "echoes": ["bram"],
		"intro": "The tide has gone out. Saltmere waits."},
	{"name": "THE DROWNED STREETS", "dir": "res://data/rooms/biome2/", "length": 9, "theme": Tiles.Look.STREETS,
		"boss": BELL, "boss_name": "THE BELL OF SALTMERE", "stir": "THE BELL CRACKS", "echoes": ["wren", "cartographer"],
		"intro": "Slack water. The streets of Saltmere, and something still ringing."},
]
## The people you can bring back, and what they say when the cage opens.
const ECHOES := {
	"bram": {"name": "Bram the Drowned", "line": "A smith. Still a smith. Get me to a fire, keeper, and I will make you something that bites."},
	"wren": {"name": "Sister Wren", "line": "The tide is not cruel. It is only patient. Find me by the tower; I remember prayers that still work."},
	"cartographer": {"name": "The Cartographer", "line": "I mapped every street before the water came. Streets do not move. The water does."},
}
const NIGHT_TINT := [Color(0.6, 0.68, 0.86), Color(0.56, 0.6, 0.8)]
const SLACK_WATER := 0.25  # tide level after a boss falls

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


func biome() -> Dictionary:
	return BIOMES[state.biome]


func _ready() -> void:
	state.seed = Game.run_seed if Game.run_seed != 0 else randi()
	_rng.seed = state.seed
	hud.bind(self)
	shop.setup(self)
	altar_ui.chosen.connect(_on_tidemark_chosen)
	Ledger.apply(player, self)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_died.connect(_on_player_died)
	EventBus.pickup_collected.connect(_on_pickup)
	EventBus.run_started.emit(state.seed)
	fade.color.a = 1.0
	Atmosphere.build(self, Vector2(640, 368))
	Audio.ambient("ambient_sea", -14.0)
	Audio.gulls_enabled = true
	# Dev / playtest aids: `-- --biome=1` starts in the streets, `--boss` at its boss.
	var start_biome := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--biome="):
			start_biome = clampi(int(a.trim_prefix("--biome=")), 0, BIOMES.size() - 1)
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


func _apply_water(delta: float) -> void:
	if player.dead:
		return
	var h := room.height_at(player.global_position)
	player.in_water = state.tide.is_flooded(h)
	if state.tide.is_deep(h):
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
	graph = RoomGraph.new(state.seed + index * 7919, b.length, echo_depths, int(SaveManager.data.get("charted_room", -1)))
	_load_templates(b.dir)
	var night := get_node_or_null("Night") as CanvasModulate
	if night:
		night.color = NIGHT_TINT[mini(index, NIGHT_TINT.size() - 1)]
	Audio.gulls_enabled = index == 0
	if at_boss:
		state.depth = b.length
		_enter_room(RoomGraph.BOSS)
		return
	_enter_room(RoomGraph.COMBAT)
	_show_banner(b.intro, 3.0, Color(0.8, 0.9, 1.0), 12)


## Past a boss: the tide slackens, the next biome begins.
func _next_biome() -> void:
	state.tide.level = SLACK_WATER
	_start_biome(state.biome + 1)


# --- rooms -----------------------------------------------------------------------
func _load_templates(dir: String) -> void:
	_templates = {RoomGraph.COMBAT: [], RoomGraph.ELITE: [], RoomGraph.FOUNTAIN: [], RoomGraph.TREASURE: [],
		RoomGraph.BOSS: [], RoomGraph.SHOP: [], RoomGraph.ALTAR: [], RoomGraph.ECHO: []}
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


func _enter_room(type: int) -> void:
	room_type = type
	room_cleared = false
	boss = null
	cage = null
	for c in content.get_children():
		c.queue_free()
	if room:
		room.queue_free()
	room = Room.new()
	room_holder.add_child(room)
	room.build(_pick_template(type), _rng.randi(), biome().theme)
	player.global_position = room.cell_to_world(room.template.player_spawn)
	player.velocity = Vector2.ZERO
	state.tide.room_entered()
	room.set_tide(state.tide.level)

	var next_depth := state.depth + 1
	if type == RoomGraph.BOSS:
		# The way down opens when the boss is dead; the last biome has no way down.
		room.place_doors([Door.DESCEND] if state.biome + 1 < BIOMES.size() else [])
	else:
		room.place_doors(graph.options_for(next_depth))
	for d in room.doors:
		d.entered.connect(_on_door_entered)

	match type:
		RoomGraph.COMBAT:
			_spawn_enemies(2 + state.depth / 2 + state.biome, false)
		RoomGraph.ELITE:
			_spawn_enemies(1 + state.depth / 3 + state.biome, true)
		RoomGraph.FOUNTAIN:
			for cell in room.template.marker_cells("F"):
				room.add_prop(Prop.Kind.FOUNTAIN, cell).used.connect(_on_fountain)
			_set_cleared()
		RoomGraph.TREASURE:
			for cell in room.template.marker_cells("T"):
				room.add_prop(Prop.Kind.CHEST, cell).used.connect(_on_chest)
			_set_cleared()
		RoomGraph.ALTAR:
			for cell in room.template.marker_cells("A"):
				room.add_prop(Prop.Kind.ALTAR, cell).used.connect(func(_p):
					altar_ui.open(Tidemarks.roll(_rng, state.tidemarks, 3, str(SaveManager.data.get("blessed_family", "")))))
			_set_cleared()
		RoomGraph.SHOP:
			shop.restock()
			for cell in room.template.marker_cells("M"):
				room.add_prop(Prop.Kind.MERCHANT, cell).used.connect(func(_p): shop.open())
			_set_cleared()
		RoomGraph.ECHO:
			_spawn_echo_room()
		RoomGraph.BOSS:
			_spawn_boss()
			_show_banner(biome().boss_name, 2.2, Color(0.95, 0.75, 0.6), 20)
			EventBus.request_shake.emit(0.6)
			Audio.play("roar" if state.biome == 0 else "bell")

	_show_room_label(biome().name, "%d / %d   %s" % [state.depth + 1, biome().length + 1, RoomGraph.NAMES[type]])
	EventBus.room_entered.emit(room)
	var fade_tw := create_tween()
	fade_tw.tween_property(fade, "color:a", 0.0, 0.25)
	fade_tw.tween_callback(func(): _transitioning = false)


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
	if state.biome == 0:
		if state.depth < 2:
			return SHELLBACK if r < 0.6 else GULL
		return SHELLBACK if r < 0.4 else (GULL if r < 0.7 else CRAB)
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
		var e: Enemy = _spawn(_enemy_scene(), room.cell_to_world(cell))
		if with_elite and i == 0:
			e.make_elite()


func _spawn_echo_room() -> void:
	cage_echo = _echo_queue.pop_front() if _echo_queue.size() > 0 else ""
	_spawn_enemies(2 + state.depth / 2 + state.biome, false)
	for cell in room.template.marker_cells("E"):
		cage = room.add_prop(Prop.Kind.CAGE, cell)
		cage.used.connect(_on_cage_opened)
	if cage_echo != "":
		_show_banner("SOMEONE IS STILL HERE", 2.0, Color(0.75, 0.9, 1.0), 12)


func _spawn_boss() -> void:
	var spawns: Array = room.template.enemy_spawns
	boss = _spawn(biome().boss, room.cell_to_world(spawns[0]))
	boss.phase_changed.connect(func(_p):
		_show_banner(biome().stir, 1.6, Color(0.95, 0.5, 0.45), 16)
		Audio.play("roar" if state.biome == 0 else "bell", 0.0, 2.0)
		state.tide.level = minf(TideSystem.MAX_LEVEL, state.tide.level + 0.35)
	)
	hud.set_boss(boss)
	# The square's statues: dormant until the bell cracks.
	if state.biome == 1:
		for i in range(1, spawns.size()):
			var c: Enemy = _spawn(CITIZEN, room.cell_to_world(spawns[i]))
			c.dormant = true
			c.salt_drop = 1


func _show_banner(text: String, duration: float, color: Color, size: int = 14) -> void:
	banner.text = text
	banner.add_theme_font_size_override("font_size", size)
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
	return e


func _set_cleared() -> void:
	if room_cleared:
		return
	room_cleared = true
	state.rooms_cleared += 1
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
		var pos: Vector2 = enemy.global_position
		for i in int(round(enemy.salt_drop * player.mods.salt_mult)):
			Pickup.spawn(content, pos, Pickup.Kind.SALT)
		for i in enemy.pearl_drop:
			Pickup.spawn(content, pos, Pickup.Kind.PEARL)
		if enemy == boss:
			_on_boss_died()
			return
	await get_tree().process_frame
	if state.ended:
		return
	if get_tree().get_nodes_in_group("enemies").is_empty():
		_set_cleared()


func _on_boss_died() -> void:
	# The boss's summons die with it.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e != boss and is_instance_valid(e):
			e.health.take(DamageInfo.make(9999, null, Vector2.ZERO, 0.0), true)
	if state.biome + 1 >= BIOMES.size():
		_win()
		return
	await get_tree().process_frame
	if state.ended:
		return
	_set_cleared()


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
		tw.tween_callback(_enter_room.bind(door.room_type))


func _on_tidemark_chosen(id: String) -> void:
	state.tidemarks.append(id)
	Tidemarks.apply(id, player, self)
	var m := Tidemarks.get_mark(id)
	FX.ring(player.global_position, Tidemarks.color_of(id), 1.6)
	FX.burst(player.global_position, Tidemarks.color_of(id), 16, 70.0)
	_show_banner(m.name.to_upper(), 1.4, Tidemarks.color_of(id), 14)
	Audio.play("altar")


func _on_fountain(_p: Prop) -> void:
	player.health.heal(35)
	FX.burst(player.global_position, Color(0.5, 0.8, 0.95), 14, 60.0)


func _on_chest(p: Prop) -> void:
	for i in 3:
		Pickup.spawn(content, p.global_position + Vector2(0, 8), Pickup.Kind.PEARL)
	for i in 10:
		Pickup.spawn(content, p.global_position + Vector2(0, 8), Pickup.Kind.SALT)


func _on_pickup(kind: int, value: int) -> void:
	if kind == Pickup.Kind.SALT:
		state.salt += value
		EventBus.salt_changed.emit(state.salt)
	else:
		state.pearls += value
		EventBus.pearls_changed.emit(state.pearls)


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
	_end_run()


## From the pause menu: abandon the run (counts as taken by the deep, salt lost).
func give_up() -> void:
	if state.ended:
		return
	player.dead = true
	_end_run()


func _end_run() -> void:
	state.ended = true
	# Let the last drops get collected before the ledger is written.
	await get_tree().create_timer(1.2).timeout
	var result := state.result()
	Game.run_finished(result)
	results.show_result(result)


## Dev aid: run with `-- --screenshot` to save .shots/latest.png after a few frames and quit.
func _handle_screenshot_arg() -> void:
	if not "--screenshot" in OS.get_cmdline_user_args():
		return
	for i in 40:
		await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	print("screenshot -> %s/latest.png (%s)" % [dir, error_string(img.save_png(dir + "/latest.png"))])
	get_tree().quit()
