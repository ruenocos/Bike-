@tool
class_name RiderRig
extends Node3D
## The rider and BMX (player/rider/rider_rig.tscn, child of Player/Visual).
## Low-poly primitives with the cel look. The body blends between RiderPose
## resources (poses/*.tres) picked from the player's state; legs and arms are
## solved each frame to reach the pedals and grips, so the cranks can turn
## and the bars can steer. In the editor, `preview` shows a pose.

@export_group("Poses")
@export var pose_ride: RiderPose
@export var pose_tuck: RiderPose
@export var pose_pedal: RiderPose
@export var pose_air: RiderPose
@export var pose_trick: RiderPose
@export var pose_grind: RiderPose
@export var pose_bail: RiderPose
@export var pose_nohander: RiderPose
## Editor only: which pose to show.
@export_enum("ride", "tuck", "pedal", "air", "trick", "grind", "bail", "nohander") var preview: String = "ride"

@export_group("Feel")
## Time to blend into a new pose (s).
@export_range(0.01, 1.0, 0.01) var blend_time: float = 0.12
## Speed (fraction of max) where the rider starts to tuck; full tuck at max.
@export_range(0.0, 1.0, 0.01) var tuck_from: float = 0.7
## How far the bars turn at full steer (deg).
@export_range(0.0, 45.0, 0.5) var steer_bars_deg: float = 16.0
## Crank turns per second while pedalling.
@export_range(0.0, 5.0, 0.05) var pedal_cadence: float = 2.0
## Hips drop on landing (m); springs back.
@export_range(0.0, 0.5, 0.01) var land_dip: float = 0.2
## The whole rider squashes on landing (0.15 = 15% shorter, a bit wider),
## harder on a perfect one; springs back with the dip.
@export_range(0.0, 0.5, 0.01) var land_squash: float = 0.12
## Swing of the torso while bailing (deg).
@export_range(0.0, 90.0, 1.0) var bail_flail_deg: float = 30.0
@export var wheel_radius: float = 0.3

@export_group("Body")
@export var thigh: float = 0.44
@export var shin: float = 0.45
@export var upper_arm: float = 0.3
@export var forearm: float = 0.29
@export var torso_length: float = 0.5
@export var hip_width: float = 0.1
@export var shoulder_width: float = 0.19
## Inverted-hull outline on the rider and bike.
@export var outline: bool = true

var _pose: RiderPose
var _crank: float = 0.0
var _wheel_angle: float = 0.0
var _dip: float = 0.0
var _dip_speed: float = 0.0
var _squash: float = 0.0
var _bars: float = 0.0
var _flail: float = 0.0
var _last_state: StringName = &""
var _player: Player
## Reused for the ride / tuck blend (no new pose every frame).
var _blend: RiderPose = RiderPose.new()
## Per side (0 = left, 1 = right): thigh, shin, shoe, upper arm, forearm, hand.
var _limbs: Array[Array] = []

@onready var _bike: Node3D = $Bike
@onready var _fork: Node3D = $Bike/Fork
@onready var _grip_l: Node3D = $Bike/Fork/GripL
@onready var _grip_r: Node3D = $Bike/Fork/GripR
@onready var _cranks: Node3D = $Bike/Cranks
@onready var _pedal_l: Node3D = $Bike/Cranks/PedalL
@onready var _pedal_r: Node3D = $Bike/Cranks/PedalR
@onready var _front_wheel: Node3D = $Bike/Fork/FrontWheel
@onready var _rear_wheel: Node3D = $Bike/RearWheel
@onready var _torso: Node3D = $Bike/Torso
@onready var _head: Node3D = $Bike/Torso/Head
@onready var _pelvis: Node3D = $Bike/Pelvis


func _ready() -> void:
	for tag: String in ["L", "R"]:
		var parts: Array[Node3D] = []
		for part: String in ["Thigh", "Shin", "Shoe", "UpperArm", "Forearm", "Hand"]:
			parts.append(get_node("Bike/" + part + tag) as Node3D)
		_limbs.append(parts)
	_pose = _pick(preview).duplicate() if _pick(preview) != null else RiderPose.new()
	if not Engine.is_editor_hint():
		CelLook.apply(self, outline)
		_add_rim(self)
		var parent: Node = get_parent()
		while parent != null and not parent is Player:
			parent = parent.get_parent()
		_player = parent as Player
	_solve()


