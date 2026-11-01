@tool
class_name FallingTree
extends Node3D
## A tree that comes down across your way (v0.13): it stands beside the
## valley floor and tips over toward its -Z once you're close enough that it
## lands about `reaction_time` before you get there. Lying down, the trunk is
## a low obstacle: hop it or ride round the root / crown end. It crashes you
## like any obstacle (group "obstacles"), also while it's falling.
## Placed by the HazardDirector at runtime (more of them in later stages).

## Seconds from the first creak to lying flat.
@export_range(0.2, 5.0, 0.05, "suffix:s") var fall_time: float = 1.1
## How long it has been down when you reach it at your current speed (s).
@export_range(0.0, 5.0, 0.05, "suffix:s") var reaction_time: float = 1.0
## Never later than this (m), whatever the speed.
@export_range(5.0, 500.0, 1.0, "suffix:m") var min_trigger_distance: float = 45.0
## Editor preview: 0 = standing, 1 = down.
@export_range(0.0, 1.0, 0.01) var preview_fall: float = 0.0:
	set(v):
		preview_fall = v
		if is_node_ready():
			_set_fall(v)

## Where the trunk crosses the rider's line (global; bots hop here).
var crossing: Vector3 = Vector3.ZERO
var falling: bool = false
var down: bool = false
var _t: float = 0.0

@onready var pivot: Node3D = $Pivot


func _ready() -> void:
	add_to_group(&"hop_hazards")
	_set_fall(preview_fall if Engine.is_editor_hint() else 0.0)
	if crossing == Vector3.ZERO:
		crossing = global_position - global_basis.z * 5.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or down:
		return
	if not falling:
		var player: Player = get_tree().get_first_node_in_group(&"player") as Player
		if player == null:
			return
		var to: Vector3 = crossing - player.global_position
		to.y = 0.0
		var heading: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
		# Only when it's ahead of you.
		if heading.length() < 1.0 or to.dot(heading) <= 0.0:
			return
		if to.length() < maxf(min_trigger_distance, player.speed * (fall_time + reaction_time)):
			falling = true
		return
	_t = minf(_t + delta / fall_time, 1.0)
	# Ease in: slow creak, then it drops.
	_set_fall(_t * _t * _t)
	if _t >= 1.0:
		down = true


func _set_fall(amount: float) -> void:
	pivot.rotation.x = -PI * 0.5 * amount
