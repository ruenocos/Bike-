class_name PlayerCamera
extends Node3D
## Chase camera. This node is top_level, so it does not inherit the player's
## transform; it follows with damping instead. Children: SpringArm3D > Camera3D.
## The spring arm pulls the camera in when a wall gets between it and the rider.

@onready var player: Player = get_parent() as Player
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var _punch: float = 0.0
var _punch_tween: Tween


func _ready() -> void:
	# We move this node ourselves in _process, so physics interpolation must not fight us.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var t: PlayerTuning = player.tuning
	spring_arm.add_excluded_object(player.get_rid())
	spring_arm.position = Vector3(0.0, t.cam_height, 0.0)
	spring_arm.rotation = Vector3(deg_to_rad(-t.cam_pitch_deg), 0.0, 0.0)
	spring_arm.spring_length = t.cam_distance
	camera.fov = t.fov_base
	global_position = player.global_position
	rotation = Vector3(0.0, player.heading, 0.0)


func _process(delta: float) -> void:
	var t: PlayerTuning = player.tuning
	var speed_ratio: float = clampf(player.speed / t.max_speed, 0.0, 1.0)

	# Position: follow the interpolated body, plus a look-ahead along velocity.
	var flat_velocity: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	var look_ahead: Vector3 = flat_velocity.normalized() * t.cam_look_ahead * speed_ratio if flat_velocity.length() > 0.1 else Vector3.ZERO
	var target_position: Vector3 = player.get_global_transform_interpolated().origin + look_ahead
	global_position = global_position.lerp(target_position, _damp_weight(t.cam_position_damping, delta))

	# Rotation: swing behind the heading.
	var yaw: float = lerp_angle(rotation.y, player.heading, _damp_weight(t.cam_rotation_damping, delta))
	rotation = Vector3(0.0, yaw, 0.0)

	# FOV widens with speed. fov_smoothing is roughly the time to get there.
	var target_fov: float = lerpf(t.fov_base, t.fov_max, ease(speed_ratio, 0.6))
	camera.fov = lerpf(camera.fov, target_fov, _damp_weight(t.fov_smoothing / 3.0, delta))

	# Landing punch: shove the camera forward and down, ease back out.
	# The spring arm places its child at z = hit length, so offset from there.
	camera.position = Vector3(0.0, -_punch * 0.5, spring_arm.get_hit_length() - _punch)


## Frame-rate independent smoothing. `time_constant` in seconds; smaller = snappier.
func _damp_weight(time_constant: float, delta: float) -> float:
	return 1.0 - exp(-delta / maxf(time_constant, 0.0001))


func punch() -> void:
	var t: PlayerTuning = player.tuning
	if _punch_tween:
		_punch_tween.kill()
	_punch = t.cam_punch_distance
	_punch_tween = create_tween()
	_punch_tween.set_ignore_time_scale(true)
	_punch_tween.tween_property(self, "_punch", 0.0, t.cam_punch_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
