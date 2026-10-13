extends Node2D
## The room editor, behind a dev flag. It draws a real room from a template file, paints
## the ASCII underneath it, rebuilds as you paint, and writes the file back.
##
##   tools\edit_room.ps1 [-Room data/rooms/biome1/flats_01.txt]
##   godot --path . src/dev/room_editor.tscn -- --room=data/rooms/biome1/flats_01.txt
##
## Mouse paints the chosen brush (right button paints floor). 1-9 and 0 pick a brush,
## Tab and Shift+Tab step the whole palette, [ and ] step through the biome's files.
## S saves (it refuses a room you cannot walk around), L reloads, G shows the grid, T steps the tide,
## Esc quits. A room larger than the screen (map Stage 02) opens framed whole; the arrow
## keys or the middle button pan, the wheel or Z zooms between 1x and the whole room. Writing goes to the real file through the project folder, so this is for
## a build run from source, which is what a dev flag means here.
## The hub (data/rooms/hub.txt) opens with its own look and legend and is checked as the rock
## (map Stage 13c). The title says which tool made the file: most rooms are written by a
## generator, and a hand edit lasts only until that generator runs again.

const DEFAULT_ROOM := "data/rooms/biome1/flats_01.txt"
const CELL := Tiles.SIZE
## The legend, as gen_rooms writes it. Order is the palette order.
const BRUSHES := [
	{"ch": ".", "name": "floor"},
	{"ch": "#", "name": "wall"},
	{"ch": "o", "name": "rock"},
	{"ch": "_", "name": "low ground (floods first)"},
	{"ch": "=", "name": "raised (floods last)"},
	{"ch": "h", "name": "high solid"},
	{"ch": "D", "name": "door"},
	{"ch": "P", "name": "the keeper"},
	{"ch": "e", "name": "a body"},
	{"ch": "T", "name": "chest"},
	{"ch": "F", "name": "fountain"},
	{"ch": "A", "name": "altar"},
	{"ch": "M", "name": "merchant"},
	{"ch": "E", "name": "cage"},
]
## The hub's legend (map Stage 12g): the way down, the tower, the lantern posts, the dock, and a
## place for each person on the rock (the letters src/hub/hub.gd reads).
const HUB_PEOPLE := {"O": "Orla", "K": "Fen", "B": "Bram", "W": "Wren", "C": "the Cartographer", "N": "Maren",
	"S": "Nessa", "I": "Idris", "L": "Aldous", "V": "Pell", "Y": "the Choir", "G": "Hale"}
const HUB_BRUSHES := [
	{"ch": ".", "name": "floor"},
	{"ch": "#", "name": "wall"},
	{"ch": "o", "name": "rock"},
	{"ch": "_", "name": "low ground (floods first)"},
	{"ch": "=", "name": "raised (floods last)"},
	{"ch": "P", "name": "the keeper"},
	{"ch": "X", "name": "the way down"},
	{"ch": "h", "name": "the lighthouse (2x2)"},
	{"ch": "l", "name": "a lantern post"},
	{"ch": "d", "name": "the dock"},
	{"ch": "O", "name": "Orla"}, {"ch": "K", "name": "Fen"}, {"ch": "B", "name": "Bram"}, {"ch": "W", "name": "Wren"},
	{"ch": "C", "name": "the Cartographer"}, {"ch": "N", "name": "Maren"}, {"ch": "S", "name": "Nessa"},
	{"ch": "I", "name": "Idris"}, {"ch": "L", "name": "Aldous"}, {"ch": "V", "name": "Pell"}, {"ch": "Y", "name": "the Choir"},
	{"ch": "G", "name": "Hale"},
]
## The rooms tools/gen_signature_rooms.py writes (map Stage 12); the rest of a biome's rooms are
## RoomGen's, recorded in docs/ROOM_REBUILD.csv by src/dev/room_rebuild.gd (map Stage 09).
const SIGNATURE := ["shop_01", "altar_01", "fountain_01", "echo_01", "echo_02", "boss_01", "hub"]
const THEME_BY_DIR := {"biome1": Tiles.Look.FLATS, "harbour": Tiles.Look.HARBOUR,
	"biome2": Tiles.Look.STREETS, "biome3": Tiles.Look.DEEP, "reef": Tiles.Look.REEF}

