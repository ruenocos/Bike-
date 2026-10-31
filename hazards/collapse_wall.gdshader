shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// The collapse wall: churning dark-red bands with hot cracks, fading out at
// the top and sides so it reads as a cloud of destruction, not a panel.

uniform vec3 hot_color : source_color = vec3(1.0, 0.45, 0.12);
uniform vec3 dark_color : source_color = vec3(0.16, 0.03, 0.03);
uniform float speed = 0.6;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV * vec2(6.0, 5.0);
	float t = TIME * speed;
	float n = fbm(p + vec2(0.0, t * 1.5));
	float cracks = smoothstep(0.62, 0.72, fbm(p * 1.7 - vec2(t, t * 2.0)));
	vec3 c = mix(dark_color, hot_color * 0.6, n);
	c += hot_color * cracks * 2.5;
	// Fade at the top and the sides.
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(0.0, 0.15, 1.0 - UV.x);
	float top = smoothstep(0.0, 0.45, UV.y + n * 0.2);
	ALBEDO = c;
	ALPHA = clamp(edge * top * (0.75 + n * 0.4), 0.0, 1.0);
}
