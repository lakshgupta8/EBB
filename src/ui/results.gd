extends CanvasLayer
## End-of-run card, centred with anchors so it sits right at any window size.

var _shown: bool = false


func show_result(r: Dictionary) -> void:
	visible = true
	_shown = true
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.08, 0.78)
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
	box.custom_minimum_size = Vector2(220, 0)
	panel.add_child(box)

	var title_text: String
	var title_color: Color
	if r.victory:
		title_text = "THE WRECK IS BROKEN"
		title_color = Color(0.95, 0.85, 0.6)
	elif r.taken:
		title_text = "TAKEN BY THE TIDE"
		title_color = Color(0.6, 0.8, 0.95)
	else:
		title_text = "TAKEN BY THE DEEP"
		title_color = Color(0.85, 0.5, 0.5)
	box.add_child(UI.label(title_text, 16, title_color, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(4))

	var mins := int(r.time) / 60
	var secs := int(r.time) % 60
	var rows := [
		["Rooms reached", "%d" % (r.depth + 1)],
		["Kills", "%d" % r.kills],
		["Salt left", "%d" % r.salt],
		["Pearls kept", "%d  (+%d from salt)" % [r.pearls, r.pearls_from_salt]],
		["Time", "%d:%02d" % [mins, secs]],
		["", ""],
		["Pearls total", "%d" % SaveManager.data.pearls],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 2)
	for row in rows:
		grid.add_child(UI.label(row[0], 8, Color(0.75, 0.75, 0.8)))
		grid.add_child(UI.label(row[1], 8, Color(0.95, 0.93, 0.9)))
	box.add_child(grid)
	box.add_child(UI.spacer(6))
	box.add_child(UI.label("[E]  back to the lighthouse", 8, Color(0.7, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER))


func _process(_delta: float) -> void:
	if _shown and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack")):
		_shown = false
		Game.go_to_hub()
