class_name RoomChunks
extends RefCounted
## Map Stage 08: hand-authored chunks, the small composed places RoomGen stamps into a room where
## its floor runs bare (data/chunks/<look>/*.txt). A chunk is a block of plan rows in the room
## legend, with '?' for "leave the ground as it is", and `@ id x y` lines for set pieces at
## chunk-relative cells. Header lines start with ';':
##   ; mirror        the chunk may be stamped flipped left to right
## A chunk is stamped only where every cell it writes is bare floor nothing else owns.

const DIR := "res://data/chunks/"
const DIRS := {Tiles.Look.FLATS: "flats", Tiles.Look.HARBOUR: "harbour", Tiles.Look.STREETS: "streets",
	Tiles.Look.DEEP: "hall"}

static var _cache: Dictionary = {}


static func for_look(look: int) -> Array:
	if _cache.has(look):
		return _cache[look]
	var out: Array = []
	var dir: String = DIR + str(DIRS.get(look, "flats")) + "/"
	if DirAccess.dir_exists_absolute(dir):
		var files := Array(DirAccess.get_files_at(dir))
		files.sort()
		for f: String in files:
			if f.ends_with(".txt"):
				out.append(parse(FileAccess.get_file_as_string(dir + f), f.get_basename()))
	_cache[look] = out
	return out


static func parse(text: String, p_name: String = "") -> Dictionary:
	var rows := PackedStringArray()
	var pieces: Array = []
	var mirror := false
	for line in text.split("\n"):
		var l := line.strip_edges(false, true)
		if l.strip_edges() == "":
			continue
		if l.begins_with(";"):
			mirror = mirror or l.contains("mirror")
		elif l.begins_with("@"):
			var p := l.substr(1).strip_edges().split(" ", false)
			if p.size() == 3 and SetPieces.has(p[0]):
				pieces.append([p[0], int(p[1]), int(p[2])])
			else:
				push_warning("chunk %s: bad line '%s'" % [p_name, l])
		else:
			rows.append(l)
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	for i in rows.size():
		rows[i] = rows[i].rpad(w, "?")
	return {"name": p_name, "rows": rows, "pieces": pieces, "mirror": mirror}


## Every cell the chunk writes lands on bare floor nothing owns, inside the rim.
static func fits(g: RoomGen.Grid, ch: Dictionary, at: Vector2i) -> bool:
	var rows: PackedStringArray = ch.rows
	if rows.is_empty() or at.x < 3 or at.y < 3 or at.x + rows[0].length() > g.w - 3 or at.y + rows.size() > g.h - 3:
		return false
	for j in rows.size():
		for i in rows[j].length():
			if rows[j][i] == "?":
				continue
			var cell := at + Vector2i(i, j)
			if g.at(cell.x, cell.y) != RoomGen.C_FLOOR or g.taken.has(cell) or g.solid.has(cell):
				return false
	return true


static func stamp(g: RoomGen.Grid, ch: Dictionary, at: Vector2i, flip: bool = false) -> void:
	var rows: PackedStringArray = ch.rows
	var w := rows[0].length()
	for j in rows.size():
		for i in w:
			var s := rows[j][w - 1 - i] if flip else rows[j][i]
			if s == "?":
				continue
			g.set_at(at.x + i, at.y + j, s.unicode_at(0))
	for p in ch.pieces:
		var pw := SetPieces.size(str(p[0])).x
		var x: int = (w - int(p[1]) - pw) if flip else int(p[1])
		var cell := at + Vector2i(x, int(p[2]))
		# The chunk is bare floor under its pieces, so a piece that no longer fits is only
		# one that would stand on the chunk's own water or rock: leave it out.
		if g.fits(str(p[0]), cell.x, cell.y, "any"):
			g.place(str(p[0]), cell.x, cell.y)
	for j in range(-1, rows.size() + 1):
		for i in range(-1, w + 1):
			g.taken[at + Vector2i(i, j)] = true
