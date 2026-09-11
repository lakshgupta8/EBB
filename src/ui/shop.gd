class_name Shop
extends CanvasLayer
## The Drowned Merchant. Opens over the run (paused), keys 1-4 buy, E or Esc closes.

signal closed

const ITEMS := [
	{"key": "salve", "name": "Salve", "desc": "heal 40", "price": 12, "stock": 2},
	{"key": "shell", "name": "Hardened shell", "desc": "+15 max health", "price": 20, "stock": 1},
	{"key": "wind", "name": "Second wind", "desc": "+1 dash charge this run", "price": 26, "stock": 1},
	{"key": "oil", "name": "Lamp oil", "desc": "lantern glow +60", "price": 8, "stock": 2},
]

var is_open: bool = false
var _run: Node
var _stock: Array = []
var _rows: Array = []
var _root: Control
var _salt_label: Label
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3
	visible = false


func setup(run: Node) -> void:
	_run = run


## Fresh stock each time a merchant room is entered.
func restock() -> void:
	_stock = []
	for it in ITEMS:
		_stock.append(it.stock)


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
		if k >= KEY_1 and k <= KEY_4:
			buy(k - KEY_1)
			get_viewport().set_input_as_handled()


func can_buy(i: int) -> bool:
	return _stock[i] > 0 and _run.state.salt >= ITEMS[i].price


func buy(i: int) -> bool:
	if not can_buy(i):
		if _hint:
			_hint.text = "not enough salt" if _stock[i] > 0 else "sold out"
			_hint.modulate = Color(1.0, 0.6, 0.55)
		return false
	var it: Dictionary = ITEMS[i]
	_run.state.salt -= it.price
	_stock[i] -= 1
	EventBus.salt_changed.emit(_run.state.salt)
	var p: Player = _run.player
	match it.key:
		"salve": p.health.heal(40)
		"shell":
			p.health.max_hp += 15
			p.health.heal(15)
		"wind":
			p.max_dash += 1
			p.dash_charges = p.max_dash
		"oil": p.add_glow(60.0)
	FX.burst(p.global_position, Color(0.98, 0.85, 0.45), 8, 40.0)
	_refresh()
	if _hint:
		_hint.text = "bought %s" % it.name.to_lower()
		_hint.modulate = Color(0.75, 0.95, 0.8)
	return true


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
	box.custom_minimum_size = Vector2(250, 0)
	panel.add_child(box)
	box.add_child(UI.label("THE DROWNED MERCHANT", 16, Color(0.7, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("\"Salt for salt. That is the bargain.\"", 8, Color(0.6, 0.65, 0.75), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(4))
	_rows = []
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	for i in ITEMS.size():
		var it: Dictionary = ITEMS[i]
		var a := UI.label("[%d] %s" % [i + 1, it.name], 8)
		var b := UI.label(it.desc, 8, Color(0.7, 0.75, 0.8))
		var c := UI.label("%d salt" % it.price, 8, Color(0.98, 0.9, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
		grid.add_child(a)
		grid.add_child(b)
		grid.add_child(c)
		_rows.append([a, b, c])
	box.add_child(grid)
	box.add_child(UI.spacer(4))
	_salt_label = UI.label("", 8, Color(0.98, 0.9, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_salt_label)
	_hint = UI.label(" ", 8, Color(0.75, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_hint)
	box.add_child(UI.label("[E]  leave", 8, Color(0.7, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	_root = center
	_refresh()


func _refresh() -> void:
	_salt_label.text = "you carry %d salt" % _run.state.salt
	for i in _rows.size():
		var dimmed := not can_buy(i)
		var col := Color(0.5, 0.5, 0.55) if dimmed else Color(0.95, 0.93, 0.9)
		_rows[i][0].add_theme_color_override("font_color", col)
		if _stock[i] <= 0:
			_rows[i][2].text = "sold"
			_rows[i][2].add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
