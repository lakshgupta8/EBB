extends Node2D
## Marrow Rock lighthouse. Orla keeps the Ledger by the tower; the shore descends.

const HUB_TEMPLATE := "res://data/rooms/hub.txt"

@onready var player: Player = $Player
@onready var room_holder: Node2D = $RoomHolder
@onready var info: Label = $HUD/Info
@onready var ledger_ui: LedgerUI = $LedgerUI

var room: Room


func _ready() -> void:
	Game.state = Game.State.HUB
	room = Room.new()
	room_holder.add_child(room)
	room.build(RoomTemplate.load_file(HUB_TEMPLATE))
	room.set_tide(0.6)  # the sea laps at the foot of the rock, always
	player.global_position = room.cell_to_world(room.template.player_spawn)
	Ledger.apply(player, null)
	Atmosphere.build(self, Vector2(640, 368))
	Audio.ambient("ambient_sea", -11.0)
	Audio.gulls_enabled = true
	for cell in room.template.marker_cells("X"):
		var d := Door.new()
		room.add_child(d)
		d.setup(room, cell, Door.DESCEND)
		d.open()
		d.entered.connect(func(_d): Game.go_to_run())
	# The tower stands on the centre of its 2x2 footprint so the sprite matches the solid cells.
	var h_cells: Array = room.template.marker_cells("h")
	if h_cells.size() > 0:
		var lo: Vector2i = h_cells[0]
		var hi: Vector2i = h_cells[0]
		for c in h_cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		var centre := (room.cell_to_world(lo) + room.cell_to_world(hi)) * 0.5
		var tower := Prop.new()
		room.add_child(tower)
		tower.setup(Prop.Kind.LIGHTHOUSE, centre)
	for cell in room.template.marker_cells("O"):
		room.add_prop(Prop.Kind.ORLA, cell).used.connect(func(_p): ledger_ui.open())
	ledger_ui.closed.connect(_refresh_info)
	_refresh_info()
	_handle_screenshot_arg()


func _refresh_info() -> void:
	var s := SaveManager.data
	info.text = "MARROW ROCK\npearls %d   runs %d   best %d   wins %d" % [s.pearls, s.runs, s.best_depth, s.wins]


func _handle_screenshot_arg() -> void:
	if not "--screenshot" in OS.get_cmdline_user_args():
		return
	for i in 30:
		await get_tree().process_frame
	if "--ledger" in OS.get_cmdline_user_args():
		ledger_ui.open()
		await get_tree().process_frame
		await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	print("screenshot -> %s/hub.png (%s)" % [dir, error_string(img.save_png(dir + "/hub.png"))])
	get_tree().quit()