var path: String = DEFAULT_ROOM
var rows: PackedStringArray = []
var directives: PackedStringArray = []  # `@` lines (set pieces, map Stage 05), kept as written
var brush: int = 0
var dirty: bool = false
var show_grid: bool = true
var _room: Room
var _files: Array = []
var _file_at: int = 0
var _status: Label
var _palette: Label
var _title: Label
var _source: Label
var _grid: GridOverlay
var _painting: int = 0  # mouse button held, or 0
var _panning: bool = false
var _framed: Vector2i = Vector2i.ZERO  # the room size the view was last framed for
var _made_by: String = ""  # which tool wrote this file, if one did
## T steps the water shown: dry, the low ground wet, the low ground deep and the floor wet, the
## floor deep, the raised ground under (the levels the tide crosses in a night and at a boss).
const TIDES := [0.0, 0.6, 1.3, 2.0, 2.9]
var _tide_at: int = 0
@onready var _cam: Camera2D = $Camera


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="):
			path = a.trim_prefix("--room=")
	_scan_dir()
	_load()
	_build_ui()
	_rebuild()
	_handle_screenshot_arg()


## Dev aid: `-- --screenshot` saves .shots/room_editor.png and quits; `--keys=T,T,Z` presses
## those keys first, through the same handler a hand on the keyboard uses.
func _handle_screenshot_arg() -> void:
	if not "--screenshot" in OS.get_cmdline_user_args():
		return
	for i in 20:
		await get_tree().process_frame
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--keys="):
			for k in a.trim_prefix("--keys=").split(","):
				var ev := InputEventKey.new()
				ev.keycode = OS.find_keycode_from_string(k)
				ev.pressed = true
				_key(ev)
				await get_tree().process_frame
	for i in 5:
		await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	print("screenshot -> %s/room_editor.png (%s)" % [dir, error_string(img.save_png(dir + "/room_editor.png"))])
	get_tree().quit()


# --- files ---------------------------------------------------------------------------
func _dir() -> String:
	return path.get_base_dir()


func _is_hub() -> bool:
	return path.get_file() == "hub.txt"


func _brushes() -> Array:
	return HUB_BRUSHES if _is_hub() else BRUSHES


func _look() -> int:
	return Tiles.Look.HUB if _is_hub() else int(THEME_BY_DIR.get(_dir().get_file(), Tiles.Look.FLATS))


## Which tool wrote the file: a hand edit here lasts until that tool runs again.
func _provenance() -> String:
	var name := path.get_file().get_basename()
	if name in SIGNATURE:
		return "made by tools/gen_signature_rooms.py (%s): edit its plan there to keep a change" % \
			("hub" if name == "hub" else _dir().get_file() + "/" + name)
	var key := _dir().get_file() + "/" + name + ","
	for line in FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://docs/ROOM_REBUILD.csv")).split("\n"):
		if line.begins_with(key):
			return "made by RoomGen, seed %s (docs/ROOM_REBUILD.csv): room_rebuild would make it again" % line.split(",")[5]
	return ""


func _scan_dir() -> void:
	_files = []
	for f in DirAccess.get_files_at("res://" + _dir()):
		if f.ends_with(".txt"):
			_files.append(_dir() + "/" + f)
	_files.sort()
	_file_at = maxi(0, _files.find(path))


func _load() -> void:
	var text := FileAccess.get_file_as_string("res://" + path)
	rows = PackedStringArray()
	directives = PackedStringArray()
	for line in text.split("\n"):
		if line.strip_edges() == "":
			continue
		if line.begins_with("@") or line.begins_with("~"):
			directives.append(line.strip_edges())
			continue
		rows.append(line.strip_edges(false, true))
	dirty = false
	brush = mini(brush, _brushes().size() - 1)
	_made_by = _provenance()


## Write the file back through the project folder. Refuses a room the keeper cannot walk
## around, because a template like that black-holes a night.
func _save() -> void:
	var problem := _check()
	if problem != "":
		_say("not saved: " + problem, false)
		return
	var f := FileAccess.open(ProjectSettings.globalize_path("res://" + path), FileAccess.WRITE)
	if f == null:
		_say("cannot write %s (error %d)" % [path, FileAccess.get_open_error()], false)
		return
	f.store_string("\n".join(rows + directives) + "\n")
	f = null
	dirty = false
	_say("saved %s" % path, true)


