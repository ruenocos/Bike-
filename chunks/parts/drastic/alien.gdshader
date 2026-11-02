shader_type spatial;
// Alien structures (v0.31 "drastic landscape"): dark glossy faces with
// glowing veins that swirl slowly (monoliths, floating shards, gravity
// rings, the energy core). Cel-banded light so it sits with the rest of
// the world; the veins are emissive so they read from far away.

uniform vec4 base_color : source_color = vec4(0.07, 0.07, 0.2, 1.0);
uniform vec4 rim_color : source_color = vec4(0.35, 0.4, 1.0, 1.0);
uniform vec4 vein_color : source_color = vec4(0.45, 0.55, 1.0, 1.0);
// Vein pattern size (world metres per swirl) and glow strength.
uniform float vein_scale = 9.0;
uniform float vein_width : hint_range(0.01, 0.4) = 0.09;
uniform float glow : hint_range(0.0, 16.0) = 3.0;
// How fast the swirl drifts.
uniform float flow_speed = 0.08;
// Light bands: shadow / mid / lit brightness.
uniform vec3 bands = vec3(0.35, 0.7, 1.0);

varying vec3 world_pos;
varying vec3 world_nrm;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = world_pos / vein_scale;
	float t = TIME * flow_speed;
	// Domain-warped noise: iso-lines of it are the swirling veins.
	vec3 warp = vec3(fbm(p + vec3(t, 0.0, 0.0)), fbm(p + vec3(5.2, t, 1.3)), fbm(p + vec3(1.7, 9.2, t)));
	float n = fbm(p + warp * 1.6);
	float line = abs(fract(n * 4.0) - 0.5);
	float vein = 1.0 - smoothstep(vein_width * 0.5, vein_width, line);
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
	EMISSION = vein_color.rgb * vein * glow;
	// Rim so the silhouette pops against the sky.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION += rim_color.rgb * fres * 0.6;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = ndl > 0.35 ? bands.z : (ndl > 0.0 ? bands.y : bands.x);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band;
	vec3 h = normalize(LIGHT + VIEW);
	float spec = step(0.92, dot(NORMAL, h)) * ATTENUATION;
	SPECULAR_LIGHT += LIGHT_COLOR * spec * 0.6;
}
