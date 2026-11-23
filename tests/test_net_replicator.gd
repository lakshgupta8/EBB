extends TestCase
## Host side: who enemies chase, how the guest's input frames are applied, what a snapshot
## says, and when a night with two keepers is over.


func _frame(seq: int, dash: bool = false) -> Dictionary:
	return {"seq": seq, "move": Vector2(1, 0), "aim": 0.0, "buttons": NetProtocol.BTN_DASH if dash else 0}


func test_nearest_player_prefers_living() -> void:
	var a := Player.new()
	var b := Player.new()
	a.position = Vector2(10, 0)
	b.position = Vector2(100, 0)
	a.dead = true
	assert_eq(Player.nearest_of(Vector2(0, 0), [a, b]), b, "the dead near one is ignored")
	b.dead = true
	assert_eq(Player.nearest_of(Vector2(0, 0), [a, b]), a, "all down: the nearest anyway")
	a.free()
	b.free()


func test_input_frames_applied_in_order_and_once() -> void:
	var r := NetReplicator.new()
	var ally := Player.new()
	r.push_input_frames([_frame(1), _frame(2), _frame(3, true)])
	r.push_input_frames([_frame(2), _frame(3, true), _frame(4)])  # the redundant copies
	assert_eq(r.queued(), 4, "each seq is queued once")
	r.step_ally(ally)
	assert_eq(r.ack_seq, 1)
	r.step_ally(ally)
	r.step_ally(ally)
	assert_eq(r.ack_seq, 3)
	assert_true(ally.net_input.dash_pressed, "the dash edge lands on the tick of frame 3")
	r.step_ally(ally)
	assert_eq(r.ack_seq, 4)
	assert_true(not ally.net_input.dash_pressed)
	ally.net_input.consume_edges()
	r.step_ally(ally)  # nothing queued: keep walking, no new edges
	assert_eq(r.ack_seq, 4)
	assert_near(ally.net_input.move.x, 1.0, 0.01)
	assert_true(not ally.net_input.dash_pressed)
	ally.free()
	r.free()


func test_snapshot_ids_stable_and_despawn_emitted() -> void:
	var r := NetReplicator.new()
	var e1 := Node2D.new()
	e1.set_meta("net_kind", NetReplicator.Kind.ENEMY)
	e1.position = Vector2(5, 5)
	var e2 := Node2D.new()
	e2.set_meta("net_kind", NetReplicator.Kind.ENEMY)
	var live: Array = [e1, e2]
	r.source = func(): return live
	var out := r.collect()
	var ids1: Array = out.entities.map(func(e): return e.id)
	assert_eq(ids1.size(), 2)
	assert_eq(out.spawned.size(), 2, "both announced the first time")
	var out2 := r.collect()
	assert_eq(out2.entities.map(func(e): return e.id), ids1, "ids are stable across snapshots")
	assert_eq(out2.spawned.size(), 0)
	live.erase(e2)
	var out3 := r.collect()
	assert_eq(out3.despawned.size(), 1)
	assert_eq(out3.entities.size(), 1)
	assert_eq(r.collect().despawned.size(), 0, "a despawn is announced once")
	e1.free()
	e2.free()
	r.free()


func test_both_down_ends_the_run_once() -> void:
	var rules := CoopRules.new()
	assert_true(not rules.on_down(0), "the host falls: the guest still stands")
	assert_true(rules.on_down(1), "the guest falls too: the night ends")
	assert_true(not rules.on_down(1), "and only once")


func test_revive_on_clear_brings_back_the_fallen() -> void:
	var rules := CoopRules.new()
	rules.on_down(1)
	assert_eq(rules.revive_all(), [1])
	assert_eq(rules.revive_all(), [], "nobody left to revive")
	assert_true(not rules.on_down(0), "the guest stands again, so one fall is not the end")


func test_forget_all_reannounces_everything() -> void:
	var r := NetReplicator.new()
	var e1 := Node2D.new()
	e1.set_meta("net_kind", NetReplicator.Kind.ENEMY)
	var live: Array = [e1]
	r.source = func(): return live
	assert_eq(r.collect().spawned.size(), 1)
	assert_eq(r.collect().spawned.size(), 0)
	r.forget_all()  # a guest that loaded late asks to be told everything again
	assert_eq(r.collect().spawned.size(), 1)
	e1.free()
	r.free()
