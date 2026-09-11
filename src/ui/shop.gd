class_name Shop
extends CanvasLayer
## The Drowned Merchant. Click a row or press 1-4 to buy; E, Esc or the Leave button closes.

signal closed

const ITEMS := [
	{"key": "salve", "name": "Salve", "desc": "heal 40", "price": 12, "stock": 2},
	{"key": "shell", "name": "Hardened shell", "desc": "+15 max health", "price": 20, "stock": 1},
	{"key": "wind", "name": "Second wind", "desc": "+1 dash charge (this run)", "price": 26, "stock": 1},
	{"key": "oil", "name": "Lamp oil", "desc": "lantern glow +60", "price": 8, "stock": 2},
]

var is_open: bool = false
var _run: Node
var _stock: Array = []
var _rows: Array = []
var _root: Control
var _salt_label: Label
var _hint: Label
var _cursor: UI.Cursor


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


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var i := UI.menu_index(event)
	var nav := UI.nav(event)
	if i >= 0 and i < ITEMS.size():
		buy(i)
		get_viewport().set_input_as_handled()
	elif nav != "" and _cursor.handle(nav):
		get_viewport().set_input_as_handled()
	elif UI.is_close(event) or nav == "accept":
		close()
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
	Audio.play("buy")
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
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.custom_minimum_size = Vector2(340, 0)
	panel.add_child(box)
	box.add_child(UI.label("THE DROWNED MERCHANT", 16, Color(0.7, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("\"Salt for salt. That is the bargain.\"", 8, Color(0.6, 0.65, 0.75), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(4))
	_rows = []
	for i in ITEMS.size():
		var it: Dictionary = ITEMS[i]
		var b := UI.row_button()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var a := UI.label("[%d] %s" % [i + 1, it.name], 8)
		a.custom_minimum_size = Vector2(110, 0)
		var d := UI.flex_label(it.desc)
		var c := UI.label("%d salt" % it.price, 8, Color(0.98, 0.9, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
		c.custom_minimum_size = Vector2(50, 0)
		h.add_child(a)
		h.add_child(d)
		h.add_child(c)
		b.add_child(h)
		UI.fill(h, 6.0, 4.0)
		b.custom_minimum_size = Vector2(320, 20)
		b.pressed.connect(buy.bind(i))
		box.add_child(b)
		_rows.append([a, d, c, b])
	box.add_child(UI.spacer(4))
	_salt_label = UI.label("", 8, Color(0.98, 0.9, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_salt_label)
	_hint = UI.label(" ", 8, Color(0.75, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_hint)
	var leave := UI.text_button("Leave   " + UI.hint("interact"))
	leave.pressed.connect(close)
	box.add_child(leave)
	_root = center
	_cursor = UI.Cursor.new(_rows.map(func(r): return r[3]))
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
