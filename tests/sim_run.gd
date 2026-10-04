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
var _altar_shot: bool = false
var _props_done: Array = []
var _tag_hits: Dictionary = {}
var _heavies_fired: int = 0
var _pause_shot_tick: int = -1  # open the pause menu at this tick and screenshot it
var _rooms_seen: Array = []
var _stuck_t: int = 0
var _last_pos: Vector2
var _weapon: String = "gaff"
var _rescued: Array = []
var _must_win: bool = false
var _shot_depths: Array = []
var _shot_boss: bool = false
var _shot_pending: int = -1
var _shot_name: String = ""
var _rest_at: int = -1     # --rest-at=N: rest at the first cleared room past this depth, resume, play on
var _shot_clear: int = -1  # --shot-clear=N: screenshot a moment after the room at this depth is cleared
var _tier: int = 0         # --tier=N: play at that spring tide
var _prefer_wet: bool = false  # --take-wet: take the wet door at every fork
var _actives_used: int = 0
var _fish_eaten: int = 0
var _resume_ok: bool = true


func _ready() -> void:
	var seed_val := 1234
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ticks="): ticks_to_run = int(a.trim_prefix("--ticks="))
		elif a.begins_with("--shot="): _shot_tick = int(a.trim_prefix("--shot="))
		elif a.begins_with("--seed="): seed_val = int(a.trim_prefix("--seed="))
		elif a == "--shot-end": _shot_end = true
		elif a == "--shop-shot": _shop_shot = true
		elif a == "--altar-shot": _altar_shot = true
		elif a.begins_with("--pause-shot="): _pause_shot_tick = int(a.trim_prefix("--pause-shot="))
		elif a.begins_with("--weapon="): _weapon = a.trim_prefix("--weapon=")
		elif a == "--must-win": _must_win = true
		elif a.begins_with("--shot-depth="):
			for d in a.trim_prefix("--shot-depth=").split(","):
				_shot_depths.append(int(d))
		elif a == "--shot-boss": _shot_boss = true
		elif a.begins_with("--rest-at="): _rest_at = int(a.trim_prefix("--rest-at="))
		elif a.begins_with("--shot-clear="): _shot_clear = int(a.trim_prefix("--shot-clear="))
		elif a.begins_with("--tier="): _tier = int(a.trim_prefix("--tier="))
		elif a == "--take-wet": _prefer_wet = true
		elif a.begins_with("--mode="): Game.mode = a.trim_prefix("--mode=")
		elif a.begins_with("--fast="):
			# Run the night N times faster: more physics ticks per real second, the same
			# delta each, so nothing in the fight changes but the wall clock.
			var n := clampi(int(a.trim_prefix("--fast=")), 1, 8)
			Juice.base = float(n)
			Engine.time_scale = float(n)
			Engine.physics_ticks_per_second = 60 * n
			Engine.max_physics_steps_per_frame = 8 * n
	Engine.max_fps = 0
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep driving while the shop pauses the tree
	seed(seed_val)  # enemies use the global RNG; seeding it makes a bot run reproducible
	# `--profile=name` keeps a bot off the screenshot profile when both run at once.
	var profile := "sim_save"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--profile="):
			profile = a.trim_prefix("--profile=")
	SaveManager.use_path("user://%s.json" % profile)
	SaveManager.data["weapon"] = _weapon
	for a in OS.get_cmdline_user_args():
		if a == "--fresh":
			SaveManager.wipe()
			SaveManager.data["weapon"] = _weapon
	SaveManager.data["tide_tier"] = _tier
	SaveManager.data["tide_unlocked"] = maxi(int(SaveManager.data.get("tide_unlocked", 0)), _tier)
	if "--fish" in OS.get_cmdline_user_args():
		SaveManager.data["fish"] = ["eel", "broth", "cod"]
	Game.run_seed = seed_val
	run = RUN.instantiate()
	EventBus.room_entered.connect(func(r): _rooms_seen.append(RoomGraph.NAMES[run.room_type] + ":" + r.template.name))
	EventBus.room_cleared.connect(func(_r):
		if run.room_type == RoomGraph.ECHO and run.cage_echo != "":
			_rescued.append(run.cage_echo)
		if run.state.depth_total == _shot_clear:
			_shot_clear = -1
			_shot_pending = tick + 70
			_shot_name = "sim_clear.png"
	)
	EventBus.damage_dealt.connect(func(target, info):
		if target is Enemy:
			for t in ["melee", "heavy", "lunge", "crit", "hook", "wake", "bleed", "wall", "flare", "third_hit", "knife", "finisher", "net", "projectile", "harpoon", "tether", "light", "beacon"]:
				if info.tags.has(t):
					_tag_hits[t] = _tag_hits.get(t, 0) + 1
	)
	add_child(run)
	player = run.player
	print("sim_run: seed %d, %d ticks" % [seed_val, ticks_to_run])


