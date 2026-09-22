class_name LogUI
extends CanvasLayer
## The Keeper's Log: three tabs. Milestones (forty, with what they pay), Fen's shell chain
## and Nessa's board (the contracts on offer and those done). L opens it from the rock or a
## run when nothing else is up; 1-3 switch tabs, W S / arrows / wheel scroll, E closes.

signal closed

const TABS := ["log", "quests", "contracts"]
const TAB_NAMES := {"log": "Keeper's Log", "quests": "Fen's Shells", "contracts": "Nessa's Board"}

var is_open: bool = false
var _root: Control
var _tab: int = 0
var _tab_buttons: Array = []
var _scroll: ScrollContainer
var _list: VBoxContainer
var _count: Label
var _run: Node  # the run when opened during a night, for live contract progress


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3
	visible = false


func open(tab: int = 0, run: Node = null) -> void:
	if is_open:
		return
	is_open = true
	_run = run
	_tab = clampi(tab, 0, TABS.size() - 1)
	get_tree().paused = true
	visible = true
	if _root:
		_root.queue_free()
	_build()


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = false
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not is_open:
		# L opens it from the world (the rock or a night) when nothing else is up.
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L and not get_tree().paused:
			open(0, get_parent() if get_parent() is Run else null)
			get_viewport().set_input_as_handled()
		return
	var i := UI.menu_index(event)
	var nav := UI.nav(event)
	if i >= 0 and i < TABS.size():
		_set_tab(i)
		get_viewport().set_input_as_handled()
	elif UI.is_close(event) or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L):
		close()
		get_viewport().set_input_as_handled()
	elif nav == "left" or nav == "right":
		_set_tab(wrapi(_tab + (1 if nav == "right" else -1), 0, TABS.size()))
		get_viewport().set_input_as_handled()
	elif (nav == "up" or nav == "down") and _scroll:
		_scroll.scroll_vertical += (28 if nav == "down" else -28)
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = UI.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.custom_minimum_size = Vector2(470, 0)
	panel.add_child(box)
	box.add_child(UI.header("THE KEEPER'S LOG"))
	box.add_child(UI.spacer(2))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_tab_buttons = []
	for i in TABS.size():
		var b := UI.text_button("", 8)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	box.add_child(tabs)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(470, 214)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	box.add_child(UI.spacer(2))
	_count = UI.label("", 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_count)
	var leave := UI.text_button("Leave   " + UI.hint("interact"))
	leave.pressed.connect(close)
	box.add_child(leave)
	_set_tab(_tab)


func _set_tab(i: int) -> void:
	_tab = i
	for j in _tab_buttons.size():
		var b: Button = _tab_buttons[j]
		b.text = "[%d] %s" % [j + 1, TAB_NAMES[TABS[j]]]
		b.add_theme_color_override("font_color", UI.PRIMARY if j == i else UI.SECONDARY)
	for c in _list.get_children():
		c.queue_free()
	match TABS[i]:
		"log":
			var n := 0
			for m in KeeperLog.ALL:
				var done := KeeperLog.is_claimed(m.id)
				n += 1 if done else 0
				_list.add_child(_row(m.name, m.desc, _reward_text(m), done))
			_count.text = "%d of %d claimed" % [n, KeeperLog.ALL.size()]
		"quests":
			for k in Quests.FEN.size():
				var q: Dictionary = Quests.FEN[k]
				var idx := Quests.fen_index()
				var done := k < idx
				var current := k == idx
				var right := "a shell, %d pearls" % int(q.pearls)
				if current and Quests.fen_ready():
					right = "hand in to Fen"
				_list.add_child(_row("%d. %s" % [k + 1, q.name], q.ask if (current or done) else "...", right, done, current))
			_count.text = "Fen's chain: %d of %d" % [mini(Quests.fen_index(), Quests.FEN.size()), Quests.FEN.size()]
		"contracts":
			var offered := Contracts.offered()
			var ledger: Dictionary = _run.state.ledger() if _run else {}
			for id in offered:
				var c := Contracts.get_contract(id)
				var live := _run != null and Contracts.check(c, ledger)
				_list.add_child(_row(c.name, c.desc, _reward_text(c) + ("   done tonight" if live else ""), false, true))
			for c in Contracts.ALL:
				if c.id in Contracts.done():
					_list.add_child(_row(c.name, c.desc, "done", true))
			_count.text = "%d of %d contracts done   (three on the board each night)" % [Contracts.done().size(), Contracts.ALL.size()]
	_scroll.scroll_vertical = 0


static func _reward_text(m: Dictionary) -> String:
	var parts: Array = []
	if int(m.get("pearls", 0)) > 0:
		parts.append("%d pearls" % int(m.pearls))
	if int(m.get("shards", 0)) > 0:
		parts.append("%d shard%s" % [int(m.shards), "s" if int(m.shards) > 1 else ""])
	if m.has("cosmetic"):
		parts.append("a lantern colour")
	if m.has("fish"):
		parts.append(Fish.name_of(str(m.fish)).to_lower())
	return ", ".join(parts)


func _row(name: String, desc: String, right: String, done: bool, current: bool = false) -> Control:
	var p := UI.row_panel(UI.ACCENT if current else UI.PANEL_EDGE)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var col := Palette.SEA_PALE if done else (UI.PRIMARY if current else UI.PRIMARY)
	var a := UI.label(("+ " if done else "  ") + name, 8, col)
	a.custom_minimum_size = Vector2(150, 0)
	h.add_child(a)
	h.add_child(UI.flex_label(desc))
	var c := UI.label(right, 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_RIGHT)
	c.custom_minimum_size = Vector2(110, 0)
	h.add_child(c)
	return p
