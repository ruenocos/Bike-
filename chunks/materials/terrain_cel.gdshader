shader_type spatial;
// Bike! terrain: eldskald's cel lighting (vfx/cel/includes) on a flat earth
// colour with a faint world-space grid, so speed and distance still read.
// With use_ground_palette (terrain.tres) the colour comes from the global
// ground palette (Project Settings > Shader Globals: ground_dirt / grass /
// rock, set per biome): grass where the TerrainPatch's vertex colour says
// (GroundCover), rock on steep faces.

#include "res://vfx/cel/includes/base-cel-shader.gdshaderinc"

global uniform vec4 ground_dirt;
global uniform vec4 ground_grass;
global uniform vec4 ground_rock;
global uniform float ground_variation;
uniform bool use_ground_palette = false;
// Steepness (normal y) where faces turn to rock.
uniform float rock_from = 0.8;
uniform float rock_full = 0.68;
uniform vec3 base_color : source_color = vec3(0.64, 0.57, 0.43);
uniform vec3 line_color : source_color = vec3(0.6, 0.53, 0.4);
uniform float cell = 2.0;
uniform float major_every = 5.0;
uniform float line_width = 0.035;
uniform vec4 specular : source_color = vec4(0.2, 0.18, 0.15, 0.3);
uniform vec4 fresnel : source_color = vec4(0.35, 0.28, 0.2, 0.25);

varying vec3 world_pos;
varying vec3 world_normal;
// Global colours arrive as typed (sRGB); the shader works in linear.
vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

varying float grass;
varying vec3 SPECULAR_COLOR;
varying float SPECULAR_STRENGTH;
varying vec3 FRESNEL_COLOR;
varying float FRESNEL_STRENGTH;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	grass = COLOR.r;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise, 0..1.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float grid_lines(vec2 p, float size, float width) {
	vec2 g = abs(fract(p / size - 0.5) - 0.5) * size;
	vec2 fw = fwidth(p);
	vec2 l = 1.0 - smoothstep(vec2(width) - fw, vec2(width) + fw, g);
	return max(l.x, l.y);
}

void fragment() {
	vec3 n = abs(normalize(world_normal));
	vec2 uv = world_pos.xz;
	if (n.x > n.y && n.x > n.z) {
		uv = world_pos.zy;
	} else if (n.z > n.y) {
		uv = world_pos.xy;
	}
	if (use_ground_palette) {
		vec3 ground = mix(srgb(ground_dirt.rgb), srgb(ground_grass.rgb), grass);
		float rock = 1.0 - smoothstep(rock_full, rock_from, normalize(world_normal).y);
		ground = mix(ground, srgb(ground_rock.rgb), rock);
		// Big soft patches (and a finer layer) so flat colour shows its shape.
		float patches = value_noise(world_pos.xz * 0.035) * 0.65 + value_noise(world_pos.xz * 0.16) * 0.35;
		ALBEDO = ground * (1.0 + (patches - 0.5) * 2.0 * ground_variation);
	} else {
		float lines = max(grid_lines(uv, cell, line_width), grid_lines(uv, cell * major_every, line_width * 1.6));
		ALBEDO = mix(base_color, line_color, lines);
	}
	SPECULAR_COLOR = specular.rgb;
	SPECULAR_STRENGTH = specular.a;
	FRESNEL_COLOR = fresnel.rgb;
	FRESNEL_STRENGTH = fresnel.a;
}

void light() {
	DIFFUSE_LIGHT += diffuse_light(ALBEDO, LIGHT_COLOR, LIGHT, NORMAL, ATTENUATION);
	SPECULAR_LIGHT += specular_light(LIGHT_COLOR, SPECULAR_COLOR, SPECULAR_STRENGTH, NORMAL, VIEW, LIGHT, ATTENUATION);
	SPECULAR_LIGHT += fresnel_light(LIGHT_COLOR, FRESNEL_COLOR, FRESNEL_STRENGTH, NORMAL, VIEW, LIGHT, ATTENUATION);
}