func _process(delta: float) -> void:
	var target: RiderPose
	if Engine.is_editor_hint() or _player == null:
		target = _pick(preview)
		_pedal_and_wheels(delta, preview == "pedal", 0.0, true)
	else:
		target = _drive(delta)
	if target == null:
		return
	_pose.approach(target, 1.0 - exp(-delta / blend_time))
	# Landing dip: a damped spring back to 0.
	_dip_speed += (-_dip * 160.0 - _dip_speed * 18.0) * delta
	_dip += _dip_speed * delta
	_squash = lerpf(_squash, 0.0, 1.0 - exp(-delta / 0.09))
	_solve()


## Picks the pose for what the player is doing and moves the bike parts.
func _drive(delta: float) -> RiderPose:
	var state: StringName = _player.state_machine.get_state_name()
	if state != _last_state:
		if state == &"Land":
			_dip_speed = -land_dip * 14.0
			_squash = land_squash * (1.4 if _player.last_landing_grade == &"perfect" else 1.0)
		_last_state = state
	var speed01: float = clampf(_player.speed / _player.tuning.max_speed, 0.0, 1.0)
	var pedal: bool = Input.get_action_strength(&"pedal") > 0.1 and state == &"Ride"
	var grounded: bool = state == &"Ride" or state == &"Land" or state == &"Bail"
	_bars = lerpf(_bars, (_player.get_steer() if grounded else 0.0) * steer_bars_deg, 1.0 - exp(-delta / 0.08))
	_fork.rotation.y = deg_to_rad(-_bars)
	_pedal_and_wheels(delta, pedal, _player.speed, grounded)
	_flail = _flail + delta * 14.0 if state == &"Bail" else 0.0
	match state:
		&"Bail":
			return pose_bail
		&"Grind":
			return pose_grind
		&"Air":
			if _player.no_hander and pose_nohander != null:
				return pose_nohander
			if _player.tricks.is_mid_trick():
				var own: RiderPose = _player.tricks.current.pose
				return own if own != null else pose_trick
			return pose_air
	if pedal:
		return pose_pedal
	var tuck: float = clampf((speed01 - tuck_from) / maxf(1.0 - tuck_from, 0.01), 0.0, 1.0)
	if tuck <= 0.0:
		return pose_ride
	_blend.set_blend(pose_ride, pose_tuck, tuck)
	return _blend


func _pedal_and_wheels(delta: float, pedal: bool, speed: float, grounded: bool) -> void:
	if pedal:
		_crank += pedal_cadence * TAU * delta
	else:
		# Coast with the cranks level (front foot forward).
		var level: float = roundf(_crank / PI) * PI
		_crank = lerpf(_crank, level, 1.0 - exp(-delta / 0.15))
	_cranks.rotation.x = -_crank
	if grounded:
		_wheel_angle -= speed / wheel_radius * delta
	else:
		_wheel_angle -= 6.0 * delta
	_wheel_angle = fmod(_wheel_angle, TAU)
	_front_wheel.rotation.x = _wheel_angle
	_rear_wheel.rotation.x = _wheel_angle


func _pick(pose_name: String) -> RiderPose:
	match pose_name:
		"tuck": return pose_tuck
		"pedal": return pose_pedal
		"air": return pose_air
		"trick": return pose_trick
		"grind": return pose_grind
		"bail": return pose_bail
		"nohander": return pose_nohander
	return pose_ride


