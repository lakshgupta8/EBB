class_name UI
extends RefCounted
## Small helpers so every menu is built the same way: pixel font, dark panels.

const FONT := preload("res://assets/fonts/ebb.fnt")
const INK := Color(0.09, 0.08, 0.14)
const PANEL := Color(0.13, 0.12, 0.19)
const PANEL_EDGE := Color(0.45, 0.55, 0.65)


static func label(text: String, size: int = 8, color: Color = Color(0.95, 0.93, 0.9),
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", INK)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.horizontal_alignment = align
	return l


static func spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = PANEL_EDGE
	s.set_border_width_all(1)
	s.set_content_margin_all(10)
	return s
