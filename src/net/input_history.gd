class_name InputHistory
extends RefCounted
## The guest's unacknowledged input frames (frame = {seq, move, aim, buttons}). Sequence
## numbers are u16 and wrap.

const MAX_FRAMES := 120

var _frames: Array = []


func push(frame: Dictionary) -> void:
	_frames.append(frame)
	if _frames.size() > MAX_FRAMES:
		_frames.pop_front()


## Drop every frame the host has processed (seq <= acked, with wrap-around).
func ack(seq: int) -> void:
	while not _frames.is_empty() and ((seq - int(_frames[0].seq)) & 0xFFFF) < 0x8000:
		_frames.pop_front()


func pending() -> Array:
	return _frames


func last_three() -> Array:
	return _frames.slice(maxi(0, _frames.size() - 3))
