@tool
class_name Abyss
extends Area3D
## A bottomless drop (v0.31 "drastic landscape": the World Tree's chasm,
## the cliffs' edges). Falling into the box respawns you at the Respawn
## marker (before the drop, facing down the hill) with the usual time cost,
## instead of the nearest ride line, which could put you back over the hole.
##
## Size the box with `size`; move the Respawn child to where you want riders
## to try again (its -Z is the direction they face, its +Y is up).

@export var size: Vector3 = Vector3(160.0, 30.0, 80.0):
	set(v):
		size = v
		_apply_size()


func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return
	monitorable = false
	body_entered.connect(_on_body_entered)


func _apply_size() -> void:
	var shape: CollisionShape3D = get_node_or_null(^"Shape") as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		(shape.shape as BoxShape3D).size = size


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null:
		return
	var marker: Node3D = get_node_or_null(^"Respawn") as Node3D
	player.respawn_hint = marker.global_transform if marker != null else null
	_fall.call_deferred(player)


func _fall(player: Player) -> void:
	if not is_instance_valid(player):
		return
	if player.auto_respawn:
		# Sandboxes and tests: straight back to the marker.
		var hint: Transform3D = player.respawn_hint if player.respawn_hint is Transform3D else player.global_transform
		player.place(hint.origin + hint.basis.y * 0.5, atan2(hint.basis.z.x, hint.basis.z.z), player.tuning.base_speed * 2.0)
		player.state_machine.transition_to(&"Air", {})
	else:
		player.fell.emit()
