extends TestCase
## The Net session: handshake, version refusal, lobby, timeout and save isolation. Two
## NetSessions talk over real ENet loopback, ticked by hand.


func _port() -> int:
	return randi_range(30000, 40000)


func _tick_until(sessions: Array, cond: Callable, cap: int = 600) -> bool:
	for i in cap:
		for s in sessions:
			s.tick()
		if cond.call():
			return true
		OS.delay_msec(5)
	return false


func _pair(ver_host: String = "t", ver_guest: String = "t") -> Array:
	var a := NetSession.new()
	var b := NetSession.new()
	a.version = ver_host
	b.version = ver_guest
	var port := _port()
	assert_eq(a.host(port), OK)
	assert_eq(b.join("127.0.0.1", port), OK)
	return [a, b]


func _free(pair: Array) -> void:
	for s in pair:
		s.leave("")
		s.free()


func test_handshake_reaches_lobby() -> void:
	var p := _pair()
	var ok := _tick_until(p, func(): return p[0].state == NetSession.State.LOBBY and p[1].state == NetSession.State.LOBBY)
	assert_true(ok, "both sides in the lobby")
	_free(p)


func test_version_mismatch_refused() -> void:
	var p := _pair("1.0", "2.0")
	var reasons: Array = []
	p[1].left.connect(func(r): reasons.append(r))
	_tick_until(p, func(): return not reasons.is_empty())
	assert_eq(reasons.size(), 1)
	assert_true(str(reasons[0]).contains("version"), "reason names the version: %s" % str(reasons))
	assert_eq(p[1].state, NetSession.State.IDLE)
	_free(p)


func test_lobby_ready_and_start() -> void:
	var p := _pair()
	_tick_until(p, func(): return p[1].state == NetSession.State.LOBBY)
	p[0].set_mode("pvp")
	p[1].set_ready(true)
	assert_true(not p[0].start_game(), "cannot start until both are ready")
	p[0].set_ready(true)
	_tick_until(p, func(): return p[0].guest_ready and p[1].mode == "pvp")
	assert_true(p[0].start_game())
	_tick_until(p, func(): return p[1].state == NetSession.State.IN_PVP)
	assert_eq(p[0].state, NetSession.State.IN_PVP)
	assert_eq(p[1].state, NetSession.State.IN_PVP)
	_free(p)


func test_timeout_after_5s_silence() -> void:
	var p := _pair()
	_tick_until(p, func(): return p[0].state == NetSession.State.LOBBY)
	var reasons: Array = []
	p[0].left.connect(func(r): reasons.append(r))
	_tick_until([p[0]], func(): return false, 20)  # drain what the guest already sent; it sends no more
	var t := [Time.get_ticks_msec() + 6000]
	p[0].now_ms = func(): return t[0]
	p[0].tick()
	assert_eq(reasons, ["timeout"], "left fires once, with the reason")
	assert_eq(p[0].state, NetSession.State.IDLE)
	p[0].tick()
	assert_eq(reasons.size(), 1, "and not again")
	_free(p)


func test_scratch_profile_isolated_and_restored() -> void:
	var orig := "user://test_net_orig.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(orig))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(NetSession.SCRATCH_PATH))
	SaveManager.use_path(orig)
	SaveManager.data["pearls"] = 5
	SaveManager.save_profile()
	var s := NetSession.new()
	assert_eq(s.host(_port()), OK)
	assert_eq(SaveManager.path, NetSession.SCRATCH_PATH)
	assert_eq(int(SaveManager.data["pearls"]), 5, "the host keeps their own profile in memory")
	SaveManager.data["pearls"] = 999
	SaveManager.save_profile()
	assert_true(FileAccess.file_exists(NetSession.SCRATCH_PATH))
	s.leave("")
	assert_eq(SaveManager.path, orig, "path restored")
	assert_eq(int(SaveManager.data["pearls"]), 5, "nothing earned in the session leaks back")
	assert_eq(int(JSON.parse_string(FileAccess.get_file_as_string(orig))["pearls"]), 5, "the real file was never written")
	s.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(orig))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(NetSession.SCRATCH_PATH))
	SaveManager.use_path(SaveManager.PATH)
