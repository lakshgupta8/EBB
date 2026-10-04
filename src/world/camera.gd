class_name GameCamera
extends Camera2D
## Trauma-based screen shake. Ask for shake through EventBus.request_shake(strength 0..1).
## In a run it also follows Tam through rooms larger than the screen (map Stage 02, STYLE.md
## 22): clamped so the view never leaves the room, centred on any axis where the room is
## smaller than the screen, leaning a little the way Tam moves, snapped on entering a room,
## and always on a whole pixel so the tiles never shimmer.

const MAX_OFFSET := 6.0
const DECAY := 2.2
## How fast the view catches Tam (per second, exponential).
const FOLLOW := 7.0
## How far it leans the way Tam moves, px at full speed, and how fast the lean turns.
const LEAD := 28.0
const LEAD_RATE := 3.0
## The haze drifts at this share of the camera's travel, so it reads as air above the ground.
const HAZE_SHIFT := 0.8

var _trauma: float = 0.0
var _noise := FastNoiseLite.new()
var _t: float = 0.0
var _room_id: int = 0
var _smooth: Vector2 = Vector2.ZERO
var _lead: Vector2 = Vector2.ZERO
var _home: Vector2 = Vector2.ZERO  # where the scene put the camera: the haze is laid out round it


func _ready() -> void:
	_noise.seed = 7
	_noise.frequency = 1.0
	_home = position
	_smooth = position
	EventBus.request_shake.connect(add_trauma)


func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func _process(delta: float) -> void:
	_follow(delta)
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return
	_t += delta * 60.0
	_trauma = maxf(0.0, _trauma - DECAY * delta)
	var s := _trauma * _trauma * Settings.shake()
	offset = Vector2(
		_noise.get_noise_2d(_t, 0.0) * MAX_OFFSET * s,
		_noise.get_noise_2d(0.0, _t) * MAX_OFFSET * s,
	).round()


## The room being played: the newest one in the group that is not on its way out.
func _room() -> Room:
	var found: Room = null
	for r in get_tree().get_nodes_in_group("room"):
		if r is Room and not r.is_queued_for_deletion() and r.template != null:
			found = r
	return found


## Where the camera's centre may go in a room: the room's own centre on an axis where it is
## no larger than the screen, otherwise anywhere that keeps the view inside it.
static func clamp_to_room(want: Vector2, room_rect: Rect2, view: Vector2) -> Vector2:
	var out := want
	for axis in 2:
		var lo := room_rect.position[axis] + view[axis] * 0.5
		var hi := room_rect.end[axis] - view[axis] * 0.5
		out[axis] = (room_rect.position[axis] + room_rect.end[axis]) * 0.5 if lo >= hi else clampf(want[axis], lo, hi)
	return out


func _follow(delta: float) -> void:
	var room := _room()
	var tam := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if room == null or tam == null:
		return
	var view := get_viewport_rect().size / zoom
	var rect := Rect2(room.global_position, room.size_px())
	var speed := tam.velocity.length()
	var lead_to := tam.velocity / speed * LEAD * minf(1.0, speed / 120.0) if speed > 1.0 else Vector2.ZERO
	if room.get_instance_id() != _room_id:
		# A new room: no glide across from the last one.
		_room_id = room.get_instance_id()
		_lead = Vector2.ZERO
		_smooth = clamp_to_room(tam.global_position, rect, view)
	else:
		_lead = _lead.lerp(lead_to, 1.0 - exp(-LEAD_RATE * delta))
		var want := clamp_to_room(tam.global_position + _lead, rect, view)
		_smooth = _smooth.lerp(want, 1.0 - exp(-FOLLOW * delta))
	global_position = _smooth.round()
	var haze := get_parent().get_node_or_null("Haze") as Node2D
	if haze != null:
		haze.position = ((global_position - _home) * HAZE_SHIFT).round()


## Put the view straight on Tam (a teleport, a rest resumed, a screenshot staged).
func snap() -> void:
	_room_id = 0
