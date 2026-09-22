extends TestCase
## Typography (art Stage 17, STYLE.md 16): the body face is proportional with a 10 px line
## and tabular digits, the display face is 16 px capitals that lowercase falls into, UI picks
## the face and the shadow by size, and the whisper face is the body face spaced out.


func test_the_body_face_is_proportional_with_tabular_digits() -> void:
	var f: Font = UI.FONT
	assert_eq(int(f.get_height(8)), 10, "a 10 px line at 8")
	assert_eq(int(f.get_ascent(8)), 7, "the baseline 7 px down")
	var wide := f.get_string_size("m", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var narrow := f.get_string_size("i", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	assert_true(wide > narrow, "m is wider than i")
	var w1 := f.get_string_size("1", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w8 := f.get_string_size("8", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	assert_eq(int(w1), int(w8), "digits are tabular")
	assert_eq(int(w8), 5, "a figure advances 5")
	var bar := f.get_string_size("#", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var dash := f.get_string_size("-", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	assert_eq(int(bar), int(dash), "the text bar's # and - advance alike")


func test_the_display_face_is_capitals_at_16() -> void:
	var f: Font = UI.DISPLAY
	assert_eq(int(f.get_height(16)), 16, "a 16 px line")
	assert_eq(int(f.get_ascent(16)), 12, "12 px capitals")
	var up := f.get_string_size("WRECK", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var low := f.get_string_size("wreck", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	assert_eq(int(up), int(low), "lowercase sets as the capitals")
	assert_true(f.get_string_size("W", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > f.get_string_size("I", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, "proportional")


func test_ui_picks_the_face_and_shadow_by_size() -> void:
	assert_true(UI.font_for(8) == UI.FONT, "8 is the body face")
	assert_true(UI.font_for(16) == UI.DISPLAY, "16 is the display face")
	assert_eq(UI.px_for(14), 16, "the old 14 lands on 16")
	assert_eq(UI.px_for(20), 16, "the old 20 lands on 16")
	assert_eq(UI.px_for(24), 32, "the old 24 is the 32 px banner")
	assert_eq(UI.shadow_for(16), 1, "1 px shadow at 16 (drawn at 1x)")
	assert_eq(UI.shadow_for(32), 2, "2 px shadow at 32")
	var l := UI.label("THE HARBOUR", 16)
	assert_true(l.get_theme_font("font") == UI.DISPLAY, "a 16 px label is set in the display face")
	assert_eq(l.get_theme_constant("shadow_offset_x"), 1, "with the 1 px shadow")
	l.free()
	var w := UI.label("the lantern says", 8, UI.SECONDARY)
	var plain := UI.width("the lantern says")
	UI.whisper(w)
	var spaced := w.get_theme_font("font").get_string_size("the lantern says", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	assert_true(spaced > plain, "the whisper face is wider")
	assert_true(w.get_theme_font("font") is FontVariation, "as a variation of the body face")
	w.free()
