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


func test_overlay_report_text() -> void:
	var r := {"rtt": 50.4, "jitter": 3.0, "bytes_in": 1800, "bytes_out": 700, "snaps_per_s": 20, "lost": 1,
			"corrections": 20, "mean_correction": 0.8, "underruns": 2}
	var text := NetOverlay.format_report(r, {"latency": 80, "jitter": 10, "loss": 0.05})
	assert_true(text.contains("rtt  50 ms"), text)
	assert_true(text.contains("1800 B/s"), text)
	assert_true(text.contains("snap 20/s"), text)
	assert_true(text.contains("loss 5%"), text)
	assert_true(NetOverlay.format_report({}, {}).contains("rtt"), "an empty report still renders")
