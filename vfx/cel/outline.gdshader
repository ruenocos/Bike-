shader_type spatial;

render_mode cull_front, unshaded, depth_draw_never;

global uniform vec4 outline_color;
global uniform float outline_width;
// Bike! (v0.25): full width up to outline_fade_start (m), none past
// outline_fade_end, so far props don't turn into ink smudges (and far
// outlines collapse to nothing, which is cheap).
global uniform float outline_fade_start;
global uniform float outline_fade_end;

#include "includes/sway.gdshaderinc"

// Bike! (v0.30): the width never drops below this on this mesh
// (CelLook.keep_outline: thicker on the rider and things you can hit).
instance uniform float outline_min = 0.0;
// Coloured lines: the surface's own colour, darkened, mixed over the ink.
uniform vec4 color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform float local_mix : hint_range(0.0, 1.0) = 0.0;
uniform float local_darken : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	VERTEX += sway_offset(VERTEX, MODEL_MATRIX, TIME);
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
			max(outline_width, outline_min) * fade;
	POSITION = clip_position;
}

void fragment() {
	vec3 local = color.rgb * texture(base_texture, UV).rgb;
	ALBEDO = mix(pow(outline_color.rgb, vec3(2.2)), local * local * local_darken, local_mix);
}
