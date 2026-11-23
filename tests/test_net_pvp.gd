extends TestCase
## The duel: rounds and scoring, and the hit masks that let one keeper hurt the other.


func test_best_of_three_ends_at_two_wins() -> void:
	var r := PvpRules.new()
	r.fall(1)
	var a := r.resolve()
	assert_eq(a.kind, "win")
	assert_eq(a.winner, 0)
	assert_true(not a.match_over)
	r.fall(0)
	var b := r.resolve()
	assert_eq(b.winner, 1)
	assert_true(not b.match_over, "one each: a deciding round")
	r.fall(1)
	var c := r.resolve()
	assert_true(c.match_over)
	assert_eq(c.wins, [2, 1])
	r.fall(0)
	assert_eq(r.resolve().kind, "none", "nothing counts after the match is over")


func test_draw_replays_round_without_score() -> void:
	var r := PvpRules.new()
	r.fall(0)
	r.fall(1)  # both fall in the same tick
	var d := r.resolve()
	assert_eq(d.kind, "draw")
	assert_eq(d.wins, [0, 0])
	assert_eq(r.round, 1, "the round is played again")
	assert_eq(r.resolve().kind, "none", "and the fall is not counted twice")


func test_pvp_hitbox_masks_opponent_but_enemy_mask_stays() -> void:
	var w: GaffHook = Weapon.scene_for("gaff").instantiate()
	w._ready()
	assert_eq(w.hitbox.collision_mask, 128, "outside a duel it hits only enemy hurtboxes")
	PvpArena.enable_pvp_masks(w)
	assert_true(w.hitbox.collision_mask & 128 != 0, "still hits enemies")
	assert_true(w.hitbox.collision_mask & 64 != 0, "now hits the other keeper's hurtbox")
	w.free()


func test_a_hitbox_never_hits_its_own_owner() -> void:
	var owner := Node2D.new()
	var mine := Hurtbox.new()
	owner.add_child(mine)
	var other := Hurtbox.new()
	assert_true(Hitbox.is_own(mine, owner))
	assert_true(not Hitbox.is_own(other, owner))
	other.free()
	owner.free()


func test_arena_is_mirror_symmetric() -> void:
	var t := RoomTemplate.parse(PvpArena.arena_text(), "pvp_arena")
	for row in t.rows:
		var plain := row.replace("P", ".")
		var back := ""
		for i in range(plain.length() - 1, -1, -1):
			back += plain[i]
		assert_eq(back, plain, "every row reads the same both ways")
	assert_true(t.player_spawn != Vector2i(-1, -1))
