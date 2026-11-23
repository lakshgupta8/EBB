class_name NetReplicator
extends Node
## Host side of the wire: queues the guest's input frames and feeds them to the ally keeper
## one per physics tick, and describes the world (both keepers, everything in the
## `net_replicated` group) as snapshots plus reliable spawn/despawn announcements.

enum Kind { PLAYER_HOST = 1, PLAYER_GUEST, ENEMY, PROJECTILE, PICKUP, TIDE }

const GROUP := "net_replicated"
const HOST_ID := 1
const GUEST_ID := 2
const TIDE_ID := 0
const MAX_QUEUE := 6
const ANIM_NAMES := ["idle", "walk", "windup", "attack", "hurt", "death", "phase", "intro", "dash"]
const FLAG_DEAD := 1
const FLAG_BOSS := 2
const FLAG_ELITE := 4
const FLAG_FLIP := 8

## Where the replicated nodes come from; tests point this at a plain array.
var source: Callable = Callable()
## The seq of the guest frame the ally last applied: sent in every snapshot.
var ack_seq: int = 0xFFFF
## What snapshots acknowledge: the frame applied one step earlier, because a snapshot is taken
## before the keeper has moved with this tick's frame.
var snapshot_ack: int = 0xFFFF

var _queue: Array = []
var _last_queued: int = -1
var _ids: Dictionary = {}    # instance id -> net id
var _nodes: Dictionary = {}  # net id -> instance id
var _next_id: int = 3


func queued() -> int:
	return _queue.size()


## Queue the frames newer than the newest one already queued (the guest repeats its last
## three in every packet, so most arrive more than once).
func push_input_frames(frames: Array) -> void:
	for f in frames:
		var seq := int(f.seq)
		if _last_queued >= 0:
			var ahead := (seq - _last_queued) & 0xFFFF
			if ahead == 0 or ahead >= 0x8000:
				continue
		_last_queued = seq
		_queue.append(f)
	while _queue.size() > MAX_QUEUE:
		_queue.pop_front()  # too far behind: skip ahead rather than lag for good


## One physics tick: give the ally the next queued frame; with none queued it keeps walking
## the way it was, with no new button edges.
func step_ally(ally: Player) -> void:
	snapshot_ack = ack_seq
	if not _queue.is_empty():
		var f: Dictionary = _queue.pop_front()
		ally.net_input = PlayerInput.from_buttons(f.move, f.aim, f.buttons)
		ack_seq = int(f.seq)
	elif ally.net_input == null:
		ally.net_input = PlayerInput.new()
	else:
		ally.net_input.consume_edges()


## Frames that waited while the host's game was paused are stale: drop them.
func clear_queue() -> void:
	_queue.clear()


## Everything replicated right now, plus what appeared and what vanished since the last call.
func collect() -> Dictionary:
	var nodes: Array = source.call() if source.is_valid() else get_tree().get_nodes_in_group(GROUP)
	var seen: Dictionary = {}
	var ents: Array = []
	var spawned: Array = []
	for n in nodes:
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		var iid: int = n.get_instance_id()
		var id: int
		if _ids.has(iid):
			id = _ids[iid]
		else:
			id = _alloc()
			_ids[iid] = id
			_nodes[id] = iid
			spawned.append({"id": id, "kind": _kind(n), "pos": _pos(n), "scene_key": _scene_key(n)})
		seen[id] = true
		ents.append(_describe(id, n))
	var gone: Array = []
	for id in _nodes.keys():
		if not seen.has(id):
			gone.append(id)
			_ids.erase(_nodes[id])
			_nodes.erase(id)
	return {"entities": ents, "spawned": spawned, "despawned": gone}


## Forget what has been announced: the next collect announces everything again (a guest that
## loaded its scene late asks for this).
func forget_all() -> void:
	_ids.clear()
	_nodes.clear()


## Send one snapshot (and the announcements that go with it) to the guest.
func flush(host: Player, ally: Player, tick: int, epoch: int, tide_level: float) -> void:
	var c := collect()
	for s in c.spawned:
		Net.send_reliable(NetProtocol.encode_spawn(s.id, s.kind, s.pos, s.scene_key))
	for id in c.despawned:
		Net.send_reliable(NetProtocol.encode_despawn(id))
	var ents: Array = [_describe_player(HOST_ID, Kind.PLAYER_HOST, host), _describe_player(GUEST_ID, Kind.PLAYER_GUEST, ally),
			{"id": TIDE_ID, "kind": Kind.TIDE, "pos": Vector2.ZERO, "hp": clampi(int(tide_level * 100.0), 0, 65535), "anim": 0, "flags": 0}]
	ents.append_array(c.entities)
	Net.send_unreliable(NetProtocol.encode_snapshot(tick, snapshot_ack, epoch, ents))


func send_event(kind: int, a: int, b: int, pos: Vector2) -> void:
	Net.send_reliable(NetProtocol.encode_event(kind, a, b, pos))


## The net id of a node already announced (-1 when it has none): events refer to things by it.
func id_of(n: Node) -> int:
	return int(_ids.get(n.get_instance_id(), -1))


func _alloc() -> int:
	var id := _next_id
	_next_id = _next_id + 1 if _next_id < 65535 else 3
	return id


func _kind(n: Node) -> int:
	if n.has_meta("net_kind"):
		return int(n.get_meta("net_kind"))
	if n is Projectile:
		return Kind.PROJECTILE
	if n is Pickup:
		return Kind.PICKUP
	return Kind.ENEMY


func _scene_key(n: Node) -> String:
	if n.scene_file_path != "":
		return n.scene_file_path.trim_prefix("res://src/").trim_suffix(".tscn")
	return "projectile" if _kind(n) == Kind.PROJECTILE else ("pickup" if _kind(n) == Kind.PICKUP else "enemy")


static func _pos(n: Node) -> Vector2:
	if n is Node2D:
		return n.global_position if n.is_inside_tree() else n.position
	return Vector2.ZERO


func _describe(id: int, n: Node) -> Dictionary:
	var hp := 0
	var anim := 0
	var flags := 0
	var sprite: AnimatedSprite2D = n.get("sprite") as AnimatedSprite2D
	if sprite != null:
		anim = maxi(0, ANIM_NAMES.find(String(sprite.animation)))
		if sprite.flip_h:
			flags |= FLAG_FLIP
	if n is Pickup:
		anim = int(n.kind)
	var health := n.get("health") as Health
	if health != null:
		hp = health.hp
		if not health.is_alive():
			flags |= FLAG_DEAD
	if n.get("is_boss") == true:
		flags |= FLAG_BOSS
	if n.get("is_elite") == true:
		flags |= FLAG_ELITE
	return {"id": id, "kind": _kind(n), "pos": _pos(n), "hp": hp, "anim": anim, "flags": flags}


func _describe_player(id: int, kind: int, p: Player) -> Dictionary:
	var anim := 0
	var flags := 0
	if p.dead:
		flags |= FLAG_DEAD
	if p.sprite != null:
		anim = maxi(0, ANIM_NAMES.find(String(p.sprite.animation)))
		if p.sprite.flip_h:
			flags |= FLAG_FLIP
	if p.is_dashing():
		anim = ANIM_NAMES.find("dash")
	return {"id": id, "kind": kind, "pos": p.global_position if p.is_inside_tree() else p.position,
			"hp": p.health.hp if p.health != null else 0, "anim": anim, "flags": flags}
