class_name NetSession
extends Node
## One multiplayer session: connect, handshake, lobby, keep-alive. The autoload `Net` is the
## instance the game uses; tests make their own. While a session is open, saves go to a
## scratch file and the real profile is put back on the way out, so a networked night never
## touches the host's real save.

enum State { IDLE, HOSTING, JOINING, LOBBY, IN_COOP, IN_PVP }

const TIMEOUT_MS := 5000
const PING_EVERY_MS := 500
const SCRATCH_PATH := "user://net_scratch.json"

signal state_changed(s: int)
## A game message the session does not handle itself (inputs, snapshots, events...).
signal message(type: int, bytes: PackedByteArray)
signal left(reason: String)
signal lobby_changed()

var state: State = State.IDLE
var mode: String = "coop"
var host_ready: bool = false
var guest_ready: bool = false
var rtt_ms: float = 0.0
var version: String = ""
var transport: NetTransport
## Injectable so tests can move time by hand.
var now_ms: Callable = func(): return Time.get_ticks_msec()

var _is_host: bool = false
var _scratch_on: bool = false
var _prev_path: String = ""
var _last_rx: int = 0
var _next_ping: int = 0
var _started: int = 0
var _have_rtt: bool = false


func _init() -> void:
	version = Game.VERSION


func _process(_delta: float) -> void:
	tick()


## `--netsim=latency_ms,jitter_ms,loss` on the command line: a bad network on purpose.
## Anything that is not exactly that returns {} (no conditions).
static func parse_netsim(args: PackedStringArray) -> Dictionary:
	for a in args:
		if a.begins_with("--netsim="):
			var parts := a.trim_prefix("--netsim=").split(",")
			if parts.size() != 3 or not (parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_float()):
				return {}
			return {"latency": int(parts[0]), "jitter": int(parts[1]), "loss": float(parts[2])}
	return {}


func is_host() -> bool:
	return _is_host


func host(port: int = NetProtocol.DEFAULT_PORT) -> Error:
	leave("")
	_open(true)
	var err := transport.host(port)
	if err != OK:
		leave("")
		return err
	_set_state(State.HOSTING)
	return OK


func join(address: String, port: int = NetProtocol.DEFAULT_PORT) -> Error:
	leave("")
	_open(false)
	var err := transport.join(address, port)
	if err != OK:
		leave("")
		return err
	_set_state(State.JOINING)
	return OK


## Close everything and put the real profile back. Idempotent; `reason` (when not empty) is
## reported once through `left`.
func leave(reason: String = "") -> void:
	if state == State.IDLE and transport == null and not _scratch_on:
		return
	var was_active := state != State.IDLE
	if transport != null:
		transport.close()
		transport = null
	if _scratch_on:
		_scratch_on = false
		SaveManager.use_path(_prev_path)
	host_ready = false
	guest_ready = false
	_have_rtt = false
	_is_host = false
	if was_active:
		state = State.IDLE
		state_changed.emit(State.IDLE)
		if reason != "":
			left.emit(reason)


func send_reliable(b: PackedByteArray) -> void:
	if transport != null:
		transport.send(b, NetProtocol.CH_RELIABLE)


func send_unreliable(b: PackedByteArray) -> void:
	if transport != null:
		transport.send(b, NetProtocol.CH_UNRELIABLE)


func set_mode(m: String) -> void:
	if not _is_host or state != State.LOBBY:
		return
	mode = m
	_send_lobby(false)
	lobby_changed.emit()


func set_ready(r: bool) -> void:
	if state != State.LOBBY:
		return
	if _is_host:
		host_ready = r
	else:
		guest_ready = r
	_send_lobby(false)
	lobby_changed.emit()


## Host only. Both must be ready.
func start_game() -> bool:
	if not _is_host or state != State.LOBBY or not (host_ready and guest_ready):
		return false
	_send_lobby(true)
	_set_state(State.IN_PVP if mode == "pvp" else State.IN_COOP)
	return true


## Back to the lobby after a match or a night.
func return_to_lobby() -> void:
	if state in [State.IN_COOP, State.IN_PVP]:
		host_ready = false
		guest_ready = false
		_set_state(State.LOBBY)
		lobby_changed.emit()


