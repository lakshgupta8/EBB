class_name UI
extends RefCounted
## Small helpers so every menu is built the same way: pixel font, dark panels,
## clickable rows, and one place that decides which keys mean what.

const FONT := preload("res://assets/fonts/ebb.fnt")
const INK := Color(0.09, 0.08, 0.14)
const PANEL := Color(0.13, 0.12, 0.19)
const PANEL_EDGE := Color(0.45, 0.55, 0.65)
const ROW := Color(0.1, 0.1, 0.16)
const ROW_HOVER := Color(0.2, 0.22, 0.32)
const ROW_PRESSED := Color(0.26, 0.3, 0.42)


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
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = PANEL_EDGE
	s.set_border_width_all(1)
	s.set_content_margin_all(10)
	return s


static func _row_style(bg: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_content_margin_all(5)
	return s


## A clickable row. Put labels inside it; it highlights on hover and fires `pressed`.
static func row_button(edge: Color = PANEL_EDGE) -> Button:
	var b := Button.new()
	b.flat = false
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _row_style(ROW, edge))
	b.add_theme_stylebox_override("hover", _row_style(ROW_HOVER, edge.lightened(0.3)))
	b.add_theme_stylebox_override("pressed", _row_style(ROW_PRESSED, edge.lightened(0.5)))
	b.add_theme_stylebox_override("disabled", _row_style(ROW, edge.darkened(0.5)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.text = ""
	return b


## A non-clickable row with the same look as row_button (codex entries).
static func row_panel(edge: Color = PANEL_EDGE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _row_style(ROW, edge.darkened(0.3)))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


## A label that yields width to its siblings and trims with an ellipsis instead of overflowing.
static func flex_label(text: String, size: int = 8, color: Color = Color(0.7, 0.75, 0.8)) -> Label:
	var l := label(text, size, color)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Buttons do not lay out their children: anchor `inner` to fill the button with margins.
static func fill(inner: Control, margin_x: float = 6.0, margin_y: float = 4.0) -> void:
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = margin_x
	inner.offset_top = margin_y
	inner.offset_right = -margin_x
	inner.offset_bottom = -margin_y
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE


## A simple text button (Resume, Leave...).
static func text_button(text: String, size: int = 8, color: Color = Color(0.85, 0.9, 1.0)) -> Button:
	var b := row_button()
	b.text = text
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


## Which menu slot a key press means: 0-8 for 1-9 on the main row or the numpad, else -1.
static func menu_index(event: InputEvent) -> int:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return -1
	for code in [event.keycode, event.physical_keycode, event.key_label]:
		if code >= KEY_1 and code <= KEY_9:
			return code - KEY_1
		if code >= KEY_KP_1 and code <= KEY_KP_9:
			return code - KEY_KP_1
	return -1


## E, Esc, Enter, Space or right-click all mean "close this menu".
static func is_close(event: InputEvent) -> bool:
	if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_E] \
			or event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_E]
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		return true
	return false