## The same things the tests insist on: one keeper, somewhere to fight from, doors that
## touch the floor, and no walled-off ground.
func _check() -> String:
	var t := _template()
	if t.player_spawn.x < 0:
		return "no P: the keeper has nowhere to stand"
	if _is_hub():
		return _check_hub(t)
	if t.doors.is_empty():
		return "no D: there is no way out"
	# Every room the run offers leads two ways on; a boss's arena has a door per road (map Stage 12g).
	if t.doors.size() < 2 and not path.get_file().begins_with("boss"):
		return "one D: a room needs two ways on"
	var seen := t.reachable_cells()
	for d in t.doors:
		var touching := false
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if seen.has(d + off):
				touching = true
		if not touching:
			return "the door at %d,%d has no floor beside it" % [d.x, d.y]
	var walled := 0
	for y in t.height:
		for x in t.width:
			var c := Vector2i(x, y)
			if t.is_solid(x, y) or t.char_at(x, y) == "D" or seen.has(c):
				continue
			var is_marker := false
			for ch in t.markers:
				if c in t.markers[ch]:
					is_marker = true
			if not is_marker:
				walled += 1
	if walled > 0:
		return "%d cells you cannot walk to" % walled
	return _check_kind(t)


## What each kind of room must hold, as tests/test_run.gd has it (map Stage 13c: the editor had
## asked every room for a spawn, and so would not save an altar, a fountain or a shop).
func _check_kind(t: RoomTemplate) -> String:
	if t.width < 40 or t.width > 80 or t.height < 23 or t.height > 46:
		return "%dx%d: a room is 40x23 to 80x46" % [t.width, t.height]
	var f := path.get_file()
	for kind in ["flats", "harbour", "reef", "streets", "hall", "boss", "echo"]:
		if f.begins_with(kind) and t.enemy_spawns.is_empty():
			return "no e: nothing can be spawned here"
	if f.begins_with("echo") and t.marker_cells("E").size() != 1:
		return "%d E: an echo room holds one cage" % t.marker_cells("E").size()
	if f.begins_with("challenge") and (t.enemy_spawns.size() < 4 or t.marker_cells("T").is_empty()):
		return "a challenge wants four e and a T"
	if f.begins_with("vault") and t.marker_cells("T").size() != 1:
		return "%d T: a vault holds one" % t.marker_cells("T").size()
	if f.begins_with("dive") and (t.marker_cells("A").size() != 1 or t.marker_cells("T").size() != 1):
		return "a dive holds one A and one T"
	if f.begins_with("boss"):
		var roads := 1
		for b in Run.BIOMES:
			if str(b.dir).get_base_dir().get_file() == _dir().get_file():
				roads = maxi(1, (b.next as Array).size())
		if t.doors.size() != roads:
			return "%d D: this arena wants a way down for each road (%d)" % [t.doors.size(), roads]
	return ""


## The rock, as tests/test_run.gd and the hub's own plan check it: one way down, the tower, one
## place for each person, the dock, four lantern posts or more, and all of it reachable on foot.
func _check_hub(t: RoomTemplate) -> String:
	if t.marker_cells("X").size() != 1:
		return "%d X: the rock needs one way down" % t.marker_cells("X").size()
	if t.marker_cells("h").is_empty():
		return "no h: there is no lighthouse"
	for ch in HUB_PEOPLE:
		if t.marker_cells(ch).size() != 1:
			return "%d %s: %s needs one place" % [t.marker_cells(ch).size(), ch, HUB_PEOPLE[ch]]
	if t.marker_cells("d").is_empty():
		return "no d: there is no dock"
	if t.marker_cells("l").size() < 4:
		return "%d l: the path wants four lantern posts or more" % t.marker_cells("l").size()
	var seen := t.reachable_cells()
	for ch in HUB_PEOPLE.keys() + ["X", "d", "l"]:
		for c: Vector2i in t.marker_cells(ch):
			var near := false
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				near = near or seen.has(c + off)
			if not near or t.is_solid(c.x, c.y):
				return "%s at %d,%d cannot be walked to" % [ch, c.x, c.y]
	return ""


