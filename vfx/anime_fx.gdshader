shader_type canvas_item;
// Impact frame + radial burst (vfx/anime_fx.gd). `flash` washes the screen
// toward a pale tint and takes some colour out (`ink_flip` 1 = the full flip to
// two colours by brightness instead); `lines` draws radial wedges outside `radius`.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float ink_flip : hint_range(0.0, 1.0) = 0.0;
uniform float line_width : hint_range(0.0, 1.0) = 0.4;
uniform float lines : hint_range(0.0, 1.0) = 0.0;
uniform float radius = 0.5;
uniform vec4 ink : source_color = vec4(0.06, 0.03, 0.16, 1.0);
uniform vec4 paper : source_color = vec4(1.0, 0.97, 0.86, 1.0);
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float threshold : hint_range(0.0, 1.0) = 0.42;
uniform float line_count = 54.0;

float hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float value = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 two = mix(ink.rgb, paper.rgb, step(threshold, value));
	vec3 soft = mix(vec3(value), paper.rgb, 0.5);
	c = mix(c, mix(soft, two, ink_flip), flash);

	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 p = (UV - 0.5) * 2.0 * aspect;
	float r = length(p);
	float slot = (atan(p.y, p.x) / TAU + 0.5) * line_count;
	float id = floor(slot);
	float start = radius + hash(id) * 0.5;
	// A wedge: wide at the screen edge, a point towards the middle.
	float half_width = clamp((r - start) * 0.9 * line_width, 0.0, 0.45) * step(0.55, hash(id * 3.7));
	float line = 1.0 - smoothstep(half_width - fwidth(slot), half_width, abs(fract(slot) - 0.5));
	c = mix(c, line_color.rgb, line * lines * step(start, r));
	COLOR = vec4(c, 1.0);
}
