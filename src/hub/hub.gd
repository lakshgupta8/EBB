extends Node2D
## Marrow Rock lighthouse. Orla keeps the Ledger by the tower; the shore descends.
## Every echo you bring back stands somewhere on the rock with something to offer, the
## village comes down to the rock as the nights go by, and the rock keeps the shape the
## last ending left it in.

const HUB_TEMPLATE := "res://data/rooms/hub.txt"
## Bram forges the later weapons for pearls. The knife is his gift.
const WEAPON_COST := {"gaff": 0, "net": 0, "harpoon": 25, "lantern": 40, "bell": 55, "line": 45}
const NPC_NAMES := {"orla": "Elder Orla", "fen": "Fen", "bram": "Bram", "wren": "Sister Wren", "cartographer": "The Cartographer",
	"maren": "Maren", "nessa": "Nessa", "idris": "Idris", "aldous": "Keeper Aldous", "pell": "Pell", "choir": "The Choir"}
## One lantern post lights for every eight Log milestones.
const LANTERNS_PER := 8

@onready var player: Player = $Player
@onready var room_holder: Node2D = $RoomHolder
@onready var info: Label = $HUD/Info
@onready var ledger_ui: LedgerUI = $LedgerUI
@onready var choice_ui: ChoiceUI = $ChoiceUI
@onready var codex_ui: CodexUI = $CodexUI
@onready var ending_ui: EndingUI = $EndingUI
@onready var log_ui: LogUI = $LogUI
@onready var talk_ui: TalkUI = $TalkUI

var room: Room
var _toast: Label
var _props: Dictionary = {}  # npc id -> Prop