func _template() -> RoomTemplate:
	return RoomTemplate.parse("\n".join(rows + directives), path.get_file().get_basename())


# --- painting ------------------------------------------------------------------------
func _set_cell(cell: Vector2i, ch: String) -> void:
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= rows[cell.y].length():
		return
	if rows[cell.y][cell.x] == ch:
		return
	# One keeper only: painting a new P lifts the old one.
	if ch == "P":
		for y in rows.size():
			var at := rows[y].find("P")
			if at >= 0:
				rows[y] = rows[y].substr(0, at) + "." + rows[y].substr(at + 1)
	var row := rows[cell.y]
	rows[cell.y] = row.substr(0, cell.x) + ch + row.substr(cell.x + 1)
	dirty = true
	_rebuild()


func _cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / CELL)), int(floor(pos.y / CELL)))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_to(_cam.zoom.x * (2.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.5))
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_painting = event.button_index if event.pressed else 0
			if event.pressed:
				_paint(get_global_mouse_position(), event.button_index)
	elif event is InputEventMouseMotion and _panning:
		_cam.position -= event.relative / _cam.zoom
	elif event is InputEventMouseMotion and _painting != 0:
		_paint(get_global_mouse_position(), _painting)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)


func _paint(at: Vector2, button: int) -> void:
	_set_cell(_cell_at(at), "." if button == MOUSE_BUTTON_RIGHT else str(_brushes()[brush].ch))


func _key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_S:
			_save()
		KEY_L:
			_load()
			_rebuild()
			_say("reloaded from disk", true)
		KEY_G:
			show_grid = not show_grid
			_grid.visible = show_grid
		KEY_Z:
			# The whole room, or 1x where the cursor is.
			var fit := _fit_zoom()
			if is_equal_approx(_cam.zoom.x, fit) and fit < 1.0:
				_cam.position = get_global_mouse_position()
				_zoom_to(1.0)
			else:
				_cam.position = _room.size_px() * 0.5
				_zoom_to(fit)
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			var step := {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}
			_cam.position += step[event.keycode] * CELL * 8.0 / _cam.zoom.x
		KEY_T:
			# The water at the next tide: the ground floods by its height (map Stage 03).
			_tide_at = wrapi(_tide_at + (-1 if event.shift_pressed else 1), 0, TIDES.size())
			_room.set_tide(TIDES[_tide_at])
			_refresh()
		KEY_TAB:
			brush = wrapi(brush + (-1 if event.shift_pressed else 1), 0, _brushes().size())
			_refresh()
		KEY_BRACKETLEFT:
			_step_file(-1)
		KEY_BRACKETRIGHT:
			_step_file(1)
		_:
			var i := UI.menu_index(event)
			if i >= 0 and i < _brushes().size():
				brush = i
				_refresh()
			elif event.keycode == KEY_0 and _brushes().size() > 9:
				brush = 9
				_refresh()


func _step_file(d: int) -> void:
	if _files.is_empty():
		return
	if dirty:
		_say("unsaved changes: S to save, L to throw them away", false)
		return
	_file_at = wrapi(_file_at + d, 0, _files.size())
	path = str(_files[_file_at])
	_load()
	_rebuild()
	_say("%s  (%d of %d)" % [path.get_file(), _file_at + 1, _files.size()], true)


# --- the view ------------------------------------------------------------------------
func _rebuild() -> void:
	if _room:
		_room.queue_free()
	_room = Room.new()
	add_child(_room)
	move_child(_room, 0)
	_room.build(_template(), 7, _look())
	_room.set_tide(TIDES[_tide_at])
	var size := Vector2i(_room.template.width, _room.template.height)
	if size != _framed:
		# A new room, or a resized one: show it whole, centred.
		_framed = size
		_cam.position = _room.size_px() * 0.5
		_zoom_to(_fit_zoom())
	if _grid:
		_grid.queue_redraw()
	_refresh()


## The largest of 1x, 1/2x, 1/4x that shows the whole room above the bar.
func _fit_zoom() -> float:
	var room := _room.size_px()
	var view := Vector2(640, 316)
	var z := 1.0
	while z > 0.25 and (room.x * z > view.x + 0.5 or room.y * z > view.y + 16.5):
		z *= 0.5
	return z


