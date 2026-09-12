class_name Announcer
extends CanvasLayer
## Everything the night says to you, in four voices that never talk over each other.
##   cards    the name of a place, a boss, a turn of the night: top of the screen, upper
##            case on a dark band, with one plain line under it saying what it means.
##   toasts   small things that just happened (a mark taken, a page found): under the cards.
##   whispers the lantern's lines (or a freed person's): bottom, in quotes, typed out.
##            Lore, never instruction.
##   hints    plain words about how a thing works, once each, only while hints are on.
## And the stage dressing: letterbox bars for a boss, a coloured pulse at the screen's
## edge, the slow red beat when you are nearly out.

const FONT := preload("res://assets/fonts/ebb.fnt")
const INK := Color("#10121c")
const NIGHT1 := Color("#1f2536")
const WET := Color("#5d6b82")
const PALE := Color("#8494a8")
const SALT := Color("#d9e3e8")
const SEA_PALE := Color("#5f9c9f")
const WARM := Color("#f2c85c")
const CREAM := Color("#fbeccb")
const RED := Color("#b5452f")

const CARD_COLOR := Color(0.8, 0.9, 1.0)
const BOSS_COLOR := Color(0.95, 0.75, 0.6)
const STIR_COLOR := Color(0.95, 0.5, 0.45)
const WON_COLOR := Color(0.95, 0.85, 0.6)

## What a thing is, in plain words, the first time you meet it. Shown once per profile.
const HINTS := {
	"move": "WASD moves. The mouse aims: left click strikes, right click is your weapon's special. Space dashes through things. Clear the room and the doors open.",
	"move_pad": "Left stick moves, right stick aims. RT strikes, Y is your weapon's special, A dashes through things. Clear the room and the doors open.",
	"goal": "Keep the tide: get to the boss at the bottom of this place before the water takes you. Whatever you find on the way is yours for the night.",
	"salt": "Salt. It buys from the merchant tonight, and it is lost if you fall.",
	"pearl": "A pearl. Pearls go home with you whatever happens tonight. Spend them at the lighthouse.",
	"tide": "The tide has come up over the low ground. It rises with every room you enter, and deep water hurts to stand in. Keep moving down.",
	"tide2": "The floor is under water now. You are slower in it, and the deep parts hurt.",
	"altar": "An altar. Walk up to it and choose one tidemark: a power that lasts tonight only.",
	"shop": "A merchant. Talk to him with E. Salt is his coin, and salt does not come home.",
	"fountain": "A fountain. Stand in it to heal. It is the only rest between here and the boss.",
	"fork": "Two doors. The wet way is already flooded and harder, but it carries you two rooms down.",
	"echo": "Someone is caged here. Clear the room, then open the cage with E. They go home to the lighthouse.",
	"challenge": "No door out. Hold on through the waves until the tide turns. Then the water drains, and pays.",
	"vault": "A vault. It opens with a key, and elites carry keys.",
	"dive": "A dive. The water is deep everywhere here and it hurts. The altar and the chest are worth it.",
	"boss": "The boss of this place. Break it and the way down opens. When it stirs, the tide jumps.",
	"elite": "An elite: tougher, and it leaves pearls behind. The named ones leave an echo shard.",
	"low": "You are nearly out of health. Fountains heal, and the merchant sells salves for salt.",
	"flare": "Your lantern is full. Press Q: a flare that hurts and stuns everything near you.",
	"riptide": "A riptide: you dashed just as a strike landed. For a moment your hits crit and the world slows.",
	"key": "A vault key. If a door offers a vault, this opens it.",
}

