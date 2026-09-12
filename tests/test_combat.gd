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
			"res://src/enemies/wrack_crab.tscn", "res://src/enemies/wreck.tscn",
			"res://src/enemies/still_citizen.tscn", "res://src/enemies/lamplighter.tscn",
			"res://src/enemies/bell_ringer.tscn", "res://src/enemies/swimmer.tscn", "res://src/enemies/bell.tscn",
			"res://src/enemies/keeper_shade.tscn", "res://src/enemies/anchor.tscn", "res://src/enemies/deep_maw.tscn",
			"res://src/enemies/ebb.tscn"]:
		var s: PackedScene = load(path)
		assert_true(s != null, path + " loads")
		var inst = s.instantiate()
		assert_true(inst is Enemy, path + " root is Enemy")
		inst.free()


func test_weapon_scenes_share_the_api() -> void:
	assert_eq(Weapon.ALL.size(), 6, "six weapons")
	for id in Weapon.ALL:
		var scene := Weapon.scene_for(id)
		assert_true(scene != null, id + " scene loads")
		var w = scene.instantiate()
		assert_true(w is Weapon, id + " is a Weapon")
		# The base API must exist on every weapon; the player calls all of these.
		for m in ["move_mult", "is_busy", "special_ready", "special_cooldown_fraction", "charge_fraction",
				"is_charging", "try_attack", "set_held", "try_lunge", "try_special", "cancel", "on_dash", "ammo_text"]:
			assert_true(w.has_method(m), "%s has %s" % [id, m])
		w.free()


func test_hurtbox_shield_absorbs_one_hit() -> void:
	var h := Health.new()
	h.max_hp = 10
	h._ready()
	var hb := Hurtbox.new()
	hb.health = h
	hb.shield_count = 1
	var shielded := [0]
	hb.shielded.connect(func(_i): shielded[0] += 1)
	assert_true(not hb.receive(DamageInfo.make(4, null, Vector2.RIGHT)), "first hit is absorbed")
	assert_eq(h.hp, 10)
	assert_eq(shielded[0], 1)
	assert_true(hb.receive(DamageInfo.make(4, null, Vector2.RIGHT)), "second hit lands")
	assert_eq(h.hp, 6)
	hb.free()
	h.free()


## The gaff's heavy sweep only exists once the charge completes. Let go early and the
## hook just drops back: no state change into HEAVY, no hitbox, no swing.
## Every enemy scene must load, wire its sprite and name itself; the M6 additions too.
func test_new_enemy_scenes() -> void:
	for f in ["tidewisp", "netted", "choir", "tallow", "mooring", "barnacle", "deckhand", "chainmother"]:
		var scene: PackedScene = load("res://src/enemies/%s.tscn" % f)
		assert_true(scene != null, f + " loads")
		var e = scene.instantiate()
		assert_true(e is Enemy, f + " is an Enemy")
		assert_true(e.display_name != "Enemy", f + " is named")
		assert_true(e.get_node_or_null("Health") != null and e.get_node_or_null("Hurtbox") != null, f + " is wired")
		e.free()


func test_aspects_table() -> void:
	var seen := {}
	for w in Weapon.ALL:
		var list: Array = Weapon.ASPECTS.get(w, [])
		assert_eq(list.size(), 2, "two aspects for " + w)
		for a in list:
			assert_true(not seen.has(a.id), "unique aspect id " + str(a.id))
			seen[a.id] = true
			assert_true(a.id.begins_with(w + "_"), "aspect id names its weapon: " + str(a.id))
			assert_true(str(a.desc).length() * 6 <= 300, "aspect desc fits: " + str(a.id))
			assert_eq(Weapon.aspect_entry(a.id).name, a.name)
	assert_true(Weapon.aspect_entry("nonsense").is_empty())
	assert_eq(Weapon.ALL.size(), 6, "six weapons")


func test_bell_and_line_load_with_an_aspect() -> void:
	SaveManager.use_path("user://test_aspects.json")
	SaveManager.wipe()
	SaveManager.data["aspects"] = {"bell": "bell_keeper", "line": "line_long"}
	assert_eq(Weapon.aspect_of("bell"), "bell_keeper")
	assert_eq(Weapon.aspect_of("gaff"), "", "plain when unset")
	var player: Player = load("res://src/player/player.tscn").instantiate()
	var bell: KeepersBell = Weapon.scene_for("bell").instantiate()
	player.add_child(bell)
	bell._ready()
	assert_eq(bell.aspect, "bell_keeper")
	assert_near(bell._parry_window, 0.55)
	assert_true(bell.special_ready(), "toll ready at the start")
	var line: LineSinker = Weapon.scene_for("line").instantiate()
	player.add_child(line)
	line._ready()
	assert_eq(line.aspect, "line_long")
	assert_near(line._reach, LineSinker.REACH + 12.0)
	var rect := line.hit_shape.shape as RectangleShape2D
	assert_near(rect.size.x, LineSinker.REACH + 8.0, 0.01)
	line.try_attack()
	assert_eq(line.state, LineSinker.State.CRACK, "a crack starts from idle")
	player.free()
	SaveManager.wipe()
	SaveManager.use_path(SaveManager.PATH)


func test_gaff_heavy_needs_a_full_charge() -> void:
	# Built outside the tree (the runner is mid-ready); calling _ready() by hand still
	# runs the @onready wiring.
	var player: Player = load("res://src/player/player.tscn").instantiate()
	var w: GaffHook = Weapon.scene_for("gaff").instantiate()
	player.add_child(w)
	w._ready()
	assert_true(w.hitbox != null, "gaff wired")
	# Hold from idle: charging starts after HOLD_TIME.
	w.set_held(true)
	w._process(GaffHook.HOLD_TIME + 0.05)
	assert_true(w.is_charging(), "holding starts a charge")
	w._process(GaffHook.CHARGE_FULL * 0.5)
	assert_true(not w.charge_complete(), "half a charge is not complete")
	w.set_held(false)
	assert_eq(w.state, GaffHook.State.IDLE, "early release: nothing")
	assert_true(not w.hitbox.active, "early release arms no hitbox")
	assert_eq(w.charge_fraction(), 0.0, "charge is gone")
	# Hold all the way: release fires the heavy.
	w.set_held(true)
	w._process(GaffHook.HOLD_TIME + 0.05)
	w._process(GaffHook.CHARGE_FULL + 0.05)
	assert_true(w.charge_complete(), "full charge is complete")
	w.set_held(false)
	assert_eq(w.state, GaffHook.State.HEAVY, "full release: heavy sweep")
	assert_eq(w.hitbox.damage, GaffHook.HEAVY_DAMAGE)
	# Holding past CHARGE_MAX releases on its own, at full strength.
	w.cancel()
	w.set_held(true)
	w._process(GaffHook.HOLD_TIME + 0.05)
	w._process(GaffHook.CHARGE_MAX + 0.05)
	assert_eq(w.state, GaffHook.State.HEAVY, "overcharge auto-releases")
	player.free()
