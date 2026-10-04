extends Node2D
## Dev aid (map Stage 01): renders every room template through the real Room builder with
## the run's night tint and low ground flooded, one PNG per room, then quits. A room larger
## than the screen is framed whole at 1/2x or 1/4x (map Stage 02).
## A test room takes the look its name says (map Stage 06). --only=<text> renders the rooms whose
## path holds it; --full renders each whole at 1x, the camera stepped across it and the frames
## stitched.
##   godot --path . src/dev/room_sheet.tscn -- --out=<dir> [--tide=0.6] [--only=sample] [--full]

const DIRS := {"biome1": Tiles.Look.FLATS, "harbour": Tiles.Look.HARBOUR,
	"biome2": Tiles.Look.STREETS, "biome3": Tiles.Look.DEEP, "test": Tiles.Look.FLATS}
const TEST_LOOKS := {"streets": Tiles.Look.STREETS, "harbour": Tiles.Look.HARBOUR, "hall": Tiles.Look.DEEP}
const VIEW := Vector2(640, 368)


func _ready() -> void:
	var out := ProjectSettings.globalize_path("res://.shots/rooms")
	var tide := 0.6
	var only := ""
	var full := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--tide="):
			tide = float(a.trim_prefix("--tide="))
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		elif a == "--full":
			full = true
	DirAccess.make_dir_recursive_absolute(out)
	Atmosphere.build(self, Vector2(640, 368), Palette.NIGHT_TINT_RUN)
	var n := 0
	for dir: String in DIRS:
		var files: Array = []
		for f in DirAccess.get_files_at("res://data/rooms/" + dir):
			if f.ends_with(".txt") and (dir + "/" + f).contains(only):
				files.append(f)
		files.sort()
		for f: String in files:
			var room := Room.new()
			add_child(room)
			move_child(room, 0)
			var look: int = DIRS[dir]
			if dir == "test":
				for k: String in TEST_LOOKS:
					if f.contains(k):
						look = TEST_LOOKS[k]
			room.build(RoomTemplate.load_file("res://data/rooms/%s/%s" % [dir, f]), 7, look)
			room.set_tide(tide)
			var cam: Camera2D = $Camera
			if full:
				await _full(room, cam, "%s/%s__%s_full.png" % [out, dir, f.get_basename()])
				room.queue_free()
				await get_tree().process_frame
				n += 1
				continue
			var z := 1.0
			while room.size_px().x * z > 640.5 or room.size_px().y * z > 368.5:
				z *= 0.5
			cam.zoom = Vector2(z, z)
			cam.position = room.size_px() * 0.5
			for i in 12:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/%s__%s.png" % [out, dir, f.get_basename()])
			room.queue_free()
			await get_tree().process_frame
			n += 1
	print("room_sheet: %d rooms -> %s" % [n, out])
	get_tree().quit()


## The whole room at 1x: the camera steps a screen at a time and each frame is pasted in.
func _full(room: Room, cam: Camera2D, path: String) -> void:
	var size := Vector2i(room.size_px())
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	cam.zoom = Vector2.ONE
	var x := 0
	while x < size.x:
		var y := 0
		while y < size.y:
			var at := Vector2i(mini(x, size.x - int(VIEW.x)), mini(y, size.y - int(VIEW.y)))
			cam.position = Vector2(at) + VIEW * 0.5
			for i in 12:
				await get_tree().process_frame
			var frame := get_viewport().get_texture().get_image()
			frame.convert(Image.FORMAT_RGBA8)
			# The window may draw the view scaled up; the sheet is at 1x.
			if frame.get_size() != Vector2i(VIEW):
				frame.resize(int(VIEW.x), int(VIEW.y), Image.INTERPOLATE_NEAREST)
			img.blit_rect(frame, Rect2i(Vector2i.ZERO, Vector2i(VIEW)), at)
			y += int(VIEW.y)
		x += int(VIEW.x)
	img.save_png(path)
