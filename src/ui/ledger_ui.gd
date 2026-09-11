class_name LedgerUI
extends CanvasLayer
## Orla's Ledger screen. Keys 1-6 buy the next tier, E closes.

signal closed

var is_open: bool = false
var _root: Control
var _rows: Array = []
var _pearls_label: Label
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3
	visible = false


static func orla_line() -> String:
	var s := SaveManager.data
	if int(s.wins) > 0:
		return "You broke the Wreck. Past the flats the water hides streets, Tam. Saltmere's streets."
	match int(s.runs):
		0: return "Maren walked into the ruins with that lantern and did not come back. Keep the tide, Tam. Whatever that means."
		1, 2: return "You came back. The lantern brought you back. They say it always does."
		3, 4, 5: return "Every keeper before Maren went down there too. Nobody in the village talks about that."
		_: return "The sea goes out further each night. I don't think it is leaving. I think it is showing us something."


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


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k >= KEY_1 and k <= KEY_1 + Ledger.UPGRADES.size() - 1:
			_buy(k - KEY_1)
			get_viewport().set_input_as_handled()


func _buy(i: int) -> void:
	var u: Dictionary = Ledger.UPGRADES[i]
	if Ledger.buy(u.id):
		_hint.text = "%s  tier %d" % [u.name.to_lower(), Ledger.tier(u.id)]
		_hint.modulate = Color(0.75, 0.95, 0.8)
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
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.custom_minimum_size = Vector2(300, 0)
	panel.add_child(box)
	box.add_child(UI.label("ORLA'S LEDGER", 16, Color(0.95, 0.85, 0.6), HORIZONTAL_ALIGNMENT_CENTER))
	var line := UI.label("\"%s\"" % orla_line(), 8, Color(0.75, 0.75, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(300, 0)
	box.add_child(line)
	box.add_child(UI.spacer(4))
	_rows = []
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	for i in Ledger.UPGRADES.size():
		var u: Dictionary = Ledger.UPGRADES[i]
		var a := UI.label("[%d] %s" % [i + 1, u.name], 8)
		var b := UI.label(u.desc, 8, Color(0.7, 0.75, 0.8))
		var c := UI.label("", 8, Color(0.92, 0.92, 0.98), HORIZONTAL_ALIGNMENT_RIGHT)
		grid.add_child(a)
		grid.add_child(b)
		grid.add_child(c)
		_rows.append([a, b, c])
	box.add_child(grid)
	box.add_child(UI.spacer(4))
	_pearls_label = UI.label("", 8, Color(0.92, 0.92, 0.98), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_pearls_label)
	_hint = UI.label(" ", 8, Color(0.75, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_hint)
	box.add_child(UI.label("[E]  leave", 8, Color(0.7, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	_root = center
	_refresh()


func _refresh() -> void:
	_pearls_label.text = "you have %d pearls" % int(SaveManager.data.pearls)
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
