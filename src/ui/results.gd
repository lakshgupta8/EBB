extends CanvasLayer
## End-of-run card. Built in code; E or click returns to the hub.

var _shown: bool = false


func show_result(r: Dictionary) -> void:
	visible = true
	_shown = true
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.08, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(240, 0)
	box.position = Vector2(200, 90)
	add_child(box)

	var title := Label.new()
	if r.victory:
		title.text = "THE FLATS ARE QUIET"
	elif r.taken:
		title.text = "TAKEN BY THE TIDE"
	else:
		title.text = "TAKEN BY THE DEEP"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6) if r.victory else Color(0.75, 0.8, 0.95))
	box.add_child(title)

	var mins := int(r.time) / 60
	var secs := int(r.time) % 60
	var lines := [
		"Rooms reached   %d" % (r.depth + 1),
		"Kills           %d" % r.kills,
		"Salt left       %d" % r.salt,
		"Pearls kept     %d  (+%d from salt)" % [r.pearls, r.pearls_from_salt],
		"Time            %d:%02d" % [mins, secs],
		"",
		"Pearls total    %d" % SaveManager.data.pearls,
		"",
		"[E] back to the lighthouse",
	]
	for l in lines:
		var lb := Label.new()
		lb.text = l
		lb.add_theme_font_size_override("font_size", 9)
		box.add_child(lb)


func _process(_delta: float) -> void:
	if _shown and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack")):
		_shown = false
		Game.go_to_hub()
