extends Node
## Bot playtest. Loads the sandbox, drives the player with synthetic input for a fixed
## number of physics ticks, and reports what happened. Catches runtime errors in the
## combat code that unit tests cannot reach. Usage:
##   godot --headless --path . tests/sim_combat.tscn  [-- --ticks=900]

const MAIN := preload("res://src/sandbox.tscn")

var ticks_to_run: int = 900  # 15 s at 60 Hz
var tick: int = 0
var kills: int = 0
var hits_taken: int = 0
var damage_dealt: int = 0
var main: Node2D
var player: Player
var _attack_cd: int = 0
var _dash_cd: int = 0
var _special_cd: int = 0
var _shot_tick: int = -1  # when running with a window: save .shots/sim.png at this tick


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ticks="):
			ticks_to_run = int(a.trim_prefix("--ticks="))
		elif a.begins_with("--shot="):
			_shot_tick = int(a.trim_prefix("--shot="))
	Engine.max_fps = 0
	main = MAIN.instantiate()
	add_child(main)
	player = main.get_node("Player")
	EventBus.enemy_died.connect(func(_e): kills += 1)
	EventBus.damage_dealt.connect(func(target, info):
		if target is Enemy:
			damage_dealt += info.amount
	)
	player.health.damaged.connect(func(_i): hits_taken += 1)
	print("sim: running %d ticks" % ticks_to_run)


func _physics_process(_delta: float) -> void:
	tick += 1
	if tick >= ticks_to_run or player.dead:
		_finish()
		return
	_drive()
	if tick == _shot_tick:
		_screenshot()


func _screenshot() -> void:
	await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	print("sim: screenshot -> %s" % error_string(img.save_png(dir + "/sim.png")))


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
	var target := _nearest_enemy()
	_release_all()
	if target == null:
		return
	var to := target.global_position - player.global_position
	player.aim_override = to
	var dist := to.length()
	# Approach until in swing range, then stand and swing; back off if hurt recently.
	if dist > 22.0:
		_press_dir(to)
	if dist < 30.0 and _attack_cd <= 0:
		Input.action_press("attack")
		_attack_cd = 6
	if dist > 50.0 and dist < 90.0 and _special_cd <= 0 and player.weapon.special_ready():
		Input.action_press("special")
		_special_cd = 180
	# Dash away when a shellback is winding up next to us, or a gull is diving.
	if _dash_cd <= 0 and (target.state == &"windup" or target.state == &"dive") and dist < 40.0:
		_press_dir(-to)
		Input.action_press("dash")
		_dash_cd = 30
	_attack_cd -= 1
	_dash_cd -= 1
	_special_cd -= 1


func _press_dir(dir: Vector2) -> void:
	if dir.x > 0.3: Input.action_press("move_right")
	elif dir.x < -0.3: Input.action_press("move_left")
	if dir.y > 0.3: Input.action_press("move_down")
	elif dir.y < -0.3: Input.action_press("move_up")


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "attack", "special", "dash"]:
		Input.action_release(a)


func _finish() -> void:
	var t := float(tick) / 60.0
	print("sim: %.1fs  kills=%d  damage_dealt=%d  hits_taken=%d  hp=%d/%d  wave=%d  dead=%s" % [
		t, kills, damage_dealt, hits_taken, player.health.hp, player.health.max_hp, main._wave, player.dead])
	var ok := kills > 0 and damage_dealt > 0
	print("sim: %s" % ("OK" if ok else "FAILED (bot never killed anything)"))
	get_tree().quit(0 if ok else 1)
