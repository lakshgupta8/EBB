class_name LedgerUI
extends CanvasLayer
## Orla's Ledger screen: five branches as tabs (A / D or click), the branch's nodes as rows
## (click or press 1-5 to buy the next tier), the spring tide gauge on T, a gift on G.
## E / Esc / Leave closes.

signal closed
signal gift_requested

var is_open: bool = false
var _root: Control
var _rows: Array = []
var _branch: int = 0
var _tab_buttons: Array = []
var _rows_box: VBoxContainer
var _pearls_label: Label
var _hint: Label
var _cursor: UI.Cursor
var _tide_btn: Button
var _tide_label: Label
var _tide_desc: Label
var _gift_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3
	visible = false


static func orla_line() -> String:
	return Story.orla()


func open() -> void:
	if is_open:
		return
	is_open = true
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
		return
	var i := UI.menu_index(event)
	var nav := UI.nav(event)
	if i >= 0 and i < _rows.size():
		_buy(i)
		get_viewport().set_input_as_handled()
	elif _tide_btn and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		_cycle_tide()
		get_viewport().set_input_as_handled()
	elif _gift_btn and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		_gift()
		get_viewport().set_input_as_handled()
	elif nav == "left" or nav == "right":
		_set_branch(wrapi(_branch + (1 if nav == "right" else -1), 0, Ledger.BRANCHES.size()))
		get_viewport().set_input_as_handled()
	elif nav != "" and _cursor.handle(nav):
		get_viewport().set_input_as_handled()
	elif UI.is_close(event) or nav == "accept":
		close()
		get_viewport().set_input_as_handled()


func _branch_nodes() -> Array:
	return Ledger.in_branch(Ledger.BRANCHES[_branch])


func _buy(i: int) -> void:
	var u: Dictionary = _branch_nodes()[i]
	if Ledger.buy(u.id):
		_hint.text = "%s  tier %d" % [u.name.to_lower(), Ledger.tier(u.id)]
		UI.hint_kind(_hint, "ok")
		Audio.play("buy")
	else:
		var why := Ledger.locked_reason(u.id)
		_hint.text = "already complete" if Ledger.next_cost(u.id) < 0 else (why if why != "" else "not enough pearls")
		UI.hint_kind(_hint, "bad")
	_refresh()