func _physics_process(_delta: float) -> void:
	tick += 1
	if tick == _shot_tick:
		_screenshot("sim_run.png")
	if tick == _pause_shot_tick:
		_pause_screenshot()
	if run.state.depth_total in _shot_depths and not run._transitioning:
		_shot_depths.erase(run.state.depth_total)
		_shot_pending = tick + 45
		_shot_name = "sim_depth_%d.png" % run.state.depth_total
	if _shot_boss and run.state.biome >= 1 and run.boss != null and is_instance_valid(run.boss):
		_shot_boss = false
		_shot_pending = tick + 150
		_shot_name = "sim_boss.png"
	if _shot_pending == tick:
		_shot_pending = -1
		_screenshot(_shot_name)
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
		# Something you cannot walk to comes last, so the fight goes on while it is stuck.
		if run.room.nav_path(player.global_position, e.global_position).is_empty():
			d += 10000.0
		if d < best_d:
			best_d = d
			best = e
	return best


func _drive() -> void:
	_release_all()
	_stall_watch()
	if run.altar_ui.is_open:
		if _altar_shot:
			_altar_shot = false
			await _screenshot("sim_altar.png")
		# An active mark when one is offered (so R gets exercised), else the first card.
		var pick := 0
		for i in run.altar_ui.offers.size():
			if Tidemarks.is_active(run.altar_ui.offers[i]):
				pick = i
		print("sim_run: took %s" % run.altar_ui.offers[pick])
		run.altar_ui.choose(pick)
		return
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
	# Deep water bites every half second and it is what drowns a bot. Wade out of it while
	# there is a fight on, but never instead of leaving a room that is done with: once the
	# doors are open the way out beats dry feet, and after three seconds of wading, so does
	# the fight.
	var fighting := not get_tree().get_nodes_in_group("enemies").is_empty()
	if run.state.depth_total != _avoid_room:
		_avoid_room = run.state.depth_total
		_avoid_ticks = 0
	if fighting and not player.mods.dry_feet and _avoid_ticks < AVOID_BUDGET 			and run.room.is_deep_at(player.global_position):
		# The budget is per room, not per spell in the water. Resetting it the moment the
		# keeper steps out means a pool between here and the last enemy is never crossed:
		# in, out, in, out, and the room never clears (seed 1234, flats_01).
		_avoid_ticks += 1
		var dry := _dry_spot()
		if dry != Vector2.INF:
			_walk_to(dry, 4.0)
			return
	if _rest_at >= 0 and run.state.depth_total >= _rest_at and run.can_rest():
		_rest_at = -1
		_rest_and_resume()
		return
	var target := _nearest_enemy()
	if target:
		_fight(target)
		return
	_retreat_t = 0
	# Use any prop once (reusable ones like the merchant would loop forever otherwise).
	for p in run.room.props:
		if not p.used_up and not p in _props_done and p.interactive:
			_walk_to(p.global_position, 6.0)
			if player.global_position.distance_to(p.global_position) < 14.0:
				Input.action_press("interact")
				_props_done.append(p)
			return
	# Then leave, through the door a player would take: hurt, look for water to drink and
	# stay out of rooms with no way out; whole, take what pays. Taking whichever door came
	# first walked the bot into two challenge rooms in one biome and ended the night there
	# every time (seed 1335, rooms 6 and 8).
	var doors: Array = run.room.doors.duplicate()
	if _prefer_wet:
		doors.sort_custom(func(a, b): return a.wet and not b.wet)
	else:
		doors.sort_custom(func(a, b): return _door_score(a) < _door_score(b))
	for d in doors:
		if d.is_open:
			_walk_to(d.global_position, 2.0)
			_stuck_report(d)
			return


