shader_type spatial;
// Greybox material: world-space grid so speed and distance read on screen.
// Minor lines every `cell` metres, accent lines every `cell * major_every`.

uniform vec3 base_color : source_color = vec3(0.56, 0.58, 0.62);
uniform vec3 line_color : source_color = vec3(0.36, 0.38, 0.42);
uniform vec3 major_color : source_color = vec3(0.95, 0.55, 0.2);
uniform float cell = 1.0;
uniform float major_every = 5.0;
uniform float line_width = 0.03;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

float grid_lines(vec2 p, float size, float width) {
	vec2 g = abs(fract(p / size - 0.5) - 0.5) * size;
	vec2 fw = fwidth(p);
	vec2 l = 1.0 - smoothstep(vec2(width) - fw, vec2(width) + fw, g);
	return max(l.x, l.y);
}

void fragment() {
	vec3 n = abs(normalize(world_normal));
	vec2 uv = world_pos.xy;
	if (n.y > max(n.x, n.z)) {
		uv = world_pos.xz;
	} else if (n.x > n.z) {
		uv = world_pos.zy;
	}
	float minor = grid_lines(uv, cell, line_width);
	float major = grid_lines(uv, cell * major_every, line_width * 1.8);
	vec3 c = mix(base_color, line_color, minor);
	c = mix(c, major_color, major);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
