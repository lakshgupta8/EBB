class_name CoopHost
extends Node
## The host's side of a co-op night, attached to the (otherwise unchanged) run. It spawns the
## guest's keeper as a second Player driven by the wire, applies the tide to it, sends the
## guest rooms, snapshots and events, and decides when the night is over (both keepers down).

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const SNAPSHOT_EVERY := 3  # physics ticks: 60 / 3 = 20 snapshots a second
const MP_MENU := "res://src/multiplayer/mp_menu.tscn"
const GUEST_TINT := Color(0.66, 0.82, 1.0)

var run: Node
var host: Player
var ally: Player
var repl := NetReplicator.new()
var rules := CoopRules.new()
var epoch: int = 0

var _tick: int = 0
var _deep_tick: float = 0.0


func setup(p_run: Node) -> void:
	run = p_run
	host = run.player
	process_physics_priority = -10  # before the keepers, so the ally has this tick's input
	add_child(repl)
	ally = PLAYER_SCENE.instantiate()
	ally.name = "Ally"
	ally.is_remote = true
	ally.forced_weapon = "gaff"
	ally.body_tint = GUEST_TINT
	ally.net_input = PlayerInput.new()
	host.get_parent().add_child(ally)
	ally.global_position = host.global_position + Vector2(16, 0)
	ally.downed.connect(func(): _on_fell(1))
	Net.message.connect(_on_message)
	Net.left.connect(_on_left)
	EventBus.damage_dealt.connect(_on_damage)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.pickup_collected.connect(_on_pickup)


func _exit_tree() -> void:
	for pair in [[Net.message, _on_message], [Net.left, _on_left], [EventBus.damage_dealt, _on_damage],
			[EventBus.enemy_died, _on_enemy_died], [EventBus.pickup_collected, _on_pickup]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func _physics_process(delta: float) -> void:
	if ally == null or not is_instance_valid(ally) or run.room == null:
		return
	repl.step_ally(ally)
	_tide(delta)
	_tick += 1
	if _tick % SNAPSHOT_EVERY == 0:
		repl.flush(host, ally, _tick, epoch, run.state.tide.level)


## The host's own fall. True when the night is over (the guest is down too).
func host_fell() -> bool:
	repl.send_event(NetProtocol.Ev.DOWNED, 0, 0, host.global_position)
	return rules.on_down(0)


func on_room_entered() -> void:
	epoch = (epoch + 1) & 0xFF
	var t: RoomTemplate = run.room.template
	Net.send_reliable(NetProtocol.encode_room_enter(epoch, run.room_type, t.name, t.to_text(), run._room_seed, run._wet_room, run.state.biome))
	ally.global_position = host.global_position + Vector2(14, 6)
	ally.velocity = Vector2.ZERO


func on_room_cleared() -> void:
	for i in rules.revive_all():
		var p: Player = host if i == 0 else ally
		p.revive(p.health.max_hp / 2)
		repl.send_event(NetProtocol.Ev.REVIVED, i, 0, p.global_position)
	repl.send_event(NetProtocol.Ev.CLEARED, 0, 0, host.global_position)


## The tide's damage to the guest's keeper (the run applies it to the host's).
func _tide(delta: float) -> void:
	if ally.dead:
		return
	var room: Room = run.room
	ally.in_water = room.is_flooded_at(ally.global_position)
	if room.current != null:
		room.carry(ally, delta)
	if room.is_deep_at(ally.global_position):
		_deep_tick += delta
		if _deep_tick >= TideSystem.DEEP_TICK:
			_deep_tick = 0.0
			var info := DamageInfo.make(TideSystem.DEEP_DAMAGE, null, Vector2.ZERO, 0.0)
			info.tags = PackedStringArray(["tide"])
			info.hitstop = 0.0
			ally.take_tide_damage(info)
	else:
		_deep_tick = 0.0


func _on_fell(i: int) -> void:
	repl.send_event(NetProtocol.Ev.DOWNED, i, 0, ally.global_position)
	if rules.on_down(i):
		run.state.taken = false
		run._end_run()


func _on_message(type: int, bytes: PackedByteArray) -> void:
	if type == NetProtocol.Msg.INPUT:
		repl.push_input_frames(NetProtocol.decode_inputs(bytes))


## The guest is gone: the night cannot go on as a shared one. Back to the menu, not recorded.
func _on_left(_reason: String) -> void:
	get_tree().call_deferred("change_scene_to_file", MP_MENU)


func _net_id(n: Node) -> int:
	if n == host:
		return NetReplicator.HOST_ID
	if n == ally:
		return NetReplicator.GUEST_ID
	return repl.id_of(n)


func _on_damage(target: Node, info: DamageInfo) -> void:
	var id := _net_id(target)
	if id >= 0 and target is Node2D:
		repl.send_event(NetProtocol.Ev.HIT, id, mini(info.amount, 65535), target.global_position)


func _on_enemy_died(enemy: Node) -> void:
	var id := _net_id(enemy)
	if id >= 0 and enemy is Node2D:
		repl.send_event(NetProtocol.Ev.DEATH, id, 0, enemy.global_position)


func _on_pickup(kind: int, value: int) -> void:
	repl.send_event(NetProtocol.Ev.PICKUP, kind, clampi(value, 0, 65535), host.global_position)
