class_name UI
extends RefCounted
## Small helpers so every menu is built the same way: pixel font, one panel, one row, one
## cursor, and one place that decides which keys mean what.
##
## The look is a Tidekeeper's kit (art Stage 16, STYLE.md 15): ledger paper in an iron frame
## with rivets, rows with an iron edge, ledger tabs in wood with a rope underline, a Warm
## yellow triangle for the gamepad cursor, and four text colours: primary Salt white,
## secondary Pale slate, muted Wet grey, accent Warm yellow. Danger never carries 8 px text:
## it is Salt white on a Salt red tag.

## The body face, Ledger (8 px, proportional, true descenders) and the display face, Plate
## (16 px slab-serif capitals; 32 for the one banner). STYLE.md 16.
const FONT := preload("res://assets/fonts/ebb.fnt")
const DISPLAY := preload("res://assets/fonts/ebb_display.fnt")
## The lantern's lines: the body face with 1 px more between the letters, so they feel
## spoken, not announced.
static var _whisper: FontVariation = null
const PANEL_TEX := preload("res://assets/sprites/ui_panel.png")
const PAPER_TEX := preload("res://assets/sprites/ui_paper.png")
const ROW_TEX := preload("res://assets/sprites/ui_row.png")
const TAB_TEX := preload("res://assets/sprites/ui_tab.png")
const TRI_TEX := preload("res://assets/sprites/ui_tri.png")
const FAMILY_TEX := preload("res://assets/sprites/family_icons.png")
const FAMILY_BIG_TEX := preload("res://assets/sprites/family_icons_big.png")
const FAMILIES := ["salt", "brine", "current", "deep", "echo"]

const INK := Palette.INK
const PRIMARY := Palette.SALT_WHITE
const SECONDARY := Palette.PALE_SLATE
const MUTED := Palette.WET_GREY
const ACCENT := Palette.WARM_YELLOW
const DANGER := Palette.SALT_RED
## Behind every menu: Ink at 60 %.
const DIM := Color(0.0627, 0.0706, 0.1098, 0.6)
## "No family edge" for row_button.
const NONE := Color(0, 0, 0, 0)
# Kept for old callers.
const PANEL := Palette.NIGHT_1
const PANEL_EDGE := Palette.IRON_LIGHT
const ROW := Palette.NIGHT_2


