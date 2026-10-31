shader_type canvas_item;
// Fullscreen radial speed streaks, clear in the middle, thicker toward the edges.
// `intensity` (0-1) is driven from vfx/speed_lines.gd; everything else is look.
//
// Godot note: a canvas_item shader runs per pixel of a 2D node (here a
// fullscreen ColorRect). UV goes 0-1 across the rect, TIME is seconds.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Number of angular slots a streak can appear in.
uniform float line_count = 110.0;
// Fraction of slots lit at any moment.
uniform float density : hint_range(0.0, 1.0) = 0.4;
// Streaks start between inner_radius and inner_radius + start_jitter (1 = screen half-height).
uniform float inner_radius = 0.55;
uniform float start_jitter = 0.4;
// How often the streak pattern re-rolls (per second).
uniform float flicker_rate = 18.0;

float hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

void fragment() {
	// Centre the coordinates and correct for aspect, so the streaks are round.
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 p = (UV - 0.5) * 2.0 * aspect;
	float r = length(p);
	float slot = (atan(p.y, p.x) / TAU + 0.5) * line_count;
	float id = floor(slot);
	float frame = floor(TIME * flicker_rate);

	float lit = step(1.0 - density, hash(id + frame * 17.31));
	float half_width = mix(0.04, 0.18, hash(id * 3.7 + frame));
	float across = abs(fract(slot) - 0.5);
	float aa = fwidth(slot) * 1.5;
	float line = 1.0 - smoothstep(half_width, half_width + aa, across);
	float start = inner_radius + hash(id * 9.1 + frame * 1.3) * start_jitter;
	float radial = smoothstep(start, start + 0.3, r);

	COLOR = vec4(line_color.rgb, line_color.a * lit * line * radial * intensity);
}
