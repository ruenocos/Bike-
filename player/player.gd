class_name Player
extends CharacterBody3D
## The rider. Holds shared data and movement helpers. The scripts in
## player/states/ decide what happens each physics tick (Ride, Air, Land,
## Grind, Bail). Children: TrickRunner plays tricks, ComboTracker scores.
##
## Godot note: the body itself never rotates. Direction lives in `heading`
## (yaw in radians) and only the Visual child is tilted to match the ground.
## That keeps the capsule collider simple and the math readable.

@export var tuning: PlayerTuning = preload("res://player/player_tuning.tres")

@onready var visual: Node3D = $Visual
@onready var ground_probe: ShapeCast3D = $GroundProbe
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var camera_rig: PlayerCamera = $CameraRig
@onready var tricks: TrickRunner = $TrickRunner
@onready var combo: ComboTracker = $ComboTracker

## Forward speed along the ground (m/s). The heart of the game.
var speed: float = 0.0
## Yaw in radians. 0 faces -Z (Godot's forward).
var heading: float = 0.0
var ground_normal: Vector3 = Vector3.UP
## Pitch of the bike while airborne (radians, + is nose up). Visual only for now.
var air_pitch: float = 0.0

# Hop input: hold to charge, release to hop. The release is buffered so a
# release just before touchdown still hops on landing.
var hop_charge: float = 0.0
var hop_release_charge: float = 0.0
var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0

# Grind input: a press is buffered briefly; after leaving a rail there is a
# short cooldown so riding off its end doesn't snap straight back on.
var grind_buffer_timer: float = 0.0
var grind_cooldown_timer: float = 0.0

# Pump tracking.
var _prev_lean: float = 0.0
var _pump_cooldown_timer: float = 0.0
var _slope_trend: float = 0.0
var pump_count: int = 0

# Landing info, read by the debug overlay.
var last_landing_angle: float = 0.0
var last_landing_grade: StringName = &"-"
var last_bail_reason: String = "-"
## Counts down after a bail; while > 0 a landing that would bail is sketchy instead.
var bail_immunity_timer: float = 0.0

var _visual_up: Vector3 = Vector3.UP
## Smoothed orientation of the Visual without the trick spin on top.
var _visual_rotation: Quaternion = Quaternion.IDENTITY
var _spawn_position: Vector3 = Vector3.ZERO
var _spawn_heading: float = 0.0


func _ready() -> void:
	# Rotate the Player node in the editor to choose the start direction.
	heading = rotation.y
	rotation = Vector3.ZERO
	_spawn_position = global_position
	_spawn_heading = heading
	speed = tuning.base_speed
	velocity = get_heading_dir() * speed
	_visual_rotation = Quaternion(visual.global_basis.orthonormalized())
	tricks.setup(self)
	combo.setup(self)
	# Signal up from the TrickRunner, call down into the ComboTracker.
	tricks.trick_completed.connect(_on_trick_completed)
	state_machine.setup(self)


func _physics_process(delta: float) -> void:
	_update_hop_input(delta)
	_update_grind_input(delta)
	bail_immunity_timer = maxf(bail_immunity_timer - delta, 0.0)
	tricks.poll_gesture(delta)
	state_machine.physics_update(delta)
	if global_position.y < -40.0 or Input.is_action_just_pressed(&"debug_reset"):
		respawn()


# --- Input ------------------------------------------------------------------

func get_steer() -> float:
	return Input.get_axis(&"steer_left", &"steer_right")


## +1 = leaning forward (stick up), -1 = leaning back (stick down).
func get_lean() -> float:
	return Input.get_axis(&"lean_back", &"lean_forward")


func _update_hop_input(delta: float) -> void:
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	if Input.is_action_just_pressed(&"hop"):
		hop_charge = 0.0
	if Input.is_action_pressed(&"hop"):
		hop_charge = minf(hop_charge + delta, tuning.hop_full_charge)
	if Input.is_action_just_released(&"hop"):
		hop_release_charge = hop_charge / tuning.hop_full_charge
		hop_charge = 0.0
		jump_buffer_timer = tuning.jump_buffer


func has_buffered_hop() -> bool:
	return jump_buffer_timer > 0.0


## Launches the hop. Call from a state, then switch to Air.
func do_hop() -> void:
	do_hop_from(get_ground_forward(ground_normal) * speed)


## Hop on top of a given velocity (the Grind state passes the rail velocity).
func do_hop_from(base_velocity: Vector3) -> void:
	var hop_velocity: float = lerpf(tuning.hop_min_velocity, tuning.hop_max_velocity, hop_release_charge)
	velocity = base_velocity + Vector3.UP * hop_velocity
	jump_buffer_timer = 0.0
	coyote_timer = 0.0


func _update_grind_input(delta: float) -> void:
	grind_buffer_timer = maxf(grind_buffer_timer - delta, 0.0)
	grind_cooldown_timer = maxf(grind_cooldown_timer - delta, 0.0)
	if Input.is_action_just_pressed(&"grind"):
		grind_buffer_timer = tuning.grind_buffer


## Rail to snap onto right now, or null. Ride and Air call this each tick
## and switch to Grind when it returns a rail.
func find_grind_rail() -> RailSnap:
	if grind_buffer_timer <= 0.0 or grind_cooldown_timer > 0.0 or tricks.is_mid_trick():
		return null
	var snap: RailSnap = RailSnap.find_closest(get_tree(), global_position, tuning.rail_snap_radius)
	if snap != null:
		grind_buffer_timer = 0.0
	return snap


