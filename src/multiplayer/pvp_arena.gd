class_name PvpArena
extends Node2D
## The duel, host side: one symmetric room, two keepers (the host's own and the guest's, driven
## by the wire), best of three. The host decides every hit; the guest watches through the same
## client view as a co-op night. Same replicator and messages, different rules.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const MP_MENU := "res://src/multiplayer/mp_menu.tscn"
const W := 26
const H := 14
const COUNTDOWN := 3.0
const PAUSE := 3.0
const SNAPSHOT_EVERY := 3
const PLAYER_HIT_MASK := 64  # player_hurtbox: layer 7

## PVP_STATE phases (the event's `a`): 0 countdown, 1 fight, 2 round over, 3 match over.
enum Phase { COUNTDOWN, FIGHT, ROUND_OVER, MATCH_OVER }

var rules := PvpRules.new()
var repl := NetReplicator.new()
var room: Room
var host: Player
var ally: Player
var epoch: int = 1

var _phase: Phase = Phase.COUNTDOWN
var _t: float = COUNTDOWN
var _tick: int = 0
var _spawn_l: Vector2
var _spawn_r: Vector2
var _label: Label
var _resolve_queued: bool = false


## Walls round the edge, two blocks of cover top and bottom, mirrored left to right; `P` marks
## the left keeper's spawn (the right one is its mirror).
static func arena_text() -> String:
	var grid: Array = []
	for y in H:
		var row := ""
		for x in W:
			var wall := x == 0 or y == 0 or x == W - 1 or y == H - 1
			for cover_x in [4, 5, 6]:
				if (y == 3 or y == H - 4) and (x == cover_x or x == W - 1 - cover_x):
					wall = true
			row += "#" if wall else "."
		grid.append(row)
	var py := H / 2
	grid[py] = grid[py].substr(0, 3) + "P" + grid[py].substr(4)
	return "\n".join(grid) + "\n"


## Let a keeper's swings also land on the other keeper (the enemy mask stays).
static func enable_pvp_masks(weapon: Node) -> void:
	for h in weapon.find_children("*", "Hitbox", true, false):
		h.collision_mask |= PLAYER_HIT_MASK


func _ready() -> void:
	process_physics_priority = -10
	var t := RoomTemplate.parse(arena_text(), "pvp_arena")
	room = Room.new()
	add_child(room)
	room.build(t, 777, Tiles.Look.FLATS)
	_spawn_l = room.cell_to_world(t.player_spawn)
	_spawn_r = room.cell_to_world(Vector2i(W - 1 - t.player_spawn.x, t.player_spawn.y))
	host = _keeper(false)
	ally = _keeper(true)
	add_child(repl)
	var cam := GameCamera.new()
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = UI.label("", 16, UI.PRIMARY, HORIZONTAL_ALIGNMENT_CENTER)
	_label.position = Vector2(120, 24)
	_label.size = Vector2(400, 20)
	layer.add_child(_label)
	Net.message.connect(_on_message)
	Net.left.connect(_on_left)
	EventBus.damage_dealt.connect(_on_damage)
	EventBus.player_died.connect(func(): _fell(0))
	ally.downed.connect(func(): _fell(1))
	_send_room()
	_start_round()


func _exit_tree() -> void:
	for pair in [[Net.message, _on_message], [Net.left, _on_left], [EventBus.damage_dealt, _on_damage]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func _keeper(remote: bool) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.forced_weapon = "gaff"
	p.pvp_locked = true
	if remote:
		p.name = "Guest"
		p.is_remote = true
		p.body_tint = CoopHost.GUEST_TINT
		p.net_input = PlayerInput.new()
	add_child(p)
	enable_pvp_masks(p.weapon)
	return p


func _physics_process(delta: float) -> void:
	repl.step_ally(ally)
	_tick += 1
	if _tick % SNAPSHOT_EVERY == 0:
		repl.flush(host, ally, _tick, epoch, 0.0)
	match _phase:
		Phase.COUNTDOWN:
			_t -= delta
			_label.text = str(maxi(1, int(ceil(_t))))
			if _t <= 0.0:
				_phase = Phase.FIGHT
				_freeze(false)
				_label.text = "FIGHT"
				_state(Phase.FIGHT, rules.round)
		Phase.ROUND_OVER:
			_t -= delta
			if _t <= 0.0:
				_start_round()
		Phase.MATCH_OVER:
			_t -= delta
			if _t <= 0.0:
				_t = 9999.0
				Net.return_to_lobby()
				get_tree().change_scene_to_file(MP_MENU)
		_:
			if _label.text == "FIGHT" and _tick % 60 == 0:
				_label.text = ""


func _start_round() -> void:
	for p in [host, ally]:
		p.revive(p.health.max_hp) if p.dead else _restore(p)
	host.global_position = _spawn_l
	ally.global_position = _spawn_r
	host.velocity = Vector2.ZERO
	ally.velocity = Vector2.ZERO
	_freeze(true)
	_phase = Phase.COUNTDOWN
	_t = COUNTDOWN
	_state(Phase.COUNTDOWN, rules.round)


func _restore(p: Player) -> void:
	p.health.hp = p.health.max_hp
	p.health.changed.emit(p.health.hp, p.health.max_hp)


func _freeze(on: bool) -> void:
	host.pvp_frozen = on
	ally.pvp_frozen = on


func _fell(i: int) -> void:
	rules.fall(i)
	if not _resolve_queued:
		_resolve_queued = true
		call_deferred("_resolve")


func _resolve() -> void:
	_resolve_queued = false
	var r := rules.resolve()
	if r.kind == "none":
		return
	_freeze(true)
	var winner := 2 if r.kind == "draw" else int(r.winner)
	if bool(r.match_over):
		_phase = Phase.MATCH_OVER
		_t = PAUSE + 1.0
		_label.text = "YOU WIN THE DUEL" if winner == 0 else "THEY WIN THE DUEL"
		_state(Phase.MATCH_OVER, winner)
	else:
		_phase = Phase.ROUND_OVER
		_t = PAUSE
		_label.text = "A DRAW" if winner == 2 else ("YOU TAKE THE ROUND" if winner == 0 else "THEY TAKE THE ROUND")
		_state(Phase.ROUND_OVER, winner)


func _state(phase: Phase, b: int) -> void:
	repl.send_event(NetProtocol.Ev.PVP_STATE, int(phase), b, Vector2(rules.wins[0], rules.wins[1]))


func _send_room() -> void:
	var t: RoomTemplate = room.template
	Net.send_reliable(NetProtocol.encode_room_enter(epoch, RoomGraph.COMBAT, t.name, t.to_text(), 777, false, 0))


func _on_message(type: int, bytes: PackedByteArray) -> void:
	if type == NetProtocol.Msg.INPUT:
		repl.push_input_frames(NetProtocol.decode_inputs(bytes))
	elif type == NetProtocol.Msg.RESYNC:
		repl.forget_all()
		_send_room()
		_state(_phase, rules.round)


func _on_damage(target: Node, info: DamageInfo) -> void:
	var id := NetReplicator.HOST_ID if target == host else (NetReplicator.GUEST_ID if target == ally else -1)
	if id >= 0:
		repl.send_event(NetProtocol.Ev.HIT, id, mini(info.amount, 65535), (target as Node2D).global_position)


func _on_left(_reason: String) -> void:
	get_tree().call_deferred("change_scene_to_file", MP_MENU)
