class_name RoomTemplate
extends RefCounted
## Parsed ASCII room (see tools/gen_rooms.py for the legend). Pure data, testable.

const WALL_HEIGHT := 99

var name: String = ""
var width: int = 0
var height: int = 0
var rows: PackedStringArray = []
var player_spawn: Vector2i = Vector2i(-1, -1)
var enemy_spawns: Array[Vector2i] = []
var doors: Array[Vector2i] = []
var markers: Dictionary = {}  # char -> Array[Vector2i]


static func parse(text: String, p_name: String = "") -> RoomTemplate:
	var t := RoomTemplate.new()
	t.name = p_name
	for line in text.split("\n"):
		if line.strip_edges() == "":
			continue
		t.rows.append(line.strip_edges(false, true))
	t.height = t.rows.size()
	t.width = t.rows[0].length() if t.height > 0 else 0
	for y in t.height:
		for x in t.width:
			var ch := t.rows[y][x]
			var cell := Vector2i(x, y)
			match ch:
				"P": t.player_spawn = cell
				"e": t.enemy_spawns.append(cell)
				"D": t.doors.append(cell)
				"F", "T", "X", "h", "M", "A", "O", "E", "B", "W", "C", "N", "K", "S", "I", "L", "V", "Y", "l", "d":
					if not t.markers.has(ch):
						t.markers[ch] = []
					t.markers[ch].append(cell)
	return t


static func load_file(path: String) -> RoomTemplate:
	var text := FileAccess.get_file_as_string(path)
	return parse(text, path.get_file().get_basename())


func char_at(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= width or y >= height:
		return "#"
	return rows[y][x]


## Flood height of a cell. Walls are WALL_HEIGHT (never flood).
func height_at(x: int, y: int) -> int:
	match char_at(x, y):
		"#": return WALL_HEIGHT
		"_", "X": return 0
		"=", "h": return 2
		_: return 1


func is_solid(x: int, y: int) -> bool:
	var ch := char_at(x, y)
	return ch == "#" or ch == "o" or ch == "h"


## Ground tile index for a cell (door cells return DOOR; caller swaps when opened).
func tile_at(x: int, y: int, theme: int = Tiles.Look.FLATS) -> int:
	var ch := char_at(x, y)
	var v := (x * 7 + y * 13) % 5 == 0  # cheap variation
	# A wall shows its face when there is floor to its south, its top otherwise (art Stage 09).
	var face := y + 1 < height and not (char_at(x, y + 1) in ["#", "o"])
	if theme == Tiles.Look.HUB:
		match ch:
			"#": return Tiles.HUB_WALL if face else Tiles.HUB_WALL2
			"_", "X": return Tiles.HUB_LOW
			"=", "h": return Tiles.HUB_RAISED
			"o": return Tiles.ROCK
			"D": return Tiles.DOOR
			_: return Tiles.HUB_SAND2 if v else Tiles.HUB_SAND
	if theme == Tiles.Look.HARBOUR:
		match ch:
			"#": return Tiles.HULL if face else Tiles.HULL2
			"_", "X": return Tiles.SILT
			"=", "h": return Tiles.QUAY
			"o": return Tiles.ROCK
			"D": return Tiles.DOOR
			_: return Tiles.DECK2 if v else Tiles.DECK
	if theme == Tiles.Look.DEEP:
		match ch:
			"#": return Tiles.HALLWALL if face else Tiles.HALLWALL2
			"_", "X": return Tiles.CHANNEL
			"=", "h": return Tiles.DAIS
			"o": return Tiles.ROCK
			"D": return Tiles.DOOR
			_: return Tiles.BASALT2 if v else Tiles.BASALT
	if theme == Tiles.Look.STREETS:
		match ch:
			"#": return Tiles.RUIN if face else Tiles.RUIN2
			"_", "X": return Tiles.MOSS
			"=", "h": return Tiles.FLAG
			"o": return Tiles.ROCK
			"D": return Tiles.DOOR
			_: return Tiles.COBBLE2 if v else Tiles.COBBLE
	match ch:
		"#": return Tiles.WALL if face else Tiles.WALL2
		"_", "X": return Tiles.LOW
		"=", "h": return Tiles.RAISED
		"o": return Tiles.ROCK
		"D": return Tiles.DOOR
		_: return Tiles.SAND2 if v else Tiles.SAND


func marker_cells(ch: String) -> Array:
	return markers.get(ch, [])


## Open cells you can walk to from the player's spawn. Doors and marker cells (props)
## are not floor.
func reachable_cells() -> Dictionary:
	var seen := {}
	if player_spawn.x < 0:
		return seen
	var stack: Array = [player_spawn]
	seen[player_spawn] = true
	while stack.size() > 0:
		var c: Vector2i = stack.pop_back()
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + off
			if seen.has(n) or is_solid(n.x, n.y) or char_at(n.x, n.y) == "D":
				continue
			seen[n] = true
			stack.append(n)
	for ch in markers:
		for cell in markers[ch]:
			seen.erase(cell)
	return seen


## One cell per body: the `e` markers first (shuffled with `rng`), then the open floor
## around them, at least two tiles from any body already placed and three from the
## player. Two bodies spawned on one point jam each other, and the physics recovery
## can walk the pair straight through a wall and out of the room.
func spawn_cells(count: int, rng: RandomNumberGenerator = null) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if enemy_spawns.is_empty():
		return out
	var bases: Array[Vector2i] = enemy_spawns.duplicate()
	if rng != null:
		for i in range(bases.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp := bases[i]
			bases[i] = bases[j]
			bases[j] = tmp
	var open := reachable_cells()
	for i in count:
		out.append(_free_cell_near(bases[i % bases.size()], out, open))
	return out


func _free_cell_near(base: Vector2i, taken: Array[Vector2i], open: Dictionary) -> Vector2i:
	for gap: int in [2, 1]:
		for r in 6:
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) != r:
						continue
					var c := base + Vector2i(dx, dy)
					if not (open.has(c) or (r == 0 and not is_solid(c.x, c.y))):
						continue
					if r > 0 and maxi(absi(c.x - player_spawn.x), absi(c.y - player_spawn.y)) < 3:
						continue
					var clear := true
					for t in taken:
						if maxi(absi(c.x - t.x), absi(c.y - t.y)) < gap:
							clear = false
							break
					if clear:
						return c
	return base
