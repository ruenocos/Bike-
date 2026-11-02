shader_type canvas_item;
// Radial zoom blur with a sharp centre (vfx/speed_feel). Every pixel smears
// toward `center` (the point you ride toward); a clear ellipse keeps the
// rider and the way ahead crisp, and the bottom of the screen (the ground
// rushing past) gets extra. `strength` is driven by SpeedFeel.
//
// Godot note: hint_screen_texture gives this shader a copy of what is already
// on screen. The CanvasLayer sits at layer -1, so that copy is the 3D view
// without the HUD or speed lines, and those stay sharp on top.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float strength : hint_range(0.0, 2.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.45);
uniform float blur_length = 0.12;
uniform vec2 clear = vec2(0.2, 0.16);
uniform float feather = 1.4;
uniform float bottom_boost = 0.8;
uniform int samples : hint_range(2, 24) = 12;

float dither(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - center;
	// Distance in ellipse radii: 1 = edge of the clear zone.
	float r = length(d / clear);
	float mask = smoothstep(1.0, 1.0 + feather, r);
	// Canvas y grows downward: below the centre is the ground.
	mask *= 1.0 + bottom_boost * smoothstep(0.0, 0.45, d.y);
	float amount = strength * mask;
	vec3 col = texture(screen_tex, uv).rgb;
	if (amount > 0.002) {
		// Jitter the start per pixel so the steps blend instead of banding.
		float j = dither(FRAGCOORD.xy);
		vec3 sum = vec3(0.0);
		float n = float(samples);
		for (int i = 0; i < samples; i++) {
			float t = (float(i) + j) / n;
			sum += texture(screen_tex, uv - d * blur_length * amount * t).rgb;
		}
		col = sum / n;
	}
	COLOR = vec4(col, 1.0);
}
