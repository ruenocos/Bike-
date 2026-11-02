global uniform sampler2D diffuse_curve: repeat_disable;
global uniform float specular_smoothness;
global uniform float fresnel_smoothness;

 float diffuse_sample(vec3 light, vec3 normal) {
	return texture(diffuse_curve, vec2(dot(light, normal), 0)
	).r;
 }

float is_lit(vec3 light, vec3 normal, float attenuation) {
	return attenuation * diffuse_sample(light, normal);
}

// Bike! (v0.25): the shadow side gets a coloured fill (per biome, Shader
// Globals shadow_tint / shadow_tint_strength) instead of only grey ambient.
// Colour globals arrive as typed (sRGB) whatever the hint; light is linear.
global uniform vec4 shadow_tint;
global uniform float shadow_tint_strength;

vec3 cel_srgb_to_linear(vec3 c) {
	return pow(c, vec3(2.2));
}

// Bike! (v0.30): a dot pattern inside the shadow band (screen space, Hi-Fi
// Rush style). Strength 0 = plain shadow; per material in the Inspector.
uniform float halftone_strength : hint_range(0.0, 1.0) = 0.2;
uniform float halftone_size : hint_range(2.0, 24.0) = 7.0;

float cel_halftone(vec2 frag) {
	vec2 p = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * frag / halftone_size;
	return 1.0 - smoothstep(0.22, 0.3, length(fract(p) - 0.5));
}

vec3 diffuse_light(
		vec3 albedo,
		vec3 light_color,
		vec3 light,
		vec3 normal,
		float attenuation,
		vec2 frag
) {
	float lit = is_lit(light, normal, attenuation);
	float dots = 1.0 - halftone_strength * cel_halftone(frag);
	return albedo * light_color * lit + albedo * cel_srgb_to_linear(shadow_tint.rgb) * (1.0 - lit) * shadow_tint_strength * dots;
}

vec3 specular_light(
		vec3 light_color,
		vec3 specular_color,
		float specular_strength,
		vec3 normal,
		vec3 view,
		vec3 light,
		float attenuation
) {
	vec3 half = normalize(view + light);
	float gloss = pow(2.0, 8.0 * (1.0 - specular_strength));
	float intensity = pow(dot(normal, half), gloss * gloss);
	return light_color
			* specular_color
			* is_lit(light, normal, attenuation)
			* smoothstep(
					0.05,
					0.05 + specular_smoothness,
					intensity
			);
}

vec3 fresnel_light(
		vec3 light_color,
		vec3 fresnel_color,
		float fresnel_strength,
		vec3 normal,
		vec3 view,
		vec3 light,
		float attenuation
) {
	float fresnel_dot = 1.0 - dot(normal, view);
	float fresnel_threshold = pow((1.0 - fresnel_strength), dot(light, normal));
	return light_color
			* fresnel_color
			* is_lit(light, normal, attenuation)
			* smoothstep(
					fresnel_threshold - fresnel_smoothness / 2.0,
					fresnel_threshold + fresnel_smoothness / 2.0,
					fresnel_dot
			);
}
