extends TestCase
## Sanity checks that the skeleton loads. Real system tests come with each milestone.


func test_player_scene_loads() -> void:
	var scene: PackedScene = load("res://src/player/player.tscn")
	assert_true(scene != null, "player.tscn should load")
	var p = scene.instantiate()
	assert_true(p is Player, "root should be Player")
	p.free()


func test_player_dash_math() -> void:
	# 3 tiles in 0.15s: speed the dash needs so the design numbers hold.
	assert_near(Player.DASH_DISTANCE / Player.DASH_TIME, 320.0)
	assert_eq(Player.DASH_CHARGES, 3)


func test_damage_info_normalises_direction() -> void:
	var d := DamageInfo.make(5, null, Vector2(3, 4), 10.0)
	assert_near(d.direction.length(), 1.0)
	assert_eq(d.amount, 5)


## Every script and scene under src/ parses: the unit tests never touch the hub or the title
## directly, and a typo there would otherwise only show up when the game was opened.
func test_every_script_and_scene_loads() -> void:
	var stack: Array = ["res://src/"]
	var n := 0
	while stack.size() > 0:
		var dir: String = stack.pop_back()
		for d in DirAccess.get_directories_at(dir):
			stack.append(dir + d + "/")
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") or f.ends_with(".tscn"):
				var res = load(dir + f)
				assert_true(res != null, "loads: " + dir + f)
				if res is GDScript:
					assert_true(res.can_instantiate() or res.is_abstract(), "compiles: " + dir + f)
				n += 1
	assert_true(n >= 100, "found %d scripts and scenes" % n)


func test_game_seed_is_deterministic() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 12345
	b.seed = 12345
	for i in 10:
		assert_eq(a.randi(), b.randi())