func _ready() -> void:
	Game.state = Game.State.HUB
	if "--sim-save" in OS.get_cmdline_user_args():
		SaveManager.use_path("user://sim_save.json")
	room = Room.new()
	room_holder.add_child(room)
	room.build(RoomTemplate.load_file(HUB_TEMPLATE))
	var epilogue := Story.epilogue()
	# The sea laps at the foot of the rock, always; up to the sand's edge since Break (the
	# lower shore is the Drowned's now, with their dock on it), out and staying out since Walk.
	room.set_tide({"break": 1.0, "walk": 0.0}.get(epilogue, 0.6))
	player.global_position = room.cell_to_world(room.template.player_spawn)
	Ledger.apply(player, null)
	Atmosphere.build(self, Vector2(640, 368))
	Audio.ambient("ambient_sea", -11.0 if epilogue != "walk" else -18.0)
	Audio.gulls_enabled = epilogue != "walk"
	if epilogue == "walk":
		Audio.music("music_still", -12.0)
	elif epilogue == "keep":
		Audio.music("music_keep", -10.0)   # the lamp is lit and someone is keeping it
	elif epilogue == "break":
		Audio.music("music_break", -10.0)  # the water is in and the rock is quieter for it
	elif SaveManager.flag("echo_choir"):
		Audio.music("music_hub_choir", -10.0)
		SaveManager.count("hymns")
	else:
		Audio.music("music_hub", -10.0)
	for cell in room.template.marker_cells("X"):
		var d := Door.new()
		room.add_child(d)
		d.setup(room, cell, Door.DESCEND)
		if Game.has_suspended():
			d.set_label("CONTINUE THE NIGHT")
		elif bool(SaveManager.data.get("launch_harbour", false)) and SaveManager.flag("boss_chainmother_broken"):
			d.set_label("LAUNCH FROM THE HARBOUR")
		d.open()
		d.entered.connect(func(_d):
			if Game.has_suspended():
				Game.continue_run()
			else:
				Game.go_to_run())
	_place_tower()
	_place_people()
	_grow()
	_apply_epilogue(epilogue)
	ledger_ui.closed.connect(_refresh_info)
	ledger_ui.gift_requested.connect(func(): gift("orla"))
	choice_ui.closed.connect(_refresh_info)
	codex_ui.closed.connect(_refresh_info)
	log_ui.closed.connect(_refresh_info)
	talk_ui.finished.connect(_refresh_info)
	ending_ui.tide = room.set_tide
	_toast = UI.label("", 8, Color(0.95, 0.9, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	_toast.position = Vector2(20, 296)
	_toast.size = Vector2(600, 30)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.visible = false
	$HUD.add_child(_toast)
	_refresh_info()
	_claim_log.call_deferred()
	_handle_screenshot_arg()


func _place_tower() -> void:
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


## Who is on the rock tonight, and where they stand.
func _place_people() -> void:
	_person("orla", "O", Prop.Kind.ORLA, true, func(): ledger_ui.open())
	_person("fen", "K", Prop.Kind.FEN, true, open_fen)
	_person("bram", "B", Prop.Kind.BRAM, SaveManager.flag("echo_bram"), open_bram)
	_person("wren", "W", Prop.Kind.WREN, SaveManager.flag("echo_wren"), open_wren)
	_person("cartographer", "C", Prop.Kind.CARTOGRAPHER, SaveManager.flag("echo_cartographer"), open_cartographer)
	_person("maren", "N", Prop.Kind.MAREN, SaveManager.flag("echo_maren"), open_maren)
	_person("nessa", "S", Prop.Kind.NESSA, int(SaveManager.data.get("runs", 0)) >= 2, open_nessa)
	_person("idris", "I", Prop.Kind.IDRIS, SaveManager.flag("boss_chainmother_broken"), open_idris)
	_person("aldous", "L", Prop.Kind.ALDOUS, SaveManager.flag("echo_aldous"), open_aldous)
	_person("pell", "V", Prop.Kind.PELL, SaveManager.flag("echo_pell"), open_pell)
	_person("choir", "Y", Prop.Kind.CHOIR, SaveManager.flag("echo_choir"), open_choir)


func _person(id: String, marker: String, kind: Prop.Kind, here: bool, on_use: Callable) -> void:
	if not here:
		return
	for cell in room.template.marker_cells(marker):
		var p := room.add_prop(kind, cell)
		p.used.connect(func(_p): on_use.call())
		_props[id] = p


## The rock grows: lantern posts with the Log, a dock once Idris is here or the Drowned built one.
func _grow() -> void:
	var posts: Array = room.template.marker_cells("l")
	var lit := mini(posts.size(), KeeperLog.claimed().size() / LANTERNS_PER)
	for i in lit:
		room.add_prop(Prop.Kind.LANTERN_POST, posts[i])
	if SaveManager.flag("boss_chainmother_broken") or Story.epilogue() == "break":
		for cell in room.template.marker_cells("d"):
			room.add_prop(Prop.Kind.DOCK, cell)


## What the last ending left behind.
func _apply_epilogue(id: String) -> void:
	match id:
		"keep":
			# Maren's lamp is lit: the tower burns warmer, and she stands at its foot.
			for cell in room.template.marker_cells("h"):
				var l := Atmosphere.light(room, Color(1.0, 0.85, 0.5), 9.0, 2.2, room.cell_to_world(cell) + Vector2(0, -40))
				Atmosphere.breathe(l, 1.8, 2.6, 2.0)
				break
		"walk":
			# Empty ruins, still sea: the people are here, but faint, the way memories are.
			for who in _props:
				if who in Story.ECHO_IDS:
					_props[who].modulate = Color(0.75, 0.8, 0.9, 0.7)


## The Log pays out the moment its milestones hold; a toast says what for.
func _claim_log() -> void:
	var got := KeeperLog.claim_all()
	if got.is_empty():
		return
	var names: Array = []
	for m in got:
		names.append(str(m.name))
	_toast_text("KEEPER'S LOG: " + ", ".join(names) + "   (" + LogUI._reward_text(_sum(got)) + ")")
	Audio.play("gift", 0.0, -4.0)
	FX.burst(player.global_position, Color(0.95, 0.85, 0.55), 12, 60.0)
	_refresh_info()


static func _sum(list: Array) -> Dictionary:
	var out := {"pearls": 0, "shards": 0}
	for m in list:
		out.pearls += int(m.get("pearls", 0))
		out.shards += int(m.get("shards", 0))
		if m.has("cosmetic"):
			out["cosmetic"] = m.cosmetic
	return out


func _toast_text(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.3)
	tw.tween_interval(5.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): _toast.visible = false)


# --- gifts and affinity -------------------------------------------------------------------
func _gifts_in_hand() -> int:
	return int(SaveManager.data.get("glass", 0)) + int(SaveManager.data.get("shells", 0))


func _gift_option(npc: String) -> Dictionary:
	var level := Story.affinity(npc)
	var top := Dialog.chain_count(npc)
	if level >= top:
		return {"name": "A gift", "desc": "they have everything you could give", "right": "%d/%d" % [level, top], "fail": "nothing left to give"}
	return {"name": "A gift", "desc": "salt-glass or a shell; they will talk", "right": "%d/%d  %d in hand" % [level, top, _gifts_in_hand()],
		"fail": "you have nothing to give (glass from dives, shells from Fen)"}


## Give `npc` a gift: one level of affinity, a chain of lines, a reward. False when refused.
func gift(npc: String) -> bool:
	var given := Story.give_gift(npc)
	if given.is_empty():
		return false
	Audio.play("gift")
	FX.burst(player.global_position, Color(0.7, 0.9, 0.95), 10, 50.0)
	talk_ui.talk.call_deferred(npc, NPC_NAMES.get(npc, npc), given.lines, given.seen_before)
	return true


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
	options.append({"name": "Aspects of the %s" % Weapon.name_of(Game.weapon_id()).to_lower(),
		"desc": "remember someone; costs shards", "right": "%d shards" % int(SaveManager.data.get("shards", 0))})
	options.append(_gift_option("bram"))
	var current := ids.find(Game.weapon_id())
	choice_ui.open("BRAM'S FORGE", Story.bram(), options, current, Color(0.95, 0.75, 0.55), func(i):
		if i == ids.size():
			choice_ui.close()
			open_aspects.call_deferred(Game.weapon_id())
			return ""
		if i > ids.size():
			return _gift_from_menu("bram")
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


## A gift picked from a ChoiceUI: close the menu first so the talk can take the screen.
func _gift_from_menu(npc: String) -> String:
	if _gifts_in_hand() <= 0 or Story.affinity(npc) >= Dialog.chain_count(npc):
		return ""
	choice_ui.close()
	gift.call_deferred(npc)
	return "..."


## Bram, second bench: an aspect for the weapon in hand, paid once in echo shards.
func open_aspects(wid: String) -> void:
	var list: Array = Weapon.ASPECTS.get(wid, [])
	var owned: Array = SaveManager.data.get("aspects_owned", [])
	var current := Weapon.aspect_of(wid)
	var options: Array = [{"name": "Plain %s" % Weapon.name_of(wid), "desc": "as Bram made it"}]
	for a in list:
		options.append({"name": a.name, "desc": a.desc,
			"right": "" if a.id in owned else "%d shards" % Weapon.ASPECT_COST, "fail": "not enough echo shards"})
	var selected := 0
	for k in list.size():
		if list[k].id == current:
			selected = k + 1
	var line := "Bring me what the sea left of them and the blade will remember. %d shards in your pocket." % int(SaveManager.data.get("shards", 0))
	choice_ui.open("ASPECTS", line, options, selected, Color(0.95, 0.75, 0.55), func(i):
		var aspects: Dictionary = SaveManager.data.get("aspects", {})
		if i == 0:
			aspects[wid] = ""
		else:
			var a: Dictionary = list[i - 1]
			if not a.id in owned:
				if int(SaveManager.data.get("shards", 0)) < Weapon.ASPECT_COST:
					return ""
				SaveManager.data["shards"] = int(SaveManager.data.get("shards", 0)) - Weapon.ASPECT_COST
				owned.append(a.id)
				SaveManager.data["aspects_owned"] = owned
				choice_ui.set_right(i, "")
				FX.burst(player.global_position, Color(0.95, 0.85, 0.55), 12, 60.0)
			aspects[wid] = a.id
		SaveManager.data["aspects"] = aspects
		SaveManager.save_profile()
		player._equip(wid)
		_refresh_info()
		return "plain again" if i == 0 else "the %s remembers" % Weapon.name_of(wid).to_lower()
	)


## Sister Wren: bless a tidemark family. Every altar offers at least one from it.
func open_wren() -> void:
	var fams := ["salt", "brine", "current", "deep"]
	var options: Array = []
	var descs := {"salt": "offence: damage, crits, bleeding", "brine": "defence: health, shields, healing",
		"current": "mobility: dashes, riptides, speed", "deep": "strange: the tide, salt, the lantern"}
	for f in fams:
		options.append({"name": Tidemarks.FAMILY_NAME[f], "desc": descs[f]})
	options.append(_gift_option("wren"))
	var current := fams.find(str(SaveManager.data.get("blessed_family", "")))
	choice_ui.open("SISTER WREN", Story.wren(), options, current, Color(0.8, 0.9, 1.0), func(i):
			if i >= fams.size():
				return _gift_from_menu("wren")
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
	options.append(_gift_option("cartographer"))
	var current := RoomGraph.CHARTABLE.find(int(SaveManager.data.get("charted_room", -1)))
	choice_ui.open("THE CARTOGRAPHER", Story.cartographer(), options, current, Color(0.75, 0.8, 1.0), func(i):
			if i >= RoomGraph.CHARTABLE.size():
				return _gift_from_menu("cartographer")
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
	options.append(_gift_option("maren"))
	choice_ui.open("MAREN", Story.maren(), options, -1, Color(0.95, 0.9, 0.8), func(i):
		if i >= ids.size():
			return _gift_from_menu("maren")
		var id: String = ids[i]
		if not Story.ending_available(id):
			return ""
		choice_ui.close()
		ending_ui.play.call_deferred(id)
		return "..."
	)


## Fen: the village kid. A quest to hand in, a quest in hand, or something to say.
func open_fen() -> void:
	if Quests.fen_ready():
		var q := Quests.fen_hand_in()
		Audio.play("gift")
		FX.burst(player.global_position, Color(0.95, 0.9, 0.8), 10, 50.0)
		var lines: Array = [str(q.done), "(a shell, %d pearls)" % int(q.pearls)]
		if not Quests.fen_done():
			lines.append(str(Quests.fen_current().ask))
		talk_ui.talk("fen", "Fen", lines)
		return
	var options: Array = [_gift_option("fen")]
	choice_ui.open("FEN", Story.fen(), options, -1, Color(0.85, 0.95, 0.8), func(_i):
		return _gift_from_menu("fen"))


## Nessa: the board (three contracts a night), fish for the night, a gift.
func open_nessa() -> void:
	var fish: Array = SaveManager.data.get("fish", [])
	var cap := 4 if Story.perk("nessa") else 3
	var options: Array = [{"name": "The board", "desc": "three a night, judged when it ends", "right": "%d done" % Contracts.done().size()}]
	for id in Fish.ORDER:
		var f: Dictionary = Fish.ALL[id]
		options.append({"name": f.name, "desc": f.desc, "right": "%d pearls" % int(f.price), "fail": "not enough pearls, or the bag is full"})
	options.append(_gift_option("nessa"))
	choice_ui.open("NESSA THE FISHER", Story.nessa(), options, -1, Color(0.85, 0.9, 0.6), func(i):
		if i == 0:
			choice_ui.close()
			log_ui.open.call_deferred(2)
			return "..."
		if i > Fish.ORDER.size():
			return _gift_from_menu("nessa")
		var id: String = Fish.ORDER[i - 1]
		var price := int(Fish.ALL[id].price)
		if int(SaveManager.data.pearls) < price or fish.size() >= cap:
			return ""
		SaveManager.data["pearls"] = int(SaveManager.data.pearls) - price
		fish.append(id)
		SaveManager.data["fish"] = fish
		SaveManager.save_profile()
		return "%s in the bag (%d of %d)" % [Fish.name_of(id).to_lower(), fish.size(), cap]
	)


## Idris: the dock. Launch from the harbour, lay a keel, wear what the Log has opened.
func open_idris() -> void:
	var launch := bool(SaveManager.data.get("launch_harbour", false))
	var cost := 0 if Story.perk("idris") else Run.LAUNCH_COST
	var options: Array = [{"name": "Launch from the harbour", "desc": "the night starts past the flats", "right": ("on" if launch else "off") + ("" if cost == 0 else ", %d pearls a night" % cost)}]
	var keels_owned: Array = SaveManager.data.get("keels_owned", [])
	for k in Ledger.KEELS:
		options.append({"name": k.name, "desc": k.desc, "right": "" if k.id in keels_owned else "%d pearls" % int(k.cost), "fail": "not enough pearls"})
	options.append({"name": "No keel", "desc": "the boat as she was"})
	options.append({"name": "Lantern and coat", "desc": "what the Log and the village have opened"})
	options.append(_gift_option("idris"))
	var selected := -1
	for k in Ledger.KEELS.size():
		if Ledger.KEELS[k].id == str(SaveManager.data.get("keel", "")):
			selected = k + 1
	choice_ui.open("THE DOCK", Story.idris(), options, selected, Color(0.7, 0.8, 1.0), func(i):
		var n := Ledger.KEELS.size()
		if i == 0:
			var on: bool = not bool(SaveManager.data.get("launch_harbour", false))
			SaveManager.data["launch_harbour"] = on
			SaveManager.save_profile()
			choice_ui.set_right(0, ("on" if on else "off") + ("" if cost == 0 else ", %d pearls a night" % cost))
			return "the boat waits at the harbour" if on else "the boat waits at the flats"
		if i <= n:
			var k: Dictionary = Ledger.KEELS[i - 1]
			if not k.id in keels_owned:
				if int(SaveManager.data.pearls) < int(k.cost):
					return ""
				SaveManager.data["pearls"] = int(SaveManager.data.pearls) - int(k.cost)
				keels_owned.append(k.id)
				SaveManager.data["keels_owned"] = keels_owned
				choice_ui.set_right(i, "")
			SaveManager.data["keel"] = k.id
			SaveManager.save_profile()
			return "%s laid" % str(k.name).to_lower()
		if i == n + 1:
			SaveManager.data["keel"] = ""
			SaveManager.save_profile()
			return "no keel"
		if i == n + 2:
			choice_ui.close()
			open_cosmetics.call_deferred()
			return "..."
		return _gift_from_menu("idris")
	)


## Lantern colours and coats: cosmetics opened by the Log and by people who like you.
func open_cosmetics() -> void:
	var lanterns := KeeperLog.LANTERNS.keys()
	var coats := KeeperLog.COATS.keys()
	var options: Array = []
	for id in lanterns:
		options.append({"name": "Lantern: " + str(KeeperLog.LANTERNS[id].name), "desc": "the light you carry", "right": "" if KeeperLog.owns_cosmetic(id) else "locked", "fail": "the Log opens lantern colours"})
	for id in coats:
		options.append({"name": str(KeeperLog.COATS[id].name), "desc": "what you wear down", "right": "" if KeeperLog.owns_cosmetic(id) else "locked", "fail": "given by people who like you"})
	var cos: Dictionary = SaveManager.data.get("cosmetics", {})
	var selected := lanterns.find(str(cos.get("lantern", "warm")))
	choice_ui.open("LANTERN AND COAT", "Idris keeps a chest of them. Nobody else on the rock has anywhere to keep anything.", options, selected, Color(0.9, 0.85, 0.7), func(i):
		var id: String = lanterns[i] if i < lanterns.size() else coats[i - lanterns.size()]
		if not KeeperLog.owns_cosmetic(id):
			return ""
		cos["lantern" if i < lanterns.size() else "coat"] = id
		SaveManager.data["cosmetics"] = cos
		SaveManager.save_profile()
		if i >= lanterns.size():
			player.sprite.sprite_frames = SheetFrames.build(load(KeeperLog.coat_sheet()), 24, {
				"idle": {"frames": [0, 1], "fps": 3}, "walk": {"frames": [2, 3, 4, 5], "fps": 9},
				"hurt": {"frames": [6], "fps": 1}, "dash": {"frames": [7], "fps": 1}})
			player.sprite.play("idle")
			return "the %s, then" % str(KeeperLog.COATS[id].name).to_lower()
		player.lantern_color = KeeperLog.lantern_color()
		player.add_glow(0.0)
		return "the lantern burns %s" % str(KeeperLog.LANTERNS[id].name).to_lower()
	)


## Keeper Aldous: reads the pages you have found, and a gift.
func open_aldous() -> void:
	var pages: Array = SaveManager.data.get("journals", []).duplicate()
	pages.sort()
	var options: Array = [{"name": "The journal", "desc": "%d of %d pages found; he reads them" % [pages.size(), Story.JOURNAL.size()], "fail": "you have found none of his pages yet"}]
	if pages.size() >= Story.JOURNAL.size():
		options.append({"name": "The way out", "desc": "the one thing he never wrote down", "fail": ""})
	options.append(_gift_option("aldous"))
	choice_ui.open("KEEPER ALDOUS", Story.aldous(), options, -1, Color(0.85, 0.85, 0.8), func(i):
		if i == 0:
			if pages.is_empty():
				return ""
			var lines: Array = []
			for n in pages:
				lines.append(Story.JOURNAL[int(n) - 1])
			choice_ui.close()
			SaveManager.count("journal_read")
			talk_ui.talk.call_deferred("aldous", "Keeper Aldous", lines, SaveManager.stat("journal_read") > 1)
			return "..."
		if i == 1 and pages.size() >= Story.JOURNAL.size():
			choice_ui.close()
			var hint := ("Maren will tell you it needs everyone home and three nights walked. It does. And then it needs you to choose it, which is the part nobody manages." if Settings.hints() else "")
			talk_ui.talk.call_deferred("aldous", "Keeper Aldous", [
				"It can be put down. That is the whole of it. Not hung at the bottom, not broken: put down, by someone who could have carried it.",
				"Every keeper before you could not. I could not. Maren went down instead. You have been up and down that hall enough times to know you can carry it.",
				"So put it down. Walk out. Let the sea forget." + ("" if hint == "" else "  " + hint),
			], SaveManager.flag("aldous_way_out"))
			SaveManager.set_flag("aldous_way_out")
			return "..."
		return _gift_from_menu("aldous")
	)


## Pell the Diver: a word about the deep, and a gift.
func open_pell() -> void:
	var options: Array = [{"name": "Salt-glass", "desc": "%d in hand; dives hold more" % int(SaveManager.data.get("glass", 0)), "fail": ""}, _gift_option("pell")]
	choice_ui.open("PELL THE DIVER", Story.pell(), options, -1, Color(0.6, 0.85, 0.9), func(i):
		if i == 0:
			return "go under when you can"
		return _gift_from_menu("pell"))


## The Choir: they sing for the rock now, and a gift.
func open_choir() -> void:
	var options: Array = [{"name": "Sing", "desc": "the hymn, for the rock"}, _gift_option("choir")]
	choice_ui.open("THE CHOIR", Story.choir(), options, -1, Color(0.85, 0.8, 1.0), func(i):
		if i == 0:
			Audio.play("hymn", 0.0, -2.0)
			SaveManager.count("hymns")
			FX.ring(_props["choir"].global_position if _props.has("choir") else player.global_position, Color(0.85, 0.75, 1.0), 2.0)
			return "the note, finished"
		return _gift_from_menu("choir"))


func _refresh_info() -> void:
	var s := SaveManager.data
	var echoes := Story.echoes_home()
	var endings := Story.endings_seen().size()
	var asp := Weapon.aspect_of(Game.weapon_id())
	var wname := Weapon.name_of(Game.weapon_id()).to_lower()
	if asp != "":
		wname = str(Weapon.aspect_entry(asp).get("name", wname)).to_lower()
	var gifts := _gifts_in_hand()
	info.text = "MARROW ROCK   %s%s\npearls %d   shards %d   runs %d   best %d   wins %d   echoes %d/%d%s%s%s%s" % [
		wname, ("   " + str(Ledger.keel().name).to_lower()) if not Ledger.keel().is_empty() else "",
		s.pearls, int(s.get("shards", 0)), s.runs, s.best_depth, s.wins, echoes, Story.ECHO_IDS.size(),
		"   endings %d/3" % endings if endings > 0 else "",
		"   spring tide %d" % int(s.get("tide_tier", 0)) if int(s.get("tide_tier", 0)) > 0 else "",
		"   gifts %d" % gifts if gifts > 0 else "",
		"   fish %d" % s.get("fish", []).size() if s.get("fish", []).size() > 0 else ""]
	if Game.has_suspended():
		var r: Dictionary = s.suspended
		var b: Dictionary = Run.BIOMES[clampi(int(r.get("biome", 0)), 0, Run.BIOMES.size() - 1)]
		info.text += "\nthe night waits at the shore:  %s %d / %d,  %s" % [
			str(b.name).to_lower(), int(r.get("depth", 0)) + 1, int(b.length) + 1, Weapon.name_of(str(r.get("weapon", "gaff"))).to_lower()]
	elif Quests.fen_ready():
		info.text += "\nFen has something for you"


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
	elif "--aspects" in args:
		open_aspects(Game.weapon_id())
	elif "--wren" in args:
		open_wren()
	elif "--maren" in args:
		open_maren()
	elif "--nessa" in args:
		open_nessa()
	elif "--idris" in args:
		open_idris()
	elif "--aldous" in args:
		open_aldous()
	elif "--pell" in args:
		open_pell()
	elif "--choir" in args:
		open_choir()
	elif "--cosmetics" in args:
		open_cosmetics()
	elif "--log" in args:
		log_ui.open(0)
	elif "--quests" in args:
		log_ui.open(1)
	elif "--contracts" in args:
		log_ui.open(2)
	elif "--gift" in args:
		gift("bram")
		for i in 90:
			await get_tree().process_frame
	elif "--pause" in args:
		$Pause.toggle()
	elif "--fen" in args:
		open_fen()
	elif "--codex" in args:
		codex_ui.open(0)
	elif "--codex2" in args:
		codex_ui.open(1)
	elif "--settings" in args:
		$SettingsUI.open()
	else:
		for a in args:
			if a.begins_with("--ending="):
				ending_ui.play(a.trim_prefix("--ending="))
				for i in 220:
					await get_tree().process_frame
			elif a.begins_with("--codex="):
				codex_ui.open(int(a.trim_prefix("--codex=")))
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	print("screenshot -> %s/hub.png (%s)" % [dir, error_string(img.save_png(dir + "/hub.png"))])
	get_tree().quit()
