class_name Prediction
extends RefCounted
## Client-side prediction, server reconciliation: start from where the host says the keeper
## was at the last input it processed, replay the inputs it has not seen yet, and compare
## with where the guest drew the keeper.

const SNAP_DIST := 48.0   # beyond this the guest is simply wrong: jump
const SMOOTH := 0.25      # otherwise close a quarter of the gap per snapshot


## `step(pos: Vector2, frame: Dictionary) -> Vector2` applies one input frame.
static func reconcile(server_pos: Vector2, ack_seq: int, hist: InputHistory, local_pos: Vector2, step: Callable) -> Dictionary:
	hist.ack(ack_seq)
	var p := server_pos
	for f in hist.pending():
		p = step.call(p, f)
	var err := p.distance_to(local_pos)
	if err > SNAP_DIST:
		return {"pos": p, "error": err, "snapped": true}
	return {"pos": local_pos.lerp(p, SMOOTH), "error": err, "snapped": false}