func _on_trick_completed(trick: TrickData) -> void:
	combo.add_action(trick.score)
	Events.trick_completed.emit(trick.display_name, trick.score)


# --- Directions ---------------------------------------------------------------

func get_heading_dir() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


## Heading projected onto the ground plane, so it points down or up the slope.
func get_ground_forward(normal: Vector3) -> Vector3:
	var dir: Vector3 = get_heading_dir()
	var projected: Vector3 = dir - normal * dir.dot(normal)
	if projected.length_squared() < 0.0001:
		return dir
	return projected.normalized()


func update_ground_normal() -> void:
	if is_on_floor():
		ground_normal = get_floor_normal()
	elif ground_probe.is_colliding():
		ground_normal = ground_probe.get_collision_normal(0)
	else:
		ground_normal = Vector3.UP


# --- Movement -----------------------------------------------------------------

## One tick of riding on the ground. Shared by Ride, Land and Bail.
## With input disabled the bike just rolls and follows gravity.
func ground_move(delta: float, input_enabled: bool) -> void:
	var t: PlayerTuning = tuning
	update_ground_normal()

	var steer: float = get_steer() if input_enabled else 0.0
	var speed_ratio: float = clampf(speed / t.max_speed, 0.0, 1.0)
	var steer_rate: float = deg_to_rad(lerpf(t.steer_rate_low, t.steer_rate_high, speed_ratio))
	heading -= steer * steer_rate * delta

	var forward: Vector3 = get_ground_forward(ground_normal)
	# Gravity along the slope: forward.y < 0 means downhill, so speed grows.
	var accel: float = -t.gravity * forward.y
	if input_enabled:
		if speed < t.pedal_max_speed:
			accel += t.pedal_accel * Input.get_action_strength(&"pedal")
		accel -= t.brake_decel * Input.get_action_strength(&"brake")
	accel -= t.rolling_drag * speed + t.air_drag * speed * speed
	speed = clampf(speed + accel * delta, 0.0, t.max_speed)

	velocity = forward * speed - ground_normal * t.ground_stick_velocity
	move_and_slide()

	# Hitting a wall eats speed.
	if is_on_wall():
		speed = minf(speed, get_real_velocity().length())

	_slope_trend = lerpf(_slope_trend, forward.y, 1.0 - exp(-delta / 0.2))
	update_visual(delta, steer, 0.0, ground_normal)


## Pump: push the left stick forward on the back side of a bump.
## Only counts when the ground is getting steeper downhill, so a constant
## slope can't be farmed.
func try_pump(delta: float) -> void:
	_pump_cooldown_timer = maxf(_pump_cooldown_timer - delta, 0.0)
	var lean: float = get_lean()
	var pressed: bool = lean > 0.6 and _prev_lean <= 0.6
	_prev_lean = lean
	if not pressed or _pump_cooldown_timer > 0.0:
		return
	var forward: Vector3 = get_ground_forward(ground_normal)
	if forward.y < _slope_trend - sin(deg_to_rad(tuning.pump_min_slope_deg)):
		speed = minf(speed * (1.0 + tuning.pump_gain), tuning.max_speed)
		_pump_cooldown_timer = tuning.pump_cooldown
		pump_count += 1


# --- Feel -----------------------------------------------------------------------

## Tilts the Visual child to the ground, banks into turns, applies air pitch.
func update_visual(delta: float, steer: float, pitch: float, up_target: Vector3) -> void:
	# lerp, not slerp: slerp errors on float noise when both vectors are almost equal.
	_visual_up = _visual_up.lerp(up_target, 1.0 - exp(-delta / 0.06)).normalized()
	var forward: Vector3 = get_heading_dir()
	forward = (forward - _visual_up * forward.dot(_visual_up)).normalized()
	var back: Vector3 = -forward
	var target: Basis = Basis(_visual_up.cross(back), _visual_up, back).orthonormalized()
	# Roll into the turn (negative angle around the back axis banks right),
	# then pitch around the side axis (positive is nose up).
	target = target * Basis(Vector3.BACK, -steer * deg_to_rad(tuning.lean_into_turn_deg))
	target = target * Basis(Vector3.RIGHT, pitch)
	_visual_rotation = _visual_rotation.slerp(Quaternion(target), 1.0 - exp(-delta / 0.05))
	# The trick spin goes on top of the smoothed pose, unsmoothed, so a full
	# 360 doesn't get "shortest-path" blended back to zero.
	var base: Basis = Basis(_visual_rotation)
	var full: Basis = base * tricks.get_visual_offset()
	visual.global_basis = full
	# Spin around the rider's hips instead of the wheels: shift the Visual so
	# the pivot point stays where it would be without the trick.
	var pivot: Vector3 = Vector3.UP * tuning.trick_pivot_height
	visual.position = base * pivot - full * pivot


## Freezes the game for a few frames. Sells impact.
func hit_stop(duration: float) -> void:
	Engine.time_scale = 0.0
	# create_timer(time, process_always, process_in_physics, ignore_time_scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func respawn() -> void:
	global_position = _spawn_position
	heading = _spawn_heading
	speed = tuning.base_speed
	velocity = get_heading_dir() * speed
	air_pitch = 0.0
	bail_immunity_timer = 0.0
	tricks.cancel()
	combo.drop()
	state_machine.transition_to(&"Air", {})
