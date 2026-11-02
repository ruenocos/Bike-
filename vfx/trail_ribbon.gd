class_name TrailRibbon
extends MeshInstance3D
## A camera-facing ribbon that follows `target` through world space and fades
## out behind it (trick trails, v0.30). Vertices are in world space (top
## level); the mesh is rebuilt every frame only while there is a trail.
## With `anchor` set, the trail travels with the anchor and only drifts back
## at `drift` m/s, so it curls around the anchor instead of stretching out
## 25 m behind it at speed.

## What it follows.
@export var target: Node3D
## What the trail travels with (none = stays where it was left in the world).
@export var anchor: Node3D
## Drift speed away from the anchor, along `drift_direction`.
@export_range(0.0, 60.0, 0.5, "suffix:m/s") var drift: float = 8.0
var drift_direction: Vector3 = Vector3.BACK
@export var emitting: bool = false
@export_range(0.05, 3.0, 0.05, "suffix:s") var lifetime: float = 0.5
@export_range(0.01, 3.0, 0.01, "suffix:m") var width: float = 0.45
@export var head_color: Color = Color(0.1, 0.95, 1.0, 0.95)
@export var tail_color: Color = Color(1.0, 0.15, 0.75, 0.0)

var _points: PackedVector3Array = PackedVector3Array()
var _ages: PackedFloat32Array = PackedFloat32Array()
var _mesh: ImmediateMesh = ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	layers = 2
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat


func _process(delta: float) -> void:
	var keep: int = 0
	for i: int in _ages.size():
		_ages[i] += delta
		if _ages[i] >= lifetime:
			keep = i + 1
	if keep > 0:
		_points = _points.slice(keep)
		_ages = _ages.slice(keep)
	var origin: Vector3 = anchor.global_position if anchor != null else Vector3.ZERO
	if anchor != null:
		var push: Vector3 = drift_direction * drift * delta
		for i: int in _points.size():
			_points[i] += push
	if emitting and target != null:
		_points.append(target.global_position - origin)
		_ages.append(0.0)
	_mesh.clear_surfaces()
	var camera: Camera3D = get_viewport().get_camera_3d()
	if _points.size() < 2 or camera == null:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in _points.size():
		var along: Vector3 = _points[mini(i + 1, _points.size() - 1)] - _points[maxi(i - 1, 0)]
		var at: Vector3 = _points[i] + origin
		var side: Vector3 = along.cross(camera.global_position - at).normalized()
		var fade: float = _ages[i] / lifetime
		_mesh.surface_set_color(head_color.lerp(tail_color, fade))
		_mesh.surface_add_vertex(at + side * width * 0.5 * (1.0 - fade * 0.7))
		_mesh.surface_add_vertex(at - side * width * 0.5 * (1.0 - fade * 0.7))
	_mesh.surface_end()
