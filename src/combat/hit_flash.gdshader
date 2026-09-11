shader_type canvas_item;

// 0 = normal, 1 = fully white. Tweened by whoever owns the sprite.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = tex.rgb * COLOR.rgb;
	COLOR = vec4(mix(base, vec3(1.0), flash), tex.a * COLOR.a);
}
