shader_type canvas_item;
// Red glow around the screen edges while the collapse is close.
// `intensity` 0 = off, 1 = right behind you. It pulses faster when closer.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.15, 0.05, 1.0);

void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float edge = pow(max(d.x * 0.85, d.y), 2.2);
	float pulse = 0.75 + 0.25 * sin(TIME * mix(4.0, 14.0, intensity));
	COLOR = vec4(color.rgb, clamp(edge * intensity * pulse * 1.4, 0.0, 0.9));
}