var _root: Control
# cards
var _band: ColorRect
var _band_top: ColorRect
var _band_bot: ColorRect
var _title: Label
var _sub: Label
var _rule: ColorRect
var _cards: Array = []
var _card_busy: bool = false
var card_showing: bool = false
# toasts
var _toasts: VBoxContainer
# whispers
var _strip: PanelContainer
var _strip_tag: Label
var _strip_text: Label
var _whispers: Array = []
var _whisper_busy: bool = false
# hints
var _hint_box: PanelContainer
var _hint_text: Label
var _hints: Array = []
var _hint_busy: bool = false
# stage
var _bars: Array = []
var _vignette: Vignette
var _low: bool = false
var _t: float = 0.0


func _ready() -> void:
	layer = 1
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_vignette = Vignette.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vignette)
	_build_cards()
	_build_toasts()
	_build_strip()
	_build_hint()
	_build_bars()


func _process(delta: float) -> void:
	_t += delta
	if _low:
		_vignette.base = Color(RED, 0.22 + 0.14 * sin(_t * 4.5))
	else:
		_vignette.base = Color(RED, 0.0)
	_vignette.queue_redraw()


# --- cards -------------------------------------------------------------------------
func _build_cards() -> void:
	_band = ColorRect.new()
	_band.color = Color(INK, 0.62)
	_band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_band.offset_top = 40
	_band.offset_bottom = 74
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.visible = false
	_root.add_child(_band)
	_band_top = _line(_band, 0)
	_band_bot = _line(_band, -1)
	_title = UI.label("", 16, CARD_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 44
	_title.offset_bottom = 62
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 2)
	_title.visible = false
	_root.add_child(_title)
	_rule = ColorRect.new()
	_rule.color = WARM
	_rule.size = Vector2(0, 1)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.visible = false
	_root.add_child(_rule)
	_sub = UI.label("", 8, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	_sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_sub.offset_top = 62
	_sub.offset_bottom = 72
	_sub.visible = false
	_root.add_child(_sub)


func _line(parent: Control, at_bottom: int) -> ColorRect:
	var l := ColorRect.new()
	l.color = Color(CARD_COLOR, 0.35)
	l.set_anchors_preset(Control.PRESET_TOP_WIDE if at_bottom == 0 else Control.PRESET_BOTTOM_WIDE)
	if at_bottom == 0:
		l.offset_bottom = 1
	else:
		l.offset_top = -1
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## A moment with a name. `sub` is the plain line under it: what it means for you.
func card(title: String, sub: String = "", hold: float = 2.2, color: Color = CARD_COLOR, big: bool = false) -> void:
	_cards.append({"title": title, "sub": sub, "hold": hold, "color": color, "big": big})
	if not _card_busy:
		_run_cards()


func _run_cards() -> void:
	_card_busy = true
	while _cards.size() > 0:
		var c: Dictionary = _cards.pop_front()
		card_showing = true
		var big: bool = c.big
		var size := 24 if big else 16
		var has_sub: bool = c.sub != ""
		_title.text = c.title
		_title.add_theme_font_size_override("font_size", size)
		_title.add_theme_color_override("font_color", c.color)
		_title.offset_top = 40
		_title.offset_bottom = 40 + size + 6
		_sub.text = c.sub
		_sub.offset_top = _title.offset_bottom + 3
		_sub.offset_bottom = _sub.offset_top + 10
		_band.offset_top = 36
		_band.offset_bottom = (_sub.offset_bottom + 4) if has_sub else (_title.offset_bottom + 2)
		_band_top.color = Color(c.color, 0.35)
		_band_bot.color = Color(c.color, 0.35)
		var title_y := float(_title.offset_top)
		var rule_y := _title.offset_bottom + 1
		var rule_w := 96 if not big else 140
		_rule.color = c.color
		_rule.position = Vector2(320 - rule_w / 2, rule_y)
		_rule.size = Vector2(0, 1)
		_rule.position.x = 320
		for n in [_band, _title, _rule, _sub]:
			n.modulate = Color(1, 1, 1, 0)
			n.visible = true
		_sub.visible = has_sub
		_title.offset_top = title_y - 6
		_title.offset_bottom = _title.offset_top + size + 6
		var tw := create_tween()
		tw.tween_property(_band, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(_title, "modulate:a", 1.0, 0.2)
		tw.parallel().tween_property(_title, "offset_top", title_y, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_title, "offset_bottom", title_y + size + 6, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_rule, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(_rule, "size:x", float(rule_w), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_rule, "position:x", 320.0 - rule_w / 2, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_sub, "modulate:a", 1.0, 0.3).set_delay(0.18)
		await tw.finished
		await get_tree().create_timer(c.hold, false).timeout
		var out := create_tween()
		for n in [_band, _title, _rule, _sub]:
			out.parallel().tween_property(n, "modulate:a", 0.0, 0.35)
		await out.finished
		for n in [_band, _title, _rule, _sub]:
			n.visible = false
		card_showing = false
		await get_tree().create_timer(0.15, false).timeout
	_card_busy = false


# --- toasts ------------------------------------------------------------------------
func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toasts.offset_top = 100
	_toasts.offset_bottom = 160
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 2)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)


## A small thing that just happened, in one line. Three at most; the oldest goes first.
func toast(text: String, color: Color = SALT, hold: float = 2.4) -> void:
	while _toasts.get_child_count() >= 3:
		var old: Node = _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var pill := _pill(Color(INK, 0.6))
	var l := UI.label(text, 8, color, HORIZONTAL_ALIGNMENT_CENTER)
	pill.add_child(l)
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(pill)
	wrap.modulate = Color(1, 1, 1, 0)
	_toasts.add_child(wrap)
	var tw := create_tween()
	tw.tween_property(wrap, "modulate:a", 1.0, 0.15)
	tw.tween_interval(hold)
	tw.tween_property(wrap, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		if is_instance_valid(wrap):
			_toasts.remove_child(wrap)
			wrap.queue_free())


func _pill(bg: Color, edge: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	if edge.a > 0.0:
		s.border_color = edge
		s.border_width_left = 2
		s.content_margin_left = 10
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# --- whispers ----------------------------------------------------------------------
func _build_strip() -> void:
	_strip = _pill(Color(INK, 0.66))
	_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_strip.offset_left = 96
	_strip.offset_right = -96
	_strip.offset_top = 268
	_strip.visible = false
	_root.add_child(_strip)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(box)
	_strip_tag = UI.label("the lantern", 8, WET)
	box.add_child(_strip_tag)
	_strip_text = UI.label("", 8, PALE)
	_strip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_strip_text)


## The lantern's line (or someone else's, with `who`). Typed out; waits for any card.
func whisper(text: String, who: String = "the lantern") -> void:
	_whispers.append({"text": text, "who": who})
	if not _whisper_busy:
		_run_whispers()


func _run_whispers() -> void:
	_whisper_busy = true
	while _whispers.size() > 0:
		while card_showing or _hint_busy:
			await get_tree().create_timer(0.2, false).timeout
		var w: Dictionary = _whispers.pop_front()
		var text: String = "\"%s\"" % w.text
		_strip_tag.text = w.who
		_strip_text.text = text
		_strip_text.visible_ratio = 0.0
		_strip.modulate = Color(1, 1, 1, 0)
		_strip.visible = true
		var tw := create_tween()
		tw.tween_property(_strip, "modulate:a", 1.0, 0.2)
		await tw.finished
		var mult := float(Settings.dialog_speed())
		if mult <= 0.0:
			_strip_text.visible_ratio = 1.0
		else:
			var type := create_tween()
			type.tween_property(_strip_text, "visible_ratio", 1.0, text.length() / (45.0 * mult))
			await type.finished
		await get_tree().create_timer(1.6 + 0.05 * text.length(), false).timeout
		var out := create_tween()
		out.tween_property(_strip, "modulate:a", 0.0, 0.5)
		await out.finished
		_strip.visible = false
		await get_tree().create_timer(0.3, false).timeout
	_whisper_busy = false


# --- hints -------------------------------------------------------------------------
func _build_hint() -> void:
	_hint_box = _pill(Color(INK, 0.74), WARM)
	_hint_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_box.offset_left = 128
	_hint_box.offset_right = -128
	_hint_box.offset_top = 232
	_hint_box.visible = false
	_root.add_child(_hint_box)
	_hint_text = UI.label("", 8, WARM)
	_hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_box.add_child(_hint_text)


## Plain words about how a thing works. Once per profile, only while hints are on.
func hint(key: String) -> void:
	if not Settings.hints() or not HINTS.has(key):
		return
	if key == "move" and Game.gamepad:
		key = "move_pad"
	var flag := "hint_" + key.trim_suffix("_pad")
	if SaveManager.flag(flag) or key in _hints:
		return
	SaveManager.set_flag(flag)
	_hints.append(key)
	if not _hint_busy:
		_run_hints()


func _run_hints() -> void:
	_hint_busy = true
	while _hints.size() > 0:
		var key: String = _hints.pop_front()
		_hint_text.text = HINTS[key]
		_hint_box.modulate = Color(1, 1, 1, 0)
		_hint_box.visible = true
		Audio.play("ui", 0.0, -10.0)
		var tw := create_tween()
		tw.tween_property(_hint_box, "modulate:a", 1.0, 0.25)
		await tw.finished
		await get_tree().create_timer(clampf(1.5 + 0.04 * HINTS[key].length(), 3.0, 7.0), false).timeout
		var out := create_tween()
		out.tween_property(_hint_box, "modulate:a", 0.0, 0.5)
		await out.finished
		_hint_box.visible = false
		await get_tree().create_timer(0.4, false).timeout
	_hint_busy = false


# --- stage -------------------------------------------------------------------------
func _build_bars() -> void:
	for i in 2:
		var b := ColorRect.new()
		b.color = INK
		b.set_anchors_preset(Control.PRESET_TOP_WIDE if i == 0 else Control.PRESET_BOTTOM_WIDE)
		if i == 0:
			b.offset_bottom = 0
		else:
			b.offset_top = 0
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(b)
		_bars.append(b)


## Cinema bars for a boss: in over 0.3 s, out the same way.
func letterbox(on: bool, height: float = 26.0) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bars[0], "offset_bottom", height if on else 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bars[1], "offset_top", -height if on else 0.0, 0.3).set_trans(Tween.TRANS_SINE)


