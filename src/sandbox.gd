extends Node2D
## Feel sandbox: a bordered room with waves of enemies. R restarts. Replaced by the
## real room system in M2 but kept around as the tuning arena.

const ROOM := Rect2(0, 0, 640, 360)
const WALL := 16.0
const SHELLBACK := preload("res://src/enemies/shellback.tscn")
const GULL := preload("res://src/enemies/gull.tscn")

@onready var player: Player = $Player
@onready var debug_label: Label = $HUD/Debug
@onready var banner: Label = $HUD/Banner
@onready var enemies_root: Node2D = $Enemies

var _wave: int = 0


func _ready() -> void:
	_build_walls()
	player.global_position = ROOM.get_center()
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_died.connect(_on_player_died)
	banner.visible = false
	_spawn_wave()
	_handle_screenshot_arg()


func _process(_delta: float) -> void:
	debug_label.text = "EBB %s   wave %d   enemies %d   fps %d   [R] restart" % [
		Game.VERSION, _wave, enemies_root.get_child_count(), Engine.get_frames_per_second(),
	]
	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()


func _spawn_wave() -> void:
	_wave += 1
	var count_shell := 1 + _wave / 2
	var count_gull := _wave
	for i in count_shell:
		_spawn(SHELLBACK, _spawn_point())
	for i in count_gull:
		_spawn(GULL, _spawn_point())


func _spawn_point() -> Vector2:
	# Somewhere away from the player.
	for attempt in 20:
		var p := Vector2(randf_range(40, ROOM.size.x - 40), randf_range(40, ROOM.size.y - 40))
		if p.distance_to(player.global_position) > 120.0:
			return p
	return Vector2(60, 60)


func _spawn(scene: PackedScene, at: Vector2) -> void:
	var e := scene.instantiate()
	e.global_position = at
	enemies_root.add_child(e)


func _on_enemy_died(_enemy: Node) -> void:
	# Deferred so the freed enemy is gone from the count.
	await get_tree().process_frame
	if enemies_root.get_child_count() == 0 and not player.dead:
		await get_tree().create_timer(1.0).timeout
		if not player.dead:
			_spawn_wave()


func _on_player_died() -> void:
	banner.text = "TAKEN\n[R] to try again"
	banner.visible = true


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	add_child(walls)
	var tiles: Texture2D = preload("res://assets/sprites/tiles.png")
	var rects := [
		Rect2(ROOM.position, Vector2(ROOM.size.x, WALL)),
		Rect2(ROOM.position + Vector2(0, ROOM.size.y - WALL), Vector2(ROOM.size.x, WALL)),
		Rect2(ROOM.position, Vector2(WALL, ROOM.size.y)),
		Rect2(ROOM.position + Vector2(ROOM.size.x - WALL, 0), Vector2(WALL, ROOM.size.y)),
	]
	for r in rects:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		walls.add_child(shape)
		var visual := TextureRect.new()
		visual.texture = _atlas(tiles, 2)
		visual.stretch_mode = TextureRect.STRETCH_TILE
		visual.position = r.position
		visual.size = r.size
		walls.add_child(visual)


func _atlas(tex: Texture2D, index: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(index * 16, 0, 16, 16)
	return at


## Dev aid: run with `-- --screenshot` to save .shots/latest.png after a few frames and quit.
func _handle_screenshot_arg() -> void:
	if not "--screenshot" in OS.get_cmdline_user_args():
		return
	for i in 30:
		await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(dir + "/latest.png")
	print("screenshot -> %s/latest.png (%s)" % [dir, error_string(err)])
	get_tree().quit()