## Places the torso, head, arms and legs for the current pose.
func _solve() -> void:
	if _bike == null or _pose == null or _limbs.size() < 2:
		return
	_bike.rotation.x = deg_to_rad(_pose.bike_pitch_deg)
	# Landing squash: the body only (hips sink, torso squashes); the bike,
	# wheels and limbs keep their shape (limbs follow the hips by IK).
	var hips: Vector3 = _pose.hips + Vector3(0.0, minf(_dip, 0.05) - _squash * 0.6, 0.0)
	var pitch: float = deg_to_rad(_pose.torso_pitch_deg + sin(_flail) * bail_flail_deg * signf(_flail))
	var torso_basis: Basis = Basis(Vector3.RIGHT, -pitch)
	_torso.transform = Transform3D(torso_basis.scaled_local(Vector3(1.0 + _squash * 0.4, 1.0 - _squash, 1.0 + _squash * 0.4)), hips)
	_head.rotation.x = deg_to_rad(-_pose.head_pitch_deg)
	_pelvis.position = hips
	var to_bike: Transform3D = _bike.global_transform.affine_inverse()
	var up: Vector3 = torso_basis.y
	var shoulders: Vector3 = hips + up * (torso_length - 0.05)
	# Legs: hip joint -> pedal.
	for side: int in [-1, 1]:
		var pedal: Node3D = _pedal_l if side < 0 else _pedal_r
		var foot_off: Vector3 = _pose.foot_left if side < 0 else _pose.foot_right
		var hip: Vector3 = hips + Vector3(side * hip_width, -0.04, 0.0)
		var foot: Vector3 = to_bike * pedal.global_position + Vector3(0.0, 0.07, 0.0) + foot_off
		var knee_pole: Vector3 = hip + Vector3(side * 0.15, -0.1, -1.0)
		var leg: PackedVector3Array = _ik(hip, foot, thigh, shin, knee_pole)
		var parts: Array = _limbs[0 if side < 0 else 1]
		_segment(parts[0], hip, leg[0])
		_segment(parts[1], leg[0], leg[1])
		(parts[2] as Node3D).position = leg[1] + Vector3(0.0, -0.03, -0.03)
		# Arms: shoulder -> grip.
		var grip: Node3D = _grip_l if side < 0 else _grip_r
		var hand_off: Vector3 = _pose.hand_left if side < 0 else _pose.hand_right
		var shoulder: Vector3 = shoulders + torso_basis.x * (side * shoulder_width)
		var hand: Vector3 = to_bike * grip.global_position + hand_off
		var elbow_pole: Vector3 = shoulder + Vector3(side * 0.6, -0.3, 0.5)
		var arm: PackedVector3Array = _ik(shoulder, hand, upper_arm, forearm, elbow_pole)
		_segment(parts[3], shoulder, arm[0])
		_segment(parts[4], arm[0], arm[1])
		(parts[5] as Node3D).position = arm[1]


## A warm rim on the rider and bike (v0.25) so they stand out from the
## ground: a stronger fresnel on their own cel materials.
@export var rim_color: Color = Color(1.0, 0.86, 0.62, 0.45)


func _add_rim(node: Node) -> void:
	var mi: MeshInstance3D = node as MeshInstance3D
	if mi != null:
		for s: int in mi.mesh.get_surface_count():
			var mat: ShaderMaterial = mi.get_surface_override_material(s) as ShaderMaterial
			if mat != null:
				# CelLook's materials are shared (props can use the same
				# cache entry): the rider gets its own copy.
				mat = mat.duplicate() as ShaderMaterial
				mat.set_shader_parameter(&"fresnel", rim_color)
				mi.set_surface_override_material(s, mat)
	for child: Node in node.get_children():
		_add_rim(child)


## Paints the frame tubes (the bike's colour, v0.14).
func set_frame_color(color: Color) -> void:
	for tube: String in ["DownTube", "TopTube", "SeatTube", "HeadTube", "ChainStayL", "ChainStayR", "SeatStayL", "SeatStayR", "Fork/BladeL", "Fork/BladeR"]:
		var mi: MeshInstance3D = get_node_or_null("Bike/" + tube) as MeshInstance3D
		if mi == null:
			continue
		var mat: Material = mi.get_surface_override_material(0)
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter(&"color", color)


## Two-bone reach from `root` toward `target`: [joint, end]. The joint bends
## toward `pole`.
static func _ik(root: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> PackedVector3Array:
	var to: Vector3 = target - root
	var dir: Vector3 = to.normalized() if to.length_squared() > 0.000001 else Vector3.DOWN
	var d: float = clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.001)
	var along: float = (l1 * l1 + d * d - l2 * l2) / (2.0 * d)
	var h: float = sqrt(maxf(l1 * l1 - along * along, 0.0))
	var bend: Vector3 = pole - root
	bend -= dir * bend.dot(dir)
	if bend.length_squared() < 0.000001:
		bend = Vector3.FORWARD
	return PackedVector3Array([root + dir * along + bend.normalized() * h, root + dir * d])


## Stretches a Y-up mesh node (centred capsule / cylinder) between a and b.
static func _segment(node: Node3D, a: Vector3, b: Vector3) -> void:
	var y: Vector3 = (b - a).normalized()
	var x: Vector3 = y.cross(Vector3.FORWARD)
	if x.length_squared() < 0.0001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	node.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