## A coloured pulse at the edge of the screen: the tide rising, a riptide, a hit.
func pulse(color: Color, strength: float = 0.5, duration: float = 0.8) -> void:
	_vignette.flash = Color(color, strength)
	var tw := create_tween()
	tw.tween_property(_vignette, "flash:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The slow red beat while you are nearly out.
func low_health(on: bool) -> void:
	_low = on


## Everything off at once (the run is over).
func clear() -> void:
	_cards.clear()
	_whispers.clear()
	_hints.clear()
	_low = false


## Four soft quads round the edge, each fading to nothing toward the middle.
class Vignette extends Control:
	var base: Color = Color(0, 0, 0, 0)
	var flash: Color = Color(0, 0, 0, 0)
	const EDGE := 60.0

	func _draw() -> void:
		for c in [base, flash]:
			if c.a <= 0.005:
				continue
			var clear_c := Color(c, 0.0)
			var w := size.x
			var h := size.y
			var e := EDGE
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, e), Vector2(0, e)]),
				PackedColorArray([c, c, clear_c, clear_c]))
			draw_polygon(PackedVector2Array([Vector2(0, h - e), Vector2(w, h - e), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([clear_c, clear_c, c, c]))
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, 0), Vector2(e, h), Vector2(0, h)]),
				PackedColorArray([c, clear_c, clear_c, c]))
			draw_polygon(PackedVector2Array([Vector2(w - e, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - e, h)]),
				PackedColorArray([clear_c, c, c, clear_c]))
