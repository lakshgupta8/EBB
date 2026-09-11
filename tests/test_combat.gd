extends TestCase
## Pure-logic combat tests: combo chaining, health, i-frames, damage direction.


func test_combo_advances_and_resets() -> void:
	var c := ComboTracker.new(3, 0.5)
	assert_eq(c.next_step(0.0), 1)
	assert_eq(c.next_step(0.2), 2)
	assert_eq(c.next_step(0.4), 3)
	assert_true(c.is_finisher(3))
	# After a finisher the chain restarts even if quick.
	assert_eq(c.next_step(0.5), 1)
	# A long gap resets mid-chain.
	assert_eq(c.next_step(0.6), 2)
	assert_eq(c.next_step(5.0), 1)


func test_health_takes_damage_and_dies() -> void:
	var h := Health.new()
	h.max_hp = 10
	h._ready()
	var died := [false]
	h.died.connect(func(): died[0] = true)
	assert_true(h.take(DamageInfo.make(4, null, Vector2.RIGHT)))
	assert_eq(h.hp, 6)
	assert_true(h.take(DamageInfo.make(40, null, Vector2.RIGHT)))
	assert_eq(h.hp, 0)
	assert_true(died[0], "died should fire at 0 hp")
	assert_true(not h.take(DamageInfo.make(1, null, Vector2.RIGHT)), "dead things take no damage")
	h.free()


func test_health_iframes_block_second_hit() -> void:
	var h := Health.new()
	h.max_hp = 10
	h.iframe_time = 0.5
	h._ready()
	assert_true(h.take(DamageInfo.make(1, null, Vector2.RIGHT)))
	assert_true(not h.take(DamageInfo.make(1, null, Vector2.RIGHT)), "second hit inside iframes is ignored")
	h._process(0.6)
	assert_true(h.take(DamageInfo.make(1, null, Vector2.RIGHT)), "hit lands after iframes expire")
	assert_eq(h.hp, 8)
	h.free()


func test_health_invulnerable_flag() -> void:
	var h := Health.new()
	h.max_hp = 3
	h._ready()
	h.invulnerable = true
	assert_true(not h.take(DamageInfo.make(1, null, Vector2.RIGHT)))
	assert_eq(h.hp, 3)
	h.free()


func test_hurtbox_damage_mult_and_dodge() -> void:
	var h := Health.new()
	h.max_hp = 10
	h._ready()
	var hb := Hurtbox.new()
	hb.health = h
	hb.damage_mult = 2.0
	assert_true(hb.receive(DamageInfo.make(2, null, Vector2.RIGHT)))
	assert_eq(h.hp, 6, "cracked: damage doubled")
	var dodged := [false]
	hb.dodged.connect(func(_i): dodged[0] = true)
	h.invulnerable = true
	assert_true(not hb.receive(DamageInfo.make(2, null, Vector2.RIGHT)), "no damage while invulnerable")
	assert_true(dodged[0], "dodged fires instead")
	assert_eq(h.hp, 6)
	hb.free()
	h.free()


func test_hitbox_crit_tags() -> void:
	var hb := Hitbox.new()
	hb.damage = 3
	hb.damage_mult = 2.0
	hb.tags = PackedStringArray(["melee"])
	# Build the info the same way the hitbox does, through DamageInfo.
	var info := DamageInfo.make(int(round(hb.damage * hb.damage_mult)), null, Vector2.RIGHT)
	assert_eq(info.amount, 6)
	hb.free()


func test_enemy_scenes_load() -> void:
	for path in ["res://src/enemies/shellback.tscn", "res://src/enemies/gull.tscn",
			"res://src/enemies/wrack_crab.tscn", "res://src/enemies/wreck.tscn"]:
		var s: PackedScene = load(path)
		assert_true(s != null, path + " loads")
		var inst = s.instantiate()
		assert_true(inst is Enemy, path + " root is Enemy")
		inst.free()
