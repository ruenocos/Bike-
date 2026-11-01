shader_type spatial;
// Bike! grass tufts (GroundCover, GrassTuftMesh): root colour = the ground's
// grass colour, tips lighter (global ground_grass / grass_tip, per biome),
// a gentle wind sway, cel lighting as if the blade were flat ground.
render_mode cull_disabled;

#include "res://vfx/cel/includes/base-cel-shader.gdshaderinc"

global uniform vec4 ground_grass;
global uniform vec4 grass_tip;
uniform float sway = 0.12;
uniform float sway_speed = 1.7;
uniform float gust_scale = 0.06;
// Per-instance brightness variation (instance colour red).
uniform float variation = 0.25;

// Global colours arrive as typed (sRGB); the shader works in linear.
vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

varying float tip;
varying float shade;
varying vec3 SPECULAR_COLOR;
varying float SPECULAR_STRENGTH;
varying vec3 FRESNEL_COLOR;
varying float FRESNEL_STRENGTH;

void vertex() {
	tip = UV.y;
	shade = 1.0 + (COLOR.r - 0.5) * variation;
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * sway_speed;
	float gust = sin(t + wp.x * gust_scale + wp.z * gust_scale * 0.7) + 0.5 * sin(t * 2.3 + wp.z * gust_scale * 2.0);
	float bend = tip * tip * sway;
	VERTEX.x += gust * bend;
	VERTEX.z += 0.5 * gust * bend;
}

void fragment() {
	ALBEDO = mix(srgb(ground_grass.rgb), srgb(grass_tip.rgb), tip) * shade;
	// Light both faces like the ground (Godot flips NORMAL on back faces).
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	SPECULAR_COLOR = vec3(0.0);
	SPECULAR_STRENGTH = 0.0;
	FRESNEL_COLOR = vec3(0.0);
	FRESNEL_STRENGTH = 0.0;
}

void light() {
	DIFFUSE_LIGHT += diffuse_light(ALBEDO, LIGHT_COLOR, LIGHT, NORMAL, ATTENUATION);
}
