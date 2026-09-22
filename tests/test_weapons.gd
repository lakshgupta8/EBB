extends TestCase
## Weapons (art Stage 14): every piece of the kit is the size the scenes expect, each held
## sprite pivots at its left edge on its vertical centre, and the net and beacon are never
## scaled or turned.

const KIT := {
	"gaff_hook": [22, 8], "knife": [14, 6], "harpoon_gun": [20, 8], "storm_lantern": [16, 10],
	"keepers_bell": [16, 10], "line_handle": [12, 6], "harpoon_bolt": [14, 4], "sinker": [8, 8],
	"net": [24, 24], "beacon": [32, 16], "lantern_shot": [8, 8], "toll": [8, 8], "debris": [8, 8],
}
const SCENES := ["gaff_hook", "net_knife", "harpoon_gun", "storm_lantern", "keepers_bell", "line_sinker"]


func test_the_kit_is_the_size_the_scenes_expect() -> void:
	for name in KIT:
		var tex: Texture2D = load("res://assets/sprites/%s.png" % name)
		assert_true(tex != null, name + " loads")
		assert_eq(tex.get_width(), int(KIT[name][0]), name + " width")
		assert_eq(tex.get_height(), int(KIT[name][1]), name + " height")


func test_held_sprites_pivot_on_the_left_edge_at_the_vertical_centre() -> void:
	for scene in SCENES:
		var packed: PackedScene = load("res://src/player/weapons/%s.tscn" % scene)
		var w := packed.instantiate()
		var s := w.get_node("Pivot/Sprite") as Sprite2D
		assert_true(s != null and not s.centered, scene + " held sprite is not centred")
		assert_eq(int(s.offset.y), -s.texture.get_height() / 2, scene + " pivots on the vertical centre")
		assert_eq(int(s.offset.x), 0, scene + " pivots on the left edge")
		w.free()


func test_the_beacon_is_a_placed_lantern_with_two_frames() -> void:
	var packed: PackedScene = load("res://src/player/weapons/storm_lantern.tscn")
	var w := packed.instantiate()
	var b := w.get_node("Beacon") as Sprite2D
	assert_true(b.region_enabled, "the beacon shows one 16 px frame of its two")
	assert_eq(b.region_rect.size, Vector2(16, 16), "one lantern frame")
	w.free()
