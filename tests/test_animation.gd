extends TestCase
## Animation (art Stage 13): every production sheet carries the standard layout (idle 4,
## walk 4, windup 2, attack 2, hurt 1; bosses add phase and intro) and the layout helper
## binds names to it the way the scripts expect.

const SHEETS := {
	"keeper_shade": 16, "shellback": 16, "wrack_crab": 16, "still_citizen": 16, "lamplighter": 16,
	"bell_ringer": 16, "swimmer": 16, "anchor": 16, "deep_maw": 16, "tidewisp": 16,
	"shellback_elite": 16, "wrack_crab_elite": 16, "still_citizen_elite": 16, "gull": 12,
}
const BOSSES := {"wreck": [72, 48], "bell": [48, 72], "ebb": [72, 72]}


func test_enemy_sheets_carry_the_layout() -> void:
	for name in SHEETS:
		var tex: Texture2D = load("res://assets/sprites/%s.png" % name)
		assert_true(tex != null, name + " loads")
		assert_eq(tex.get_width() / 24, int(SHEETS[name]), name + " frames")
		assert_eq(tex.get_height(), 24, name + " cell height")
	for name in BOSSES:
		var tex: Texture2D = load("res://assets/sprites/%s.png" % name)
		assert_eq(tex.get_width() / int(BOSSES[name][0]), Enemy.BOSS_FRAMES, name + " frames")
		assert_eq(tex.get_height(), int(BOSSES[name][1]), name + " cell height")


func test_the_layout_helper_binds_names_to_parts() -> void:
	var a := Enemy.anims({"idle": "idle", "walk": "walk", "windup": "windup", "slam": "attack", "hurt": "hurt"}, {"idle": 2, "walk": 5})
	assert_eq(a["idle"]["frames"], [0, 1, 2, 3], "idle is four frames")
	assert_eq(int(a["idle"]["fps"]), 2, "the script's idle speed wins")
	assert_true(bool(a["idle"]["loop"]) and bool(a["walk"]["loop"]), "idle and walk loop")
	assert_eq(a["windup"]["frames"], [8, 9], "windup is the anticipation and the held pose")
	assert_true(not bool(a["windup"]["loop"]), "a windup holds its last frame")
	assert_eq(a["slam"]["frames"], [10, 11], "the attack is the strike and the follow-through")
	assert_eq(int(a["slam"]["fps"]), 12, "attacks default to 12 fps")
	assert_eq(a["hurt"]["frames"], [12], "hurt is the one frame after the attack")
	assert_eq(a["death"]["frames"], [13, 14, 15], "every enemy gets its drawn death")
	assert_true(not bool(a["death"]["loop"]), "the death plays once")
	assert_true(not a.has("phase"), "enemies have no phase frame")
	var b := Enemy.anims({"idle": "idle"}, {}, true)
	assert_eq(b["phase"]["frames"], [13], "a boss's phase frame")
	assert_eq(b["intro"]["frames"], [14], "a boss's intro frame")
	assert_eq(b["death"]["frames"], [15, 16, 17], "a boss's death comes after its intro")
	for part in Enemy.LAYOUT:
		for f in Enemy.LAYOUT[part]:
			assert_true(int(f) < Enemy.BOSS_FRAMES, "every layout frame is inside a boss sheet")


func test_tam_has_her_death_drawn() -> void:
	var tex: Texture2D = load("res://assets/sprites/player.png")
	var frames: Array = Player.ANIMS["death"]["frames"]
	assert_eq(frames.size(), 4, "knee, fall, lie, still")
	assert_true(not bool(Player.ANIMS["death"].get("loop", true)), "the death plays once")
	for f in frames:
		assert_true(int(f) < tex.get_width() / 24, "death frame inside the sheet")
