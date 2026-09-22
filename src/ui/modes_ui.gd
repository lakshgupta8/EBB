class_name ModesUI
extends CanvasLayer
## The other ways down, from the title: the daily, a seeded night, the three trials, and
## the history of the last fifty nights. Rows open with a click, a number, or the cursor
## and Enter; the seed field takes typing (S focuses it, Enter starts). E / Esc / B leaves.

signal closed
## The player picked a mode: the title runs its transition and starts the night.
signal start(mode: String, seed_value: int)

var is_open: bool = false
var page: int = 0   # 0 modes, 1 history
var _root: Control
var _cursor: UI.Cursor
var _hint: Label
var _seed_edit: LineEdit
var _buttons: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	visible = false


func open(p: int = 0) -> void:
	if is_open:
		return
	is_open = true
	page = p
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


func _typing() -> bool:
	return _seed_edit != null and is_instance_valid(_seed_edit) and _seed_edit.has_focus()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if _typing():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_seed_edit.release_focus()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_seed_edit.release_focus()
			pick("seeded")
			get_viewport().set_input_as_handled()
		return
	var i := UI.menu_index(event)
	var nav := UI.nav(event)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		set_page(1 - page)
		get_viewport().set_input_as_handled()
	elif page == 0 and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S and _seed_edit:
		_seed_edit.grab_focus()
		get_viewport().set_input_as_handled()
	elif page == 0 and i >= 0 and i < Modes.ALL.size():
		pick(str(Modes.ALL[i].id))
		get_viewport().set_input_as_handled()
	elif page == 0 and i == Modes.ALL.size():
		set_page(1)
		get_viewport().set_input_as_handled()
	elif nav != "" and _cursor.handle(nav):
		get_viewport().set_input_as_handled()
	elif UI.is_close(event) or nav == "accept":
		if page == 1:
			set_page(0)
		else:
			close()
		get_viewport().set_input_as_handled()


func set_page(p: int) -> void:
	page = p
	if _root:
		_root.queue_free()
	_build()
	Audio.play("ui", 0.0, -12.0)


## Start a mode, or say why not.
func pick(id: String) -> void:
	var why := Modes.locked_reason(id)
	if why != "":
		_say(why, false)
		return
	var seed_value := 0
	match id:
		"daily":
			if not Modes.daily_played().is_empty():
				_say("today's night is played; the sea keeps time, come back tomorrow", false)
				return
			seed_value = Modes.daily_seed()
		"seeded":
			seed_value = Modes.parse_seed(_seed_edit.text if _seed_edit else "")
			if seed_value == 0:
				seed_value = randi() % 2147483647 + 1
				if _seed_edit:
					_seed_edit.text = str(seed_value)
	Audio.play("buy")
	start.emit(id, seed_value)
	close()


func _say(text: String, good: bool) -> void:
	_hint.text = text
	UI.hint_kind(_hint, "ok" if good else "bad")
	Audio.play("ui", 0.0, -6.0)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = UI.DIM
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
	box.custom_minimum_size = Vector2(500, 0)
	panel.add_child(box)
	_buttons = []
	_seed_edit = null
	if page == 0:
		_build_modes(box)
	else:
		_build_history(box)
	_root = center
	_cursor = UI.Cursor.new(_buttons)


