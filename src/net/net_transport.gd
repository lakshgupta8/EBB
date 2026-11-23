class_name NetTransport
extends RefCounted
## ENet transport, polled by hand (no SceneMultiplayer, no @rpc). Two logical channels:
## CH_UNRELIABLE (state that goes stale: inputs, snapshots; sequencing is by the `seq` and
## `tick` fields in the payload) and CH_RELIABLE (everything that must arrive, in order).
## Both directions pass through a NetSim so a bad network can be dialled in.

signal connected()
signal disconnected()
signal packet(data: PackedByteArray, channel: int)

var sim_out := NetSim.new(11)
var sim_in := NetSim.new(12)
var stats := NetStats.new()
## Injectable so tests can move simulated time by hand.
var clock: Callable = func(): return Time.get_ticks_msec()

var _peer: ENetMultiplayerPeer
var _remote: int = 1
var _up: bool = false
var _joining: bool = false


func _init() -> void:
	stats.clock = _now  # a method callable, not a lambda: a lambda would capture self and leak


func _now() -> int:
	return int(clock.call())


func host(port: int) -> Error:
	close()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, 1)
	if err != OK:
		_peer = null
		return err
	_wire()
	return OK


func join(address: String, port: int) -> Error:
	close()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		_peer = null
		return err
	_remote = 1
	_joining = true
	_wire()
	return OK


func close() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	_up = false
	_joining = false


func is_up() -> bool:
	return _up


## One-way conditions, applied to this machine's outgoing and incoming traffic.
func set_conditions(latency_ms: int, jitter_ms: int, loss: float) -> void:
	for s in [sim_out, sim_in]:
		s.latency_ms = latency_ms
		s.jitter_ms = jitter_ms
		s.loss = loss


func send(data: PackedByteArray, channel: int) -> void:
	if _peer == null:
		return
	stats.record_sent(channel, data.size())
	var now := int(clock.call())
	sim_out.submit(data, channel, now, channel == NetProtocol.CH_RELIABLE)
	_flush_out(now)


func pump() -> void:
	if _peer == null:
		return
	_peer.poll()
	var now := int(clock.call())
	while _peer != null and _peer.get_available_packet_count() > 0:
		var mode := _peer.get_packet_mode()
		var data := _peer.get_packet()
		var ch := NetProtocol.CH_RELIABLE if mode == MultiplayerPeer.TRANSFER_MODE_RELIABLE else NetProtocol.CH_UNRELIABLE
		sim_in.submit(data, ch, now, ch == NetProtocol.CH_RELIABLE)
	for p in sim_in.poll(now):
		stats.record_received(p.channel, p.data.size())
		packet.emit(p.data, p.channel)
	_flush_out(now)
	if _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED and (_up or _joining):
		_drop()


func _wire() -> void:
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(id: int) -> void:
	_remote = id
	_up = true
	_joining = false
	connected.emit()


func _on_peer_disconnected(_id: int) -> void:
	_drop()


func _drop() -> void:
	close()
	disconnected.emit()


func _flush_out(now: int) -> void:
	if _peer == null or not _up:
		return
	for p in sim_out.poll(now):
		_peer.set_target_peer(_remote)
		_peer.set_transfer_channel(0)
		_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE if p.channel == NetProtocol.CH_RELIABLE else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
		_peer.put_packet(p.data)
