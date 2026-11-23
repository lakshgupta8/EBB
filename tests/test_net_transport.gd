extends TestCase
## NetTransport over real ENet on loopback, two peers in one process, pumped by hand.


func _pair(port: int) -> Array:
	var a := NetTransport.new()
	var b := NetTransport.new()
	var up := [false, false]
	a.connected.connect(func(): up[0] = true)
	b.connected.connect(func(): up[1] = true)
	assert_eq(a.host(port), OK)
	assert_eq(b.join("127.0.0.1", port), OK)
	var tries := 0
	while not (up[0] and up[1]) and tries < 400:
		a.pump()
		b.pump()
		OS.delay_msec(5)
		tries += 1
	assert_true(up[0] and up[1], "both sides connected")
	return [a, b]


func _drain(ts: Array, rounds: int = 30) -> void:
	for i in rounds:
		for t in ts:
			t.pump()
		OS.delay_msec(4)


func test_loopback_two_peers_in_process() -> void:
	var port := randi_range(30000, 40000)
	var pair := _pair(port)
	var a: NetTransport = pair[0]
	var b: NetTransport = pair[1]
	var got_a: Array = []
	var got_b: Array = []
	a.packet.connect(func(d, c): got_a.append([d, c]))
	b.packet.connect(func(d, c): got_b.append([d, c]))
	var u := PackedByteArray()
	u.resize(40)
	for i in 40:
		u[i] = i
	var r := PackedByteArray([9, 9, 9])
	a.send(u, NetProtocol.CH_UNRELIABLE)
	a.send(r, NetProtocol.CH_RELIABLE)
	b.send(r, NetProtocol.CH_RELIABLE)
	b.send(u, NetProtocol.CH_UNRELIABLE)
	_drain(pair)
	assert_eq(got_b.size(), 2, "guest got both packets")
	assert_eq(got_a.size(), 2, "host got both packets")
	for g in got_b:
		if g[1] == NetProtocol.CH_UNRELIABLE:
			assert_eq(g[0], u)
		else:
			assert_eq(g[0], r)
	assert_true(a.stats.report(Time.get_ticks_msec()).bytes_out >= 43, "stats counted the bytes")
	a.close()
	b.close()
	a.free()
	b.free()


func test_sim_latency_applies_on_receive() -> void:
	var port := randi_range(30000, 40000)
	var pair := _pair(port)
	var a: NetTransport = pair[0]
	var b: NetTransport = pair[1]
	var t := [0]
	b.clock = func(): return t[0]
	b.set_conditions(80, 0, 0.0)
	var got: Array = []
	b.packet.connect(func(d, c): got.append(d))
	a.send(PackedByteArray([1, 2, 3]), NetProtocol.CH_RELIABLE)
	_drain(pair, 20)
	assert_eq(got.size(), 0, "held back until the simulated latency has passed")
	t[0] = 80
	_drain(pair, 5)
	assert_eq(got.size(), 1)
	a.close()
	b.close()
	a.free()
	b.free()


func test_close_emits_disconnected_on_peer() -> void:
	var port := randi_range(30000, 40000)
	var pair := _pair(port)
	var a: NetTransport = pair[0]
	var b: NetTransport = pair[1]
	var down := [0]
	a.disconnected.connect(func(): down[0] += 1)
	b.close()
	for i in 200:
		a.pump()
		OS.delay_msec(5)
		if down[0] > 0:
			break
	assert_eq(down[0], 1)
	a.close()
	a.free()
	b.free()
