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
## How stylised the whole game looks (v0.30): 1 = hard cel bands and ink
## lines, 0 = soft low-poly (smooth light, soft shadows and highlights, no
## ink except a thin line on the rider and on things you can hit, light
## SSAO). F5 cycles 1 / 0.5 / 0 while playing. Moving it here also previews
## in the editor (and changes the scene's sun / SSAO values, like `preview`).
@export_range(0.0, 1.0, 0.01) var stylize: float = 1.0:
	set(v):
		stylize = v
		if is_inside_tree():
			apply_stylize()
@export_group("Soft end of stylize (0)")
## Softness of the highlight and rim edges (the cel look uses 0.05).
@export_range(0.0, 1.0, 0.01) var soft_highlights: float = 0.6
## Sun shadow edge blur.
@export_range(0.0, 6.0, 0.1) var soft_shadow_blur: float = 2.5
## SSAO fades in as stylize goes down (0 = off). Cost: see CLAUDE.md.
@export_range(0.0, 4.0, 0.05) var soft_ssao_intensity: float = 0.8
@export_range(0.1, 4.0, 0.05) var soft_ssao_radius: float = 1.0
@export_group("")
## Editor only: shows this biome in the scene.
@export var preview: Biome:
	set(v):
		preview = v
		if Engine.is_editor_hint() and v != null and is_inside_tree():
			apply(v)


func apply(b: Biome) -> void:
	apply_stylize()
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


## Current value for the F3 readout.
static var current_stylize: float = 1.0
const CEL_CURVE: GradientTexture1D = preload("res://vfx/cel/diffuse_curve.tres")
var _base_shadow_blur: float = -1.0


## Puts `stylize` on the shader globals, sun and environment. At 1 everything
## is exactly the Project Settings look.
func apply_stylize() -> void:
	current_stylize = stylize
	RenderingServer.global_shader_parameter_set(&"diffuse_curve", _light_curve(stylize))
	RenderingServer.global_shader_parameter_set(&"outline_width", _project_global(&"outline_width", 2.0) * stylize)
	RenderingServer.global_shader_parameter_set(&"specular_smoothness", lerpf(soft_highlights, _project_global(&"specular_smoothness", 0.05), stylize))
	RenderingServer.global_shader_parameter_set(&"fresnel_smoothness", lerpf(soft_highlights, _project_global(&"fresnel_smoothness", 0.05), stylize))
	if sun != null:
		if _base_shadow_blur < 0.0:
			_base_shadow_blur = sun.shadow_blur
		sun.shadow_blur = lerpf(soft_shadow_blur, _base_shadow_blur, stylize)
	if world_environment != null and world_environment.environment != null:
		var env: Environment = world_environment.environment
		env.ssao_enabled = soft_ssao_intensity > 0.0 and stylize < 0.99
		env.ssao_intensity = soft_ssao_intensity * (1.0 - stylize)
		env.ssao_radius = soft_ssao_radius
		env.ssao_light_affect = 0.3


## The light ramp (input: light dot normal): the cel bands blended toward
## half-Lambert, so the shadow side stays filled and the bands melt away.
func _light_curve(s: float) -> Texture2D:
	if s >= 0.999:
		return CEL_CURVE
	var width: int = 128
	var image: Image = Image.create(width, 1, false, Image.FORMAT_RGB8)
	for i: int in width:
		var x: float = (float(i) + 0.5) / float(width)
		var half: float = (x + 1.0) * 0.5
		var v: float = lerpf(half * half, CEL_CURVE.gradient.sample(x).r, s)
		image.set_pixel(i, 0, Color(v, v, v))
	return ImageTexture.create_from_image(image)


func _project_global(global_name: StringName, fallback: float) -> float:
	var entry: Variant = ProjectSettings.get_setting("shader_globals/%s" % global_name)
	return float(entry["value"]) if entry is Dictionary else fallback
