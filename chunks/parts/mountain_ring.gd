@tool
class_name MountainRing
extends Node3D
## Distant mountain range: an open cylinder band around this node whose top
## edge is cut into sharp, cel-lit anime peaks (chunks/materials/
## mountain_ridge.gdshader). The game keeps it centred on the rider, so the
## range stays on the horizon. Change the count, sizes, seed and colours in
## the inspector and it rebuilds in the editor. The peaks ignore the fog and
## fade toward `haze_color` at the base, so they melt into the sky.

@export_range(1, 200) var count: int = 46:
	set(v):
		count = v
		_rebuild()
@export_range(100.0, 20000.0, 10.0, "suffix:m") var radius_min: float = 2800.0:
	set(v):
		radius_min = v
		_rebuild()
@export_range(100.0, 20000.0, 10.0, "suffix:m") var radius_max: float = 4000.0:
	set(v):
		radius_max = v
		_rebuild()
@export_range(10.0, 5000.0, 10.0, "suffix:m") var height_min: float = 320.0:
	set(v):
		height_min = v
		_rebuild()
@export_range(10.0, 5000.0, 10.0, "suffix:m") var height_max: float = 900.0:
	set(v):
		height_max = v
		_rebuild()
## Peak width as a multiple of the height (bigger = broader, gentler).
@export_range(0.3, 4.0, 0.05) var spread: float = 1.4:
	set(v):
		spread = v
		_rebuild()
@export var ring_seed: int = 5:
	set(v):
		ring_seed = v
		_rebuild()
@export var peak_color: Color = Color(0.36, 0.38, 0.52):
	set(v):
		peak_color = v
		_rebuild()
@export var haze_color: Color = Color(0.86, 0.66, 0.56):
	set(v):
		haze_color = v
		_rebuild()

@export var lit_color: Color = Color(0.95, 0.75, 0.6):
	set(v):
		lit_color = v
		_update_material()
@export var rim_color: Color = Color(1.0, 0.88, 0.7):
	set(v):
		rim_color = v
		_update_material()
@export var snow_color: Color = Color(0.95, 0.95, 1.0):
	set(v):
		snow_color = v
		_update_material()
## Snow above this share of the range height (1 = no snow).
@export_range(0.0, 1.0, 0.01) var snow_line: float = 1.0:
	set(v):
		snow_line = v
		_update_material()
## Towards the sun (BiomeLook sets it from the scene's sun).
@export var sun_direction: Vector3 = Vector3(0.4, 0.3, -0.8):
	set(v):
		sun_direction = v
		_update_material()

## How much taller the band is than height_max.
@export_range(0.5, 4.0, 0.05) var band_height_scale: float = 1.6:
	set(v):
		band_height_scale = v
		_rebuild()

var _instance: MeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _instance == null:
		_instance = MeshInstance3D.new()
		_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_instance, false, Node.INTERNAL_MODE_BACK)
		_material = ShaderMaterial.new()
		_material.shader = preload("res://chunks/materials/mountain_ridge.gdshader")
		var band: CylinderMesh = CylinderMesh.new()
		band.top_radius = 1.0
		band.bottom_radius = 1.0
		band.height = 1.0
		band.radial_segments = 256
		band.rings = 1
		band.cap_top = false
		band.cap_bottom = false
		band.material = _material
		_instance.mesh = band
		# Never culled: the band surrounds the camera.
		_instance.extra_cull_margin = 16384.0
	var r: float = (radius_min + radius_max) * 0.5
	# The band is taller than the old cones: its peaks stand above the
	# haze, which covers the lower part.
	var h: float = height_max * band_height_scale
	_instance.scale = Vector3(r, h, r)
	_instance.position = Vector3(0.0, h * 0.5 - 60.0, 0.0)
	_update_material()


func _update_material() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"peak_color", peak_color)
	_material.set_shader_parameter(&"haze_color", haze_color)
	_material.set_shader_parameter(&"lit_color", lit_color)
	_material.set_shader_parameter(&"rim_color", rim_color)
	_material.set_shader_parameter(&"snow_color", snow_color)
	_material.set_shader_parameter(&"snow_line", snow_line)
	_material.set_shader_parameter(&"sun_direction", sun_direction)
	# `count` was the number of cones; a range reads better with fewer,
	# bigger peaks, each with its own shoulders.
	_material.set_shader_parameter(&"peaks", maxf(roundf(count / 3.0), 3.0))
	_material.set_shader_parameter(&"height_min", height_min / maxf(height_max, 1.0))
	_material.set_shader_parameter(&"height_max", 1.0)
	_material.set_shader_parameter(&"steepness", 11.0 / spread)
	_material.set_shader_parameter(&"ring_seed", float(ring_seed))
