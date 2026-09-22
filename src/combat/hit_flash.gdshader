shader_type canvas_item;

// 0 = normal, 1 = Salt white (STYLE.md 14). Tweened by whoever owns the sprite.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = tex.rgb * COLOR.rgb;
	COLOR = vec4(mix(base, vec3(0.851, 0.890, 0.910), flash), tex.a * COLOR.a);
}

// The soft knee (STYLE.md 11 and 20, art Stage 20). A 2D light adds to the body without a
// ceiling, so a Bone-pale body inside the lantern pool went past 1.0 and clipped to pure
// white: the Bell, the sinker's dome, a wax pool. Each light's contribution is bent toward
// half the room the body has left below white: a small light is unchanged (the slope is 1
// at zero), a large one approaches that half and never crosses it, so two saturating
// lights (the lantern and a lit status) land exactly on white and never past it, and Bone
// dark, Bone and Bone light are still three colours in the lantern's core.
void light() {
	vec3 add = COLOR.rgb * LIGHT_COLOR.rgb * LIGHT_ENERGY;
	vec3 room = max(vec3(1.0) - COLOR.rgb, vec3(0.02)) * 0.5;
	LIGHT = vec4(room * (vec3(1.0) - exp(-add / room)), LIGHT_COLOR.a);
}
