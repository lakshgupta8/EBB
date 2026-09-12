class_name LedgerUI
extends CanvasLayer
## Orla's Ledger screen. Click a row or press 1-6 to buy the next tier; E/Esc/Leave closes.

signal closed

var is_open: bool = false
var _root: Control
var _rows: Array = []
var _pearls_label: Label
var _hint: Label
var _cursor: UI.Cursor
var _tide_btn: Button
var _tide_label: Label
var _tide_desc: Label


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
	if i >= 0 and i < Ledger.UPGRADES.size():
		_buy(i)
		get_viewport().set_input_as_handled()
	elif _tide_btn and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		_cycle_tide()
		get_viewport().set_input_as_handled()
	elif nav != "" and _cursor.handle(nav):
		get_viewport().set_input_as_handled()
	elif UI.is_close(event) or nav == "accept":
		close()
		get_viewport().set_input_as_handled()


func _buy(i: int) -> void:
	var u: Dictionary = Ledger.UPGRADES[i]
	if Ledger.buy(u.id):
		_hint.text = "%s  tier %d" % [u.name.to_lower(), Ledger.tier(u.id)]
		_hint.modulate = Color(0.75, 0.95, 0.8)
		Audio.play("buy")
	else:
		_hint.text = "already complete" if Ledger.next_cost(u.id) < 0 else "not enough pearls"
		_hint.modulate = Color(1.0, 0.6, 0.55)
	_refresh()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.08, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.custom_minimum_size = Vector2(440, 0)
	panel.add_child(box)
	box.add_child(UI.label("ORLA'S LEDGER", 16, Color(0.95, 0.85, 0.6), HORIZONTAL_ALIGNMENT_CENTER))
	var line := UI.label("\"%s\"" % orla_line(), 8, Color(0.75, 0.75, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(440, 0)
	box.add_child(line)
	box.add_child(UI.spacer(4))
	_rows = []
	for i in Ledger.UPGRADES.size():
		var u: Dictionary = Ledger.UPGRADES[i]
		var b := UI.row_button()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var a := UI.label("[%d] %s" % [i + 1, u.name], 8)
		a.custom_minimum_size = Vector2(130, 0)
		var d := UI.flex_label(u.desc)
		var c := UI.label("", 8, Color(0.92, 0.92, 0.98), HORIZONTAL_ALIGNMENT_RIGHT)
		c.custom_minimum_size = Vector2(84, 0)
		h.add_child(a)
		h.add_child(d)
		h.add_child(c)
		b.add_child(h)
		UI.fill(h, 6.0, 4.0)
		b.custom_minimum_size = Vector2(420, 20)
		b.pressed.connect(_buy.bind(i))
		box.add_child(b)
		_rows.append([a, d, c, b])
	# The spring tide gauge, once the Ebb has fallen: a harder night for more pearls.
	_tide_btn = null
	if int(SaveManager.data.get("tide_unlocked", 0)) > 0:
		_tide_btn = UI.row_button()
		var th := HBoxContainer.new()
		th.add_theme_constant_override("separation", 8)
		_tide_label = UI.label("", 8, Color(0.75, 0.9, 1.0))
		_tide_label.custom_minimum_size = Vector2(130, 0)
		_tide_desc = UI.flex_label("")
		th.add_child(_tide_label)
		th.add_child(_tide_desc)
		_tide_btn.add_child(th)
		UI.fill(th, 6.0, 4.0)
		_tide_btn.custom_minimum_size = Vector2(420, 20)
		_tide_btn.pressed.connect(_cycle_tide)
		box.add_child(_tide_btn)
	box.add_child(UI.spacer(4))
	_pearls_label = UI.label("", 8, Color(0.92, 0.92, 0.98), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_pearls_label)
	_hint = UI.label(" ", 8, Color(0.75, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_hint)
	var leave := UI.text_button("Leave   " + UI.hint("interact"))
	leave.pressed.connect(close)
	box.add_child(leave)
	_root = center
	var buttons: Array = _rows.map(func(r): return r[3])
	if _tide_btn:
		buttons.append(_tide_btn)
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
	_hint.modulate = Color(0.75, 0.9, 1.0)
	_refresh()


func _refresh() -> void:
	_pearls_label.text = "you have %d pearls" % int(SaveManager.data.pearls)
	if _tide_btn:
		var t := int(SaveManager.data.get("tide_tier", 0))
		var unlocked := int(SaveManager.data.get("tide_unlocked", 0))
		_tide_label.text = "[T] Spring tide  %d / %d" % [t, unlocked]
		_tide_desc.text = "calm water; turn it for a harder night and more pearls" if t == 0 else "%s: %s" % [Run.TIERS[t - 1].name, Run.TIERS[t - 1].desc]
	for i in _rows.size():
		var u: Dictionary = Ledger.UPGRADES[i]
		var t := Ledger.tier(u.id)
		var cost := Ledger.next_cost(u.id)
		var right: Label = _rows[i][2]
		if cost < 0:
			right.text = "%d/%d  done" % [t, Ledger.max_tier(u.id)]
			right.add_theme_color_override("font_color", Color(0.55, 0.75, 0.6))
		else:
			right.text = "%d/%d  %d pearls" % [t, Ledger.max_tier(u.id), cost]
			right.add_theme_color_override("font_color", Color(0.92, 0.92, 0.98) if Ledger.can_buy(u.id) else Color(0.5, 0.5, 0.55))
		_rows[i][0].add_theme_color_override("font_color", Color(0.95, 0.93, 0.9) if Ledger.can_buy(u.id) else Color(0.6, 0.6, 0.65))