var _no_progress: int = 0
var _progress_depth: int = -1
var _stall_depth: int = -1
var _stall_ticks: int = 0
var _wedged: bool = false
## Ninety seconds of game time in one room without getting deeper: the night is going
## nowhere, and waiting out the tick budget only hides it.
const WEDGE_TICKS := 5400


## Dumps run state whenever depth has not advanced for 20 s, so a stall is diagnosable.
func _stall_watch() -> void:
	if run.state.depth != _stall_depth:
		_stall_depth = run.state.depth
		_stall_ticks = 0
		return
	_stall_ticks += 1
	if _stall_ticks == WEDGE_TICKS and not run.state.ended:
		_wedged = true
		var names := []
		for e in get_tree().get_nodes_in_group("enemies"):
			names.append("%s:%s" % [e.display_name, e.state])
		print("sim_run: WEDGED at depth %d in %s after %d s, holding %s" % [
			run.state.depth, run.room.template.name, WEDGE_TICKS / 60, names])
		run.give_up()
		return
	if _stall_ticks % (1200 * _room_scale()) == 0:
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


## How many one-screen rooms this room is (map Stage 02): walking an L room takes longer, so
## the stall and stuck reports wait that much longer before they speak.
func _room_scale() -> int:
	var t: RoomTemplate = run.room.template
	return maxi(1, ceili(float(t.width * t.height) / (40.0 * 23.0)))


func _stuck_report(door: Door) -> void:
	if run.state.depth != _progress_depth:
		_progress_depth = run.state.depth
		_no_progress = 0
	_no_progress += 1
	if _no_progress % (600 * _room_scale()) == 0:
		var path := run.room.nav_path(player.global_position, door.global_position)
		print("sim_run: STUCK? tick=%d room=%s player=%s cell=%s door=%s cell=%s open=%s path=%d solid_here=%s" % [
			tick, run.room.template.name, player.global_position.round(), run.room.world_to_cell(player.global_position),
			door.global_position.round(), door.cell, door.is_open, path.size(),
			run.room.template.is_solid(run.room.world_to_cell(player.global_position).x, run.room.world_to_cell(player.global_position).y)])
		print("sim_run:   player vel=%s rooted=%.2f yanked=%s dashing=%s dead=%s dash=%d weapon=%s busy=%s move_mult=%.2f in_water=%s deep=%s" % [
			player.velocity.round(), player.rooted_t, player.is_yanked(), player.is_dashing(), player.dead,
			player.dash_charges, player.weapon.id, player.weapon.is_busy(), player.weapon.move_mult(),
			player.in_water, run.room.is_deep_at(player.global_position)])


