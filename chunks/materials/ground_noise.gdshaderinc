// Bike! ground patches: smooth value noise with a sin-free hash (Dave
// Hoskins' hash12), cells wrapped every 289 so it stays clean far from the
// world origin (a fract(sin()) hash went blocky kilometres out). Used by the
// terrain and the grass tufts so both follow the same light / dark patches.

float ground_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ground_value_noise(vec2 p) {
	vec2 i = mod(floor(p), 289.0);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 i1 = mod(i + 1.0, 289.0);
	return mix(mix(ground_hash(i), ground_hash(vec2(i1.x, i.y)), u.x),
			mix(ground_hash(vec2(i.x, i1.y)), ground_hash(i1), u.x), u.y);
}

// Brightness factor around 1.0 for a world position (xz) and a strength.
float ground_patches(vec2 xz, float strength) {
	float n = ground_value_noise(xz * 0.035) * 0.65 + ground_value_noise(xz * 0.16) * 0.35;
	return 1.0 + (n - 0.5) * 2.0 * strength;
}
