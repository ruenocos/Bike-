@tool
class_name PropModel
extends Node3D
## The look of a prop (tree, rock, log, fence): one of `variants` (picked
## from the prop's position, so the same spot always gets the same model),
## scaled, with the cel look. Collision stays on the prop's own simple
## shape; this node is visual only. The model is a generated child that
## isn't saved: change the variants / scale here and it updates.

## Model scenes to pick from (.gltf / .glb).
@export var variants: Array[PackedScene] = []:
	set(v):
		variants = v
		_rebuild()
## Scale applied to the model.
@export var model_scale: Vector3 = Vector3.ONE:
	set(v):
		model_scale = v
		_rebuild()
## Random extra rotation around up (deg, +/-), also picked from the position.
@export_range(0.0, 180.0, 1.0) var yaw_jitter: float = 180.0
## Draw the inverted-hull outline (costs a second pass; trees and rocks).
@export var outline: bool = true:
	set(v):
		outline = v
		_rebuild()

var _model: Node3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _model != null:
		_model.free()
		_model = null
	if variants.is_empty():
		return
	var spot: Vector3 = global_position
	var h: int = hash(Vector3i(roundi(spot.x * 10.0), roundi(spot.y * 10.0), roundi(spot.z * 10.0)))
	var scene: PackedScene = variants[absi(h) % variants.size()]
	if scene == null:
		return
	_model = scene.instantiate() as Node3D
	_model.scale = model_scale
	_model.rotation.y = deg_to_rad(float(posmod(h >> 3, 360) - 180) / 180.0 * yaw_jitter)
	add_child(_model, false, Node.INTERNAL_MODE_BACK)
	CelLook.apply(_model, outline)