var _hold_ticks: int = 0
var _lunge_next: bool = false
var _retreat_t: int = 0
## Wading out of deep water is worth this much of a room and no more; after that the
## fight matters more than dry feet.
const AVOID_BUDGET := 420
var _avoid_room: int = -1
var _avoid_ticks: int = 0
var _dry_at: Vector2 = Vector2.INF
var _dry_until: int = -1


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
	# Nessa's fish when hurt; the Choir let go when its note falters.
	if run.state.fish.size() > 0 and player.health.hp * 5 < player.health.max_hp * 2:
		Input.action_press("consume")
		_fish_eaten += 1
	if target.state == &"falter":
		_walk_to(target.global_position, 24.0)
		if dist < 34.0:
			Input.action_press("interact")
		return
	if target.display_name.contains("Choir") and tick % 60 == 0:
		print("sim_run: choir hp=%d/%d state=%s dist=%.0f" % [target.health.hp, target.health.max_hp, target.state, dist])
	for id in run.state.actives():
		if float(run.state.active_cd.get(id, 0.0)) <= 0.0 and dist < 80.0:
			Input.action_press("active")
			_actives_used += 1
			break
	if player.weapon.id == "harpoon":
		# Ranged: hang back, fire when lined up, reload by holding. No line of sight: close in.
		var ray := PhysicsRayQueryParameters2D.create(player.global_position, target.global_position, 1)
		var blocked: bool = not player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
		if dist > 110.0 or blocked:
			_walk_to(target.global_position, 40.0 if blocked else 100.0)
		elif dist < 40.0:
			_press_dir(-to)
		if dist < 150.0 and _attack_cd <= 0:
			Input.action_press("attack")
			_attack_cd = 4
		if dist < 150.0 and _special_cd <= 0 and player.weapon.special_ready():
			Input.action_press("special")
			_special_cd = 240
		if _dash_cd <= 0 and (target.state in [&"windup", &"dive", &"strike", &"chain_windup", &"pull_windup", &"wave"]) and dist < 60.0:
			_press_dir(-to)
			Input.action_press("dash")
			_dash_cd = 30
		_attack_cd -= 1
		_dash_cd -= 1
		_special_cd -= 1
		return
	var reach := 30.0
	if player.weapon.id == "line":
		reach = 42.0
	elif player.weapon.id == "bell":
		reach = 26.0
	# Nearly gone: give ground for a breath, then go back in. The breath has to be short
	# next to the fighting, or the bot kites a room forever, never clears it, and burns the
	# whole tick budget standing off a shellback (seeds 1234, net and harpoon).
	if player.health.hp * 4 < player.health.max_hp:
		_retreat_t += 1
		if _retreat_t < 45:
			_press_dir(-to)
			if _dash_cd <= 0 and dist < 40.0:
				Input.action_press("dash")
				_dash_cd = 40
			_dash_cd -= 1
			return
		if _retreat_t > 285:
			_retreat_t = 0
	if dist > reach - 8.0:
		# Always close. Waiting for a flyer to come to you deadlocks against anything that
		# keeps its distance on purpose, and the gull dives just as happily at a moving
		# target, so there is nothing to gain by standing still.
		_walk_to(target.global_position, reach - 8.0)
		# Something that runs away cannot be walked down: a tidewisp kept a gaff bot in one
		# room for the whole tick budget (seed 1234, room 8). Dash after it.
		if target.state == &"flee" and dist > reach and _dash_cd <= 0:
			_press_dir(to)
			Input.action_press("dash")
			_dash_cd = 25
	if dist < reach and _attack_cd <= 0:
		Input.action_press("attack")
		_attack_cd = 6 if player.weapon.id != "bell" else 20
		if randf() < 0.2 and player.weapon.id == "gaff":
			_hold_ticks = 75
			_heavies_fired += 1
	var special_near := player.weapon.id == "bell"  # the toll only matters up close
	if ((dist > 30.0 and dist < 90.0) if not special_near else dist < 40.0) and _special_cd <= 0 and player.weapon.special_ready():
		player.aim_dist = dist
		Input.action_press("special")
		_special_cd = 180
	if _dash_cd <= 0 and _threat_near():
		_press_dir(-to)
		Input.action_press("dash")
		_dash_cd = 30
		_lunge_next = true
	_attack_cd -= 1
	_dash_cd -= 1
	_special_cd -= 1