func _build_modes(box: VBoxContainer) -> void:
	box.add_child(UI.header("THE SEA KEEPS TIME"))
	var l := UI.label("\"Every tide has a clock in it. Idris keeps them all.\"", 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(l)
	box.add_child(UI.spacer(4))
	for i in Modes.ALL.size():
		var m: Dictionary = Modes.ALL[i]
		var why := Modes.locked_reason(str(m.id))
		var b := UI.row_button(Palette.SEA_PALE if why == "" else UI.NONE)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var a := UI.label("[%d] %s" % [i + 1, m.name], 8, UI.PRIMARY if why == "" else UI.SECONDARY)
		a.custom_minimum_size = Vector2(120, 0)
		var d := UI.flex_label(str(m.desc) if why == "" else "locked: " + why)
		h.add_child(a)
		h.add_child(d)
		var right := ""
		if m.id == "daily":
			var played := Modes.daily_played()
			right = Modes.today() if played.is_empty() else "played: %s" % _score_text(played)
		elif m.id == "seeded":
			_seed_edit = LineEdit.new()
			_seed_edit.placeholder_text = "seed  [S]"
			_seed_edit.custom_minimum_size = Vector2(110, 14)
			_seed_edit.max_length = 24
			UI.set_size(_seed_edit, 8)
			_seed_edit.add_theme_color_override("font_color", UI.PRIMARY)
			_seed_edit.add_theme_color_override("font_placeholder_color", Color(0.5, 0.55, 0.65))
			var st := StyleBoxFlat.new()
			st.bg_color = UI.INK
			st.border_color = UI.PANEL_EDGE
			st.set_border_width_all(1)
			st.set_content_margin_all(2)
			_seed_edit.add_theme_stylebox_override("normal", st)
			_seed_edit.add_theme_stylebox_override("focus", st)
			_seed_edit.mouse_filter = Control.MOUSE_FILTER_STOP
			h.add_child(_seed_edit)
		if right != "":
			var c := UI.label(right, 8, UI.PRIMARY, HORIZONTAL_ALIGNMENT_RIGHT)
			h.add_child(c)
		b.add_child(h)
		UI.fill(h, 6.0, 4.0)
		b.custom_minimum_size = Vector2(480, 20)
		b.pressed.connect(pick.bind(str(m.id)))
		box.add_child(b)
		_buttons.append(b)
	var hist := UI.row_button()
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 8)
	var ha := UI.label("[%d] History" % (Modes.ALL.size() + 1), 8)
	ha.custom_minimum_size = Vector2(120, 0)
	hh.add_child(ha)
	hh.add_child(UI.flex_label("the last fifty nights: seed, weapon, depth, marks, time, how it ended"))
	hist.add_child(hh)
	UI.fill(hh, 6.0, 4.0)
	hist.custom_minimum_size = Vector2(480, 20)
	hist.pressed.connect(set_page.bind(1))
	box.add_child(hist)
	_buttons.append(hist)
	box.add_child(UI.spacer(4))
	# The daily board: the last few, each against the bot's pace.
	var scores: Array = SaveManager.data.get("daily_scores", [])
	if scores.size() > 0:
		box.add_child(UI.label("DAILY BOARD   (bar: your time against the bot's pace for the rooms you reached)", 8, UI.SECONDARY))
		var n := mini(5, scores.size())
		for k in n:
			var s: Dictionary = scores[scores.size() - 1 - k]
			box.add_child(UI.label("%s   %s   %s" % [str(s.get("date", "")), _score_text(s), _bar(s)], 8, UI.PRIMARY))
		box.add_child(UI.spacer(2))
	if Settings.assists_on():
		box.add_child(UI.label("assists are on: pearls x%.2f, and the board says so" % Settings.assist_pearl_mult(), 8, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_hint = UI.label(" ", 8, UI.PRIMARY, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(480, 0)
	box.add_child(_hint)
	var leave := UI.text_button("Back   " + UI.hint("interact"))
	leave.pressed.connect(close)
	box.add_child(leave)
	_buttons.append(leave)


static func _score_text(s: Dictionary) -> String:
	return "room %d, %s, %s%s" % [int(s.get("depth", 0)) + 1, Modes.time_text(float(s.get("time", 0.0))),
		str(s.get("cause", "")), "  (assisted)" if bool(s.get("assisted", false)) else ""]


## Ten cells: your time as a share of par; a full bar is twice the bot's time or worse.
static func _bar(s: Dictionary) -> String:
	var par := Modes.par_seconds(int(s.get("depth", 0)) + 1)
	var frac := clampf(float(s.get("time", 0.0)) / maxf(1.0, par * 2.0), 0.0, 1.0)
	var n := int(round(frac * 10.0))
	return "[" + "#".repeat(n) + "-".repeat(10 - n) + "]" + ("  under par" if float(s.get("time", 0.0)) <= par else "")


func _build_history(box: VBoxContainer) -> void:
	box.add_child(UI.header("HISTORY"))
	var hist: Array = SaveManager.data.get("history", [])
	box.add_child(UI.label("%d of the last fifty nights   [Tab] back" % hist.size(), 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(2))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 1)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	box.add_child(scroll)
	if hist.is_empty():
		list.add_child(UI.label("no nights yet", 8, UI.SECONDARY))
	for k in hist.size():
		var h: Dictionary = hist[hist.size() - 1 - k]
		var marks: Array = h.get("marks", [])
		var n := marks.size()
		# JSON hands every number back as a float: print them as the counts they are.
		var line := "%s  %-8s %-8s seed %-11d room %2d  %d mark%s  %5s  %s%s" % [
			str(h.get("date", "")).substr(5), Modes.short_name(str(h.get("mode", "night"))),
			str(h.get("weapon", "gaff")), int(h.get("seed", 0)), int(h.get("depth", 0)) + 1,
			n, "" if n == 1 else "s", Modes.time_text(float(h.get("time", 0.0))), str(h.get("cause", "")),
			"   tier %d" % int(h.get("tier", 0)) if int(h.get("tier", 0)) > 0 else ""]
		if bool(h.get("assisted", false)):
			line += "   assisted"
		var col := UI.ACCENT if str(h.get("cause", "")) == "won" else UI.PRIMARY
		list.add_child(UI.label(line, 8, col))
	box.add_child(UI.spacer(2))
	var back := UI.text_button("Back   " + UI.hint("interact"))
	back.pressed.connect(set_page.bind(0))
	box.add_child(back)
	_buttons.append(back)
