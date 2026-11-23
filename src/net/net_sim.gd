class_name NetSim
extends RefCounted
## A bad network in a box: holds packets for `latency_ms` plus up to `jitter_ms`, and drops
## unreliable ones at `loss`. Reliable packets are only delayed, and stay in order.

var latency_ms: int = 0
var jitter_ms: int = 0
var loss: float = 0.0

var _rng := RandomNumberGenerator.new()
var _queue: Array = []
var _seq: int = 0
var _last_reliable_due: int = 0


func _init(rng_seed: int = 1) -> void:
	_rng.seed = rng_seed


func submit(data: PackedByteArray, channel: int, now_ms: int, reliable: bool) -> void:
	if not reliable and loss > 0.0 and _rng.randf() < loss:
		return
	var due := now_ms + latency_ms + (_rng.randi_range(0, jitter_ms) if jitter_ms > 0 else 0)
	if reliable:
		due = maxi(due, _last_reliable_due)
		_last_reliable_due = due
	_seq += 1
	_queue.append({"due": due, "seq": _seq, "data": data, "channel": channel})


## Everything due by `now_ms`, earliest first.
func poll(now_ms: int) -> Array:
	var out: Array = []
	var keep: Array = []
	for q in _queue:
		if int(q.due) <= now_ms:
			out.append(q)
		else:
			keep.append(q)
	_queue = keep
	out.sort_custom(func(a, b): return a.due < b.due or (a.due == b.due and a.seq < b.seq))
	return out
