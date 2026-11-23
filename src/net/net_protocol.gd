class_name NetProtocol
extends RefCounted
## The wire format. Every message is [type u8][fields...] with explicit widths. Decoders
## validate length and type and return {} / [] on anything malformed, never crash.

const PROTOCOL_VERSION := 1
const DEFAULT_PORT := 24680
const CH_UNRELIABLE := 0
const CH_RELIABLE := 1
## Positions travel as i16 at half-pixel resolution: +-16383 px, error <= 0.25 px.
const POS_SCALE := 2.0
const SNAPSHOT_HEADER := 10  # type u8, tick u32, ack u16, epoch u8, count u16
const ENTITY_BYTES := 11     # id u16, kind u8, x i16, y i16, hp u16, anim u8, flags u8
const INPUT_FRAME_BYTES := 6 # seq u16, mx i8, my i8, aim u8, buttons u8

enum Msg { HELLO = 1, WELCOME, REFUSE, LOBBY_STATE, ROOM_ENTER, SPAWN, DESPAWN, EVENT, PING, PONG, INPUT, SNAPSHOT }
enum Ev { HIT, DEATH, TELEGRAPH, BOSS_PHASE, PICKUP, ROUND_RESULT, CHOICE_MADE, HOST_CHOOSING, DOWNED, REVIVED, CLEARED }

const BTN_ATTACK := 1
const BTN_SPECIAL := 2
const BTN_DASH := 4
const BTN_USE := 8
const BTN_HELD := 16


static func msg_type(b: PackedByteArray) -> int:
	return -1 if b.is_empty() else int(b[0])


static func _q_pos(v: float) -> int:
	return int(round(clampf(v * POS_SCALE, -32768.0, 32767.0)))


static func _put_pos(b: PackedByteArray, off: int, p: Vector2) -> void:
	b.encode_s16(off, _q_pos(p.x))
	b.encode_s16(off + 2, _q_pos(p.y))


static func _get_pos(b: PackedByteArray, off: int) -> Vector2:
	return Vector2(b.decode_s16(off), b.decode_s16(off + 2)) / POS_SCALE


static func _is(b: PackedByteArray, type: int, min_size: int) -> bool:
	return b.size() >= min_size and int(b[0]) == type


static func encode_hello(version: String) -> PackedByteArray:
	var s := version.to_utf8_buffer()
	var b := PackedByteArray([Msg.HELLO, PROTOCOL_VERSION, mini(s.size(), 255)])
	b.append_array(s.slice(0, 255))
	return b


static func decode_hello(b: PackedByteArray) -> Dictionary:
	if not _is(b, Msg.HELLO, 3) or b.size() != 3 + int(b[2]):
		return {}
	return {"proto": int(b[1]), "version": b.slice(3).get_string_from_utf8()}


static func encode_inputs(frames: Array) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(2 + INPUT_FRAME_BYTES * frames.size())
	b[0] = Msg.INPUT
	b[1] = frames.size()
	var off := 2
	for f in frames:
		b.encode_u16(off, int(f.seq) & 0xFFFF)
		b.encode_s8(off + 2, int(round(clampf(f.move.x, -1.0, 1.0) * 127.0)))
		b.encode_s8(off + 3, int(round(clampf(f.move.y, -1.0, 1.0) * 127.0)))
		b.encode_u8(off + 4, int(round(wrapf(float(f.aim), 0.0, TAU) / TAU * 256.0)) % 256)
		b.encode_u8(off + 5, int(f.buttons) & 0xFF)
		off += INPUT_FRAME_BYTES
	return b


static func decode_inputs(b: PackedByteArray) -> Array:
	if not _is(b, Msg.INPUT, 2) or b.size() != 2 + INPUT_FRAME_BYTES * int(b[1]):
		return []
	var out := []
	var off := 2
	for i in int(b[1]):
		out.append({
			"seq": b.decode_u16(off),
			"move": Vector2(b.decode_s8(off + 2), b.decode_s8(off + 3)) / 127.0,
			"aim": float(b.decode_u8(off + 4)) / 256.0 * TAU,
			"buttons": b.decode_u8(off + 5),
		})
		off += INPUT_FRAME_BYTES
	return out


static func encode_snapshot(tick: int, ack_seq: int, epoch: int, entities: Array) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(SNAPSHOT_HEADER + ENTITY_BYTES * entities.size())
	b[0] = Msg.SNAPSHOT
	b.encode_u32(1, tick & 0xFFFFFFFF)
	b.encode_u16(5, ack_seq & 0xFFFF)
	b.encode_u8(7, epoch & 0xFF)
	b.encode_u16(8, entities.size())
	var off := SNAPSHOT_HEADER
	for e in entities:
		b.encode_u16(off, int(e.id) & 0xFFFF)
		b.encode_u8(off + 2, int(e.kind) & 0xFF)
		_put_pos(b, off + 3, e.pos)
		b.encode_u16(off + 7, clampi(int(e.hp), 0, 65535))
		b.encode_u8(off + 9, int(e.anim) & 0xFF)
		b.encode_u8(off + 10, int(e.flags) & 0xFF)
		off += ENTITY_BYTES
	return b


static func decode_snapshot(b: PackedByteArray) -> Dictionary:
	if not _is(b, Msg.SNAPSHOT, SNAPSHOT_HEADER):
		return {}
	var n := b.decode_u16(8)
	if b.size() != SNAPSHOT_HEADER + ENTITY_BYTES * n:
		return {}
	var ents := []
	var off := SNAPSHOT_HEADER
	for i in n:
		ents.append({
			"id": b.decode_u16(off), "kind": b.decode_u8(off + 2), "pos": _get_pos(b, off + 3),
			"hp": b.decode_u16(off + 7), "anim": b.decode_u8(off + 9), "flags": b.decode_u8(off + 10),
		})
		off += ENTITY_BYTES
	return {"tick": b.decode_u32(1), "ack": b.decode_u16(5), "epoch": b.decode_u8(7), "entities": ents}


