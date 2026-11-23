extends TestCase
## Smoke tests for the Multiplayer screen: it loads, builds in the idle state, and lists only
## addresses another machine could use.


func test_menu_scene_loads_and_builds_idle_page() -> void:
	var scene: PackedScene = load("res://src/multiplayer/mp_menu.tscn")
	assert_true(scene != null and scene.can_instantiate(), "mp_menu.tscn loads")
	var m = scene.instantiate()
	assert_true(m is MpMenu)
	m._render()  # outside the tree, _ready has not run: building the page must still work
	assert_true(m._content != null, "a page was built")
	m.free()


func test_addresses_skip_loopback_and_link_local() -> void:
	var a := MpMenu._addresses()
	assert_true(not a.contains("127.0.0.1"))
	assert_true(not a.contains("169.254."))
