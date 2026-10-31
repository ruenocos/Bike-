shader_type spatial;
// Distant mountain silhouettes (MountainRing): flat colour from peak to base,
// fading into the haze colour at the bottom. No fog, no lighting: they're a
// backdrop.
render_mode unshaded, fog_disabled, cull_back;

uniform vec3 peak_color : source_color = vec3(0.36, 0.38, 0.52);
uniform vec3 haze_color : source_color = vec3(0.86, 0.66, 0.56);
// How far up the haze reaches (0 = none, 1 = to the peak).
uniform float haze_height = 0.75;

varying float height;

void vertex() {
	// The cone mesh runs from y -0.5 (base) to 0.5 (peak).
	height = VERTEX.y + 0.5;
}

void fragment() {
	float t = smoothstep(0.0, haze_height, height);
	ALBEDO = mix(haze_color, peak_color, t);
}
