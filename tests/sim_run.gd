extends Node
## Bot plays a whole run: fights what is in the room, uses props, walks through the
## first open door, repeats until the run ends or the tick budget runs out.
##   godot --headless --path . tests/sim_run.tscn -- --ticks=6000 [--seed=N] [--shot=T]

const RUN := preload("res://src/run/run.tscn")

var ticks_to_run: int = 6000
var tick: int = 0
var run: Run
var player: Player
var _attack_cd: int = 0
var _dash_cd: int = 0
var _special_cd: int = 0
var _shot_tick: int = -1  # when running with a window: save .shots/sim_run.png at this tick
var _shot_end: bool = false  # also screenshot the results card
var _finishing: bool = false
var _shop_shot: bool = false
var _props_done: Array = []
var _pause_shot_tick: int = -1  # open the pause menu at this tick and screenshot it
var _rooms_seen: Array = []
var _stuck_t: int = 0
var _last_pos: Vector2


func _ready() -> void:
	var seed_val := 1234
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ticks="): ticks_to_run = int(a.trim_prefix("--ticks="))
		elif a.begins_with("--shot="): _shot_tick = int(a.trim_prefix("--shot="))
		elif a.begins_with("--seed="): seed_val = int(a.trim_prefix("--seed="))
		elif a == "--shot-end": _shot_end = true
		elif a == "--shop-shot": _shop_shot = true
		elif a.begins_with("--pause-shot="): _pause_shot_tick = int(a.trim_prefix("--pause-shot="))
	Engine.max_fps = 0
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep driving while the shop pauses the tree
	seed(seed_val)  # enemies use the global RNG; seeding it makes a bot run reproducible
	SaveManager.use_path("user://sim_save.json")
	Game.run_seed = seed_val
	run = RUN.instantiate()
	EventBus.room_entered.connect(func(r): _rooms_seen.append(RoomGraph.NAMES[run.room_type] + ":" + r.template.name))
	add_child(run)
	player = run.player
	print("sim_run: seed %d, %d ticks" % [seed_val, ticks_to_run])


func _physics_process(_delta: float) -> void:
	tick += 1
	if tick == _shot_tick:
		_screenshot("sim_run.png")
	if tick == _pause_shot_tick:
		_pause_screenshot()
	if _finishing:
		return
	if tick >= ticks_to_run or run.state.ended:
		_finishing = true
		if _shot_end and run.state.ended:
			await get_tree().create_timer(1.8, true, false, true).timeout
			await _screenshot("sim_results.png")
		_finish()
		return
	_drive()


func _pause_screenshot() -> void:
	var pm = run.get_node("Pause")
	pm.toggle()
	await get_tree().process_frame
	await get_tree().process_frame
	await _screenshot("sim_pause.png")
	pm.toggle()


func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _drive() -> void:
	_release_all()
	_stall_watch()
	if run.shop.is_open:
		if _shop_shot:
			_shop_shot = false
			await _screenshot("sim_shop.png")
		# Buy the first affordable thing, then leave.
		for i in Shop.ITEMS.size():
			if run.shop.can_buy(i):
				run.shop.buy(i)
				print("sim_run: bought %s" % Shop.ITEMS[i].name)
				break
		run.shop.close()
		return
	if run._transitioning or player.dead:
		return
	var target := _nearest_enemy()
	if target:
		_fight(target)
		return
	# Use any prop once (reusable ones like the merchant would loop forever otherwise).
	for p in run.room.props:
		if not p.used_up and not p in _props_done:
			_walk_to(p.global_position, 6.0)
			if player.global_position.distance_to(p.global_position) < 14.0:
				Input.action_press("interact")
				_props_done.append(p)
			return
	# Then leave through the first open door.
	for d in run.room.doors:
		if d.is_open:
			_walk_to(d.global_position, 2.0)
			_stuck_report(d)
			return


var _no_progress: int = 0
var _progress_depth: int = -1
var _stall_depth: int = -1
var _stall_ticks: int = 0


## Dumps run state whenever depth has not advanced for 20 s, so a stall is diagnosable.
func _stall_watch() -> void:
	if run.state.depth != _stall_depth:
		_stall_depth = run.state.depth
		_stall_ticks = 0
		return
	_stall_ticks += 1
	if _stall_ticks % 1200 == 0:
		var enemies := get_tree().get_nodes_in_group("enemies")
		var names := []
		for e in enemies:
			names.append("%s@%s:%s" % [e.display_name, e.global_position.round(), e.state])
		var doors := []
		for d in run.room.doors:
			doors.append("%s:%s" % [d.cell, d.is_open])
		print("sim_run: STALL tick=%d depth=%d room=%s transitioning=%s cleared=%s player=%s hp=%d enemies=%s doors=%s" % [
			tick, run.state.depth, run.room.template.name, run._transitioning, run.room_cleared,
			player.global_position.round(), player.health.hp, names, doors])


