class_name SheetFrames
extends RefCounted
## Builds a SpriteFrames from a horizontal strip sheet so animations are declared in
## code next to the thing that uses them instead of in a .tres file.
##
## anims = {"idle": {"frames": [0, 1], "fps": 4, "loop": true}, ...}


static func build(tex: Texture2D, cell: int, anims: Dictionary, cell_h: int = -1) -> SpriteFrames:
	var h := cell if cell_h < 0 else cell_h
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim_name in anims:
		var a: Dictionary = anims[anim_name]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, float(a.get("fps", 8)))
		sf.set_animation_loop(anim_name, bool(a.get("loop", true)))
		for idx in a["frames"]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(int(idx) * cell, 0, cell, h)
			sf.add_frame(anim_name, at)
	return sf
