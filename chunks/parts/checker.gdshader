shader_type spatial;
// Finish banner: checkerboard in UV space.

uniform vec3 color_a : source_color = vec3(0.95);
uniform vec3 color_b : source_color = vec3(0.08, 0.08, 0.1);
uniform vec2 squares = vec2(14.0, 2.0);

void fragment() {
	vec2 cell = floor(UV * squares);
	bool a = mod(cell.x + cell.y, 2.0) < 1.0;
	ALBEDO = a ? color_a : color_b;
	EMISSION = a ? color_a * 0.3 : vec3(0.0);
}
