extends Node
## The guest bot: joins a host started with `tests/sim_run.tscn -- --mp-host=PORT`, readies up,
## and plays the shared night by following and fighting what the host's snapshots show.
##   godot --headless --path . tests/sim_net_guest.tscn -- --connect=127.0.0.1 --port=24680 --ticks=1800
## Prints a `sim_net_guest:` summary and exits 0 when the guest saw what it should, else 1.

const VIEW := preload("res://src/net/client_view.tscn")

var _addr: String = "127.0.0.1"
var _port: int = NetProtocol.DEFAULT_PORT
var _ticks_to_run: int = 1800
var _view: ClientView
var _ticks: int = 0
var _done: bool = false
var _reached_coop: bool = false
var _end_reason: String = ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--connect="): _addr = a.trim_prefix("--connect=")
		elif a.begins_with("--port="): _port = int(a.trim_prefix("--port="))
		elif a.begins_with("--ticks="): _ticks_to_run = int(a.trim_prefix("--ticks="))
	Engine.max_fps = 0
	SaveManager.use_path("user://sim_net_guest.json")
	Net.state_changed.connect(_on_state)
	Net.left.connect(func(r): _end_reason = r)
	var err := Net.join(_addr, _port)
	print("sim_net_guest: joining %s:%d (%s)" % [_addr, _port, error_string(err)])
	if err != OK:
		get_tree().quit(1)


func _on_state(s: int) -> void:
	if s == NetSession.State.LOBBY:
		Net.set_ready(true)
	elif s == NetSession.State.IN_COOP and _view == null:
		_reached_coop = true
		_view = VIEW.instantiate()
		_view.bot = _bot
		add_child(_view)
		_view.session_ended.connect(func(r): _end_reason = r)
	elif s == NetSession.State.IDLE and not _done:
		_finish()


func _physics_process(_delta: float) -> void:
	if _view == null or _done:
		return
	_ticks += 1
	if _ticks >= _ticks_to_run:
		_finish()


## Walk at the nearest enemy puppet and swing; with none about, stay by the host's keeper.
func _bot(v: ClientView) -> PlayerInput:
	var i := PlayerInput.new()
	var here := v.local.global_position
	var target: Puppet = null
	var best := INF
	for p in v.puppets.values():
		if p.kind == NetReplicator.Kind.ENEMY:
			var d := here.distance_to(p.position)
			if d < best:
				best = d
				target = p
	if target == null:
		var host_p: Puppet = v.puppets.get(NetReplicator.HOST_ID)
		if host_p != null and here.distance_to(host_p.position) > 24.0:
			i.move = (host_p.position - here).normalized()
			i.aim = i.move
		return i
	var to := target.position - here
	i.aim = to.normalized()
	i.attack_held = best < 34.0
	i.attack_pressed = best < 34.0 and _ticks % 24 == 0
	i.move = to.normalized() if best > 22.0 else Vector2.ZERO
	i.dash_pressed = _ticks % 150 == 0 and best > 60.0
	return i


func _finish() -> void:
	if _done:
		return
	_done = true
	var fails: PackedStringArray = []
	if not _reached_coop:
		fails.append("never reached the co-op night")
	if _view != null:
		if _view.rooms_entered < 1:
			fails.append("never entered a room")
		if _view.snapshots < 30:
			fails.append("only %d snapshots" % _view.snapshots)
		if _view.snaps > 3 * maxi(1, _view.rooms_entered) + 3:
			fails.append("%d snap corrections in %d rooms" % [_view.snaps, _view.rooms_entered])
		print("sim_net_guest: rooms=%d snapshots=%d puppets=%d snaps=%d max_error=%.1f local=(%d,%d) ticks=%d end=%s" % [
			_view.rooms_entered, _view.snapshots, _view.puppets.size(), _view.snaps, _view.max_error,
			int(_view.local.global_position.x), int(_view.local.global_position.y), _ticks, _end_reason])
		if Net.transport != null:
			print("sim_net_guest: stats %s" % [Net.transport.stats.report(Time.get_ticks_msec())])
	for f in fails:
		printerr("sim_net_guest: FAIL " + f)
	print("sim_net_guest: " + ("OK" if fails.is_empty() else "FAILED"))
	Net.leave("")
	get_tree().quit(0 if fails.is_empty() else 1)