static func encode_event(kind: int, a: int, b_: int, pos: Vector2) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(10)
	b[0] = Msg.EVENT
	b.encode_u8(1, kind & 0xFF)
	b.encode_u16(2, a & 0xFFFF)
	b.encode_u16(4, b_ & 0xFFFF)
	_put_pos(b, 6, pos)
	return b


static func decode_event(b: PackedByteArray) -> Dictionary:
	if not _is(b, Msg.EVENT, 10) or b.size() != 10:
		return {}
	return {"kind": b.decode_u8(1), "a": b.decode_u16(2), "b": b.decode_u16(4), "pos": _get_pos(b, 6)}


## The room travels as text (name + rows and directives): generated rooms have no file on the
## guest. Layout: type u8, epoch u8, type u8, seed u32, wet u8, biome u8, name_len u8, name,
## text_len u16, text.
static func encode_room_enter(epoch: int, type: int, p_name: String, text: String, room_seed: int, wet: bool, biome: int) -> PackedByteArray:
	var n := p_name.to_utf8_buffer().slice(0, 255)
	var t := text.to_utf8_buffer().slice(0, 65535)
	var b := PackedByteArray()
	b.resize(10)
	b[0] = Msg.ROOM_ENTER
	b.encode_u8(1, epoch & 0xFF)
	b.encode_u8(2, type & 0xFF)
	b.encode_u32(3, room_seed & 0xFFFFFFFF)
	b.encode_u8(7, 1 if wet else 0)
	b.encode_u8(8, biome & 0xFF)
	b.encode_u8(9, n.size())
	b.append_array(n)
	var len_at := b.size()
	b.resize(len_at + 2)
	b.encode_u16(len_at, t.size())
	b.append_array(t)
	return b


static func decode_room_enter(b: PackedByteArray) -> Dictionary:
	if not _is(b, Msg.ROOM_ENTER, 12):
		return {}
	var n := int(b[9])
	if b.size() < 12 + n:
		return {}
	var tl := b.decode_u16(10 + n)
	if b.size() != 12 + n + tl:
		return {}
	return {"epoch": b.decode_u8(1), "type": b.decode_u8(2), "room_seed": b.decode_u32(3),
			"wet": b.decode_u8(7) == 1, "biome": b.decode_u8(8),
			"name": b.slice(10, 10 + n).get_string_from_utf8(), "text": b.slice(12 + n).get_string_from_utf8()}


static func encode_spawn(id: int, kind: int, pos: Vector2, scene_key: String) -> PackedByteArray:
	var s := scene_key.to_utf8_buffer()
	var b := PackedByteArray()
	b.resize(9)
	b[0] = Msg.SPAWN
	b.encode_u16(1, id & 0xFFFF)
	b.encode_u8(3, kind & 0xFF)
	_put_pos(b, 4, pos)
	b.encode_u8(8, mini(s.size(), 255))
	b.append_array(s.slice(0, 255))
	return b


static func decode_spawn(b: PackedByteArray) -> Dictionary:
	if not _is(b, Msg.SPAWN, 9) or b.size() != 9 + int(b[8]):
		return {}
	return {"id": b.decode_u16(1), "kind": b.decode_u8(3), "pos": _get_pos(b, 4), "scene_key": b.slice(9).get_string_from_utf8()}


static func encode_despawn(id: int) -> PackedByteArray:
	var b := PackedByteArray([Msg.DESPAWN, 0, 0])
	b.encode_u16(1, id & 0xFFFF)
	return b


static func decode_despawn(b: PackedByteArray) -> Dictionary:
	if not _is(b, Msg.DESPAWN, 3) or b.size() != 3:
		return {}
	return {"id": b.decode_u16(1)}


static func encode_ping(t_ms: int, is_pong: bool) -> PackedByteArray:
	var b := PackedByteArray([Msg.PONG if is_pong else Msg.PING, 0, 0, 0, 0])
	b.encode_u32(1, t_ms & 0xFFFFFFFF)
	return b


static func decode_ping(b: PackedByteArray) -> Dictionary:
	if b.size() != 5 or (int(b[0]) != Msg.PING and int(b[0]) != Msg.PONG):
		return {}
	return {"t_ms": b.decode_u32(1), "is_pong": int(b[0]) == Msg.PONG}


static func encode_refuse(reason: String) -> PackedByteArray:
	var s := reason.to_utf8_buffer()
	var b := PackedByteArray([Msg.REFUSE, mini(s.size(), 255)])
	b.append_array(s.slice(0, 255))
	return b


static func decode_refuse(b: PackedByteArray) -> Dictionary:
	if not _is(b, Msg.REFUSE, 2) or b.size() != 2 + int(b[1]):
		return {}
	return {"reason": b.slice(2).get_string_from_utf8()}


static func encode_welcome() -> PackedByteArray:
	return PackedByteArray([Msg.WELCOME])


## mode_id 0 = co-op, 1 = PvP.
static func encode_lobby(mode_id: int, host_ready: bool, guest_ready: bool, start: bool) -> PackedByteArray:
	return PackedByteArray([Msg.LOBBY_STATE, mode_id & 0xFF, 1 if host_ready else 0, 1 if guest_ready else 0, 1 if start else 0])


static func decode_lobby(b: PackedByteArray) -> Dictionary:
	if not _is(b, Msg.LOBBY_STATE, 5) or b.size() != 5:
		return {}
	return {"mode": int(b[1]), "host_ready": b[2] == 1, "guest_ready": b[3] == 1, "start": b[4] == 1}
