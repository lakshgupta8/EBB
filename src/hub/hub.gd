extends Node2D
## Marrow Rock lighthouse. Orla keeps the Ledger by the tower; the shore descends.
## Every echo you bring back stands somewhere on the rock with something to offer.

const HUB_TEMPLATE := "res://data/rooms/hub.txt"
## Bram forges the later weapons for pearls. The knife is his gift.
const WEAPON_COST := {"gaff": 0, "net": 0, "harpoon": 25, "lantern": 40}

@onready var player: Player = $Player
@onready var room_holder: Node2D = $RoomHolder
@onready var info: Label = $HUD/Info
@onready var ledger_ui: LedgerUI = $LedgerUI
@onready var choice_ui: ChoiceUI = $ChoiceUI
@onready var codex_ui: CodexUI = $CodexUI
@onready var ending_ui: EndingUI = $EndingUI

var room: Room


func _ready() -> void:
	Game.state = Game.State.HUB
	if "--sim-save" in OS.get_cmdline_user_args():
		SaveManager.use_path("user://sim_save.json")
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
	for cell in room.template.marker_cells("K"):
		room.add_prop(Prop.Kind.FEN, cell).used.connect(func(_p): open_fen())
	if SaveManager.flag("echo_bram"):
		for cell in room.template.marker_cells("B"):
			room.add_prop(Prop.Kind.BRAM, cell).used.connect(func(_p): open_bram())
	if SaveManager.flag("echo_wren"):
		for cell in room.template.marker_cells("W"):
			room.add_prop(Prop.Kind.WREN, cell).used.connect(func(_p): open_wren())
	if SaveManager.flag("echo_cartographer"):
		for cell in room.template.marker_cells("C"):
			room.add_prop(Prop.Kind.CARTOGRAPHER, cell).used.connect(func(_p): open_cartographer())
	if SaveManager.flag("echo_maren"):
		for cell in room.template.marker_cells("N"):
			room.add_prop(Prop.Kind.MAREN, cell).used.connect(func(_p): open_maren())
	ledger_ui.closed.connect(_refresh_info)
	choice_ui.closed.connect(_refresh_info)
	codex_ui.closed.connect(_refresh_info)
	ending_ui.tide = room.set_tide
	_refresh_info()
	_handle_screenshot_arg()


# --- the echoes ------------------------------------------------------------------------
func _owned_weapons() -> Array:
	var owned: Array = SaveManager.data.get("weapons", ["gaff", "net"])
	if not "gaff" in owned:
		owned.append("gaff")
	if not "net" in owned:
		owned.append("net")
	SaveManager.data["weapons"] = owned
	return owned


## Bram: pick the weapon the next night starts with; forge the later ones for pearls.
func open_bram() -> void:
	var ids := Weapon.ALL.keys()
	var owned := _owned_weapons()
	var options: Array = []
	for id in ids:
		var cost: int = WEAPON_COST.get(id, 0)
		options.append({"name": Weapon.ALL[id].name, "desc": Weapon.ALL[id].desc,
			"right": "" if id in owned else "%d pearls" % cost, "fail": "not enough pearls"})
	var current := ids.find(Game.weapon_id())
	choice_ui.open("BRAM'S FORGE", Story.bram(), options, current, Color(0.95, 0.75, 0.55), func(i):
		var id: String = ids[i]
		if not id in owned:
			var cost: int = WEAPON_COST.get(id, 0)
			if int(SaveManager.data.pearls) < cost:
				return ""
			SaveManager.data.pearls -= cost
			owned.append(id)
			choice_ui.set_right(i, "")
			FX.burst(player.global_position, Color(0.98, 0.85, 0.45), 10, 50.0)
		SaveManager.data["weapon"] = id
		SaveManager.save_profile()
		player._equip(id)
		return "the %s waits by the door" % Weapon.ALL[id].name.to_lower()
	)


