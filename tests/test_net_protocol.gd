extends TestCase
## The wire format: round trips, sizes, quantisation error, and hostile input.


func test_inputs_round_trip() -> void:
	var frames := [
		{"seq": 65534, "move": Vector2(1, 0), "aim": 0.0, "buttons": NetProtocol.BTN_ATTACK},
		{"seq": 65535, "move": Vector2(-0.5, 0.25), "aim": 3.0, "buttons": NetProtocol.BTN_DASH | NetProtocol.BTN_HELD},
		{"seq": 0, "move": Vector2.ZERO, "aim": 6.0, "buttons": 0},
	]
	var back := NetProtocol.decode_inputs(NetProtocol.encode_inputs(frames))
	assert_eq(back.size(), 3)
	for i in 3:
		assert_eq(back[i].seq, frames[i].seq)
		assert_eq(back[i].buttons, frames[i].buttons)
		assert_near(back[i].move.x, frames[i].move.x, 1.0 / 127.0 + 0.0001)
		assert_near(back[i].move.y, frames[i].move.y, 1.0 / 127.0 + 0.0001)
		assert_near(back[i].aim, frames[i].aim, TAU / 256.0 + 0.0001)


func test_snapshot_round_trip_and_size() -> void:
	var ents := []
	for i in 10:
		ents.append({"id": 100 + i, "kind": i % 4, "pos": Vector2(i * 13.5, -i * 7.25), "hp": 40 + i, "anim": i, "flags": 1})
	var b := NetProtocol.encode_snapshot(1234, 77, 3, ents)
	assert_eq(b.size(), NetProtocol.SNAPSHOT_HEADER + 10 * NetProtocol.ENTITY_BYTES)
	assert_eq(NetProtocol.ENTITY_BYTES, 11)
	var d := NetProtocol.decode_snapshot(b)
	assert_eq(d.tick, 1234)
	assert_eq(d.ack, 77)
	assert_eq(d.epoch, 3)
	assert_eq(d.entities.size(), 10)
	for i in 10:
		assert_eq(d.entities[i].id, ents[i].id)
		assert_eq(d.entities[i].hp, ents[i].hp)
		assert_true(d.entities[i].pos.distance_to(ents[i].pos) <= 0.5, "pos within half a pixel")


func test_snapshot_negative_positions() -> void:
	var d := NetProtocol.decode_snapshot(NetProtocol.encode_snapshot(1, 1, 1,
			[{"id": 1, "kind": 0, "pos": Vector2(-300.5, 12.0), "hp": 1, "anim": 0, "flags": 0}]))
	assert_near(d.entities[0].pos.x, -300.5, 0.5)
	assert_near(d.entities[0].pos.y, 12.0, 0.5)


func test_hello_version() -> void:
	var h := NetProtocol.decode_hello(NetProtocol.encode_hello("1.4.0"))
	assert_eq(h.proto, NetProtocol.PROTOCOL_VERSION)
	assert_eq(h.version, "1.4.0")


func test_event_room_enter_spawn_ping_round_trip() -> void:
	var e := NetProtocol.decode_event(NetProtocol.encode_event(NetProtocol.Ev.BOSS_PHASE, 7, 2, Vector2(10, -20)))
	assert_eq(e.kind, NetProtocol.Ev.BOSS_PHASE)
	assert_eq(e.a, 7)
	assert_eq(e.b, 2)
	assert_near(e.pos.x, 10.0, 0.5)
	var long_text := "#".repeat(60) + "
"
	long_text = long_text.repeat(60)  # 3660 bytes: well past one byte of length
	var r := NetProtocol.decode_room_enter(NetProtocol.encode_room_enter(5, 2, "arena_a", long_text, 987654321, true, 3))
	assert_eq(r.epoch, 5)
	assert_eq(r.type, 2)
	assert_eq(r.name, "arena_a")
	assert_eq(r.text, long_text)
	assert_eq(r.room_seed, 987654321)
	assert_eq(r.wet, true)
	assert_eq(r.biome, 3)
	var s := NetProtocol.decode_spawn(NetProtocol.encode_spawn(42, 3, Vector2(5, 6), "gull"))
	assert_eq(s.id, 42)
	assert_eq(s.scene_key, "gull")
	assert_eq(NetProtocol.decode_despawn(NetProtocol.encode_despawn(42)).id, 42)
	var p := NetProtocol.decode_ping(NetProtocol.encode_ping(123456, true))
	assert_eq(p.t_ms, 123456)
	assert_eq(p.is_pong, true)


