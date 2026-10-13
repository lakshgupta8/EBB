extends Node
## What a large room costs to make (map Stage 13b): build, the terrain, the water at a high tide,
## and RoomGen, in milliseconds, over the 80x46 rooms of every biome. Headless:
##   godot --headless --path . tests/bench_rooms.tscn [-- --tide=2.0 --reps=3 --hash]
## `--hash` prints a fingerprint of every layer of every room (the same before and after a change).

const DIRS := {0: "biome1", 1: "harbour", 2: "biome2", 3: "biome3", 4: "reef"}


func _ready() -> void:
	var tide := 2.0
	var reps := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tide="): tide = float(a.trim_prefix("--tide="))
		elif a.begins_with("--reps="): reps = int(a.trim_prefix("--reps="))
	if "--hash" in OS.get_cmdline_user_args():
		_hash_all()
		get_tree().quit(0)
		return
	var sums := {"build": 0.0, "terrain": 0.0, "water": 0.0, "gen": 0.0}
	var n := 0
	for b in DIRS:
		var look: int = Run.BIOMES[b].theme
		var dir := "res://data/rooms/%s/" % DIRS[b]
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".txt"):
				continue
			var t := RoomTemplate.load_file(dir + f)
			if t == null or t.width < 80 or t.height < 45:
				continue
			for r in reps:
				var room := Room.new()
				add_child(room)
				var t0 := Time.get_ticks_usec()
				room.build(t, 1234 + r, look)
				var t1 := Time.get_ticks_usec()
				room._paint_terrain()
				var t2 := Time.get_ticks_usec()
				room._tide_level = tide
				room._refresh_water()
				var t3 := Time.get_ticks_usec()
				sums.build += (t1 - t0) / 1000.0
				sums.terrain += (t2 - t1) / 1000.0
				sums.water += (t3 - t2) / 1000.0
				n += 1
				room.free()
		for r in reps:
			var t0 := Time.get_ticks_usec()
			var g := RoomGen.generate(look, 777 + r * 31 + b, "combat", Vector2i.ZERO, "", "any")
			RoomGen.validate(g, look)
			sums.gen += (Time.get_ticks_usec() - t0) / 1000.0
	print("bench: %d builds of 80x46 rooms, tide %.1f: build %.1f  terrain %.1f  water %.1f ms each;  RoomGen %.1f ms each (%d)" % [
		n, tide, sums.build / n, sums.terrain / n, sums.water / n, sums.gen / (reps * DIRS.size()), reps * DIRS.size()])
	get_tree().quit(0)


## Every room of every size, at four tides: one line each.
func _hash_all() -> void:
	for b in DIRS:
		var look: int = Run.BIOMES[b].theme
		var dir := "res://data/rooms/%s/" % DIRS[b]
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".txt"):
				continue
			var t := RoomTemplate.load_file(dir + f)
			if t == null:
				continue
			var room := Room.new()
			add_child(room)
			room.build(t, 1234, look)
			var line := "hash: %s/%s" % [DIRS[b], f]
			for tide in [0.6, 1.3, 2.0, 2.9]:
				room.set_tide(tide)
				line += " | " + _fingerprint(room)
			print(line)
			room.free()


## Every tile on every layer the room draws (each layer's packed tile data, hashed natively), and
## what the water was made from, so a faster build can be shown to draw the same.
static func _fingerprint(room: Room) -> String:
	var parts: Array = []
	for layer in room._terrain + room._patch_layers + [room._water, room._deep, room._ground]:
		parts.append("%08x" % (hash(layer.tile_map_data) & 0xffffffff))
	return " ".join(parts) + " fl%d dp%d %08x %08x" % [room._flooded.size(), room._deep_cells.size(),
		str(room._body).hash() & 0xffffffff, str(room._foam_case).hash() & 0xffffffff]
