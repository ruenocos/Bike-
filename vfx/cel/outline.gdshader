shader_type spatial;

render_mode cull_front, unshaded, depth_draw_never;

global uniform vec4 outline_color;
global uniform float outline_width;
// Bike! (v0.25): full width up to outline_fade_start (m), none past
// outline_fade_end, so far props don't turn into ink smudges (and far
// outlines collapse to nothing, which is cheap).
global uniform float outline_fade_start;
global uniform float outline_fade_end;

void vertex() {
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float fade = 1.0 - smoothstep(outline_fade_start, outline_fade_end, -view_position.z);
	vec4 clip_position = PROJECTION_MATRIX * view_position;
	vec3 clip_normal =
			mat3(PROJECTION_MATRIX) *
			(mat3(MODELVIEW_MATRIX) * NORMAL);
	clip_position.xy +=
			normalize(clip_normal.xy) /
			VIEWPORT_SIZE *
			clip_position.w *
			outline_width * fade;
	POSITION = clip_position;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
