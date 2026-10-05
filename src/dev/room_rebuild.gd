extends Node
## Dev aid (map Stage 09): rebuilds the hand-made fighting and reward rooms with RoomGen.
##   godot --headless --path . src/dev/room_rebuild.tscn -- [--only=<text>] [--new] [--tries=10] [--dry]
## --new makes only the rooms whose file is missing (map Stage 10's new shapes); the rooms left
## alone still count as chosen, so a new room is measured against them.
## For every room in TARGETS it makes `tries` candidates from seeds of its own (each one passing
## the validator), keeps the one least like the rooms already chosen in its biome (by feature
## cells, as tools/map_audit.py measures "near"), writes it over data/rooms/<dir>/<file>.txt as
## an ordinary template, and records file, look, kind, size and seed in docs/ROOM_REBUILD.csv,
## so the set can be made again exactly with the generator of the commit that made it (docs/ has a .gdignore: Godot would import a CSV there as
## a translation table). Signature rooms (shop, altar, fountain, echo, boss, the
## hub) are map Stage 12's and are left alone.

const BIOMES := [
	["biome1", Tiles.Look.FLATS, "flats", 12],
	["harbour", Tiles.Look.HARBOUR, "harbour", 10],
	["biome2", Tiles.Look.STREETS, "streets", 10],
	["biome3", Tiles.Look.DEEP, "hall", 10],
]
const CSV := "res://docs/ROOM_REBUILD.csv"


## [dir, file, look, kind, size, shape] for every room this stage rebuilds. Fights are mixed in
## size: two one-screen rooms a biome (the smallest fights), a third medium, the rest large.
## Map Stage 10 adds one fighting room of each shape a biome, numbered on from the open ones.
static func targets() -> Array:
	var out: Array = []
	for b in BIOMES:
		var n: int = b[3]
		for i in n:
			var size := RoomGen.SIZE_L
			if i < 2:
				size = RoomGen.SIZE_S
			elif i < 2 + n / 3:
				size = RoomGen.SIZE_M
			out.append([b[0], "%s_%02d" % [b[2], i + 1], b[1], "combat", size, ""])
		for i in RoomGen.SHAPES.size():
			out.append([b[0], "%s_%02d" % [b[2], n + 1 + i], b[1], "combat", Vector2i.ZERO, RoomGen.SHAPES[i]])
		out.append([b[0], "challenge_01", b[1], "challenge", RoomGen.SIZE_M, ""])
		out.append([b[0], "dive_01", b[1], "dive", RoomGen.SIZE_M, ""])
		out.append([b[0], "treasure_01", b[1], "treasure", RoomGen.SIZE_M, ""])
		out.append([b[0], "vault_01", b[1], "vault", RoomGen.SIZE_S, ""])
	return out


