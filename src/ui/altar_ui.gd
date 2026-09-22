class_name AltarUI
extends CanvasLayer
## Three tidemarks, pick one. Click a card, or press 1-3 (numpad works too).
## You cannot leave without choosing. With a Second Look in hand, R rerolls the offer.

signal chosen(id: String)
signal rerolled

var is_open: bool = false
var offers: Array = []
var rerolls: int = 0
var _root: Control
var _cursor: UI.Cursor


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3
	visible = false


func open(p_offers: Array, p_rerolls: int = 0) -> void:
	if is_open:
		return
	offers = p_offers
	rerolls = p_rerolls
	is_open = true
	get_tree().paused = true
	visible = true
	if _root:
		_root.queue_free()
	_build()


## A fresh offer while the altar is up (after a reroll).
func set_offers(p_offers: Array, p_rerolls: int) -> void:
	offers = p_offers
	rerolls = p_rerolls
	if _root:
		_root.queue_free()
	_build()
	Audio.play("altar", 0.0, -6.0)


func choose(i: int) -> void:
	if not is_open or i < 0 or i >= offers.size():
		return
	var id: String = offers[i]
	is_open = false
	get_tree().paused = false
	visible = false
	chosen.emit(id)


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var i := UI.menu_index(event)
	var nav := UI.nav(event)
	if i >= 0 and i < offers.size():
		choose(i)
		get_viewport().set_input_as_handled()
	elif rerolls > 0 and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		rerolled.emit()
		get_viewport().set_input_as_handled()
	elif nav != "" and _cursor.handle(nav):
		get_viewport().set_input_as_handled()
	elif UI.is_close(event) and not (event is InputEventMouseButton):
		# Swallow E/Esc so nothing behind the menu reacts; choosing is mandatory.
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = UI.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(270, 0)
	panel.add_child(box)
	box.add_child(UI.header("THE ALTAR OFFERS"))
	box.add_child(UI.label("Choose one tidemark. It is yours for tonight only.", 8, UI.PRIMARY, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("click a mark, or press 1-%d" % offers.size(), 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(4))
	var buttons: Array = []
	for i in offers.size():
		var m := Tidemarks.get_mark(offers[i])
		var col: Color = Tidemarks.FAMILY_COLOR[m.family]
		var b := UI.row_button(col)
		var card := HBoxContainer.new()
		card.add_theme_constant_override("separation", 6)
		card.add_child(UI.family_icon(str(m.family), true))
		var inner := VBoxContainer.new()
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_theme_constant_override("separation", 2)
		var tag := str(m.family) + ("  " + str(m.rarity) if m.has("rarity") else "") + ("  active" if m.has("active") else "")
		inner.add_child(UI.label("[%d] %s   %s" % [i + 1, m.name.to_upper(), tag], 8, Palette.TEXT.primary))
		var desc := UI.label(m.desc, 8, UI.PRIMARY)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(desc)
		card.add_child(inner)
		b.add_child(card)
		UI.fill(card, 8.0, 5.0)
		b.custom_minimum_size = Vector2(250, 32 if UI.width(m.desc) <= 238 else 42)
		b.pressed.connect(choose.bind(i))
		box.add_child(b)
		buttons.append(b)
	if rerolls > 0:
		box.add_child(UI.spacer(2))
		var r := UI.text_button("Second look   [R]   (%d left)" % rerolls)
		r.pressed.connect(func(): rerolled.emit())
		box.add_child(r)
		buttons.append(r)
	_cursor = UI.Cursor.new(buttons)
