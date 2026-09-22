extends TestCase
## UI (art Stage 16): the kit's sheets are the sizes the helpers slice, the panel and rows are
## nine-slices at 1x, the family icons come in five, and text colours are the four roles.


func test_the_kit_sheets_are_the_sizes_the_helpers_slice() -> void:
	var sizes := {"ui_panel": [24, 24], "ui_paper": [24, 24], "ui_row": [48, 12], "ui_tab": [24, 12], "ui_tri": [3, 5],
		"hud_health": [66, 8], "hud_pip": [10, 5], "hud_special": [26, 6], "hud_lantern": [12, 14],
		"hud_staff": [10, 128], "hud_boss": [244, 12], "pickups": [56, 8], "family_icons": [35, 7],
		"family_icons_big": [75, 15], "cursor": [16, 8]}
	for name in sizes:
		var tex: Texture2D = load("res://assets/sprites/%s.png" % name)
		assert_true(tex != null, name + " loads")
		assert_eq(tex.get_width(), int(sizes[name][0]), name + " width")
		assert_eq(tex.get_height(), int(sizes[name][1]), name + " height")


func test_the_panel_and_rows_are_nine_slices() -> void:
	var p := UI.panel_style()
	assert_true(p is StyleBoxTexture, "the panel is a texture")
	assert_eq(int(p.texture_margin_left), 8, "8 px corners")
	var b := UI.row_button(Palette.SALT_RED)
	assert_true(b.get_theme_stylebox("normal") is StyleBoxTexture, "rows are textures")
	var edge := b.get_child(0) as ColorRect
	assert_true(edge != null and edge.color == Palette.SALT_RED, "a family colour is a 2 px left edge")
	assert_eq(int(edge.offset_right - edge.offset_left), 2, "2 px wide")
	b.free()


func test_family_icons_and_text_roles() -> void:
	assert_eq(UI.FAMILIES.size(), 5, "five families")
	var icon := UI.family_icon("deep", true)
	assert_eq((icon.texture as AtlasTexture).region, Rect2(45, 0, 15, 15), "the Deep is the fourth 15 px icon")
	icon.free()
	var l := UI.label("x")
	assert_eq(l.get_theme_color("font_color"), Palette.SALT_WHITE, "primary text is Salt white")
	l.free()
	var h := UI.label("hint", 8, UI.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	UI.hint_kind(h, "bad")
	assert_eq(h.get_theme_color("font_color"), Palette.SALT_WHITE, "danger text stays Salt white")
	assert_true(h.get_theme_stylebox("normal") is StyleBoxFlat and (h.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == Palette.SALT_RED, "on a Salt red tag")
	h.free()