## Sister Wren: bless a tidemark family. Every altar offers at least one from it.
func open_wren() -> void:
	var fams := Tidemarks.FAMILY_COLOR.keys()
	var options: Array = []
	var descs := {"salt": "offence: damage, crits, bleeding", "brine": "defence: health, shields, healing",
		"current": "mobility: dashes, riptides, speed", "deep": "strange: the tide, salt, the lantern"}
	for f in fams:
		options.append({"name": Tidemarks.FAMILY_NAME[f], "desc": descs[f]})
	var current := fams.find(str(SaveManager.data.get("blessed_family", "")))
	choice_ui.open("SISTER WREN", Story.wren(), options, current, Color(0.8, 0.9, 1.0), func(i):
			SaveManager.data["blessed_family"] = fams[i]
			SaveManager.save_profile()
			return "every altar will carry %s" % fams[i]
	)


## The Cartographer: promise one room type at depth 2 of every biome.
func open_cartographer() -> void:
	var options: Array = []
	var descs := {RoomGraph.FOUNTAIN: "a fountain two rooms in", RoomGraph.TREASURE: "a chest two rooms in", RoomGraph.SHOP: "the merchant two rooms in"}
	for t in RoomGraph.CHARTABLE:
		options.append({"name": RoomGraph.NAMES[t], "desc": descs[t]})
	var current := RoomGraph.CHARTABLE.find(int(SaveManager.data.get("charted_room", -1)))
	choice_ui.open("THE CARTOGRAPHER", Story.cartographer(), options, current, Color(0.75, 0.8, 1.0), func(i):
			SaveManager.data["charted_room"] = RoomGraph.CHARTABLE[i]
			SaveManager.save_profile()
			return "charted: %s at depth 2" % RoomGraph.NAMES[RoomGraph.CHARTABLE[i]].to_lower()
	)


## Maren: the old keeper, back from under the hall. She holds the endings.
func open_maren() -> void:
	var ids: Array = []
	var options: Array = []
	for id in Story.ENDING_ORDER:
		if not Story.ending_visible(id):
			continue
		var e: Dictionary = Story.ENDINGS[id]
		var reason := Story.ending_locked_reason(id)
		var right := "seen" if Story.seen(id) else ("locked" if reason != "" else "")
		ids.append(id)
		options.append({"name": e.name, "desc": e.desc, "right": right, "fail": reason})
	choice_ui.open("MAREN", Story.maren(), options, -1, Color(0.95, 0.9, 0.8), func(i):
		var id: String = ids[i]
		if not Story.ending_available(id):
			return ""
		choice_ui.close()
		ending_ui.play.call_deferred(id)
		return "..."
	)


## Fen: the village kid. Only ever has something to say.
func open_fen() -> void:
	choice_ui.open("FEN", Story.fen(), [], -1, Color(0.85, 0.95, 0.8))


func _refresh_info() -> void:
	var s := SaveManager.data
	var echoes := int(s.get("echoes", 0))
	var endings := Story.endings_seen().size()
	info.text = "MARROW ROCK   %s\npearls %d   runs %d   best %d   wins %d   echoes %d%s" % [
		Weapon.name_of(Game.weapon_id()).to_lower(), s.pearls, s.runs, s.best_depth, s.wins, echoes,
		"   endings %d/3" % endings if endings > 0 else ""]


func _handle_screenshot_arg() -> void:
	if not "--screenshot" in OS.get_cmdline_user_args():
		return
	for i in 30:
		await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	if "--ledger" in args:
		ledger_ui.open()
	elif "--bram" in args:
		open_bram()
	elif "--wren" in args:
		open_wren()
	elif "--maren" in args:
		open_maren()
	elif "--pause" in args:
		$Pause.toggle()
	elif "--fen" in args:
		open_fen()
	elif "--codex" in args:
		codex_ui.open(0)
	elif "--codex2" in args:
		codex_ui.open(1)
	else:
		for a in args:
			if a.begins_with("--ending="):
				ending_ui.play(a.trim_prefix("--ending="))
				for i in 220:
					await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	print("screenshot -> %s/hub.png (%s)" % [dir, error_string(img.save_png(dir + "/hub.png"))])
	get_tree().quit()
