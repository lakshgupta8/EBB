class_name NetOverlay
extends CanvasLayer
## F3 shows what the connection is doing (RTT, bandwidth, snapshots, corrections); F4 opens
## sliders that put a bad network on it (latency, jitter, loss), for demos and for the report.

var _label: Label
var _panel: VBoxContainer
var _sliders: Dictionary = {}


static func format_report(r: Dictionary, cond: Dictionary) -> String:
	return "net\nrtt %3.0f ms   jitter %3.0f ms\nin %d B/s   out %d B/s\nsnap %d/s   lost %d\ncorr %d (%.1f px)   underruns %d\nsim %d ms +%d ms   loss %d%%" % [
		float(r.get("rtt", 0.0)), float(r.get("jitter", 0.0)), int(r.get("bytes_in", 0)), int(r.get("bytes_out", 0)),
		int(r.get("snaps_per_s", 0)), int(r.get("lost", 0)), int(r.get("corrections", 0)),
		float(r.get("mean_correction", 0.0)), int(r.get("underruns", 0)),
		int(cond.get("latency", 0)), int(cond.get("jitter", 0)), int(round(float(cond.get("loss", 0.0)) * 100.0))]


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = UI.label("", 8, UI.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_label.position = Vector2(400, 4)
	_label.size = Vector2(232, 80)
	_label.visible = false
	add_child(_label)
	_panel = VBoxContainer.new()
	_panel.position = Vector2(440, 90)
	_panel.custom_minimum_size = Vector2(190, 0)
	_panel.visible = false
	add_child(_panel)
	for spec in [["latency", 0.0, 300.0, 1.0], ["jitter", 0.0, 100.0, 1.0], ["loss", 0.0, 0.2, 0.01]]:
		var row := VBoxContainer.new()
		row.add_child(UI.label(str(spec[0]), 8, UI.SECONDARY))
		var s := HSlider.new()
		s.min_value = spec[1]
		s.max_value = spec[2]
		s.step = spec[3]
		s.custom_minimum_size = Vector2(180, 10)
		s.value_changed.connect(func(_v): _apply())
		row.add_child(s)
		_panel.add_child(row)
		_sliders[spec[0]] = s


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			_label.visible = not _label.visible
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F4:
			_panel.visible = not _panel.visible
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _label.visible or Net.transport == null:
		return
	var t := Net.transport
	_label.text = format_report(t.stats.report(Time.get_ticks_msec()),
			{"latency": t.sim_out.latency_ms, "jitter": t.sim_out.jitter_ms, "loss": t.sim_out.loss})


func _apply() -> void:
	if Net.transport != null:
		Net.transport.set_conditions(int(_sliders["latency"].value), int(_sliders["jitter"].value), float(_sliders["loss"].value))
