// Bike! ground flow (v0.31, vfx/speed_feel): small light and dark flecks on
// the ground near the camera, so the eye has something to track at speed
// (plain colour at 55 m/s looks still). Two tones, hard-edged, for the cel
// look. Fades out with distance and where the flecks get smaller than a few
// pixels, so it never shimmers far away.
// Tweak in Project Settings > Shader Globals: ground_flow_*.
// Needs ground_noise.gdshaderinc included first.

global uniform float ground_flow_strength;
global uniform float ground_flow_size;
global uniform float ground_flow_far;

// Brightness factor around 1.0 for a world position and the camera position.
float ground_flow(vec3 world_pos, vec3 camera_pos) {
	if (ground_flow_strength <= 0.0) {
		return 1.0;
	}
	float dist = distance(world_pos, camera_pos);
	float near = 1.0 - smoothstep(ground_flow_far * 0.5, ground_flow_far, dist);
	vec2 p = world_pos.xz / max(ground_flow_size, 0.01);
	// Anti-alias: fade out where one fleck covers under ~3 pixels.
	float px = length(fwidth(p));
	near *= 1.0 - smoothstep(0.15, 0.35, px);
	if (near <= 0.0) {
		return 1.0;
	}
	float a = ground_value_noise(p) * 0.6 + ground_value_noise(p * 2.7 + 31.0) * 0.4;
	float b = ground_value_noise(p * 1.3 + 77.0) * 0.6 + ground_value_noise(p * 3.1 + 5.0) * 0.4;
	float aa = max(px * 0.6, 0.01);
	float dark = smoothstep(0.66 - aa, 0.66 + aa, a);
	float light = smoothstep(0.68 - aa, 0.68 + aa, b);
	return 1.0 + (light * 0.7 - dark) * ground_flow_strength * near;
}