func tick() -> void:
	if transport == null:
		return
	transport.pump()
	if transport == null:
		return  # the pump may have ended the session
	var now := int(now_ms.call())
	if state == State.JOINING and now - _started > TIMEOUT_MS:
		leave("could not connect")
	elif state in [State.LOBBY, State.IN_COOP, State.IN_PVP]:
		if now - _last_rx > TIMEOUT_MS:
			leave("timeout")
		elif now >= _next_ping:
			_next_ping = now + PING_EVERY_MS
			send_reliable(NetProtocol.encode_ping(now, false))


func _open(as_host: bool) -> void:
	_is_host = as_host
	_prev_path = SaveManager.path
	# The host keeps their own profile in memory (weapon, perks) but saves go to the scratch
	# file; `leave` reloads the real one, so nothing earned here leaks back.
	SaveManager.path = SCRATCH_PATH
	_scratch_on = true
	host_ready = false
	guest_ready = false
	_started = int(now_ms.call())
	_last_rx = _started
	transport = NetTransport.new()
	var cond := parse_netsim(OS.get_cmdline_user_args())
	if not cond.is_empty():
		transport.set_conditions(int(cond.latency), int(cond.jitter), float(cond.loss))
	transport.connected.connect(_on_connected)
	transport.disconnected.connect(_on_down)
	transport.packet.connect(_on_packet)


func _set_state(s: State) -> void:
	if state == s:
		return
	state = s
	state_changed.emit(s)


func _on_connected() -> void:
	_last_rx = int(now_ms.call())
	if not _is_host:
		send_reliable(NetProtocol.encode_hello(version))


func _on_down() -> void:
	if state != State.IDLE:
		leave("connection lost")


func _send_lobby(start: bool) -> void:
	send_reliable(NetProtocol.encode_lobby(1 if mode == "pvp" else 0, host_ready, guest_ready, start))


func _on_packet(data: PackedByteArray, _channel: int) -> void:
	_last_rx = int(now_ms.call())
	var type := NetProtocol.msg_type(data)
	match type:
		NetProtocol.Msg.HELLO:
			if _is_host:
				_on_hello(data)
		NetProtocol.Msg.WELCOME:
			if not _is_host:
				_set_state(State.LOBBY)
		NetProtocol.Msg.REFUSE:
			var r := NetProtocol.decode_refuse(data)
			if not _is_host and not r.is_empty():
				leave(str(r.reason))
		NetProtocol.Msg.PING:
			var p := NetProtocol.decode_ping(data)
			if not p.is_empty():
				send_reliable(NetProtocol.encode_ping(int(p.t_ms), true))
		NetProtocol.Msg.PONG:
			var p := NetProtocol.decode_ping(data)
			if not p.is_empty():
				var sample := float(int(now_ms.call()) - int(p.t_ms))
				rtt_ms = lerpf(rtt_ms, sample, 0.2) if _have_rtt else sample
				_have_rtt = true
				transport.stats.record_rtt(sample)
		NetProtocol.Msg.LOBBY_STATE:
			_on_lobby(data)
		_:
			message.emit(type, data)


func _on_hello(data: PackedByteArray) -> void:
	var h := NetProtocol.decode_hello(data)
	if h.is_empty():
		return
	if int(h.proto) != NetProtocol.PROTOCOL_VERSION:
		send_reliable(NetProtocol.encode_refuse("protocol mismatch: host speaks %d, you speak %d" % [NetProtocol.PROTOCOL_VERSION, int(h.proto)]))
	elif str(h.version) != version:
		send_reliable(NetProtocol.encode_refuse("version mismatch: host has %s, you have %s" % [version, str(h.version)]))
	else:
		send_reliable(NetProtocol.encode_welcome())
		_set_state(State.LOBBY)
		_send_lobby(false)


func _on_lobby(data: PackedByteArray) -> void:
	var l := NetProtocol.decode_lobby(data)
	if l.is_empty():
		return
	if _is_host:
		guest_ready = bool(l.guest_ready)
	else:
		mode = "pvp" if int(l.mode) == 1 else "coop"
		host_ready = bool(l.host_ready)
		guest_ready = bool(l.guest_ready)
		if bool(l.start):
			_set_state(State.IN_PVP if mode == "pvp" else State.IN_COOP)
	lobby_changed.emit()