## Rest the night, drop the run scene, lift the night back from the profile into a fresh
## run scene, and check that nothing was lost on the way.
## Anything close enough to land a blow and already winding one up.
const WINDUPS := [&"windup", &"dive", &"strike", &"toll_windup", &"swing_windup", &"peal_windup", &"peal",
	&"chain_windup", &"pull_windup", &"slam_windup", &"wave_windup", &"wave", &"charge", &"leap"]


func _threat_near() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and is_instance_valid(e) and e.state in WINDUPS \
				and e.global_position.distance_to(player.global_position) < 52.0:
			return true
	return false


func _rest_and_resume() -> void:
	var before := run.snapshot()
	if not run.rest():
		print("sim_run: rest refused")
		_resume_ok = false
		return
	var old := run
	remove_child(old)
	old.queue_free()
	if not Game.load_suspended():
		print("sim_run: nothing suspended after rest")
		_resume_ok = false
		return
	run = RUN.instantiate()
	add_child(run)
	player = run.player
	_props_done = []
	var after := run.snapshot()
	var bad: Array = []
	for k in ["seed", "biome", "depth", "depth_total", "rooms_cleared", "kills", "salt", "pearls", "hp", "max_hp",
			"max_dash", "weapon", "tidemarks", "echoes", "room_type", "template", "rng_state", "echo_queue", "props"]:
		if str(before[k]) != str(after[k]):
			bad.append("%s %s != %s" % [k, before[k], after[k]])
	if absf(float(before.tide_level) - float(after.tide_level)) > 0.001:
		bad.append("tide %s != %s" % [before.tide_level, after.tide_level])
	if not run.resumed or not run.room_cleared:
		bad.append("not marked resumed/cleared")
	for d in run.room.doors:
		if not d.is_open:
			bad.append("door closed")
	if not get_tree().get_nodes_in_group("enemies").is_empty():
		bad.append("enemies in a rested room")
	if Game.has_suspended():
		bad.append("the night is still in the profile")
	_resume_ok = bad.is_empty()
	print("sim_run: rested at depth %d (%s, hp %d, %d tidemarks) and resumed: %s" % [
		int(before.depth_total), before.template, int(before.hp), before.tidemarks.size(), "OK" if _resume_ok else str(bad)])


## The nearest standing ground that is not deep: a ring search out from the keeper, in
## cells. One path check on the cell it settles on (a check per candidate costs more than
## the wading does), and the answer is kept for a third of a second.
func _dry_spot() -> Vector2:
	if _dry_until > tick:
		return _dry_at
	_dry_until = tick + 20
	_dry_at = Vector2.INF
	var here := run.room.world_to_cell(player.global_position)
	var t: RoomTemplate = run.room.template
	for r in range(1, 7):
		var best := Vector2.INF
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := Vector2i(here.x + dx, here.y + dy)
				if c.x < 1 or c.y < 1 or c.x >= t.width - 1 or c.y >= t.height - 1 or t.is_solid(c.x, c.y):
					continue
				var at := run.room.cell_to_world(c)
				if run.room.is_deep_at(at):
					continue
				var d := player.global_position.distance_squared_to(at)
				if d < best_d:
					best_d = d
					best = at
		if best != Vector2.INF and not run.room.nav_path(player.global_position, best).is_empty():
			_dry_at = best
			return _dry_at
	return _dry_at


