@tool
class_name FallingTree
extends Node3D
## A tree that comes down across your way (v0.13): it stands beside the
## valley floor and tips over toward its -Z once you're close enough that it
## lands about `reaction_time` before you get there. Lying down, the trunk is
## a low obstacle: hop it or ride round the root / crown end. It crashes you
## like any obstacle (group "obstacles"), also while it's falling.
## Placed by the HazardDirector at runtime (more of them in later stages).

## Seconds from the first creak to lying flat (the warning shake included).
@export_range(0.2, 5.0, 0.05, "suffix:s") var fall_time: float = 1.1
## The first part of the fall it only shakes and leans a little (s), so you
## see which tree is going before it drops.
@export_range(0.0, 2.0, 0.05, "suffix:s") var warn_time: float = 0.45
## Shake size during the warning (deg).
@export_range(0.0, 20.0, 0.5) var warn_shake_deg: float = 4.0
## How long it has been down when you reach it at your current speed (s).
@export_range(0.0, 5.0, 0.05, "suffix:s") var reaction_time: float = 1.0
## Seen with less than fall_time + this left before you get there (s), it
## doesn't fall at all: it's already down (a log to hop).
@export_range(0.0, 2.0, 0.05, "suffix:s") var min_fall_margin: float = 0.3
## Never later than this (m), whatever the speed.
@export_range(5.0, 500.0, 1.0, "suffix:m") var min_trigger_distance: float = 45.0
## Editor preview: 0 = standing, 1 = down.
@export_range(0.0, 1.0, 0.01) var preview_fall: float = 0.0:
	set(v):
		preview_fall = v
		if is_node_ready():
			_set_fall(v)

## Length of the trunk lying down (m; matches the collision capsule).
@export_range(1.0, 30.0, 0.1, "suffix:m") var trunk_length: float = 10.0
## Where the trunk crosses the rider's line (global; bots hop here).
var crossing: Vector3 = Vector3.ZERO
var falling: bool = false
var down: bool = false
var _t: float = 0.0
var _warn: float = 0.0
var _player: Player
## Line-of-sight check (tests swap it before adding the tree).
var can_see: Callable

@onready var pivot: Node3D = $Pivot
@onready var dust: CPUParticles3D = $Dust
@onready var trunk: AnimatableBody3D = $Pivot/Trunk
@onready var hit_area: Area3D = $Pivot/HitArea


func _ready() -> void:
	add_to_group(&"hop_hazards")
	CelLook.keep_outline(self)
	if not can_see.is_valid():
		can_see = _can_see
	_set_fall(preview_fall if Engine.is_editor_hint() else 0.0)
	if crossing == Vector3.ZERO:
		crossing = global_position - global_basis.z * 5.0
	if not Engine.is_editor_hint():
		hit_area.body_entered.connect(_on_hit_area_body_entered)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or down:
		return
	if not falling:
		if _player == null:
			_player = get_tree().get_first_node_in_group(&"player") as Player
			if _player == null:
				return
		var to: Vector3 = crossing - _player.global_position
		to.y = 0.0
		var heading: Vector3 = Vector3(_player.velocity.x, 0.0, _player.velocity.z)
		# Only when it's ahead of you.
		if heading.length() < 1.0 or to.dot(heading) <= 0.0:
			return
		if to.length() < _player.speed * (fall_time + reaction_time) and can_see.call():
			# Seen in time to fall and land before you arrive? Else it's down.
			if to.length() / maxf(_player.speed, 1.0) > fall_time + min_fall_margin:
				falling = true
			else:
				_set_fall(1.0)
				down = true
		elif to.length() < min_trigger_distance:
			# Never in view in time (behind a crest): it's simply already
			# down, a log to hop, never a tree landing on you unseen.
			_set_fall(1.0)
			down = true
		return
	if _warn < warn_time:
		# The warning: a shake and a slight lean toward where it'll fall.
		_warn += delta
		var k: float = _warn / maxf(warn_time, 0.001)
		pivot.rotation.z = deg_to_rad(warn_shake_deg) * sin(_warn * 40.0) * (1.0 - k * 0.5)
		_set_fall(0.06 * k)
		return
	pivot.rotation.z = 0.0
	_t = minf(_t + delta / maxf(fall_time - warn_time, 0.05), 1.0)
	# Ease in: slow creak, then it drops.
	_set_fall(0.06 + 0.94 * _t * _t * _t)
	if _t >= 1.0:
		down = true
		dust.emitting = true


## Can the rider see the tree (no ground in between)? A tree behind a crest
## waits until it comes into view (or you're within min_trigger_distance).
func _can_see() -> bool:
	var eye: Vector3 = _player.global_position + Vector3.UP * 1.6
	var top: Vector3 = global_position + Vector3.UP * 5.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, top)
	query.exclude = [_player.get_rid(), trunk.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Node = hit["collider"] as Node
	return collider == null or not collider.get_parent() is TerrainPatch


## While it falls, the trunk landing on you is a crash at any speed (the
## player applies it on its next physics tick).
func _on_hit_area_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player != null and falling and not down:
		player.hit_by_hazard("A tree", trunk)


func _set_fall(amount: float) -> void:
	pivot.rotation.x = -PI * 0.5 * amount