func _zoom_to(z: float) -> void:
	z = clampf(z, 0.25, 1.0)
	_cam.zoom = Vector2(z, z)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_grid = GridOverlay.new()
	_grid.editor = self
	add_child(_grid)
	_grid.z_index = 50
	var bar := ColorRect.new()
	bar.color = Color(0.04, 0.03, 0.08, 0.75)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -44
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bar)
	_source = UI.label("", 8, Color(0.95, 0.75, 0.5))
	_source.position = Vector2(4, 318)
	_source.size = Vector2(632, 10)
	layer.add_child(_source)
	_title = UI.label("", 8, Color(0.95, 0.9, 0.75))
	_title.position = Vector2(4, 328)
	_title.size = Vector2(632, 10)
	layer.add_child(_title)
	_palette = UI.label("", 8, Color(0.8, 0.85, 0.95))
	_palette.position = Vector2(4, 338)
	_palette.size = Vector2(632, 10)
	layer.add_child(_palette)
	_status = UI.label("paint: mouse  clear: right  [S] save  [L] reload  [Tab] brush  [ ] file  [G] grid  [T] tide  [Z] zoom  arrows pan  [Esc] quit", 8, Color(0.6, 0.7, 0.8))
	_status.position = Vector2(4, 348)
	_status.size = Vector2(632, 10)
	layer.add_child(_status)


func _refresh() -> void:
	var problem := _check()
	_title.text = "%s%s   %d x %d   tide %.1f   %s" % [path.get_file(), "  *" if dirty else "", rows[0].length() if rows.size() > 0 else 0,
		rows.size(), TIDES[_tide_at], "ok" if problem == "" else problem]
	_title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75) if problem == "" else Color(1.0, 0.6, 0.55))
	_source.text = _made_by
	var parts: Array = []
	var list := _brushes()
	for i in list.size():
		var b: Dictionary = list[i]
		var key := str(i + 1) if i < 9 else ("0" if i == 9 else "")
		parts.append("%s%s%s%s" % ["[" if i == brush else " ", key, b.ch, "]" if i == brush else " "])
	_palette.text = "".join(parts) + "  brush: " + str(list[brush].name)


func _say(text: String, good: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color(0.75, 0.95, 0.8) if good else Color(1.0, 0.6, 0.55))
	_refresh()


## The cell grid, the keeper's spawn, the doors and the bodies, drawn over the room.
class GridOverlay extends Node2D:
	var editor: Node2D

	func _draw() -> void:
		if editor == null or editor.rows.is_empty():
			return
		var w: int = editor.rows[0].length()
		var h: int = editor.rows.size()
		if editor.show_grid:
			for x in w + 1:
				draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, h * CELL), Color(1, 1, 1, 0.06))
			for y in h + 1:
				draw_line(Vector2(0, y * CELL), Vector2(w * CELL, y * CELL), Color(1, 1, 1, 0.06))
		for y in h:
			for x in editor.rows[y].length():
				var ch: String = editor.rows[y][x]
				var col := Color(0, 0, 0, 0)
				match ch:
					"P": col = Color(0.95, 0.85, 0.5, 0.9)
					"e": col = Color(0.9, 0.4, 0.4, 0.8)
					"D": col = Color(0.5, 0.8, 1.0, 0.8)
					"E": col = Color(0.7, 0.9, 1.0, 0.8)
					"T", "F", "A", "M": col = Color(0.6, 1.0, 0.7, 0.8)
					"X", "d": col = Color(0.5, 0.8, 1.0, 0.8)
					"l": col = Color(1.0, 0.8, 0.45, 0.8)
					_:
						if editor.call("_is_hub") and HUB_PEOPLE.has(ch):
							col = Color(0.95, 0.75, 0.95, 0.85)
				if col.a > 0.0:
					var r := Rect2(x * CELL + 3, y * CELL + 3, CELL - 6, CELL - 6)
					draw_rect(r, Color(col, 0.25))
					draw_rect(r, col, false, 1.0)
					draw_string(UI.FONT, Vector2(x * CELL + 5, y * CELL + 12), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
