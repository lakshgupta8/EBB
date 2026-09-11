class_name Run
extends Node2D
## One descent. Builds rooms from the graph, spawns content, drives the tide, ends the
## run on death / taken / boss kill, and shows results.

const SHELLBACK := preload("res://src/enemies/shellback.tscn")
const GULL := preload("res://src/enemies/gull.tscn")
const CRAB := preload("res://src/enemies/wrack_crab.tscn")
const WRECK := preload("res://src/enemies/wreck.tscn")
const ROOM_DIR := "res://data/rooms/biome1/"
const BIOME_LENGTH := 8

var state := RunState.new()
var graph: RoomGraph
var room: Room
var room_type: int = RoomGraph.COMBAT
var room_cleared: bool = false
var boss: Enemy

var _rng := RandomNumberGenerator.new()
var _templates: Dictionary = {}  # type -> Array[RoomTemplate]
var _deep_tick: float = 0.0
var _transitioning: bool = false

@onready var player: Player = $Player
@onready var room_holder: Node2D = $RoomHolder
@onready var content: Node2D = $Content
@onready var hud: Control = $HUD/Bars
@onready var fade: ColorRect = $HUD/Fade
@onready var results: CanvasLayer = $Results
@onready var room_label: Label = $HUD/RoomLabel
@onready var banner: Label = $HUD/Banner


func _ready() -> void:
	state.seed = Game.run_seed if Game.run_seed != 0 else randi()
	_rng.seed = state.seed
	graph = RoomGraph.new(state.seed, BIOME_LENGTH)
	_load_templates()
	hud.bind(self)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_died.connect(_on_player_died)
	EventBus.pickup_collected.connect(_on_pickup)
	EventBus.run_started.emit(state.seed)
	fade.color.a = 1.0
	_enter_room(RoomGraph.COMBAT)
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


# --- rooms -----------------------------------------------------------------------
func _load_templates() -> void:
	_templates = {RoomGraph.COMBAT: [], RoomGraph.ELITE: [], RoomGraph.FOUNTAIN: [],
		RoomGraph.TREASURE: [], RoomGraph.BOSS: []}
	for f in DirAccess.get_files_at(ROOM_DIR):
		if not f.ends_with(".txt"):
			continue
		var t := RoomTemplate.load_file(ROOM_DIR + f)
		if f.begins_with("fountain"):
			_templates[RoomGraph.FOUNTAIN].append(t)
		elif f.begins_with("treasure"):
			_templates[RoomGraph.TREASURE].append(t)
		elif f.begins_with("boss"):
			_templates[RoomGraph.BOSS].append(t)
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
	for c in content.get_children():
		c.queue_free()
	if room:
		room.queue_free()
	room = Room.new()
	room_holder.add_child(room)
	room.build(_pick_template(type), _rng.randi())
	player.global_position = room.cell_to_world(room.template.player_spawn)
	player.velocity = Vector2.ZERO
	state.tide.room_entered()
	room.set_tide(state.tide.level)

	var next_depth := state.depth + 1
	room.place_doors(graph.options_for(next_depth))
	for d in room.doors:
		d.entered.connect(_on_door_entered)

	match type:
		RoomGraph.COMBAT:
			_spawn_enemies(2 + state.depth / 2, false)
		RoomGraph.ELITE:
			_spawn_enemies(1 + state.depth / 3, true)
		RoomGraph.FOUNTAIN:
			for cell in room.template.marker_cells("F"):
				room.add_prop(Prop.Kind.FOUNTAIN, cell).used.connect(_on_fountain)
			_set_cleared()
		RoomGraph.TREASURE:
			for cell in room.template.marker_cells("T"):
				room.add_prop(Prop.Kind.CHEST, cell).used.connect(_on_chest)
			_set_cleared()
		RoomGraph.BOSS:
			_spawn_boss()
			_show_banner("THE WRECK", 2.2, Color(0.95, 0.75, 0.6), 20)
			EventBus.request_shake.emit(0.6)

	room_label.text = "The Flats  %d / %d   %s" % [state.depth + 1, BIOME_LENGTH + 1, RoomGraph.NAMES[type]]
	EventBus.room_entered.emit(room)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.25)
	tw.tween_callback(func(): _transitioning = false)


func _spawn_enemies(count: int, with_elite: bool) -> void:
	var spawns: Array = room.template.enemy_spawns.duplicate()
	spawns.shuffle()
	for i in count:
		var cell: Vector2i = spawns[i % spawns.size()]
		var r := _rng.randf()
		var scene: PackedScene
		if state.depth < 2:
			scene = SHELLBACK if r < 0.6 else GULL
		else:
			scene = SHELLBACK if r < 0.4 else (GULL if r < 0.7 else CRAB)
		var e: Enemy = _spawn(scene, room.cell_to_world(cell))
		if with_elite and i == 0:
			e.make_elite()


func _spawn_boss() -> void:
	var cell: Vector2i = room.template.enemy_spawns[0]
	boss = _spawn(WRECK, room.cell_to_world(cell))
	boss.phase_changed.connect(func(_p):
		_show_banner("THE WRECK STIRS", 1.6, Color(0.95, 0.5, 0.45), 16)
		state.tide.level = minf(TideSystem.MAX_LEVEL, state.tide.level + 0.35)
	)
	hud.set_boss(boss)


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
	room.open_doors()
	if room_type == RoomGraph.COMBAT or room_type == RoomGraph.ELITE:
		_show_banner("THE WAY OPENS", 1.2, Color(0.7, 0.9, 1.0), 12)
	EventBus.room_cleared.emit(room)


func _on_enemy_died(enemy: Node) -> void:
	state.kills += 1
	if enemy is Enemy:
		var pos: Vector2 = enemy.global_position
		for i in enemy.salt_drop:
			Pickup.spawn(content, pos, Pickup.Kind.SALT)
		for i in enemy.pearl_drop:
			Pickup.spawn(content, pos, Pickup.Kind.PEARL)
		if enemy == boss:
			_win()
			return
	await get_tree().process_frame
	if state.ended:
		return
	if get_tree().get_nodes_in_group("enemies").is_empty():
		_set_cleared()


func _on_door_entered(door: Door) -> void:
	if _transitioning or state.ended or not room_cleared:
		return
	_transitioning = true
	state.depth += 1
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.2)
	tw.tween_callback(_enter_room.bind(door.room_type))


func _on_fountain(_p: Prop) -> void:
	player.health.heal(35)
	FX.burst(player.global_position, Color(0.5, 0.8, 0.95), 14, 60.0)


func _on_chest(p: Prop) -> void:
	for i in 3:
		Pickup.spawn(content, p.global_position + Vector2(0, 8), Pickup.Kind.PEARL)
	for i in 6:
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
