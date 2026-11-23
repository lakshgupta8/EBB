extends TestCase
## Fixes from the whole-branch review: pause, leaving, the handshake, snapshot acks, replay,
## duel scoring and stats growth.


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


func _session(ver: String) -> NetSession:
	var s := NetSession.new()
	s.version = ver
	return s


# --- C1: a paused tree must not stop the network -----------------------------------------------

func test_session_keeps_running_while_the_tree_is_paused() -> void:
	var s := NetSession.new()
	s._ready()
	assert_eq(s.process_mode, Node.PROCESS_MODE_ALWAYS)
	s.free()


func test_host_choosing_freezes_the_guest_until_the_choice_is_made() -> void:
	var v := ClientView.new()
	v.entities = Node2D.new()
	v.handle_event({"kind": NetProtocol.Ev.HOST_CHOOSING, "a": 1, "b": 0, "pos": Vector2.ZERO})
	assert_true(v.frozen)
	v.handle_event({"kind": NetProtocol.Ev.CHOICE_MADE, "a": 0, "b": 0, "pos": Vector2.ZERO})
	assert_true(not v.frozen)
	v.entities.free()
	v.free()


func test_clear_queue_drops_frames_waiting_from_a_pause() -> void:
	var r := NetReplicator.new()
	r.push_input_frames([{"seq": 1, "move": Vector2.RIGHT, "aim": 0.0, "buttons": 0}, {"seq": 2, "move": Vector2.RIGHT, "aim": 0.0, "buttons": 0}])
	r.clear_queue()
	assert_eq(r.queued(), 0)
	r.free()


# --- C2: going to the title leaves the session and puts the real save back ----------------------

func test_dropping_the_session_restores_the_real_save() -> void:
	var before := SaveManager.path
	assert_eq(Net.host(_port()), OK)
	assert_eq(SaveManager.path, NetSession.SCRATCH_PATH)
	Game.drop_session()
	assert_eq(Net.state, NetSession.State.IDLE)
	assert_eq(SaveManager.path, before)


# --- I1: the host's handshake survives bad visitors ---------------------------------------------

func test_a_refused_guest_does_not_end_hosting() -> void:
	var port := _port()
	var a := _session("1.0")
	var b := _session("2.0")
	assert_eq(a.host(port), OK)
	assert_eq(b.join("127.0.0.1", port), OK)
	var gone := [false]
	b.left.connect(func(_r): gone[0] = true)
	_tick_until([a, b], func(): return gone[0])
	_tick_until([a], func(): return false, 40)
	assert_eq(a.state, NetSession.State.HOSTING, "the host is still waiting")
	var c := _session("1.0")
	assert_eq(c.join("127.0.0.1", port), OK)
	assert_true(_tick_until([a, c], func(): return a.state == NetSession.State.LOBBY and c.state == NetSession.State.LOBBY), "a right-version guest can still join")
	for s in [a, b, c]:
		s.leave("")
		s.free()


func test_a_silent_peer_is_dropped_and_hosting_goes_on() -> void:
	var port := _port()
	var a := _session("t")
	assert_eq(a.host(port), OK)
	var squatter := NetTransport.new()
	assert_eq(squatter.join("127.0.0.1", port), OK)
	for i in 400:
		a.tick()
		squatter.pump()
		if a.transport.is_up():
			break
		OS.delay_msec(5)
	assert_true(a.transport.is_up(), "the squatter connected")
	var t := [Time.get_ticks_msec() + 6000]
	a.now_ms = func(): return t[0]
	a.tick()
	for i in 60:
		a.tick()
		squatter.pump()
		OS.delay_msec(5)
	assert_true(not a.transport.is_up(), "kicked for never saying hello")
	assert_eq(a.state, NetSession.State.HOSTING)
	squatter.close()
	a.leave("")
	a.free()


func test_a_second_hello_mid_night_is_ignored() -> void:
	var port := _port()
	var a := _session("t")
	var b := _session("t")
	a.host(port)
	b.join("127.0.0.1", port)
	_tick_until([a, b], func(): return b.state == NetSession.State.LOBBY)
	b.set_ready(true)
	a.set_ready(true)
	_tick_until([a, b], func(): return a.guest_ready)
	assert_true(a.start_game())
	b.send_reliable(NetProtocol.encode_hello("t"))
	_tick_until([a, b], func(): return false, 40)
	assert_eq(a.state, NetSession.State.IN_COOP, "a stray HELLO does not send the night back to the lobby")
	for s in [a, b]:
		s.leave("")
		s.free()


# --- I2: a snapshot only acknowledges inputs its positions include ------------------------------

func test_snapshot_ack_lags_the_applied_frame_by_one_step() -> void:
	var r := NetReplicator.new()
	var ally := Player.new()
	r.push_input_frames([{"seq": 1, "move": Vector2.RIGHT, "aim": 0.0, "buttons": 0}, {"seq": 2, "move": Vector2.RIGHT, "aim": 0.0, "buttons": 0}])
	assert_eq(r.snapshot_ack, 0xFFFF, "nothing applied yet")
	r.step_ally(ally)
	assert_eq(r.snapshot_ack, 0xFFFF, "frame 1 is applied this tick but not yet moved")
	r.step_ally(ally)
	assert_eq(r.snapshot_ack, 1, "by the next tick frame 1 has moved the keeper")
	ally.free()
	r.free()


# --- I3: replay what the local body really did --------------------------------------------------

func test_replay_uses_the_recorded_displacement() -> void:
	assert_eq(ClientView.replay_step(Vector2(1, 1), {"d": Vector2(2, 0), "move": Vector2(1, 0)}), Vector2(3, 1))
	assert_eq(ClientView.replay_step(Vector2(1, 1), {"d": Vector2.ZERO, "move": Vector2(1, 0)}), Vector2(1, 1), "a wall: no movement to replay")
	var walked := ClientView.replay_step(Vector2.ZERO, {"move": Vector2(1, 0)})
	assert_near(walked.x, Player.SPEED / 60.0, 0.01)


# --- I4: only falls during the fight count ------------------------------------------------------

func test_pvp_ignores_falls_outside_the_fight() -> void:
	var r := PvpRules.new()
	r.fighting = false
	r.fall(0)
	assert_eq(r.resolve().kind, "none")
	r.fighting = true
	r.fall(0)
	assert_eq(r.resolve().kind, "win")


# --- I5: stats do not grow without bound --------------------------------------------------------

func test_stats_buffers_stay_bounded_without_a_report() -> void:
	var t := [0]
	var st := NetStats.new()
	st.clock = func(): return t[0]
	for i in 10000:
		t[0] = i
		st.record_sent(0, 20)
		st.record_received(0, 20)
		st.record_underrun()
	assert_true(st._sent.size() <= 1100, "sent samples: %d" % st._sent.size())
	assert_true(st._recv.size() <= 1100)
	assert_true(st._under.size() <= 1100)