## What a door is worth from here: lower is better. Health decides most of it.
func _door_score(d: Door) -> int:
	var hurt: bool = player.health.hp * 2 < player.health.max_hp
	match d.room_type:
		RoomGraph.FOUNTAIN:
			return 0 if hurt else 3
		RoomGraph.ECHO:
			return 1
		RoomGraph.ALTAR:
			return 2
		RoomGraph.TREASURE:
			return 3
		RoomGraph.SHOP:
			return 3 if run.state.salt >= 12 else 5
		RoomGraph.VAULT:
			return 3 if run.state.keys > 0 else 6
		RoomGraph.COMBAT:
			return 4
		RoomGraph.ELITE:
			return 7 if hurt else 5
		RoomGraph.DIVE:
			return 9 if hurt else 6
		RoomGraph.CHALLENGE:
			return 10 if hurt else 7
	return 5


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
		# Press each axis the body is off by more than a couple of pixels: the lanes are
		# two tiles wide and the body nearly one, so an off-centre push into a gap just
		# grinds on the corner (seed 202, flats_08).
		_press_axes(goal - player.global_position)
	# Unstick: if we have not moved for a while, dash toward the goal.
	if player.global_position.distance_to(_last_pos) < 0.5:
		_stuck_t += 1
		if _stuck_t > 90:
			Input.action_press("dash")
			_stuck_t = 0
	else:
		_stuck_t = 0
	_last_pos = player.global_position


func _press_axes(d: Vector2, slack: float = 2.0) -> void:
	if d.x > slack: Input.action_press("move_right")
	elif d.x < -slack: Input.action_press("move_left")
	if d.y > slack: Input.action_press("move_down")
	elif d.y < -slack: Input.action_press("move_up")


func _press_dir(dir: Vector2, threshold: float = 0.35) -> void:
	var n := dir.normalized()
	if n.x > threshold: Input.action_press("move_right")
	elif n.x < -threshold: Input.action_press("move_left")
	if n.y > threshold: Input.action_press("move_down")
	elif n.y < -threshold: Input.action_press("move_up")


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "attack", "special", "dash", "interact", "use_item", "active", "consume"]:
		Input.action_release(a)


func _screenshot(file: String) -> void:
	await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	print("sim_run: screenshot %s -> %s (tick=%d fade_a=%.2f paused=%s time_scale=%.2f)" % [
		file, error_string(img.save_png(dir + "/" + file)), tick, run.fade.color.a, get_tree().paused, Engine.time_scale])


func _finish() -> void:
	# A night takes a breath after it ends (the last drops are collected, the board is
	# judged, the ledger is written). Quitting on `ended` alone meant the bot never
	# exercised any of it: no contracts, no history, no daily board.
	if run.state.ended:
		var waited := 0.0
		while Game.last_result.is_empty() and waited < 4.0:
			await get_tree().create_timer(0.1, true, false, true).timeout
			waited += 0.1
	var s := run.state
	print("sim_run: %.1fs  biome=%d depth=%d total=%d  cleared=%d  kills=%d  salt=%d  pearls=%d  tide=%.2f  hp=%d  ended=%s victory=%s taken=%s weapon=%s rescued=%s" % [
		float(tick) / 60.0, s.biome, s.depth, s.depth_total, s.rooms_cleared, s.kills, s.salt, s.pearls, s.tide.level,
		player.health.hp, s.ended, s.victory, s.taken, player.weapon.id, _rescued])
	print("sim_run: rooms: " + ", ".join(_rooms_seen))
	print("sim_run: mode=%s history=%d daily_scores=%d" % [s.mode, SaveManager.data.get("history", []).size(), SaveManager.data.get("daily_scores", []).size()])
	print("sim_run: hits by tag: %s  (heavy holds started: %d, actives used: %d, fish eaten: %d)" % [_tag_hits, _heavies_fired, _actives_used, _fish_eaten])
	var done: Array = []
	for c in Game.last_result.get("contracts", []):
		done.append(str(c.id))
	print("sim_run: village: pages=%s glass=%d spared=%d contracts=%s journals=%s" % [
		str(s.stats.get("pages", 0)), int(SaveManager.data.get("glass", 0)), int(s.stats.get("spared", 0)), done, SaveManager.data.get("journals", [])])
	var ok := s.depth_total >= 2 and s.kills > 0 and (s.victory or not _must_win) and _resume_ok and not _wedged
	print("sim_run: %s" % ("OK" if ok else ("WEDGED in a room" if _wedged else "FAILED (did not progress, or did not win with --must-win)")))
	get_tree().quit(0 if ok else 1)
