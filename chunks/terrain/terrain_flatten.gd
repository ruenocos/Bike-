@tool
class_name TerrainFlatten
extends Node3D
## Makes a flat pad in the TerrainPatch it sits under: the ground inside
## `size` is pulled onto this node's own floor plane (its local XZ plane),
## easing back to the terrain over `blend`. Put kickers, rails and landings
## on one. Tilt the node (rotate around X) to match the slope: at -23 deg
## the pad runs downhill with the standard slope; 0 = level.
## Shows a translucent plate in the editor so you can see the pad.

## Pad size: x across, y along (the node's local X and Z).
@export var size: Vector2 = Vector2(20.0, 30.0):
	set(v):
		size = v
		_update_preview()
		_changed()
## Distance over which the pad eases back into the terrain around it.
@export_range(0.0, 50.0, 0.5, "suffix:m") var blend: float = 8.0:
	set(v):
		blend = v
		_changed()

var _preview: MeshInstance3D


func _ready() -> void:
	set_notify_local_transform(true)
	visibility_changed.connect(_changed)
	if Engine.is_editor_hint():
		_preview = MeshInstance3D.new()
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.6, 0.15, 0.25)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_preview.material_override = mat
		add_child(_preview, false, Node.INTERNAL_MODE_BACK)
		_update_preview()


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED or what == NOTIFICATION_EXIT_TREE:
		_changed()


func _update_preview() -> void:
	if _preview == null:
		return
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	_preview.mesh = plane
	_preview.position = Vector3(0.0, 0.05, 0.0)


func _changed() -> void:
	var patch: TerrainPatch = TerrainShape.find_patch(self)
	if patch != null:
		patch.queue_rebuild()