func _gift() -> void:
	close()
	gift_requested.emit()


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
	box.add_child(UI.header("ORLA'S LEDGER"))
	var line := UI.label("\"%s\"" % orla_line(), 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(470, 0)
	box.add_child(line)
	box.add_child(UI.spacer(2))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_tab_buttons = []
	for i in Ledger.BRANCHES.size():
		var b := UI.tab_button("", false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_branch.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	box.add_child(tabs)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 3)
	box.add_child(_rows_box)
	# The spring tide gauge, once the Ebb has fallen: a harder night for more pearls.
	_tide_btn = null
	if int(SaveManager.data.get("tide_unlocked", 0)) > 0:
		_tide_btn = UI.row_button()
		var th := HBoxContainer.new()
		th.add_theme_constant_override("separation", 8)
		_tide_label = UI.label("", 8, UI.PRIMARY)
		_tide_label.custom_minimum_size = Vector2(130, 0)
		_tide_desc = UI.flex_label("")
		th.add_child(_tide_label)
		th.add_child(_tide_desc)
		_tide_btn.add_child(th)
		UI.fill(th, 6.0, 4.0)
		_tide_btn.custom_minimum_size = Vector2(450, 20)
		_tide_btn.pressed.connect(_cycle_tide)
		box.add_child(_tide_btn)
	_gift_btn = null
	if Story.affinity("orla") < Dialog.chain_count("orla") and int(SaveManager.data.get("glass", 0)) + int(SaveManager.data.get("shells", 0)) > 0:
		_gift_btn = UI.text_button("Give Orla a gift   [G]   (affinity %d / %d)" % [Story.affinity("orla"), Dialog.chain_count("orla")])
		_gift_btn.pressed.connect(_gift)
		box.add_child(_gift_btn)
	box.add_child(UI.spacer(2))
	_pearls_label = UI.label("", 8, UI.PRIMARY, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_pearls_label)
	_hint = UI.label(" ", 8, UI.PRIMARY, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_hint)
	var leave := UI.text_button("Leave   " + UI.hint("interact"))
	leave.pressed.connect(close)
	box.add_child(leave)
	_set_branch(_branch)


func _set_branch(i: int) -> void:
	_branch = i
	for j in _tab_buttons.size():
		var id: String = Ledger.BRANCHES[j]
		var b: Button = _tab_buttons[j]
		var open := Ledger.branch_open(id)
		b.text = ("%s" if open else "%s (locked)") % Ledger.BRANCH_NAME[id]
		UI.set_tab_active(b, j == i)
		if not open and j != i:
			b.add_theme_color_override("font_color", UI.MUTED)
	for c in _rows_box.get_children():
		c.queue_free()
	_rows = []
	var nodes := _branch_nodes()
	for k in nodes.size():
		var u: Dictionary = nodes[k]
		var b := UI.row_button()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var a := UI.label("[%d] %s" % [k + 1, u.name], 8)
		a.custom_minimum_size = Vector2(140, 0)
		var d := UI.flex_label(u.desc)
		var c := UI.label("", 8, UI.PRIMARY, HORIZONTAL_ALIGNMENT_RIGHT)
		c.custom_minimum_size = Vector2(96, 0)
		h.add_child(a)
		h.add_child(d)
		h.add_child(c)
		b.add_child(h)
		UI.fill(h, 6.0, 4.0)
		b.custom_minimum_size = Vector2(450, 20)
		b.pressed.connect(_buy.bind(k))
		_rows_box.add_child(b)
		_rows.append([a, d, c, b])
	var buttons: Array = _rows.map(func(r): return r[3])
	if _tide_btn:
		buttons.append(_tide_btn)
	if _gift_btn:
		buttons.append(_gift_btn)
	_cursor = UI.Cursor.new(buttons)
	_refresh()


## Turn the gauge: calm, then each unlocked tier, then round to calm again.
func _cycle_tide() -> void:
	var unlocked := int(SaveManager.data.get("tide_unlocked", 0))
	var t := (int(SaveManager.data.get("tide_tier", 0)) + 1) % (unlocked + 1)
	SaveManager.data["tide_tier"] = t
	SaveManager.save_profile()
	Audio.play("ui", 0.0, -8.0)
	_hint.text = "calm water tonight" if t == 0 else "spring tide %d: %s" % [t, str(Run.TIERS[t - 1].name).to_lower()]
	UI.hint_kind(_hint, "accent")
	_refresh()


func _refresh() -> void:
	_pearls_label.text = "you have %d pearls   %s adjust the branch" % [int(SaveManager.data.pearls), UI.hint("leftright")]
	if _tide_btn:
		var t := int(SaveManager.data.get("tide_tier", 0))
		var unlocked := int(SaveManager.data.get("tide_unlocked", 0))
		_tide_label.text = "[T] Spring tide  %d / %d" % [t, unlocked]
		_tide_desc.text = "calm water; turn it for a harder night and more pearls" if t == 0 else "%s: %s" % [Run.TIERS[t - 1].name, Run.TIERS[t - 1].desc]
	var nodes := _branch_nodes()
	for i in _rows.size():
		var u: Dictionary = nodes[i]
		var t := Ledger.tier(u.id)
		var cost := Ledger.next_cost(u.id)
		var right: Label = _rows[i][2]
		var why := Ledger.locked_reason(u.id)
		if cost < 0:
			right.text = "%d/%d  done" % [t, Ledger.max_tier(u.id)]
			right.add_theme_color_override("font_color", Palette.SEA_PALE)
		elif why != "":
			right.text = why
			right.add_theme_color_override("font_color", UI.MUTED)
		else:
			right.text = "%d/%d  %d pearls" % [t, Ledger.max_tier(u.id), cost]
			right.add_theme_color_override("font_color", UI.PRIMARY if Ledger.can_buy(u.id) else UI.MUTED)
		_rows[i][0].add_theme_color_override("font_color", UI.PRIMARY if Ledger.can_buy(u.id) else UI.SECONDARY)