func _stuck_report(door: Door) -> void:
	if run.state.depth != _progress_depth:
		_progress_depth = run.state.depth
		_no_progress = 0
	_no_progress += 1
	if _no_progress % 600 == 0:
		var path := run.room.nav_path(player.global_position, door.global_position)
		print("sim_run: STUCK? tick=%d room=%s player=%s cell=%s door=%s cell=%s open=%s path=%d solid_here=%s" % [
			tick, run.room.template.name, player.global_position.round(), run.room.world_to_cell(player.global_position),
			door.global_position.round(), door.cell, door.is_open, path.size(),
			run.room.template.is_solid(run.room.world_to_cell(player.global_position).x, run.room.world_to_cell(player.global_position).y)])


var _hold_ticks: int = 0
var _lunge_next: bool = false


func _fight(target: Enemy) -> void:
	var to := target.global_position - player.global_position
	player.aim_override = to
	var dist := to.length()
	# Exercise the new moves: occasional heavy (hold), lunge after a dash, flare when full.
	if _hold_ticks > 0:
		Input.action_press("attack")
		_hold_ticks -= 1
		return
	if _lunge_next:
		_lunge_next = false
		Input.action_press("attack")
	if player.glow_full():
		Input.action_press("use_item")
	if dist > 22.0:
		if target.flying:
			# Flyers come to you: hold position, keep facing, strike when it dives in.
			pass
		else:
			_walk_to(target.global_position, 22.0)
	if dist < 30.0 and _attack_cd <= 0:
		Input.action_press("attack")
		_attack_cd = 6
		if randf() < 0.2:
			_hold_ticks = 40
	if dist > 50.0 and dist < 90.0 and _special_cd <= 0 and player.weapon.special_ready():
		Input.action_press("special")
		_special_cd = 180
	if _dash_cd <= 0 and (target.state == &"windup" or target.state == &"dive") and dist < 40.0:
		_press_dir(-to)
		Input.action_press("dash")
		_dash_cd = 30
		_lunge_next = true
	_attack_cd -= 1
	_dash_cd -= 1
	_special_cd -= 1


func _walk_to(pos: Vector2, tolerance: float) -> void:
	var to := pos - player.global_position
	player.aim_override = to
	if to.length() > tolerance:
		# Follow the room's grid path; the first waypoint is our own cell, so aim at the next.
		var path := run.room.nav_path(player.global_position, pos)
		var goal := pos
		if path.size() >= 2:
			goal = path[1]
			if player.global_position.distance_to(goal) < 4.0 and path.size() >= 3:
				goal = path[2]
		elif path.size() == 1:
			goal = pos
		# Final approach: centre precisely so the body clears the door jambs.
		_press_dir(goal - player.global_position, 0.12 if goal == pos else 0.35)
	# Unstick: if we have not moved for a while, dash toward the goal.
	if player.global_position.distance_to(_last_pos) < 0.5:
		_stuck_t += 1
		if _stuck_t > 90:
			Input.action_press("dash")
			_stuck_t = 0
	else:
		_stuck_t = 0
	_last_pos = player.global_position


func _press_dir(dir: Vector2, threshold: float = 0.35) -> void:
	var n := dir.normalized()
	if n.x > threshold: Input.action_press("move_right")
	elif n.x < -threshold: Input.action_press("move_left")
	if n.y > threshold: Input.action_press("move_down")
	elif n.y < -threshold: Input.action_press("move_up")


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "attack", "special", "dash", "interact", "use_item"]:
		Input.action_release(a)


func _screenshot(file: String) -> void:
	await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	print("sim_run: screenshot %s -> %s (tick=%d fade_a=%.2f paused=%s time_scale=%.2f)" % [
		file, error_string(img.save_png(dir + "/" + file)), tick, run.fade.color.a, get_tree().paused, Engine.time_scale])


func _finish() -> void:
	var s := run.state
	print("sim_run: %.1fs  depth=%d  cleared=%d  kills=%d  salt=%d  pearls=%d  tide=%.2f  hp=%d  ended=%s victory=%s taken=%s" % [
		float(tick) / 60.0, s.depth, s.rooms_cleared, s.kills, s.salt, s.pearls, s.tide.level,
		player.health.hp, s.ended, s.victory, s.taken])
	print("sim_run: rooms: " + ", ".join(_rooms_seen))
	var ok := s.depth >= 2 and s.kills > 0
	print("sim_run: %s" % ("OK" if ok else "FAILED (did not progress past depth 2)"))
	get_tree().quit(0 if ok else 1)
