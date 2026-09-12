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
		title_text = str(Run.BIOMES[clampi(int(r.get("biome", 0)), 0, Run.BIOMES.size() - 1)].won)
		if int(r.get("tier", 0)) >= 8 and int(r.get("biome", 0)) >= Run.BIOMES.size() - 1:
			title_text = "THE SEA REMEMBERS"
		title_color = Color(0.95, 0.85, 0.6)
	elif r.taken:
		title_text = "TAKEN BY THE TIDE"
		title_color = Color(0.6, 0.8, 0.95)
	else:
		title_text = "TAKEN BY THE DEEP"
		title_color = Color(0.85, 0.5, 0.5)
	box.add_child(UI.label(title_text, 16, title_color, HORIZONTAL_ALIGNMENT_CENTER))
	var why := ""
	if r.victory:
		why = "Everything you carried comes home."
	elif r.taken:
		why = "The water rose over you. Half your salt still comes home as pearls."
	else:
		why = "Your health ran out. The salt is lost; pearls and echoes come home."
	var wl := UI.label(why, 8, Color(0.9, 0.9, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl.custom_minimum_size = Vector2(300, 0)
	box.add_child(wl)
	var line := ""
	if r.victory and int(r.get("biome", 0)) >= Run.BIOMES.size() - 1:
		line = "Maren is standing on the rock. Go up and talk to her."
	elif not r.victory:
		line = Story.whisper("taken" if r.taken else "death")
	if line != "":
		var l := UI.label("\"%s\"" % line, 8, Color(0.75, 0.75, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		box.add_child(l)
	box.add_child(UI.spacer(4))

	var mins := int(r.time) / 60
	var secs := int(r.time) % 60
	var rows := [
		["Rooms reached", "%d" % (r.depth + 1)],
		["Deepest place", Run.BIOMES[int(r.get("biome", 0))].name.capitalize()],
		["Kills", "%d" % r.kills],
		["Salt left", "%d" % r.salt],
		["Pearls kept", "%d  (+%d from salt)" % [r.pearls, r.pearls_from_salt]],
		["Time", "%d:%02d" % [mins, secs]],
		["Echoes freed", str(r.get("echoes", []).size())],
		["Spring tide", "tier %d  (pearls +%d%%)" % [int(r.get("tier", 0)), 15 * int(r.get("tier", 0))]] if int(r.get("tier", 0)) > 0 else ["", ""],
		["", ""],
		["Pearls total", "%d" % SaveManager.data.pearls],
	]
	# Nessa's board: what the night paid for.
	for c in r.get("contracts", []):
		rows.insert(rows.size() - 2, ["Contract: " + str(c.name), LogUI._reward_text(c)])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 2)
	for row in rows:
		grid.add_child(UI.label(row[0], 8, Color(0.75, 0.75, 0.8)))
		grid.add_child(UI.label(row[1], 8, Color(0.95, 0.93, 0.9)))
	box.add_child(grid)
	box.add_child(UI.spacer(6))
	var back := UI.text_button("Back to the lighthouse   " + UI.hint("interact"))
	back.pressed.connect(_leave)
	box.add_child(back)


func _leave() -> void:
	if not _shown:
		return
	_shown = false
	Game.go_to_hub()


func _input(event: InputEvent) -> void:
	if _shown and (UI.is_close(event) or UI.nav(event) == "accept"):
		_leave()
		get_viewport().set_input_as_handled()
