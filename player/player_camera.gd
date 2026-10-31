class_name PlayerCamera
extends Node3D
## Chase camera. This node is top_level, so it does not inherit the player's
## transform; it follows with damping instead. Children: SpringArm3D > Camera3D.
## The spring arm pulls the camera in when a wall gets between it and the rider.
## On transitions (Player.transition_normal) it stays upright, faces along
## the ramp instead of swinging with every carve, pulls back and moves out
## over the pipe so the curve reads.

@onready var player: Player = get_parent() as Player
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var _punch: float = 0.0
var _punch_tween: Tween
var _shake_strength: float = 0.0
var _shake_time: float = 0.0
var _shake_timer: float = 0.0
## 0..1, eases toward 1 while on (or just off) a transition.
var _transition_blend: float = 0.0
var _transition_normal: Vector3 = Vector3.ZERO
var _transition_hold_timer: float = 0.0


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

	# Transition mode holds for a moment after leaving the ramp, so crossing a
	# halfpipe's flat bottom between carves doesn't swing the camera around.
	if player.transition_normal != Vector3.ZERO:
		_transition_normal = player.transition_normal
		_transition_hold_timer = t.cam_transition_hold
	else:
		_transition_hold_timer = maxf(_transition_hold_timer - delta, 0.0)
	var on_transition: bool = _transition_hold_timer > 0.0
	_transition_blend = lerpf(_transition_blend, 1.0 if on_transition else 0.0, _damp_weight(t.cam_transition_blend_time, delta))

	# On a transition only the speed along the ramp counts for look-ahead and
	# yaw (the part across the ramp flips with every carve).
	var flat_velocity: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	var target_yaw: float = player.heading
	if _transition_normal != Vector3.ZERO and _transition_blend > 0.01:
		var along: Vector3 = flat_velocity - _transition_normal * flat_velocity.dot(_transition_normal)
		flat_velocity = flat_velocity.lerp(along, _transition_blend)
		if on_transition:
			target_yaw = atan2(-along.x, -along.z) if along.length() > 1.0 else rotation.y

	# Position: follow the interpolated body, plus a look-ahead along velocity,
	# plus the transition inset out over the pipe.
	var look_ahead: Vector3 = flat_velocity.normalized() * t.cam_look_ahead * speed_ratio if flat_velocity.length() > 0.1 else Vector3.ZERO
	var inset: Vector3 = _transition_normal * t.cam_transition_inset * _transition_blend
	var target_position: Vector3 = player.get_global_transform_interpolated().origin + look_ahead + inset
	global_position = global_position.lerp(target_position, _damp_weight(t.cam_position_damping, delta))

	# Rotation: swing behind the heading (or along the ramp). Yaw only, so the
	# camera never rolls with the rider.
	var yaw: float = lerp_angle(rotation.y, target_yaw, _damp_weight(t.cam_rotation_damping, delta))
	rotation = Vector3(0.0, yaw, 0.0)
	spring_arm.position = Vector3(0.0, t.cam_height + t.cam_transition_height * _transition_blend, 0.0)
	spring_arm.spring_length = t.cam_distance + t.cam_transition_distance * _transition_blend

	# FOV widens with speed. fov_smoothing is roughly the time to get there.
	var target_fov: float = lerpf(t.fov_base, t.fov_max, ease(speed_ratio, 0.6))
	camera.fov = lerpf(camera.fov, target_fov, _damp_weight(t.fov_smoothing / 3.0, delta))

	# Landing punch: shove the camera forward and down, ease back out.
	# The spring arm places its child at z = hit length, so offset from there.
	camera.position = Vector3(0.0, -_punch * 0.5, spring_arm.get_hit_length() - _punch)

	# Shake: random offset that fades out linearly over the shake time.
	if _shake_timer > 0.0:
		_shake_timer = maxf(_shake_timer - delta, 0.0)
		var amount: float = _shake_strength * _shake_timer / _shake_time
		camera.position += Vector3(randf_range(-amount, amount), randf_range(-amount, amount), 0.0)


## Frame-rate independent smoothing. `time_constant` in seconds; smaller = snappier.
func _damp_weight(time_constant: float, delta: float) -> float:
	return 1.0 - exp(-delta / maxf(time_constant, 0.0001))


func shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_time = maxf(duration, 0.0001)
	_shake_timer = _shake_time


func punch() -> void:
	var t: PlayerTuning = player.tuning
	if _punch_tween:
		_punch_tween.kill()
	_punch = t.cam_punch_distance
	_punch_tween = create_tween()
	_punch_tween.set_ignore_time_scale(true)
	_punch_tween.tween_property(self, "_punch", 0.0, t.cam_punch_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