static func label(text: String, size: int = 8, color: Color = PRIMARY,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t(text)
	set_size(l, size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- M8: every line of chrome goes through one door -------------------------------------
## Words the game says, in the language of data/strings.json. The key is the English
## itself, so a translation is one file of pairs and a missing line simply stays English.
## Run with `-- --dump-strings` to write every line the game showed to
## user://strings_seen.json, which is the file a translator starts from.
const STRINGS_PATH := "res://data/strings.json"
static var _strings: Dictionary = {}
static var _loaded: bool = false
static var _seen: Dictionary = {}
static var _dumping: bool = false


static func t(text: String) -> String:
	if not _loaded:
		_loaded = true
		_dumping = "--dump-strings" in OS.get_cmdline_user_args()
		if FileAccess.file_exists(STRINGS_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(STRINGS_PATH))
			if parsed is Dictionary:
				for k in parsed:
					_strings[str(k)] = str(parsed[k])
	if _dumping and text.strip_edges() != "":
		_seen[text] = _strings.get(text, text)
		var f := FileAccess.open("user://strings_seen.json", FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(_seen, "	", false))
	var out: String = _strings.get(text, text)
	return out if out != "" else text


## A font size under the text-size setting (8 stays 8 at normal, 10 at large, 12 at largest).
static func scaled(size: int) -> int:
	return int(round(size * Settings.text_scale()))


## The face for a size: body under 16, the display face at 16, and at 32 for the banner.
## The old sizes 12, 14, 20 and 24 land on the nearest of the three (STYLE.md 16).
static func font_for(size: int) -> Font:
	return DISPLAY if size >= 12 else FONT


static func px_for(size: int) -> int:
	if size >= 24:
		return 32
	if size >= 12:
		return 16
	return scaled(size)


## The Ink shadow: 1 px at 8 and 16 (both drawn at 1x), 2 px at 32 (the display face at 2x).
static func shadow_for(size: int) -> int:
	return 2 if size >= 24 else 1


## Gives a Label (or Button) its face, pixel size and shadow for a size.
static func set_size(c: Control, size: int) -> void:
	c.add_theme_font_override("font", font_for(size))
	c.add_theme_font_size_override("font_size", px_for(size))
	c.add_theme_color_override("font_shadow_color", INK)
	var sh := shadow_for(size)
	c.add_theme_constant_override("shadow_offset_x", sh)
	c.add_theme_constant_override("shadow_offset_y", sh)


## The whisper face for a Label: Pale slate is the caller's; this is the spacing.
static func whisper(l: Label) -> void:
	if _whisper == null:
		_whisper = FontVariation.new()
		_whisper.base_font = FONT
		_whisper.spacing_glyph = 1
	l.add_theme_font_override("font", _whisper)


## The width of a string in a face, in pixels (never count characters: the body face is
## proportional).
static func width(text: String, size: int = 8) -> float:
	return font_for(size).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px_for(size)).x


static func spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## The Ink at 60 % behind a menu.
static func dim() -> ColorRect:
	var d := ColorRect.new()
	d.color = DIM
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return d


# --- the kit -----------------------------------------------------------------------------------
static func _nine(tex: Texture2D, region: Rect2, margin: int, content: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.region_rect = region
	s.texture_margin_left = margin
	s.texture_margin_top = margin
	s.texture_margin_right = margin
	s.texture_margin_bottom = margin
	s.set_content_margin_all(content)
	return s


## The iron-framed panel: an Iron light rim, Ink, a Night 1 face, a rivet in each corner.
static func panel_style(content: int = 10) -> StyleBoxTexture:
	return _nine(PANEL_TEX, Rect2(0, 0, 24, 24), 8, content)


## The paper inset for text-heavy panels (codex, Ledger, results, dialog).
static func paper_style(content: int = 6) -> StyleBoxTexture:
	return _nine(PAPER_TEX, Rect2(0, 0, 24, 24), 3, content)


## A row state: 0 normal, 1 hover, 2 pressed (the Warm yellow tick), 3 disabled.
static func _row_style(state: int) -> StyleBoxTexture:
	return _nine(ROW_TEX, Rect2(state * 12, 0, 12, 12), 3, 5)


## The header band: Night 2 with a Rope underline.
static func header_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.NIGHT_2
	s.border_color = Palette.ROPE
	s.border_width_bottom = 1
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


## A panel's title in its header band. Display size (16) unless told otherwise.
static func header(text: String, size: int = 16, color: Color = PRIMARY) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", header_style())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER))
	return p


## A danger tag: Salt white text on a Salt red box (danger never carries 8 px text).
static func tag_style(color: Color = DANGER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.content_margin_left = 3
	s.content_margin_right = 3
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	return s


## Colour a notice line by what it says: "ok" primary, "bad" a danger tag, "accent", else secondary.
static func hint_kind(l: Label, kind: String) -> void:
	l.modulate = Color.WHITE
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else Control.SIZE_FILL
	if kind == "bad":
		l.add_theme_color_override("font_color", PRIMARY)
		l.add_theme_stylebox_override("normal", tag_style())
		return
	l.remove_theme_stylebox_override("normal")
	l.add_theme_color_override("font_color", PRIMARY if kind == "ok" else (ACCENT if kind == "accent" else SECONDARY))


## A clickable row. Put labels inside it; it highlights on hover and fires `pressed`.
## `edge` paints a family colour as a 2 px left edge (never a full coloured border).
static func row_button(edge: Color = NONE) -> Button:
	var b := Button.new()
	b.flat = false
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _row_style(0))
	b.add_theme_stylebox_override("hover", _row_style(1))
	b.add_theme_stylebox_override("pressed", _row_style(2))
	b.add_theme_stylebox_override("disabled", _row_style(3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.text = ""
	if edge.a > 0.0 and edge != PANEL_EDGE:
		var e := ColorRect.new()
		e.color = edge
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		e.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		e.offset_left = 1
		e.offset_right = 3
		e.offset_top = 1
		e.offset_bottom = -1
		b.add_child(e)
	return b


## A non-clickable row with the same look as row_button (codex entries).
static func row_panel(_edge: Color = NONE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _row_style(0))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


## A ledger tab: Wood with a Rope underline, Wood light when it is the open page.
static func tab_button(text: String, active: bool, size: int = 8) -> Button:
	var b := Button.new()
	b.flat = false
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var st := _nine(TAB_TEX, Rect2(12 if active else 0, 0, 12, 12), 3, 4)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", _nine(TAB_TEX, Rect2(12, 0, 12, 12), 3, 4))
	b.add_theme_stylebox_override("pressed", st)
	b.add_theme_stylebox_override("disabled", st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.text = t(text)
	set_size(b, size)
	b.add_theme_color_override("font_color", PRIMARY if active else SECONDARY)
	b.add_theme_color_override("font_hover_color", PRIMARY)
	b.add_theme_color_override("font_pressed_color", PRIMARY)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


## Turn a ledger tab to the open page or back.
static func set_tab_active(b: Button, active: bool) -> void:
	var st := _nine(TAB_TEX, Rect2(12 if active else 0, 0, 12, 12), 3, 4)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("pressed", st)
	b.add_theme_color_override("font_color", PRIMARY if active else SECONDARY)


## A 24x24 sprite slot for a codex entry: the sheet's first frame, a family icon, or empty.
static func sprite_slot(e: Dictionary) -> Control:
	var slot := PanelContainer.new()
	slot.add_theme_stylebox_override("panel", paper_style(0))
	slot.custom_minimum_size = Vector2(26, 26)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner: Control = null
	if e.has("sprite") and ResourceLoader.exists(str(e.sprite)):
		var tex: Texture2D = load(str(e.sprite))
		if tex:
			var at := AtlasTexture.new()
			at.atlas = tex
			# a 24 px enemy's first frame; a boss sheet's first frame cropped about its centre
			var fw := tex.get_width()
			var fh := tex.get_height()
			if fh > 24:
				fw = tex.get_width() / Enemy.BOSS_FRAMES
			elif fw > 24 and fw % 24 == 0:
				fw = 24  # a strip of 24 px cells: the first frame
			at.region = Rect2(maxi(0, (fw - 24) / 2), maxi(0, (fh - 24) / 2), mini(24, fw), mini(24, fh))
			var r := TextureRect.new()
			r.texture = at
			r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			inner = r
	elif e.has("family"):
		inner = family_icon(str(e.family), true)
		(inner as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	if inner != null:
		inner.custom_minimum_size = Vector2(24, 24)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(inner)
	return slot


## A scroll container's bar in the kit: a Night 1 track, a Pale slate grabber, 4 px wide.
static func style_scroll(sc: ScrollContainer) -> void:
	var bar := sc.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Palette.NIGHT_1
	track.border_color = Palette.IRON_DARK
	track.set_border_width_all(1)
	track.content_margin_left = 1
	track.content_margin_right = 1
	var grab := StyleBoxFlat.new()
	grab.bg_color = Palette.PALE_SLATE
	var grab_hi := StyleBoxFlat.new()
	grab_hi.bg_color = Palette.SALT_WHITE
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab_hi)
	bar.add_theme_stylebox_override("grabber_pressed", grab_hi)
	bar.custom_minimum_size = Vector2(6, 0)


## A settings slider: an iron rail with a brass slider (STYLE.md 15). 42x7.
class Rail extends Control:
	var frac: float = 0.0:
		set(v):
			frac = clampf(v, 0.0, 1.0)
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(42, 7)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(0, 2, 42, 3), Palette.INK)
		draw_rect(Rect2(1, 3, 40, 1), Palette.IRON_LIGHT)
		var x := 1 + int(round(38.0 * frac))
		draw_rect(Rect2(x - 1, 0, 4, 7), Palette.INK)
		draw_rect(Rect2(x, 1, 2, 5), Palette.BRONZE_LIGHT)
		draw_rect(Rect2(x, 4, 2, 2), Palette.BRONZE)


## A tidemark family's icon: 7 px for the HUD, 15 px for cards.
static func family_icon(family: String, big: bool = false) -> TextureRect:
	var r := TextureRect.new()
	var at := AtlasTexture.new()
	var i := maxi(0, FAMILIES.find(family))
	var s := 15 if big else 7
	at.atlas = FAMILY_BIG_TEX if big else FAMILY_TEX
	at.region = Rect2(i * s, 0, s, s)
	r.texture = at
	r.stretch_mode = TextureRect.STRETCH_KEEP
	r.custom_minimum_size = Vector2(s, s)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A label that yields width to its siblings and trims with an ellipsis instead of overflowing.
static func flex_label(text: String, size: int = 8, color: Color = SECONDARY) -> Label:
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
static func text_button(text: String, size: int = 8, color: Color = PRIMARY) -> Button:
	var b := row_button()
	b.text = t(text)
	set_size(b, size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", PRIMARY)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_disabled_color", MUTED)
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


## E, Esc, right-click, or the pad's B / Start all mean "close this menu".
static func is_close(event: InputEvent) -> bool:
	if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		return true
	return false


## Menu navigation from arrows, WASD, the d-pad or the left stick; Enter / Space / A accept.
static func nav(event: InputEvent) -> String:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		return "up"
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		return "down"
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		return "left"
	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		return "right"
	if event.is_action_pressed("ui_accept"):
		return "accept"
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		return "accept"
	return ""


## The key or button to show for an action, for whichever device was used last. Bindable
## actions read the player's own bindings; menu-only ones have fixed names.
static func hint(action: String) -> String:
	if Game.gamepad:
		match action:
			"accept": return "[A]"
			"leftright": return "[d-pad]"
		var p := Settings.pad_name(action)
		return "[%s]" % p if p != "" else ""
	match action:
		"accept": return "[Enter]"
		"leftright": return "[%s / %s]" % [Settings.key_name("move_left"), Settings.key_name("move_right")]
	var k := Settings.key_name(action)
	return "[%s]" % k if k != "" else ""


## The bare key name without brackets ("E", "Q", "F"), for the HUD's short prompts.
static func key(action: String) -> String:
	if Game.gamepad:
		return Settings.pad_name(action)
	return Settings.key_name(action)


## A highlighted row that the keyboard or pad moves through. `handle(nav)` moves on
## up / down, presses the row on accept (false when nothing is highlighted). The highlight
## is a Warm yellow triangle at the row's left, not a whole-row modulate (STYLE.md 15).
class Cursor:
	var buttons: Array = []
	var index: int = -1
	var _marker: TextureRect

	func _init(p_buttons: Array) -> void:
		buttons = p_buttons

	func handle(nav: String) -> bool:
		match nav:
			"up":
				_move(-1)
				return true
			"down":
				_move(1)
				return true
			"accept":
				if index >= 0 and index < buttons.size() and is_instance_valid(buttons[index]):
					buttons[index].pressed.emit()
					return true
				return false
		return false

	func _move(d: int) -> void:
		if buttons.is_empty():
			return
		if index < 0:
			index = 0 if d > 0 else buttons.size() - 1
		else:
			index = wrapi(index + d, 0, buttons.size())
		apply()
		Audio.play("ui", 0.0, -14.0)

	func apply() -> void:
		if _marker == null:
			_marker = TextureRect.new()
			_marker.texture = TRI_TEX
			_marker.stretch_mode = TextureRect.STRETCH_KEEP
			_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_instance_valid(_marker.get_parent()):
			_marker.get_parent().remove_child(_marker)
		for b in buttons:
			if is_instance_valid(b):
				b.modulate = Color.WHITE
		if index < 0 or index >= buttons.size() or not is_instance_valid(buttons[index]):
			return
		var b: Control = buttons[index]
		b.add_child(_marker)
		var h := b.size.y if b.size.y > 0.0 else b.custom_minimum_size.y
		_marker.position = Vector2(-7, floorf((h - 5.0) * 0.5))
