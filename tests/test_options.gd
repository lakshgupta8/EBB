extends TestCase
## M8 options: rebinding round trip, save slots and their migration, assists as a trade,
## the input log's file round trip.


func _settings_scratch() -> void:
	Settings.path = "user://test_settings.json"
	Settings.data = Settings.DEFAULTS.duplicate(true)
	Settings.apply_bindings()


func _settings_restore() -> void:
	if FileAccess.file_exists(Settings.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.path = Settings.PATH
	Settings.load_settings()
	Settings.apply_bindings()


func test_rebinding_round_trip() -> void:
	_settings_scratch()
	assert_eq(Settings.key_name("interact"), "E", "the project's own binding reads back")
	assert_eq(Settings.pad_name("dash"), "A")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F
	ev.pressed = true
	assert_true(Settings.bind("interact", ev), "F takes interact")
	assert_eq(Settings.key_name("interact"), "F")
	assert_eq(Settings.key_name("consume"), "E", "eat, which had F, took interact's old E: nothing is left unbound")
	assert_true(Settings.is_rebound("interact") and Settings.is_rebound("consume"))
	# The InputMap agrees with the setting.
	var found := false
	for e in InputMap.action_get_events("interact"):
		if e is InputEventKey and e.physical_keycode == KEY_F:
			found = true
	assert_true(found, "the InputMap carries the new key")
	assert_true(InputMap.event_is_action(ev, "interact"))
	# Pad buttons rebind on their own column; the stick axes on move_* survive.
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_Y
	pad.pressed = true
	assert_true(Settings.bind("dash", pad))
	assert_eq(Settings.pad_name("dash"), "Y")
	assert_eq(Settings.pad_name("special"), "A", "special took A from dash")
	var axes := 0
	for e in InputMap.action_get_events("move_left"):
		if e is InputEventJoypadMotion:
			axes += 1
	assert_true(axes >= 1, "the stick still moves")
	# Esc and the wheel are refused.
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	assert_true(not Settings.bind("pause", esc), "Esc cannot be taken")
	# Saved, reloaded, the same.
	Settings.save_settings()
	Settings.data = Settings.DEFAULTS.duplicate(true)
	Settings.load_settings()
	Settings.apply_bindings()
	assert_eq(Settings.key_name("interact"), "F", "the binding survives a reload")
	assert_eq(Settings.pad_name("dash"), "Y")
	Settings.reset_bindings()
	assert_eq(Settings.key_name("interact"), "E", "reset brings the project's bindings back")
	assert_true(not Settings.is_rebound("interact"))
	_settings_restore()


func test_settings_ranges_and_assists() -> void:
	_settings_scratch()
	Settings.set_value("hud_scale", 1.5)
	assert_near(Settings.hud_scale(), 1.5, 0.001, "scales are not clamped to 1")
	Settings.set_value("hud_scale", 9.0)
	assert_near(Settings.hud_scale(), 1.5)
	Settings.set_value("assist_tide", 0.1)
	assert_near(Settings.assist_tide(), 0.5, 0.001, "assists bottom out at half")
	Settings.set_value("assist_tide", 1.0)
	assert_near(Settings.assist_pearl_mult(), 1.0, 0.001, "no assists, full pearls")
	Settings.set_value("assist_damage", 0.75)
	assert_near(Settings.assist_pearl_mult(), 0.85)
	Settings.set_value("assist_tide", 0.5)
	assert_near(Settings.assist_pearl_mult(), 0.85 * 0.7)
	Settings.set_value("assist_aim", true)
	assert_near(Settings.assist_pearl_mult(), 0.85 * 0.7 * 0.9)
	assert_true(Settings.assists_on())
	Settings.set_value("reduced_motion", true)
	assert_near(Settings.shake(), 0.0, 0.001, "reduced motion means no shake")
	assert_true(not Settings.flashes())
	Settings.set_value("water_tint", "amber")
	assert_true(Settings.water_tint() != Settings.WATER_TINTS.sea.color)
	Settings.set_value("water_tint", "nonsense")
	assert_eq(Settings.water_tint(), Settings.WATER_TINTS.sea.color, "an unknown tint falls back to the sea")
	# The run state carries the trade to the ledger.
	var s := RunState.new()
	s.pearls = 20
	s.assist_mult = 0.5
	assert_eq(s.result().pearls, 10, "assisted pearls are halved")
	var d := s.to_dict()
	var back := RunState.new()
	back.from_dict(d)
	assert_near(back.assist_mult, 0.5, 0.001, "a rested night keeps its assist trade")
	_settings_restore()


func test_save_slots_and_migration() -> void:
	var before := SaveManager.path
	for n in [2, 3]:
		var p := SaveManager.slot_path(n)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	assert_eq(SaveManager.slot_path(1), SaveManager.PATH, "slot 1 is the profile every version wrote")
	assert_true(SaveManager.slot_path(2) != SaveManager.slot_path(3))
	assert_true(SaveManager.slot_summary(2).is_empty(), "an empty slot has no summary")
	# An old profile dropped into slot 3 migrates when the slot is used.
	var old := {"version": 1, "pearls": 12, "runs": 4, "wins": 1, "weapon": "net", "flags": {"echo_bram": true}, "ledger": {}}
	var f := FileAccess.open(SaveManager.slot_path(3), FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f = null
	var sum := SaveManager.slot_summary(3)
	assert_eq(int(sum.get("runs", -1)), 4, "the summary reads a slot without loading it")
	assert_eq(int(sum.get("echoes", -1)), 1, "echoes counted from flags")
	SaveManager.use_slot(3)
	assert_eq(SaveManager.slot_in_use(), 3)
	assert_eq(int(SaveManager.data.version), SaveManager.VERSION, "migrated")
	assert_eq(int(SaveManager.data.pearls), 12)
	assert_true(SaveManager.data.has("affinity") and SaveManager.data.has("saved"))
	SaveManager.save_profile()
	assert_true(int(SaveManager.data.saved) > 0, "the profile knows when it was written")
	SaveManager.use_slot(2)
	assert_eq(int(SaveManager.data.pearls), 0, "slot 2 is a fresh keeper")
	assert_eq(int(SaveManager.slot_summary(3).pearls), 12, "slot 3 is untouched by slot 2")
	SaveManager.wipe_slot(3)
	assert_true(SaveManager.slot_summary(3).is_empty(), "wiped")
	SaveManager.wipe_slot(2)
	assert_true(SaveManager.slot_summary(2).is_empty())
	SaveManager.use_path(before)


func test_input_log_round_trip() -> void:
	var log := InputLog.new()
	log.seed_value = 777
	log.weapon = "net"
	log.tier = 2
	log.ticks = [[0, 100, 0], [1 | (1 << 5), -70, 70], [0, 0, -100]]
	log.positions = [[0, 0, 100, 120], [0, 4, 104, 120], [1, 0, 60, 80]]
	var d := log.to_dict()
	var text := JSON.stringify(d)
	var f := FileAccess.open("user://test_replay.json", FileAccess.WRITE)
	f.store_string(text)
	f = null
	var back := InputLog.load_file("user://test_replay.json")
	assert_true(back != null, "the file loads")
	assert_eq(back.seed_value, 777)
	assert_eq(back.weapon, "net")
	assert_eq(back.ticks, log.ticks, "ticks come back as ints")
	assert_eq(back.positions, log.positions)
	assert_eq(back.position_at(0, 3), Vector2(104, 120), "the nearest sample in the room")
	assert_eq(back.position_at(1, 50), Vector2(60, 80))
	assert_eq(back.position_at(5, 0), Vector2.INF, "a room the log never reached")
	assert_true(not back.done())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_replay.json"))
	assert_eq(InputLog._stamp("replay_777_1700000000.json"), 1700000000)


func test_strings_file_stands_in_for_english() -> void:
	# The English text is its own key: an untranslated line comes back as it was.
	assert_eq(UI.t("Keep the tide"), "Keep the tide")
	assert_eq(UI.t(""), "")
	var f := FileAccess.open("res://data/strings.json", FileAccess.READ)
	assert_true(f != null, "data/strings.json is there for a translator to fill")
	var parsed = JSON.parse_string(f.get_as_text())
	assert_true(parsed is Dictionary, "and it parses")
	assert_true(parsed.has("_note"), "with a note saying how to use it")
	# A label takes its text through the same door.
	var l := UI.label("Done")
	assert_eq(l.text, "Done")
	l.free()
	var b := UI.text_button("Back")
	assert_eq(b.text, "Back")
	b.free()
