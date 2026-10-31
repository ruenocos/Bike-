@tool
class_name TightZone
extends Area3D
## Marks a tight section (slalom, narrow gap, canyon): while the rider is
## inside, the camera tucks in closer instead of pulling up and back for the
## open-valley view. Set `size` in the inspector (the box shows in the editor);
## rotate the node to lie along the slope.

@export var size: Vector3 = Vector3(130.0, 30.0, 100.0):
	set(v):
		size = v
		_update_shape()


func _ready() -> void:
	_update_shape()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _update_shape() -> void:
	var col: CollisionShape3D = get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if col == null:
		return
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	col.shape = box


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		(body as Player).tight_zones += 1


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		(body as Player).tight_zones = maxi((body as Player).tight_zones - 1, 0)
