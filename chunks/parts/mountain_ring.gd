@tool
class_name MountainRing
extends Node3D
## Distant mountain silhouettes: a ring of low-poly peaks around this node
## (game.tscn puts it under FarGround, which follows the rider, so they stay
## on the horizon). Greybox mood, not final art: change the count, sizes,
## seed and colours in the inspector and the ring rebuilds in the editor.
## The peaks ignore the fog and fade toward `haze_color` at the base, so they
## read as far away instead of disappearing into the fog.

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
## Base radius as a multiple of the height.
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

var _instance: MultiMeshInstance3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _instance == null:
		_instance = MultiMeshInstance3D.new()
		_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_instance, false, Node.INTERNAL_MODE_BACK)
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = preload("res://chunks/materials/mountain.gdshader")
	mat.set_shader_parameter(&"peak_color", peak_color)
	mat.set_shader_parameter(&"haze_color", haze_color)
	cone.material = mat
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = count
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = ring_seed
	for i: int in count:
		var angle: float = TAU * (i + rng.randf_range(-0.35, 0.35)) / count
		var r: float = rng.randf_range(radius_min, radius_max)
		var h: float = rng.randf_range(height_min, height_max)
		var w: float = h * spread * rng.randf_range(0.7, 1.3)
		var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, h, w * rng.randf_range(0.7, 1.2)))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(cos(angle) * r, h * 0.5 - 60.0, sin(angle) * r)))
	_instance.multimesh = mm
