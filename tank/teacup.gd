class_name Teacup
extends Node3D
## A teacup on the hull (v0.32), visual only: it rattles on landings, flies off
## in a crash, and is back in place a moment later.

## Rattle height on a landing (m), and how long the bounce lasts.
@export_range(0.0, 1.0, 0.01, "suffix:m") var rattle: float = 0.12
@export_range(0.05, 1.0, 0.01, "suffix:s") var rattle_time: float = 0.25
## In a crash: launch speed (m/s), and how long until a fresh cup is there.
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var fly_speed: float = 9.0
@export_range(0.2, 10.0, 0.1, "suffix:s") var respawn_time: float = 2.5

var _home: Vector3
var _shake: float = 0.0
var _flying: bool = false
var _fly_velocity: Vector3 = Vector3.ZERO
var _fly_left: float = 0.0


func _ready() -> void:
	_home = position
	CelLook.apply(self, true)
	CelLook.keep_outline(self, 1.5)
	if get_viewport() != null:
		Events.landed.connect(_on_landed)
		Events.bailed.connect(_on_bailed)


func _process(delta: float) -> void:
	if _flying:
		_fly_velocity.y -= 18.0 * delta
		global_position += _fly_velocity * delta
		rotation += Vector3(11.0, 7.0, 5.0) * delta
		_fly_left -= delta
		if _fly_left <= 0.0:
			_flying = false
			top_level = false
			position = _home
			rotation = Vector3.ZERO
		return
	_shake = maxf(_shake - delta / rattle_time, 0.0)
	var bounce: float = absf(sin(_shake * 18.0)) * _shake * rattle
	position = _home + Vector3(0.0, bounce, 0.0)
	rotation.z = sin(_shake * 26.0) * _shake * 0.5


func _on_landed(grade: StringName) -> void:
	_shake = 1.4 if grade == &"perfect" else 1.0


func _on_bailed() -> void:
	if _flying:
		return
	_flying = true
	var at: Transform3D = global_transform
	var parent_body: Node3D = get_parent_node_3d()
	top_level = true
	global_transform = at
	_fly_velocity = parent_body.global_basis.y * fly_speed + parent_body.global_basis.z * fly_speed * 0.4
	_fly_left = respawn_time
