extends TestCase
## Reconciliation of the guest's predicted keeper, and snapshot interpolation of puppets.

var step := func(pos: Vector2, f: Dictionary) -> Vector2: return pos + f.move * 10.0


func _hist(first: int, count: int) -> InputHistory:
	var h := InputHistory.new()
	for i in count:
		h.push({"seq": (first + i) & 0xFFFF, "move": Vector2(1, 0), "aim": 0.0, "buttons": 0})
	return h


func test_reconcile_no_error_when_server_matches() -> void:
	var h := _hist(1, 5)
	var r := Prediction.reconcile(Vector2(30, 0), 3, h, Vector2(50, 0), step)
	assert_near(r.error, 0.0)
	assert_eq(r.pos, Vector2(50, 0))
	assert_true(not r.snapped)


func test_reconcile_replays_pending_inputs() -> void:
	var h := _hist(1, 5)
	Prediction.reconcile(Vector2(30, 0), 3, h, Vector2(50, 0), step)
	assert_eq(h.pending().size(), 2, "frames 4 and 5 are still unacknowledged")


func test_reconcile_small_error_smooths_not_snaps() -> void:
	var h := _hist(1, 5)
	var r := Prediction.reconcile(Vector2(31, 0), 3, h, Vector2(50, 0), step)
	assert_near(r.error, 1.0)
	assert_true(not r.snapped)
	assert_near(r.pos.x, 50.0 + 1.0 * Prediction.SMOOTH, 0.001)


func test_reconcile_large_error_snaps() -> void:
	var h := _hist(1, 5)
	var r := Prediction.reconcile(Vector2(100, 0), 3, h, Vector2(50, 0), step)
	assert_true(r.snapped)
	assert_eq(r.pos, Vector2(120, 0))


func test_ack_wraps_u16() -> void:
	var h := _hist(65534, 4)  # 65534, 65535, 0, 1
	h.ack(65535)
	assert_eq(h.pending().size(), 2)
	assert_eq(h.pending()[0].seq, 0)
	h.ack(1)
	assert_eq(h.pending().size(), 0)


func test_last_three() -> void:
	var h := _hist(1, 6)
	var l := h.last_three()
	assert_eq(l.size(), 3)
	assert_eq(l[0].seq, 4)
	assert_eq(l[2].seq, 6)


func test_interp_midpoint() -> void:
	var b := InterpBuffer.new()
	b.push(0, Vector2(0, 0), 1, 10)
	b.push(100, Vector2(100, 0), 2, 9)
	var s := b.sample(50)
	assert_true(s.valid)
	assert_near(s.pos.x, 50.0, 0.01)
	assert_true(not s.extrapolated)


func test_interp_extrapolates_then_holds() -> void:
	var b := InterpBuffer.new()
	b.push(0, Vector2(0, 0), 0, 1)
	b.push(100, Vector2(100, 0), 0, 1)
	var s1 := b.sample(150)
	assert_true(s1.extrapolated)
	assert_near(s1.pos.x, 150.0, 0.01)
	var s2 := b.sample(400)
	assert_near(s2.pos.x, 100.0 + float(InterpBuffer.EXTRAP_CAP_MS), 0.01)
	assert_eq(b.underruns, 2)


func test_interp_ignores_out_of_order_sample() -> void:
	var b := InterpBuffer.new()
	b.push(100, Vector2(100, 0), 0, 1)
	b.push(50, Vector2(999, 0), 0, 1)
	var s := b.sample(100)
	assert_near(s.pos.x, 100.0, 0.01)


func test_interp_empty_is_invalid() -> void:
	assert_true(not InterpBuffer.new().sample(10).valid)
