class_name SetPieces
extends RefCounted
## The set pieces (map Stage 05, STYLE.md 22): large drawn things a room is built round, from
## tools/gen_set_pieces.py (set_pieces.png and data/set_pieces.json). A template places one with
## a line `@ <id> <x> <y>` (the footprint's top-left cell). The footprint's '#' cells are solid,
## its '=' cells lay a deck (raised ground: a pier, a bridge, steps) and its '_' cells water (a
## tide pool inside its rim) into the plan, and '.' leaves the ground as it is (map Stage 05,
## second batch);
## the sprite sits on the footprint's south edge, and room.gd splits it there so what rises
## above draws over anyone standing behind it.

const TEXTURE := preload("res://assets/sprites/set_pieces.png")
const DATA := "res://data/set_pieces.json"

static var _table: Dictionary = {}


static func table() -> Dictionary:
	if _table.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if parsed is Dictionary:
			_table = parsed
	return _table


static func has(id: String) -> bool:
	return table().has(id)


static func info(id: String) -> Dictionary:
	return table().get(id, {})


## The solid cells of a piece placed with its footprint's top-left at `at`.
static func footprint(id: String, at: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rows: Array = info(id).get("foot", [])
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				out.append(at + Vector2i(x, y))
	return out


## The ground a piece lays under itself: cell -> plan char ('=' a deck, '_' water).
static func ground(id: String, at: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	var rows: Array = info(id).get("foot", [])
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "=" or row[x] == "_":
				out[at + Vector2i(x, y)] = row[x]
	return out


## The piece's footprint size in cells.
static func size(id: String) -> Vector2i:
	var rows: Array = info(id).get("foot", [])
	return Vector2i(str(rows[0]).length() if rows.size() > 0 else 0, rows.size())


## World light (map Stage 07, STYLE.md 11 and 22): the lights a template's pieces carry, by
## colour key ("WARM", "FLAME", "COLD"). Candle drifts are the Hall's own and are counted apart.
static func lights(t: RoomTemplate) -> Dictionary:
	var out := {"WARM": 0, "FLAME": 0, "COLD": 0, "candles": 0}
	for p in t.pieces:
		var l: Dictionary = info(str(p.id)).get("light", {})
		if l.is_empty():
			continue
		if str(p.id) == "candles":
			out.candles += 1
		else:
			out[str(l.color)] += 1
	return out
