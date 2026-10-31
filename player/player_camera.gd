class_name PlayerCamera
extends Node3D
## Chase camera. This node is top_level, so it does not inherit the player's
## transform; it follows with damping instead. Children: SpringArm3D > Camera3D.
## The spring arm pulls the camera in when a wall gets between it and the rider.
## On transitions (Player.transition_normal) it stays upright, faces along
## the ramp instead of swinging with every carve, pulls back and moves out
## over the pipe so the curve reads.
## Sense of speed: FOV widens, the camera drops lower and closer, and a
## smooth noise rumble fades in near max speed. The pitch follows the slope
## you ride (in the air: the ground under you), so it looks down the hill.

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
## Smoothed slope pitch (radians, + = looking down the hill).
var _slope_pitch: float = 0.0
var _slope_target: float = 0.0
## 0..1, eases toward 1 while on the ground (the speed rumble only shows there).
var _ground_blend: float = 0.0
## Godot note: FastNoiseLite gives smooth random values; sampling it along
## time makes a wobble that drifts instead of jittering frame to frame.
var _noise: FastNoiseLite = FastNoiseLite.new()
var _noise_time: float = 0.0


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
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0


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

	# Pitch down the slope (none in the halfpipe: it stays upright there).
	var grounded: bool = player.is_grounded()
	_update_slope_target(grounded)
	var slope_target: float = 0.0 if on_transition else _slope_target * t.cam_slope_follow
	_slope_pitch = lerpf(_slope_pitch, slope_target, _damp_weight(t.cam_slope_smoothing, delta))
	spring_arm.rotation = Vector3(-deg_to_rad(t.cam_pitch_deg) - _slope_pitch * (1.0 - _transition_blend), 0.0, 0.0)

	# Lower and closer at speed.
	var fast: float = smoothstep(t.cam_fast_from, 1.0, speed_ratio)
	spring_arm.position = Vector3(0.0, lerpf(t.cam_height, t.cam_height_fast, fast) + t.cam_transition_height * _transition_blend, 0.0)
	spring_arm.spring_length = lerpf(t.cam_distance, t.cam_distance_fast, fast) + t.cam_transition_distance * _transition_blend

	# FOV widens with speed. fov_smoothing is roughly the time to get there.
	var target_fov: float = lerpf(t.fov_base, t.fov_max, pow(speed_ratio, t.fov_speed_curve))
	camera.fov = lerpf(camera.fov, target_fov, _damp_weight(t.fov_smoothing / 3.0, delta))

	# Landing punch: shove the camera forward and down, ease back out.
	# The spring arm places its child at z = hit length, so offset from there.
	camera.position = Vector3(0.0, -_punch * 0.5, spring_arm.get_hit_length() - _punch)
	camera.rotation = Vector3.ZERO

	# Speed rumble: smooth noise, only on the ground, fading in near max speed.
	_ground_blend = lerpf(_ground_blend, 1.0 if grounded else 0.0, _damp_weight(0.1, delta))
	var rumble: float = clampf((speed_ratio - t.cam_speed_shake_from) / maxf(1.0 - t.cam_speed_shake_from, 0.0001), 0.0, 1.0) * _ground_blend
	if rumble > 0.0:
		_noise_time += delta * t.cam_speed_shake_frequency
		var nx: float = _noise.get_noise_2d(_noise_time, 0.0)
		var ny: float = _noise.get_noise_2d(0.0, _noise_time + 57.0)
		camera.position += Vector3(nx, ny, 0.0) * t.cam_speed_shake_amount * rumble
		var turn: float = deg_to_rad(t.cam_speed_shake_rotation_deg) * rumble
		camera.rotation = Vector3(ny * turn, nx * turn, 0.0)

	# Shake: random offset that fades out linearly over the shake time.
	if _shake_timer > 0.0:
		_shake_timer = maxf(_shake_timer - delta, 0.0)
		var amount: float = _shake_strength * _shake_timer / _shake_time
		camera.position += Vector3(randf_range(-amount, amount), randf_range(-amount, amount), 0.0)


## Slope pitch to aim for: the direction you ride on the ground, or in the
## air the slope of the ground under you along your heading (so a kicker
## over a steep hill keeps looking down the hill). Held when nothing is below.
func _update_slope_target(grounded: bool) -> void:
	var t: PlayerTuning = player.tuning
	var dir: Vector3 = Vector3.ZERO
	if grounded:
		dir = player.ground_dir
	else:
		var from: Vector3 = player.global_position + Vector3.UP * 0.5
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * t.cam_slope_probe_length)
		query.exclude = [player.get_rid()]
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return
		dir = player.tangent_dir(player.get_heading_dir(), hit["normal"])
	_slope_target = clampf(asin(clampf(-dir.y, -1.0, 1.0)), deg_to_rad(t.cam_slope_min_deg), deg_to_rad(t.cam_slope_max_deg))


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
