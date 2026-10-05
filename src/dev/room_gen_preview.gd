extends Node2D
## Dev aid (map Stage 08): what RoomGen makes from a seed.
##   godot --path . src/dev/room_gen_preview.tscn -- --look=flats --seed=1 --count=12 [--out=<dir>]
## renders the rooms through the real Room builder (night tint, tide 0.6) into a contact sheet,
## four across, each named with its seed, size and attempts: <out>/gen_<look>_<seed>.png.
## --shape=<corridor|ell|ring|split|flooded|any> makes every room that shape (map Stage 10).
##   godot --headless --path . src/dev/room_gen_preview.tscn -- --check=50 [--look=all]
## generates seeds 1..N per look and prints, per look, how many pass the validator, how many
## passed on the first attempt, the first attempts' failures by reason, and the time per room.

const LOOKS := {"flats": Tiles.Look.FLATS, "harbour": Tiles.Look.HARBOUR, "streets": Tiles.Look.STREETS,
	"hall": Tiles.Look.DEEP, "reef": Tiles.Look.REEF}
const VIEW := Vector2(640, 368)
const CELL := Vector2i(320, 184)


func _ready() -> void:
	var out := ProjectSettings.globalize_path("res://.shots/gen")
	var look := "flats"
	var seed_from := 1
	var count := 12
	var check := 0
	var shape := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--look="):
			look = a.trim_prefix("--look=")
		elif a.begins_with("--seed="):
			seed_from = int(a.trim_prefix("--seed="))
		elif a.begins_with("--count="):
			count = int(a.trim_prefix("--count="))
		elif a.begins_with("--check="):
			check = int(a.trim_prefix("--check="))
		elif a.begins_with("--shape="):
			shape = a.trim_prefix("--shape=")
	var looks: Array = LOOKS.keys() if look == "all" else [look]
	if check > 0:
		for l: String in looks:
			_check(l, check, shape)
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(out)
	Atmosphere.build(self, VIEW, Palette.NIGHT_TINT_RUN)
	for l: String in looks:
		await _sheet(l, seed_from, count, "%s/gen_%s%s_%d.png" % [out, l, "_" + shape if shape != "" else "", seed_from], shape)
	get_tree().quit()


func _check(look: String, n: int, shape: String = "") -> void:
	var lk: int = LOOKS[look]
	var passed := 0
	var first := 0
	var attempts := 0
	var reasons: Dictionary = {}
	var t0 := Time.get_ticks_msec()
	for s in range(1, n + 1):
		var t := RoomGen.generate(lk, s, "combat", Vector2i.ZERO, "", shape)
		attempts += RoomGen.last_attempts
		if RoomGen.validate(t, lk).is_empty():
			passed += 1
		var t1 := RoomTemplate.parse(RoomGen.build(lk, hash([s, 0, lk]), "combat", Vector2i.ZERO, RoomGen.pick_shape(s) if shape == "any" else shape).text(), "first")
		var bad := RoomGen.validate(t1, lk)
		if bad.is_empty():
			first += 1
		for b in bad:
			var key := b.split(" ")[0] if b.begins_with("door") or b.begins_with("spawn") else b.rstrip("0123456789. ")
			reasons[key] = int(reasons.get(key, 0)) + 1
	var ms := float(Time.get_ticks_msec() - t0) / n
	print("room_gen %s%s: %d/%d pass, %d first try, %.2f attempts a room, %.0f ms a room (with the first-try check)" % [look, " " + shape if shape != "" else "", passed, n, first, float(attempts) / n, ms])
	if not reasons.is_empty():
		print("  first-try failures: %s" % reasons)


func _sheet(look: String, from: int, count: int, path: String, shape: String = "") -> void:
	var lk: int = LOOKS[look]
	var cols := 4
	var rows := (count + cols - 1) / cols
	var sheet := Image.create(CELL.x * cols, (CELL.y + 12) * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Palette.INK)
	var cam: Camera2D = $Camera
	for i in count:
		var s := from + i
		var t := RoomGen.generate(lk, s, "combat", Vector2i.ZERO, "", shape)
		var tries := RoomGen.last_attempts
		var room := Room.new()
		add_child(room)
		move_child(room, 0)
		room.build(t, s, lk)
		room.set_tide(0.6)
		var z := 1.0
		while room.size_px().x * z > VIEW.x + 0.5 or room.size_px().y * z > VIEW.y + 0.5:
			z *= 0.5
		cam.zoom = Vector2(z, z)
		cam.position = room.size_px() * 0.5
		for k in 12:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		var at := Vector2i((i % cols) * CELL.x, (i / cols) * (CELL.y + 12) + 12)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), at)
		var ok := RoomGen.validate(t, lk).is_empty()
		print("%s seed %d: %dx%d, %d attempt(s), %d pieces, %s" % [look, s, t.width, t.height, tries, t.pieces.size(), "ok" if ok else str(RoomGen.validate(t, lk))])
		room.queue_free()
		await get_tree().process_frame
	sheet.save_png(path)
	print("room_gen_preview -> %s" % path)
