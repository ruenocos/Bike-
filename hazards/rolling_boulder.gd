@tool
class_name RollingBoulder
extends Node3D
## A boulder that rolls across the slope from where this node sits to
## `roll_to` (relative to it) once the rider comes within trigger_distance.
## It sits at the start until then, so you can see it coming. Hitting it at
## speed is a crash (it's in group "obstacles"). The End marker shows where
## it stops (it follows roll_to in the editor); it hugs the ground on the way.

@export_range(10.0, 500.0, 5.0, "suffix:m") var trigger_distance: float = 150.0
## Time to roll from Start to End.
@export_range(0.5, 20.0, 0.1, "suffix:s") var roll_time: float = 3.5
## Ball radius (match the Body's mesh and shape).
@export_range(0.5, 10.0, 0.1, "suffix:m") var radius: float = 2.2
## Where it rolls to, from this node (m). Downhill is -Z.
@export var roll_to: Vector3 = Vector3(60.0, 0.0, -10.0):
	set(v):
		roll_to = v
		if is_node_ready():
			end_marker.position = roll_to

@onready var body: AnimatableBody3D = $Body
@onready var end_marker: Marker3D = $End

var rolling: bool = false
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	end_marker.position = roll_to
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	body.global_position = _ground_point(global_position)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if not rolling:
		var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
		if player == null:
			return
		var middle: Vector3 = global_position + global_basis * (roll_to * 0.5)
		var flat: Vector2 = Vector2(player.global_position.x - middle.x, player.global_position.z - middle.z)
		if flat.length() < trigger_distance:
			rolling = true
		return
	_t = minf(_t + delta / roll_time, 1.0)
	var from: Vector3 = body.global_position
	var to: Vector3 = _ground_point(global_position + global_basis * (roll_to * _t))
	body.global_position = to
	var moved: Vector3 = to - from
	var axis: Vector3 = Vector3.UP.cross(moved)
	if axis.length() > 0.0001:
		body.global_rotate(axis.normalized(), moved.length() / radius)
	if _t >= 1.0:
		_done = true


## `at` dropped onto the ground (its own body excluded), lifted by the radius.
func _ground_point(at: Vector3) -> Vector3:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0)
	query.exclude = [body.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return at
	return (hit["position"] as Vector3) + Vector3.UP * radius
