extends Node2D
## The room editor, behind a dev flag. It draws a real room from a template file, paints
## the ASCII underneath it, rebuilds as you paint, and writes the file back.
##
##   tools\edit_room.ps1 [-Room data/rooms/biome1/flats_01.txt]
##   godot --path . src/dev/room_editor.tscn -- --room=data/rooms/biome1/flats_01.txt
##
## Mouse paints the chosen brush (right button paints floor). 1-9 and 0 pick a brush,
## Tab and Shift+Tab step the whole palette, [ and ] step through the biome's files.
## S saves (it refuses a room you cannot walk around), L reloads, G shows the grid,
## Esc quits. Writing goes to the real file through the project folder, so this is for
## a build run from source, which is what a dev flag means here.

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
const THEME_BY_DIR := {"biome1": Tiles.Look.FLATS, "harbour": Tiles.Look.HARBOUR,
	"biome2": Tiles.Look.STREETS, "biome3": Tiles.Look.DEEP}

var path: String = DEFAULT_ROOM
var rows: PackedStringArray = []
var brush: int = 0
var dirty: bool = false
var show_grid: bool = true
var _room: Room
var _files: Array = []
var _file_at: int = 0
var _status: Label
var _palette: Label
var _title: Label
var _grid: GridOverlay
var _painting: int = 0  # mouse button held, or 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="):
			path = a.trim_prefix("--room=")
	_scan_dir()
	_load()
	_build_ui()
	_rebuild()
	_handle_screenshot_arg()


## Dev aid: `-- --screenshot` saves .shots/room_editor.png and quits.
func _handle_screenshot_arg() -> void:
	if not "--screenshot" in OS.get_cmdline_user_args():
		return
	for i in 20:
		await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	print("screenshot -> %s/room_editor.png (%s)" % [dir, error_string(img.save_png(dir + "/room_editor.png"))])
	get_tree().quit()


# --- files ---------------------------------------------------------------------------
func _dir() -> String:
	return path.get_base_dir()


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
	for line in text.split("\n"):
		if line.strip_edges() == "":
			continue
		rows.append(line.strip_edges(false, true))
	dirty = false


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
	f.store_string("\n".join(rows) + "\n")
	f = null
	dirty = false
	_say("saved %s" % path, true)


## The same things the tests insist on: one keeper, somewhere to fight from, doors that
## touch the floor, and no walled-off ground.
func _check() -> String:
	var t := _template()
	if t.player_spawn.x < 0:
		return "no P: the keeper has nowhere to stand"
	if t.doors.is_empty():
		return "no D: there is no way out"
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
	if t.enemy_spawns.is_empty() and not path.get_file().begins_with("hub"):
		return "no e: nothing can be spawned here"
	return ""


func _template() -> RoomTemplate:
	return RoomTemplate.parse("\n".join(rows), path.get_file().get_basename())


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
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_painting = event.button_index if event.pressed else 0
			if event.pressed:
				_paint(get_global_mouse_position(), event.button_index)
	elif event is InputEventMouseMotion and _painting != 0:
		_paint(get_global_mouse_position(), _painting)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)


func _paint(at: Vector2, button: int) -> void:
	_set_cell(_cell_at(at), "." if button == MOUSE_BUTTON_RIGHT else str(BRUSHES[brush].ch))


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
		KEY_TAB:
			brush = wrapi(brush + (-1 if event.shift_pressed else 1), 0, BRUSHES.size())
			_refresh()
		KEY_BRACKETLEFT:
			_step_file(-1)
		KEY_BRACKETRIGHT:
			_step_file(1)
		_:
			var i := UI.menu_index(event)
			if i >= 0 and i < BRUSHES.size():
				brush = i
				_refresh()
			elif event.keycode == KEY_0 and BRUSHES.size() > 9:
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
	var look: int = THEME_BY_DIR.get(_dir().get_file(), Tiles.Look.FLATS)
	_room.build(_template(), 7, look)
	_room.set_tide(0.0)
	if _grid:
		_grid.queue_redraw()
	_refresh()


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
	bar.offset_top = -34
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bar)
	_title = UI.label("", 8, Color(0.95, 0.9, 0.75))
	_title.position = Vector2(4, 328)
	_title.size = Vector2(632, 10)
	layer.add_child(_title)
	_palette = UI.label("", 8, Color(0.8, 0.85, 0.95))
	_palette.position = Vector2(4, 338)
	_palette.size = Vector2(632, 10)
	layer.add_child(_palette)
	_status = UI.label("mouse paints   right button clears   [S] save  [L] reload  [Tab] brush  [ ] file  [G] grid  [Esc] quit", 8, Color(0.6, 0.7, 0.8))
	_status.position = Vector2(4, 348)
	_status.size = Vector2(632, 10)
	layer.add_child(_status)


func _refresh() -> void:
	var problem := _check()
	_title.text = "%s%s   %d x %d   %s" % [path.get_file(), "  *" if dirty else "", rows[0].length() if rows.size() > 0 else 0,
		rows.size(), "ok" if problem == "" else problem]
	_title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75) if problem == "" else Color(1.0, 0.6, 0.55))
	var parts: Array = []
	for i in BRUSHES.size():
		var b: Dictionary = BRUSHES[i]
		var key := str(i + 1) if i < 9 else ("0" if i == 9 else "-")
		parts.append("%s%s %s%s" % ["[" if i == brush else " ", key, b.ch, "]" if i == brush else " "])
	_palette.text = " ".join(parts) + "   brush: " + str(BRUSHES[brush].name)


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
				if col.a > 0.0:
					var r := Rect2(x * CELL + 3, y * CELL + 3, CELL - 6, CELL - 6)
					draw_rect(r, Color(col, 0.25))
					draw_rect(r, col, false, 1.0)
					draw_string(UI.FONT, Vector2(x * CELL + 5, y * CELL + 12), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
