@tool
class_name BiomeLook
extends Node
## Puts a Biome's look on the world around the stage (game.tscn BiomeLook):
## ground palette (global shader parameters), sky, fog, sun, far ground,
## mountains and outline colour. The Game calls apply() every stage. In the
## editor, pick `preview` to see a biome in game.tscn without running. It
## changes the scene's sky / sun / fog values, so clear it (and undo, or
## pick Sunset Meadow) before saving if you want the old values kept.

@export var world_environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var far_ground: MeshInstance3D
@export var mountains: MountainRing
## A second, nearer ring (v0.29, ~1.5 km) for a middle depth plane: a
## little darker and less hazy than the far one.
@export var near_mountains: MountainRing
@export_range(0.0, 1.0, 0.01) var near_mountains_darken: float = 0.12
## Editor only: shows this biome in the scene.
@export var preview: Biome:
	set(v):
		preview = v
		if Engine.is_editor_hint() and v != null and is_inside_tree():
			apply(v)


func apply(b: Biome) -> void:
	RenderingServer.global_shader_parameter_set(&"ground_dirt", b.ground_dirt)
	RenderingServer.global_shader_parameter_set(&"ground_grass", b.ground_grass)
	RenderingServer.global_shader_parameter_set(&"ground_rock", b.ground_rock)
	RenderingServer.global_shader_parameter_set(&"grass_tip", b.grass_tip)
	RenderingServer.global_shader_parameter_set(&"outline_color", b.outline_color)
	RenderingServer.global_shader_parameter_set(&"shadow_tint", b.shadow_tint)
	RenderingServer.global_shader_parameter_set(&"shadow_tint_strength", b.shadow_tint_strength)
	RenderingServer.global_shader_parameter_set(&"ground_variation", b.ground_variation)
	if world_environment != null and world_environment.environment != null:
		var env: Environment = world_environment.environment
		if env.sky != null:
			var sky: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
			if sky != null:
				sky.sky_top_color = b.sky_top
				sky.sky_horizon_color = b.sky_horizon
				# The sky below the horizon = the fog, so nothing far reads
				# as a band against it.
				sky.ground_horizon_color = b.fog_color
				# The sky's whole lower half too: beyond the valley there's no
				# ground, and its old dark brown read as a flat band.
				sky.ground_bottom_color = b.fog_color.darkened(0.08)
		env.fog_light_color = b.fog_color
		env.fog_density = b.fog_density
		env.fog_height_density = b.height_fog_density
		_height_fog_below = b.height_fog_below
		env.ambient_light_energy = b.ambient_energy
		env.adjustment_saturation = b.saturation
		env.glow_intensity = b.glow_intensity
		env.glow_bloom = b.glow_bloom
		env.tonemap_exposure = b.exposure
	if sun != null:
		sun.light_color = b.sun_color
		sun.light_energy = b.sun_energy
		sun.rotation = Vector3(deg_to_rad(-b.sun_elevation), deg_to_rad(b.sun_heading), 0.0)
	if far_ground != null and far_ground.mesh != null:
		var far_mat: ShaderMaterial = far_ground.mesh.surface_get_material(0) as ShaderMaterial
		if far_mat != null:
			# Most of the way to the fog colour, so the plane far below melts
			# into the haze instead of reading as a flat table.
			var far: Color = b.far_ground.lerp(b.fog_color, 0.65)
			far_mat.set_shader_parameter(&"base_color", far)
			far_mat.set_shader_parameter(&"fade_color", b.fog_color)
	if mountains != null:
		mountains.peak_color = b.peak_color
		mountains.haze_color = b.haze_color
	if near_mountains != null:
		near_mountains.peak_color = b.peak_color.darkened(near_mountains_darken)
		near_mountains.haze_color = b.haze_color.lerp(b.peak_color, 0.25)


var _height_fog_below: float = 40.0


## The height fog follows whoever is looking (the rider, or the title
## camera), so it always starts the same distance below them.
func follow_height(y: float) -> void:
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.fog_height = y - _height_fog_below
