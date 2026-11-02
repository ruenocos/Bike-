class_name SpeedFeel
extends Node
## Sense of speed on screen (v0.31 "low and loud"), vehicle-agnostic.
## Sits under the vehicle's camera rig (Player > CameraRig > SpeedFeel) and
## only reads three things from `vehicle`: its speed ratio (get_speed_ratio(),
## else speed / tuning.max_speed, else velocity / fallback_max_speed), whether
## it is grounded (is_grounded(), optional) and its velocity.
##
## - Low chase framing: the camera rig asks low_blend / low_height_m() /
##   low_distance_m() / low_pitch_rad() and blends its framing toward them.
## - FOV kick: any speed gain kicks the FOV (fov_kick, degrees) and the blur.
##   Kicks come from detected surges, a perfect landing (Events.landed),
##   the vehicle's boost_flashed signal (if it has one) and Events.speed_gained.
## - Radial blur: the RadialBlur layer, converging on where you're heading.
##
## Sound hook: Events.speed_gained fires on every kick (strength 0..1), and
## speed_ratio is public; find this node in group "speed_feel".
## All numbers live in `tuning` (speed_feel.tres).

@export var tuning: SpeedFeelTuning = preload("res://vfx/speed_feel/speed_feel.tres")
## The vehicle this follows. Empty = the camera rig's parent.
@export var vehicle: Node3D
## How tall the vehicle is (m, ground to top of rider / turret). Framing scales
## with it, so a bigger vehicle gets a higher, further camera.
@export_range(0.5, 6.0, 0.05, "suffix:m") var vehicle_height: float = 1.7
## Used only when the vehicle has no speed ratio of its own.
@export var fallback_max_speed: float = 60.0
## Turn the whole effect off (A/B compare in the editor or from a debug key).
@export var enabled: bool = true

## 0..1 speed / max speed, smoothed a little.
var speed_ratio: float = 0.0
## 0..1 how far the framing is toward the low chase cam (air raise included).
var low_blend: float = 0.0
## Current FOV kick in degrees.
var fov_kick: float = 0.0
## 0..1 current kick envelope.
var kick_amount: float = 0.0

var _kick_peak: float = 0.0
var _prev_speed: float = 0.0
var _prev_position: Vector3 = Vector3.ZERO
var _gain: float = 0.0
var _surge_cooldown: float = 0.0
var _blur_center: Vector2 = Vector2(0.5, 0.45)
var _emitting: bool = false

@onready var _blur_layer: CanvasLayer = $RadialBlur
@onready var _blur_rect: ColorRect = $RadialBlur/Blur
@onready var _blur_material: ShaderMaterial = _blur_rect.material as ShaderMaterial


func _ready() -> void:
	add_to_group(&"speed_feel")
	if vehicle == null:
		vehicle = get_parent().get_parent() as Node3D
	if vehicle:
		_prev_position = vehicle.global_position
		if vehicle.has_signal(&"boost_flashed"):
			vehicle.connect(&"boost_flashed", func() -> void: kick(tuning.boost_kick))
	Events.landed.connect(_on_landed)
	Events.speed_gained.connect(_on_speed_gained)
	_blur_rect.visible = false


## Kick the FOV and the blur (0..1). Also tells listeners (sound) via Events.
func kick(strength: float) -> void:
	if not enabled or strength <= 0.0:
		return
	_kick_peak = clampf(maxf(_kick_peak, strength), 0.0, 1.0)
	_emitting = true
	Events.speed_gained.emit(strength)
	_emitting = false


func low_height_m() -> float:
	return tuning.low_height * vehicle_height


func low_distance_m() -> float:
	return tuning.low_distance * vehicle_height


func low_pitch_rad() -> float:
	return deg_to_rad(tuning.low_pitch_deg)


func _on_landed(grade: StringName) -> void:
	if grade == &"perfect":
		kick(tuning.perfect_kick)


func _on_speed_gained(strength: float) -> void:
	if not _emitting:
		kick(strength)


