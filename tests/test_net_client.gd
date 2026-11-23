extends TestCase
## The guest's view: puppets follow snapshots, and nothing stale or unknown can break it.


func _view() -> ClientView:
	var v := ClientView.new()
	v.entities = Node2D.new()
	v.epoch = 2
	return v


func _ent(id: int, pos: Vector2) -> Dictionary:
	return {"id": id, "kind": NetReplicator.Kind.ENEMY, "pos": pos, "hp": 3, "anim": 0, "flags": 0}


func _free(v: ClientView) -> void:
	v.entities.free()
	v.free()


func test_ignores_stale_epoch_and_unknown_ids() -> void:
	var v := _view()
	v.handle_snapshot({"tick": 5, "ack": 0, "epoch": 1, "entities": [_ent(77, Vector2(1, 1))]})
	assert_eq(v.puppets.size(), 0, "a snapshot from the room before is dropped")
	v.handle_snapshot({"tick": 6, "ack": 0, "epoch": 2, "entities": [_ent(77, Vector2(1, 1))]})
	assert_eq(v.puppets.size(), 0, "an id that was never announced is ignored")
	_free(v)


func test_spawn_snapshot_then_despawn() -> void:
	var v := _view()
	v.handle_spawn({"id": 5, "kind": NetReplicator.Kind.ENEMY, "pos": Vector2(10, 20), "scene_key": "enemies/gull"})
	assert_eq(v.puppets.size(), 1)
	v.handle_snapshot({"tick": 6, "ack": 0, "epoch": 2, "entities": [_ent(5, Vector2(30, 40))]})
	var p: Puppet = v.puppets[5]
	assert_near(p.buffer.sample(100000).pos.x, 30.0, 0.01, "the snapshot fed the puppet")
	v.handle_snapshot({"tick": 7, "ack": 0, "epoch": 1, "entities": [_ent(5, Vector2(999, 999))]})
	assert_near(p.buffer.sample(100000).pos.x, 30.0, 0.01, "a stale snapshot does not move it")
	v.handle_despawn({"id": 5})
	assert_eq(v.puppets.size(), 0)
	assert_true(not is_instance_valid(p), "the puppet is freed")
	v.handle_despawn({"id": 5})  # a repeat is harmless
	_free(v)


func test_unknown_scene_key_still_gets_a_puppet() -> void:
	var v := _view()
	v.handle_spawn({"id": 9, "kind": NetReplicator.Kind.ENEMY, "pos": Vector2.ZERO, "scene_key": "nonsense/nothing"})
	assert_eq(v.puppets.size(), 1)
	v.handle_spawn({"id": 10, "kind": NetReplicator.Kind.PROJECTILE, "pos": Vector2.ZERO, "scene_key": "projectile"})
	v.handle_spawn({"id": 11, "kind": NetReplicator.Kind.PICKUP, "pos": Vector2.ZERO, "scene_key": "pickup"})
	assert_eq(v.puppets.size(), 3)
	_free(v)
