extends Node2D
## M0 test room: a bordered floor with the player in it. Replaced by the real
## room system in M2; kept as a sandbox for feel tuning.

const ROOM := Rect2(0, 0, 640, 360)
const WALL := 16.0

@onready var player: Player = $Player
@onready var debug_label: Label = $HUD/Debug


func _ready() -> void:
	_build_walls()
	player.global_position = ROOM.get_center()
	_handle_screenshot_arg()


## Dev aid: run with `-- --screenshot` to save .shots/latest.png after a few frames and quit.
func _handle_screenshot_arg() -> void:
	if not "--screenshot" in OS.get_cmdline_user_args():
		return
	for i in 5:
		await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(dir + "/latest.png")
	print("screenshot -> %s/latest.png (%s)" % [dir, error_string(err)])
	get_tree().quit()


func _process(_delta: float) -> void:
	debug_label.text = "EBB %s   pos %s   dash %d/%d   fps %d" % [
		Game.VERSION,
		player.global_position.round(),
		player.dash_charges, Player.DASH_CHARGES,
		Engine.get_frames_per_second(),
	]


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	add_child(walls)
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
		var visual := ColorRect.new()
		visual.position = r.position
		visual.size = r.size
		visual.color = Color(0.27, 0.24, 0.20)
		walls.add_child(visual)
