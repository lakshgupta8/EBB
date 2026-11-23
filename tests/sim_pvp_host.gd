extends Node
## The host bot for a duel: opens a session, waits for the guest bot (tests/sim_net_guest.gd
## --mode=pvp), starts the arena and fights the guest until the match is decided.
##   godot --headless --path . tests/sim_pvp_host.tscn -- --port=24680

const ARENA := preload("res://src/multiplayer/pvp_arena.tscn")

var _port: int = NetProtocol.DEFAULT_PORT
var _max_ticks: int = 60 * 300
var _arena: PvpArena
var _ticks: int = 0
var _done: bool = false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="): _port = int(a.trim_prefix("--port="))
		elif a.begins_with("--max-ticks="): _max_ticks = int(a.trim_prefix("--max-ticks="))
	Engine.max_fps = 0
	SaveManager.use_path("user://sim_pvp_host.json")
	if Net.host(_port) != OK:
		print("sim_pvp_host: could not host")
		get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	while Net.state != NetSession.State.LOBBY:
		if Time.get_ticks_msec() - t0 > 90000:
			print("sim_pvp_host: no guest arrived")
			get_tree().quit(1)
			return
		await get_tree().process_frame
	Net.set_mode("pvp")
	Net.set_ready(true)
	while not Net.guest_ready:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout  # let the mode reach the guest before the start
	Net.start_game()
	print("sim_pvp_host: duel starts")
	_arena = ARENA.instantiate()
	add_child(_arena)


func _physics_process(_delta: float) -> void:
	if _arena == null or _done:
		return
	_ticks += 1
	var me := _arena.host
	var them := _arena.ally
	var to := them.global_position - me.global_position
	var dist := to.length()
	var inp := PlayerInput.new()
	inp.aim = to.normalized()
	inp.move = to.normalized() if dist > 24.0 else Vector2.ZERO
	inp.attack_held = dist < 36.0
	inp.attack_pressed = dist < 36.0 and _ticks % 20 == 0
	inp.dash_pressed = _ticks % 170 == 0 and dist > 70.0
	me.net_input = inp
	if _arena.rules.match_over:
		_done = true
		print("sim_pvp_host: match over, wins=%s rounds=%d ticks=%d" % [_arena.rules.wins, _arena.rules.round - 1, _ticks])
		print("sim_pvp_host: stats %s" % [Net.transport.stats.report(Time.get_ticks_msec()) if Net.transport != null else {}])
		get_tree().quit(0)  # at once: the guest leaving would send the arena back to the menu under us
	elif _ticks > _max_ticks:
		_done = true
		print("sim_pvp_host: TIMEOUT, wins=%s" % [_arena.rules.wins])
		get_tree().quit(1)
