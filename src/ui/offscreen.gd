class_name OffscreenMarks
extends Control
## In a room larger than the screen (map Stage 02), a small Salt red wedge on the screen's
## edge points at every enemy out of view, so a fight never hides. Nothing shows in a
## one-screen room. Screen space, on the HUD layer, under the bars.

const INSET := 6.0
const SIZE := 4.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect()
	var xf := get_viewport().get_canvas_transform()
	var centre := view.size * 0.5
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or e.is_queued_for_deletion():
			continue
		var p: Vector2 = xf * ((e as Node2D).global_position + Vector2(0, -8))
		if view.grow(-2.0).has_point(p):
			continue
		var dir := (p - centre).normalized()
		# Where the line from the centre to the enemy leaves the inset frame.
		var half := centre - Vector2(INSET, INSET)
		var t := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
		var at := (centre + dir * t).round()
		var side := Vector2(-dir.y, dir.x)
		var tip := at + dir * SIZE
		var pts := PackedVector2Array([tip, at - dir * SIZE + side * SIZE, at - dir * SIZE - side * SIZE])
		draw_colored_polygon(PackedVector2Array([tip + dir, pts[1] - dir + side, pts[2] - dir - side]), Palette.INK)
		draw_colored_polygon(pts, Palette.SALT_RED)
