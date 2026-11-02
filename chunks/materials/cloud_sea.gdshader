shader_type spatial;
// Bike! sea of clouds (FarGround, sky pass): the big plane under the valley
// is a layer of cel cloud tops drifting below the rim, so the world reads
// as high up instead of ending in an empty plane. Puffs rise out of the
// plane (vertex), are lit on the sun side with a hard cel step, and the
// whole sea fades into the fog colour with distance so the mountains sink
// into it. Cloud colours come from the biome's SkyLook (BiomeLook sets
// them); the noise is the sky's own (sky/cloud_noise.tres).
render_mode unshaded, fog_disabled, cull_disabled;

uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
/// Deep gaps between the clouds.
uniform vec3 base_color : source_color = vec3(0.62, 0.55, 0.7);
/// Far away everything melts into this (the fog colour).
uniform vec3 fade_color : source_color = vec3(0.93, 0.72, 0.56);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.93, 0.85);
uniform vec3 cloud_shadow : source_color = vec3(0.75, 0.66, 0.85);
uniform vec3 rim_color : source_color = vec3(1.0, 0.86, 0.65);
uniform vec3 sun_direction = vec3(0.4, 0.3, -0.8);
/// Noise repeats per metre (smaller = bigger clouds).
uniform float scale = 0.00035;
uniform float coverage : hint_range(0.0, 1.0, 0.01) = 0.62;
/// How high the biggest puffs rise (m).
uniform float puff_height = 120.0;
uniform vec2 wind = vec2(0.0012, 0.0005);
uniform float fade_from = 1500.0;
uniform float fade_to = 5800.0;

varying vec3 world_pos;

float density(vec2 xz) {
	vec2 uv = xz * scale + TIME * wind;
	float n = textureLod(cloud_noise, uv, 0.0).r;
	// A finer octave so the edges get puffy.
	n += (textureLod(cloud_noise, uv * 3.7 + 0.31, 0.0).r - 0.5) * 0.18;
	return n;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float thr = 1.0 - coverage;
	float n = density(w.xz);
	float puff = max(n - thr, 0.0) / max(coverage, 0.01);
	VERTEX.y += sqrt(puff) * puff_height;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float thr = 1.0 - coverage;
	vec2 uv = world_pos.xz * scale + TIME * wind;
	float n = texture(cloud_noise, uv).r + (texture(cloud_noise, uv * 3.7 + 0.31).r - 0.5) * 0.18;
	vec2 sun_xz = normalize(sun_direction.xz + vec2(0.0001));
	float n_sun = texture(cloud_noise, uv + sun_xz * 0.012).r + (texture(cloud_noise, (uv + sun_xz * 0.012) * 3.7 + 0.31).r - 0.5) * 0.18;
	float d = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);
	// Cloud edge: a little softer far away so it doesn't shimmer.
	float soft = 0.01 + d * 0.000004;
	float mask = smoothstep(thr - soft, thr + soft, n);
	// Rising toward the sun = this side faces it.
	float lit = step(n, n_sun + 0.004);
	vec3 c = mix(cloud_shadow, cloud_light, lit);
	// Silver lining on the lit edges.
	float edge = 1.0 - smoothstep(thr, thr + 0.05, n);
	c = mix(c, rim_color, edge * lit * 0.7);
	c = mix(base_color, c, mask);
	ALBEDO = mix(c, fade_color, smoothstep(fade_from, fade_to, d));
}
