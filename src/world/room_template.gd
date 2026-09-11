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
				"F", "T", "X", "h":
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
func tile_at(x: int, y: int) -> int:
	var ch := char_at(x, y)
	var v := (x * 7 + y * 13) % 5 == 0  # cheap variation
	match ch:
		"#": return Tiles.WALL2 if v else Tiles.WALL
		"_", "X": return Tiles.LOW
		"=", "h": return Tiles.RAISED
		"o": return Tiles.ROCK
		"D": return Tiles.DOOR
		_: return Tiles.SAND2 if v else Tiles.SAND


func marker_cells(ch: String) -> Array:
	return markers.get(ch, [])
