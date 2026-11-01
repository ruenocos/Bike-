// Bike! (v0.28): wind sway for trees, visual only (collision never moves).
// Strength per mesh instance (PropModel sets `sway` on tree meshes; 0 =
// still). The offset grows with the square of the height above the
// model's origin (capped at 10 m, so big trees don't swing further than
// small ones), so trunks barely move and the tops sway, and the phase
// comes from the world position so a forest doesn't move in lockstep.
instance uniform float sway = 0.0;

vec3 sway_offset(vec3 vertex, mat4 model, float time) {
	if (sway <= 0.0) {
		return vec3(0.0);
	}
	vec3 wp = (model * vec4(vertex, 1.0)).xyz;
	float h = clamp(wp.y - model[3].y, 0.0, 10.0);
	float s = sin(time * 1.3 + wp.x * 0.11 + wp.z * 0.07) + 0.35 * sin(time * 3.1 + wp.x * 0.3 + wp.z * 0.2);
	vec3 world = vec3(0.8, 0.0, 0.6) * s * sway * h * h;
	// Props are scaled uniformly: the inverse is the transpose / scale^2.
	float s2 = dot(model[0].xyz, model[0].xyz);
	return transpose(mat3(model)) * world / s2;
}