func _ready() -> void:
	var only := ""
	var tries := 10
	var dry := false
	var only_new := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		elif a.begins_with("--tries="):
			tries = int(a.trim_prefix("--tries="))
		elif a == "--dry":
			dry = true
		elif a == "--new":
			only_new = true
	var rows := _read_csv()
	var chosen: Dictionary = {}  # dir -> Array of feature sets
	var todo: Array = []
	for tg in targets():
		var dir: String = tg[0]
		var path := "res://data/rooms/%s/%s.txt" % [dir, tg[1]]
		if (only != "" and not (dir + "/" + str(tg[1])).contains(only)) or (only_new and FileAccess.file_exists(path)):
			# Left alone: it is one of the chosen all the same.
			if FileAccess.file_exists(path):
				if not chosen.has(dir):
					chosen[dir] = []
				chosen[dir].append(_features(RoomTemplate.load_file(path)))
			continue
		todo.append(tg)
	for tg in todo:
		var dir: String = tg[0]
		var file: String = tg[1]
		var look: int = tg[2]
		var kind: String = tg[3]
		var size: Vector2i = tg[4]
		var shape: String = tg[5]
		var base := hash([dir, file]) % 100000
		var best: RoomTemplate = null
		var best_seed := 0
		var best_near := 2.0
		var best_attempts := 0
		# Ten tries; a tight plan (a vault in a one-screen Hall) may take up to four times that.
		for k in tries * 4:
			if k >= tries and best != null:
				break
			var s := base + k
			var t := RoomGen.generate(look, s, kind, size, file, shape)
			if not RoomGen.validate(t, look, kind).is_empty():
				continue
			var f := _features(t)
			var near := 0.0
			for o in chosen.get(dir, []):
				near = maxf(near, _jaccard(f, o))
			if near < best_near:
				best_near = near
				best = t
				best_seed = s
				best_attempts = RoomGen.last_attempts
		if best == null:
			push_error("room_rebuild: no valid %s/%s in %d tries" % [dir, file, tries])
			continue
		if not chosen.has(dir):
			chosen[dir] = []
		chosen[dir].append(_features(best))
		var text := "\n".join(best.rows) + "\n"
		for d in best.directives:
			text += d + "\n"
		if not dry:
			var fa := FileAccess.open("res://data/rooms/%s/%s.txt" % [dir, file], FileAccess.WRITE)
			fa.store_string(text)
			fa.close()
		rows[dir + "/" + file] = "%s/%s,%s,%s,%dx%d,%s,%d,%d,%.2f" % [dir, file, RoomGen.LOOK_NAME[look], kind,
			best.width, best.height, shape, best_seed, best_attempts, best_near]
		print("room_rebuild: %s/%s %s %s %dx%d seed %d, nearest %.2f" % [dir, file, kind, shape, best.width, best.height,
			best_seed, best_near])
	if not dry:
		var lines := PackedStringArray([HEADER])
		for tg in targets():
			var key := str(tg[0]) + "/" + str(tg[1])
			if rows.has(key):
				lines.append(rows[key])
		var fa := FileAccess.open(CSV, FileAccess.WRITE)
		fa.store_string("\n".join(lines) + "\n")
		fa.close()
	get_tree().quit()


const HEADER := "file,look,kind,size,shape,seed,attempts,nearest"


## The manifest as it stands, by file; Stage 09's rows (no shape column) are read as open plans.
static func _read_csv() -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(CSV):
		return out
	for line in FileAccess.get_file_as_string(CSV).split("\n"):
		var f := line.strip_edges().split(",")
		if f.size() < 7 or f[0] == "file":
			continue
		if f.size() == 7:
			f.insert(4, "")
		out[f[0]] = ",".join(f)
	return out


## The plan's feature cells inside the rim, as map_audit.py counts them (water, raised, solid
## blocks standing in the room; pieces as rock). Wall joined to the room's edge is the rim.
static func _features(t: RoomTemplate) -> Dictionary:
	var rim: Dictionary = {}
	var stack: Array[Vector2i] = []
	for x in t.width:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, t.height - 1))
	for y in t.height:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(t.width - 1, y))
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if rim.has(c) or c.x < 0 or c.y < 0 or c.x >= t.width or c.y >= t.height or t.char_at(c.x, c.y) != "#":
			continue
		rim[c] = true
		stack.append_array([c + Vector2i(1, 0), c - Vector2i(1, 0), c + Vector2i(0, 1), c - Vector2i(0, 1)])
	var out: Dictionary = {}
	for y in t.height:
		for x in t.width:
			if rim.has(Vector2i(x, y)):
				continue
			var ch := t.char_at(x, y)
			if t.piece_cells.has(Vector2i(x, y)):
				ch = "o"
			if ch in ["#", "o", "_", "="]:
				out[Vector3i(x, y, ch.unicode_at(0))] = true
	return out


static func _jaccard(a: Dictionary, b: Dictionary) -> float:
	var inter := 0
	for k in a:
		if b.has(k):
			inter += 1
	var union := a.size() + b.size() - inter
	return float(inter) / maxf(1.0, union)