func test_msg_type() -> void:
	assert_eq(NetProtocol.msg_type(PackedByteArray()), -1)
	assert_eq(NetProtocol.msg_type(NetProtocol.encode_hello("x")), NetProtocol.Msg.HELLO)
	assert_eq(NetProtocol.msg_type(NetProtocol.encode_inputs([])), NetProtocol.Msg.INPUT)
	assert_eq(NetProtocol.msg_type(NetProtocol.encode_snapshot(0, 0, 0, [])), NetProtocol.Msg.SNAPSHOT)


func test_truncated_and_garbage_decode_to_empty() -> void:
	var junk := PackedByteArray([250])
	var valid := {
		"hello": NetProtocol.encode_hello("1.4.0"),
		"snap": NetProtocol.encode_snapshot(9, 9, 1, [{"id": 1, "kind": 0, "pos": Vector2(1, 1), "hp": 1, "anim": 0, "flags": 0}]),
		"event": NetProtocol.encode_event(0, 1, 2, Vector2.ZERO),
		"room": NetProtocol.encode_room_enter(1, 0, "t", "txt", 5, false, 0),
		"spawn": NetProtocol.encode_spawn(1, 1, Vector2.ZERO, "gull"),
		"despawn": NetProtocol.encode_despawn(1),
		"ping": NetProtocol.encode_ping(1, false),
	}
	for empty_or_junk in [PackedByteArray(), junk]:
		assert_true(NetProtocol.decode_hello(empty_or_junk).is_empty())
		assert_true(NetProtocol.decode_snapshot(empty_or_junk).is_empty())
		assert_true(NetProtocol.decode_event(empty_or_junk).is_empty())
		assert_true(NetProtocol.decode_room_enter(empty_or_junk).is_empty())
		assert_true(NetProtocol.decode_spawn(empty_or_junk).is_empty())
		assert_true(NetProtocol.decode_despawn(empty_or_junk).is_empty())
		assert_true(NetProtocol.decode_ping(empty_or_junk).is_empty())
		assert_eq(NetProtocol.decode_inputs(empty_or_junk).size(), 0)
	var cut := {
		"hello": NetProtocol.decode_hello, "snap": NetProtocol.decode_snapshot, "event": NetProtocol.decode_event,
		"room": NetProtocol.decode_room_enter, "spawn": NetProtocol.decode_spawn,
		"despawn": NetProtocol.decode_despawn, "ping": NetProtocol.decode_ping,
	}
	for k in cut:
		var b: PackedByteArray = valid[k]
		var short := b.slice(0, b.size() - 1)
		assert_true((cut[k] as Callable).call(short).is_empty(), "%s cut by one byte" % k)


func test_refuse_welcome_lobby_round_trip() -> void:
	assert_eq(NetProtocol.decode_refuse(NetProtocol.encode_refuse("version mismatch")).reason, "version mismatch")
	assert_eq(NetProtocol.msg_type(NetProtocol.encode_welcome()), NetProtocol.Msg.WELCOME)
	var l := NetProtocol.decode_lobby(NetProtocol.encode_lobby(1, true, false, true))
	assert_eq(l.mode, 1)
	assert_eq(l.host_ready, true)
	assert_eq(l.guest_ready, false)
	assert_eq(l.start, true)
	var r := NetProtocol.encode_refuse("x")
	assert_true(NetProtocol.decode_refuse(r.slice(0, r.size() - 1)).is_empty())
	assert_true(NetProtocol.decode_lobby(PackedByteArray([NetProtocol.Msg.LOBBY_STATE])).is_empty())
	assert_true(NetProtocol.decode_refuse(PackedByteArray()).is_empty())


func test_resync_message() -> void:
	assert_eq(NetProtocol.msg_type(NetProtocol.encode_resync()), NetProtocol.Msg.RESYNC)
	assert_eq(NetProtocol.encode_resync().size(), 1)
