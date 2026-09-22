extends TestCase
## Effects (art Stage 15): every sheet is the size the engine plays it at, rings come in
## three native sizes and never scale, and colour literals snap to the palette.

const SHEETS := {
	"fx_slash": [192, 48], "fx_slash_warm": [192, 48], "fx_stab": [72, 8], "fx_spark": [36, 12],
	"fx_crack": [96, 24], "fx_ring16": [48, 16], "fx_ring32": [96, 32], "fx_ring96": [288, 96],
	"fx_lit": [48, 24], "fx_stun": [32, 8], "fx_bleed": [16, 8],
}


func test_the_sheets_are_the_sizes_the_engine_plays() -> void:
	for name in SHEETS:
		var tex: Texture2D = load("res://assets/sprites/%s.png" % name)
		assert_true(tex != null, name + " loads")
		assert_eq(tex.get_width(), int(SHEETS[name][0]), name + " width")
		assert_eq(tex.get_height(), int(SHEETS[name][1]), name + " height")


func test_rings_pick_a_native_size_and_a_palette_tint() -> void:
	assert_eq(FX.ring_size(0.5), 16, "the cue ring")
	assert_eq(FX.ring_size(1.2), 32, "a riptide")
	assert_eq(FX.ring_size(2.6), 96, "the flare")
	assert_eq(FX.ring_tint(Color(0.6, 0.85, 1.0)), Palette.SEA_PALE, "the Ebb casts cold")
	assert_eq(FX.ring_tint(Color(1.0, 0.9, 0.5)), Palette.WARM_YELLOW, "the flare is warm")
	assert_eq(FX.ring_tint(Color(1.0, 0.5, 0.4)), Palette.SALT_RED, "a second wind is red")
	assert_eq(FX.ring_tint(Color(0.85, 0.75, 1.0)), Palette.VIOLET_LIGHT, "the Choir is violet")
	assert_eq(FX.ring_tint(Color(0.8, 0.82, 0.9)), Palette.PALE_SLATE, "a statue waking is grey")


func test_a_ring_spawns_at_scale_one() -> void:
	var scene: Node = (Engine.get_main_loop() as SceneTree).current_scene
	FX.ring(Vector2(100, 100), Color(0.6, 0.9, 1.0), 2.6)
	var s := scene.get_child(scene.get_child_count() - 1) as AnimatedSprite2D
	assert_true(s != null, "a ring sprite was added")
	if s:
		assert_eq(s.scale, Vector2.ONE, "never scaled")
		assert_eq(s.sprite_frames.get_frame_texture("play", 0).get_width(), 96, "the 96 px sheet")
		assert_eq(s.modulate, Palette.SEA_PALE, "tinted cold")
		s.queue_free()


func test_bursts_snap_to_the_palette_and_stay_small() -> void:
	assert_eq(FX.palette_colour(Color(0.8, 0.2, 0.2)), Palette.SALT_RED, "old blood-red literal")
	assert_eq(FX.palette_colour(Color(0.6, 0.9, 1.0)), Palette.SEA_PALE, "old riptide literal")
	assert_eq(FX.palette_colour(Palette.BONE), Palette.BONE, "a palette colour stays")
	assert_true(FX.BURST_MAX <= 12, "no fireworks")
