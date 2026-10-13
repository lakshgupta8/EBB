extends Node
## Frame times room by room (map Stage 13b): what a night costs to draw in the large rooms.
## The bot adds one with `--perf` (run with a window, `--fast=1`); vsync is turned off so
## every frame shows its true cost. `--crowd=N` tops every fight up to N enemies.
## One line per room at the end:
##   perf: <template> 80x46 COMBAT frames=N avg=.. p50=.. p95=.. p99=.. max=.. entry=..
##         gpu=.. gpu95=.. draws95=.. enemies=.. flooded=.. nodes=..   (milliseconds)

var run: Run
var crowd: int = 0
var _rows: Array = []
var _cur: Dictionary = {}
var _last_us: int = 0
var _vp: RID
const SPIKE_MS := 33.0  # a frame this long is printed as it happens, with what was going on


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	EventBus.room_entered.connect(_on_room)
	print("perf: %s, %s, window %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(), DisplayServer.window_get_size()])


func _on_room(r: Room) -> void:
	_close()
	_cur = {"name": r.template.name, "size": "%dx%d" % [r.template.width, r.template.height],
		"type": str(RoomGraph.NAMES[run.room_type]), "frames": PackedFloat32Array(), "gpu": PackedFloat32Array(),
		"draws": PackedFloat32Array(), "entry": 0.0, "since": 0, "enemies": 0, "flooded": 0, "nodes": 0, "t0": Time.get_ticks_msec(), "way": PackedFloat32Array()}
	if crowd > 0 and run.room_type in [RoomGraph.COMBAT, RoomGraph.ELITE]:
		_top_up.call_deferred()


func _top_up() -> void:
	var n := crowd - get_tree().get_nodes_in_group("enemies").size()
	if n > 0:
		run._spawn_enemies(n, false)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := float(now - _last_us) / 1000.0
	_last_us = now
	if _cur.is_empty():
		return
	_cur.since += 1
	# The frame that built the room and the two after it are the way in: a hitch, not the fight.
	if _cur.since <= 6:
		_cur.way.append(ms)
		if _cur.since == 6:
			print("perf-way: %s %s" % [_cur.name, " ".join(Array(_cur.way).map(func(v): return "%.1f" % v))])
	if _cur.since <= 3:
		_cur.entry = maxf(_cur.entry, ms)
		return
	if get_tree().paused or run._transitioning:
		return
	_cur.frames.append(ms)
	if ms > SPIKE_MS:
		print("perf-spike: %.1f ms in %s at %.1f s (frame %d), enemies %d, flooded %d, paused %s" % [ms, _cur.name,
			float(Time.get_ticks_msec() - _cur.t0) / 1000.0, _cur.since, get_tree().get_nodes_in_group("enemies").size(),
			run.room._flooded.size() if run.room != null else 0, get_tree().paused])
	_cur.gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp))
	_cur.draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_cur.enemies = maxi(_cur.enemies, get_tree().get_nodes_in_group("enemies").size())
	if run.room != null:
		_cur.flooded = maxi(_cur.flooded, run.room._flooded.size())
	_cur.nodes = maxi(_cur.nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))


func _close() -> void:
	if not _cur.is_empty() and _cur.frames.size() > 30:
		_rows.append(_cur)
	_cur = {}


static func _pct(a: PackedFloat32Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[clampi(int(p * float(s.size() - 1)), 0, s.size() - 1)]


static func _avg(a: PackedFloat32Array) -> float:
	var t := 0.0
	for v in a:
		t += v
	return t / maxf(1.0, float(a.size()))


func report() -> void:
	_close()
	for r in _rows:
		print("perf: %s %s %s frames=%d avg=%.2f p50=%.2f p95=%.2f p99=%.2f max=%.2f entry=%.1f gpu=%.2f gpu95=%.2f draws95=%d enemies=%d flooded=%d nodes=%d" % [
			r.name, r.size, r.type, r.frames.size(), _avg(r.frames), _pct(r.frames, 0.5), _pct(r.frames, 0.95),
			_pct(r.frames, 0.99), _pct(r.frames, 1.0), r.entry, _avg(r.gpu), _pct(r.gpu, 0.95), int(_pct(r.draws, 0.95)),
			r.enemies, r.flooded, r.nodes])
