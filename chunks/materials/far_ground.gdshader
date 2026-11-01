shader_type spatial;
// Bike! far ground: the big plane deep under the valley. Unshaded, and it
// fades to the biome's fog colour with distance so its edge never reads as
// a band on the horizon (BiomeLook sets both colours).
render_mode unshaded, fog_disabled;

uniform vec3 base_color : source_color = vec3(0.46, 0.41, 0.33);
uniform vec3 fade_color : source_color = vec3(0.93, 0.72, 0.56);
uniform float fade_from = 300.0;
uniform float fade_to = 1500.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = length(world_pos - CAMERA_POSITION_WORLD);
	ALBEDO = mix(base_color, fade_color, smoothstep(fade_from, fade_to, d));
}