func _physics_process(delta: float) -> void:
	if vehicle == null or delta <= 0.0:
		return
	var speed: float = _vehicle_speed()
	# A teleport (respawn, new stage) is not a surge.
	if vehicle.global_position.distance_to(_prev_position) > 20.0:
		_gain = 0.0
	else:
		_gain = _gain * exp(-delta / 0.08) + maxf(speed - _prev_speed, 0.0)
	_prev_speed = speed
	_prev_position = vehicle.global_position
	_surge_cooldown = maxf(_surge_cooldown - delta, 0.0)
	if _gain >= tuning.surge_threshold and _surge_cooldown <= 0.0:
		kick(clampf(_gain / tuning.surge_full, 0.0, 1.0))
		_gain = 0.0
		_surge_cooldown = 0.3


func _process(delta: float) -> void:
	if vehicle == null:
		return
	var t: SpeedFeelTuning = tuning
	speed_ratio = lerpf(speed_ratio, _vehicle_ratio(), _damp(0.1, delta))

	# Framing: low at speed, partly back up in the air.
	var low: float = smoothstep(t.low_from, maxf(t.low_full, t.low_from + 0.01), speed_ratio) if enabled else 0.0
	if not _vehicle_grounded():
		low *= 1.0 - t.air_raise
	low_blend = lerpf(low_blend, low, _damp(t.low_blend_time / 3.0, delta))

	# Kick envelope: the peak decays (release), the value chases it (attack).
	_kick_peak *= exp(-delta / maxf(t.kick_release / 3.0, 0.0001))
	kick_amount = lerpf(kick_amount, _kick_peak, _damp(t.kick_attack / 3.0, delta))
	fov_kick = t.fov_kick_deg * kick_amount if enabled else 0.0

	_update_blur(delta)


func _update_blur(delta: float) -> void:
	var t: SpeedFeelTuning = tuning
	var strength: float = 0.0
	if enabled:
		strength = t.blur_max * smoothstep(t.blur_from, 1.0, speed_ratio) + t.blur_kick * kick_amount
	_blur_rect.visible = strength > 0.01
	if not _blur_rect.visible:
		return
	# Converge on the point straight ahead along the velocity.
	var target: Vector2 = Vector2(0.5, 0.45)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var velocity: Vector3 = _vehicle_velocity()
	if camera and velocity.length() > 1.0:
		var ahead: Vector3 = camera.global_position + velocity.normalized() * 100.0
		if not camera.is_position_behind(ahead):
			var size: Vector2 = get_viewport().get_visible_rect().size
			target = camera.unproject_position(ahead) / size
	target = Vector2(clampf(target.x, 0.25, 0.75), clampf(target.y, 0.2, 0.7))
	_blur_center = _blur_center.lerp(target, _damp(t.blur_center_smoothing, delta))
	_blur_material.set_shader_parameter(&"strength", strength)
	_blur_material.set_shader_parameter(&"center", _blur_center)
	_blur_material.set_shader_parameter(&"blur_length", t.blur_length)
	_blur_material.set_shader_parameter(&"clear", t.blur_clear)
	_blur_material.set_shader_parameter(&"feather", t.blur_feather)
	_blur_material.set_shader_parameter(&"bottom_boost", t.blur_bottom_boost)


func _vehicle_speed() -> float:
	if &"speed" in vehicle:
		return float(vehicle.get(&"speed"))
	return _vehicle_velocity().length()


func _vehicle_ratio() -> float:
	if vehicle.has_method(&"get_speed_ratio"):
		return clampf(float(vehicle.call(&"get_speed_ratio")), 0.0, 1.0)
	return clampf(_vehicle_speed() / maxf(fallback_max_speed, 0.01), 0.0, 1.0)


func _vehicle_grounded() -> bool:
	if vehicle.has_method(&"is_grounded"):
		return bool(vehicle.call(&"is_grounded"))
	return true


func _vehicle_velocity() -> Vector3:
	if vehicle is CharacterBody3D:
		return (vehicle as CharacterBody3D).velocity
	if vehicle is RigidBody3D:
		return (vehicle as RigidBody3D).linear_velocity
	return Vector3.ZERO


func _damp(time_constant: float, delta: float) -> float:
	return 1.0 - exp(-delta / maxf(time_constant, 0.0001))
