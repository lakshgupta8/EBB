shader_type canvas_item;
// The water overlay (art Stage 10, STYLE.md 11-12). Lights reach the water as they reach
// everything, plus 1 px horizontal glints of the light's colour at 30 % inside its pool:
// about one row in four carries 3 px runs, anchored to the world, only where the overlay
// has paint. No painted reflections anywhere.

uniform float glint_strength : hint_range(0.0, 1.0) = 0.3;

varying vec2 world_pos;

float hash1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void light() {
	vec2 p = floor(world_pos);
	float h = hash1(p.y);
	float on = step(0.72, h);
	float per = 7.0 + floor(hash1(p.y + 3.0) * 6.0);   // 7..12 px between runs, per row
	float run = step(mod(p.x + floor(h * 97.0), per), 2.0);
	float g = on * run * glint_strength * step(0.01, COLOR.a);
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * (COLOR.rgb + vec3(g)), LIGHT_COLOR.a);
}
