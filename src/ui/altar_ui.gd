class_name AltarUI
extends CanvasLayer
## Three tidemarks, pick one. Keys 1-3 choose; you cannot leave without choosing.

signal chosen(id: String)

var is_open: bool = false
var offers: Array = []
var _root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3
	visible = false


func open(p_offers: Array) -> void:
	if is_open:
		return
	offers = p_offers
	is_open = true
	get_tree().paused = true
	visible = true
	if _root:
		_root.queue_free()
	_build()


func choose(i: int) -> void:
	if not is_open or i < 0 or i >= offers.size():
		return
	var id: String = offers[i]
	is_open = false
	get_tree().paused = false
	visible = false
	chosen.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k >= KEY_1 and k <= KEY_3:
			choose(k - KEY_1)
			get_viewport().set_input_as_handled()


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
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(260, 0)
	panel.add_child(box)
	box.add_child(UI.label("THE TIDE OFFERS", 16, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("choose one mark", 8, Color(0.6, 0.65, 0.75), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(4))
	for i in offers.size():
		var m := Tidemarks.get_mark(offers[i])
		var col: Color = Tidemarks.FAMILY_COLOR[m.family]
		var row := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.16)
		style.border_color = col
		style.set_border_width_all(1)
		style.set_content_margin_all(6)
		row.add_theme_stylebox_override("panel", style)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 1)
		inner.add_child(UI.label("[%d] %s   %s" % [i + 1, m.name.to_upper(), m.family], 8, col))
		inner.add_child(UI.label(m.desc, 8, Color(0.85, 0.85, 0.9)))
		row.add_child(inner)
		box.add_child(row)
	_root = center
