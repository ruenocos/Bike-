class_name Player
extends CharacterBody3D
## The rider. Holds shared data and movement helpers. The scripts in
## player/states/ decide what happens each physics tick (Ride, Air, Land,
## Grind, Bail). Children: TrickRunner plays tricks, ComboTracker scores.
##
## Godot note: the body itself never rotates; only the Visual child is tilted
## to match the ground. The collider is a sphere, so it touches any surface
## the same way, all the way up a vertical quarter-pipe face.
## On the ground, motion is a direction tangent to the surface (`ground_dir`)
## times `speed`. Steering turns it around the ground normal and gravity pulls
## it along the surface, so ramps slow you down and give the speed back.
## While grounded, CharacterBody3D.up_direction follows the ground normal, so
## floor detection and floor snapping keep working on curved walls.

@export var tuning: PlayerTuning = preload("res://player/player_tuning.tres")

@onready var visual: Node3D = $Visual
@onready var ground_probe: ShapeCast3D = $GroundProbe
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var camera_rig: PlayerCamera = $CameraRig
@onready var tricks: TrickRunner = $TrickRunner
@onready var combo: ComboTracker = $ComboTracker

## Speed along the ground (m/s). The heart of the game.
var speed: float = 0.0
## Unit direction of travel on the ground, tangent to the surface.
var ground_dir: Vector3 = Vector3.FORWARD
## Yaw in radians, derived from the velocity (camera and visuals). 0 faces -Z (Godot's forward).
var heading: float = 0.0
## Smoothed surface normal while grounded (also the body's up_direction then).
var ground_normal: Vector3 = Vector3.UP
## Horizontal normal of the transition you're riding or launched off (points
## into the pipe), or Vector3.ZERO. The camera reads it.
var transition_normal: Vector3 = Vector3.ZERO
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
## One transition pump per descent; re-armed when you go back up.
var _transition_pump_armed: bool = true
var pump_count: int = 0

# Lip tracking: the last spot where the face was steeper than lip_min_angle_deg.
# Leaving the ground soon after is a lip air. (The contact normal rolls over
# the edge for a tick or two at the top, so the latest normal alone isn't enough.)
var _lip_timer: float = 0.0
var _lip_normal: Vector3 = Vector3.ZERO
var _lip_position: Vector3 = Vector3.ZERO
## True while above carve_min_angle_deg on a transition.
var _carving: bool = false
## Ground normal before the current convex roll (cresting a bump, rolling over
## an edge). Rolling too far past it lets go of the ground (see ground_move).
var _convex_ref_normal: Vector3 = Vector3.UP
## Set by ground_move when an edge let go of the ground this tick.
var _ground_released: bool = false
## True while the floor falls away ahead of you (cresting, rolling over an edge).
var _on_convex: bool = false
## True when this tick's ground contact is a body in group "transitions".
## Only those count as transitions (camera mode, carving, transition pump);
## a steep drop-in or a berm wall on the track is just ground.
var _on_transition_body: bool = false

# Landing info, read by the debug overlay.
var last_landing_angle: float = 0.0
var last_landing_grade: StringName = &"-"
var last_bail_reason: String = "-"
## Counts down after a bail; while > 0 a landing that would bail is sketchy instead.
var bail_immunity_timer: float = 0.0

var _visual_up: Vector3 = Vector3.UP
## Smoothed orientation of the Visual without the trick spin on top.
var _visual_rotation: Quaternion = Quaternion.IDENTITY
## The sphere collider's radius, read from the scene.
var _body_radius: float = 0.35
var _spawn_position: Vector3 = Vector3.ZERO
var _spawn_heading: float = 0.0
## floor_snap_length from the scene. A hop turns snapping off until the next ground tick.
var _ground_snap_length: float = 0.0
## Rail lit up because it is within snap reach (see _update_rail_highlight).
var _highlighted_rail: Rail


func _ready() -> void:
	# Rotate the Player node in the editor to choose the start direction.
	heading = rotation.y
	rotation = Vector3.ZERO
	_spawn_position = global_position
	_spawn_heading = heading
	_ground_snap_length = floor_snap_length
	_body_radius = (($CollisionShape3D as CollisionShape3D).shape as SphereShape3D).radius
	speed = tuning.base_speed
	ground_dir = get_heading_dir()
	velocity = ground_dir * speed
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
	_lip_timer = maxf(_lip_timer - delta, 0.0)
	tricks.poll_gesture(delta)
	state_machine.physics_update(delta)
	_update_rail_highlight()
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
## The pop goes mostly along the ground normal (hop_normal_blend), so on a
## downhill slope it lifts you off the slope instead of fighting it.
func do_hop() -> void:
	var hop_dir: Vector3 = Vector3.UP.lerp(ground_normal, tuning.hop_normal_blend).normalized()
	do_hop_from(ground_dir * speed, hop_dir)


## Hop on top of a given velocity (the Grind state passes the rail velocity).
func do_hop_from(base_velocity: Vector3, hop_dir: Vector3 = Vector3.UP) -> void:
	var hop_velocity: float = lerpf(tuning.hop_min_velocity, tuning.hop_max_velocity, hop_release_charge)
	velocity = base_velocity + hop_dir * hop_velocity
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	# Godot note: move_and_slide() snaps a body that was on the floor back down
	# whenever its velocity points even slightly downward. Going 25 m/s down a
	# 12 deg slope, a small hop still points down, so the snap ate it. Snapping
	# comes back on the next ground tick (ground_move).
	floor_snap_length = 0.0


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


## Steep transition surface hit by an Air move_and_slide(), as its normal, or
## Vector3.ZERO. In the air up_direction is world up, so a quarter-pipe face
## steeper than floor_max_angle counts as a wall; landing back into a
## transition is picked up here instead. Only bodies in the "transitions"
## group count, so true walls stay walls.
func find_transition_contact(approach: Vector3) -> Vector3:
	for i: int in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Node = collision.get_collider() as Node
		if collider == null or not collider.is_in_group(&"transitions"):
			continue
		var normal: Vector3 = collision.get_normal()
		if normal.y > -0.2 and approach.dot(normal) < 0.0:
			return normal
	return Vector3.ZERO


## Highlights the rail you could snap onto right now (or are grinding).
func _update_rail_highlight() -> void:
	var snap: RailSnap = RailSnap.find_closest(get_tree(), global_position, tuning.rail_snap_radius)
	var rail: Rail = snap.rail as Rail if snap != null else null
	if rail == _highlighted_rail:
		return
	if _highlighted_rail != null:
		_highlighted_rail.set_highlighted(false)
	_highlighted_rail = rail
	if rail != null:
		rail.set_highlighted(true)


func _on_trick_completed(trick: TrickData) -> void:
	combo.add_action(trick.score)
	Events.trick_completed.emit(trick.display_name, trick.score)


# --- Directions ---------------------------------------------------------------

func get_heading_dir() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


## `dir` flattened onto the plane with normal `normal`, unit length. Falls
## back to the heading (and then any tangent) when `dir` is along the normal.
func tangent_dir(dir: Vector3, normal: Vector3) -> Vector3:
	var projected: Vector3 = dir - normal * dir.dot(normal)
	if projected.length_squared() < 0.0001:
		var fallback: Vector3 = get_heading_dir()
		projected = fallback - normal * fallback.dot(normal)
		if projected.length_squared() < 0.0001:
			projected = normal.cross(Vector3.RIGHT)
	return projected.normalized()


## Surface normal under the rider right now: the floor from the last move, or
## a short probe along the current up when that move didn't touch the floor.
func get_raw_ground_normal() -> Vector3:
	if is_on_floor():
		return get_floor_normal()
	# The body never rotates, so its local space is world space.
	ground_probe.target_position = -ground_normal * tuning.ground_probe_length
	ground_probe.force_shapecast_update()
	if ground_probe.is_colliding():
		return ground_probe.get_collision_normal(0)
	return Vector3.UP


## Eases ground_normal toward the surface (CSG curves are faceted; this hides
## the steps). `delta` 0 snaps straight to it, for touchdowns.
func update_ground_normal(delta: float) -> void:
	var raw: Vector3 = get_raw_ground_normal()
	if delta <= 0.0:
		ground_normal = raw
		return
	# lerp, not slerp: slerp errors on float noise when both vectors are almost equal.
	ground_normal = ground_normal.lerp(raw, 1.0 - exp(-delta / maxf(tuning.ground_normal_smoothing, 0.0001))).normalized()


## Starts riding on the ground along `dir` (flattened onto ground_normal).
func set_ground_motion(dir: Vector3, new_speed: float) -> void:
	ground_dir = tangent_dir(dir, ground_normal)
	speed = minf(new_speed, tuning.max_speed)
	up_direction = ground_normal
	_update_heading(ground_dir)


## Back to world up, for Air and Grind.
func leave_surface() -> void:
	up_direction = Vector3.UP
	_carving = false


func _update_heading(dir: Vector3) -> void:
	var flat: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.05:
		heading = atan2(-flat.x, -flat.z)


# --- Movement -----------------------------------------------------------------

## One tick of riding on the ground. Shared by Ride, Land and Bail.
## With input disabled the bike just rolls and follows gravity.
func ground_move(delta: float, input_enabled: bool) -> void:
	var t: PlayerTuning = tuning
	floor_snap_length = _ground_snap_length
	update_ground_normal(delta)
	up_direction = ground_normal

	var steer: float = get_steer() if input_enabled else 0.0
	var speed_ratio: float = clampf(speed / t.max_speed, 0.0, 1.0)
	var steer_rate: float = deg_to_rad(lerpf(t.steer_rate_low, t.steer_rate_high, speed_ratio))
	# Keep the direction on the surface, then steer around its normal.
	ground_dir = tangent_dir(ground_dir, ground_normal)
	ground_dir = ground_dir.rotated(ground_normal, -steer * steer_rate * delta)

	# Gravity along the surface. It also bends the direction: carving across a
	# bank curves you back down it; riding straight up a ramp slows you to a
	# stop and rolls you back.
	var gravity_along: Vector3 = Vector3.DOWN * t.gravity
	gravity_along -= ground_normal * gravity_along.dot(ground_normal)
	var surface_velocity: Vector3 = ground_dir * speed + gravity_along * delta
	if surface_velocity.length() > 0.001:
		ground_dir = surface_velocity.normalized()
	speed = surface_velocity.length()

	var accel: float = 0.0
	if input_enabled:
		if speed < t.pedal_max_speed:
			accel += t.pedal_accel * Input.get_action_strength(&"pedal")
		accel -= t.brake_decel * Input.get_action_strength(&"brake")
	accel -= t.rolling_drag * speed + t.air_drag * speed * speed
	speed = clampf(speed + accel * delta, 0.0, t.max_speed)

	velocity = ground_dir * speed - ground_normal * t.ground_stick_velocity
	move_and_slide()

	if is_on_wall():
		var wall_normal: Vector3 = get_wall_normal()
		if wall_normal.y > ground_normal.y + 0.3:
			# Sharp inside corner (rode down a steep face into the floor): the
			# floor counts as a wall relative to the tilted up, so it becomes
			# the new ground.
			ground_normal = wall_normal
			up_direction = wall_normal
			ground_dir = tangent_dir(ground_dir, wall_normal)
		elif delta > 0.0:
			# Hitting a wall eats speed. (Skipped during hit-stop: with delta 0
			# the real velocity is a division by zero.)
			speed = minf(speed, get_real_velocity().length())
	_on_transition_body = _touching_transition_body()
	_check_convex_release()

	_update_heading(ground_dir)
	_update_transition()
	_slope_trend = lerpf(_slope_trend, ground_dir.y, 1.0 - exp(-delta / 0.2))
	update_visual(delta, steer, 0.0, ground_normal, ground_dir)


## Floor snapping would let the sphere roll over any edge and ride down the
## far side, even over a quarter pipe's coping or off the back of its deck.
## Real bikes fly off sharp edges: once the floor normal has rolled more than
## convex_release_deg past where the convex part began (lip_release_deg at a
## steep face), let go of the ground.
func _check_convex_release() -> void:
	var t: PlayerTuning = tuning
	_ground_released = false
	_on_convex = false
	if not is_on_floor():
		return
	var raw: Vector3 = get_floor_normal()
	# The surface falls away ahead of you only on a convex part.
	if raw.dot(ground_dir) <= 0.02:
		_convex_ref_normal = raw
		return
	_on_convex = true
	var limit: float = t.convex_release_deg
	if _convex_ref_normal.y < cos(deg_to_rad(t.lip_min_angle_deg)):
		limit = t.lip_release_deg
	if rad_to_deg(raw.angle_to(_convex_ref_normal)) > limit:
		_ground_released = true
		floor_snap_length = 0.0
		# Fly off along the surface before the edge (a kicker face, a deck),
		# not the direction already tipped over it.
		ground_dir = tangent_dir(ground_dir, _convex_ref_normal)
		velocity = ground_dir * speed


## On the ground after this tick's ground_move? States use this, not
## is_on_floor(), so an edge that let go counts as leaving the ground.
func is_grounded() -> bool:
	return is_on_floor() and not _ground_released


func _touching_transition_body() -> bool:
	for i: int in get_slide_collision_count():
		var collider: Node = get_slide_collision(i).get_collider() as Node
		if collider != null and collider.is_in_group(&"transitions"):
			return true
	return false


## Sets transition_normal and remembers the last steep face for the lip check.
func _update_transition() -> void:
	var t: PlayerTuning = tuning
	var flat_normal: Vector3 = Vector3(ground_normal.x, 0.0, ground_normal.z)
	if _on_transition_body and ground_normal.y < cos(deg_to_rad(t.transition_min_tilt_deg)) and flat_normal.length() > 0.01:
		transition_normal = flat_normal.normalized()
	else:
		transition_normal = Vector3.ZERO
	# Not while rolling over the coping: the lip line is the face itself.
	if ground_normal.y < cos(deg_to_rad(t.lip_min_angle_deg)) and flat_normal.length() > 0.01 and not _on_convex:
		_lip_timer = t.lip_memory_time
		_lip_normal = flat_normal.normalized()
		_lip_position = global_position


## Message for the Air state when the ground runs out under you. Going up off
## a steep face it's a lip air: the push into the wall is dropped so you fly
## straight up, and Air gets the lip to drift back to (vert assist).
func leave_ground_msg(coyote: bool) -> Dictionary:
	var msg: Dictionary = {"coyote": coyote}
	if _lip_timer > 0.0 and ground_dir.y > 0.0:
		# Rolling onto the coping tips the direction toward the deck; fly
		# straight up the face instead.
		var dir: Vector3 = ground_dir - _lip_normal * minf(ground_dir.dot(_lip_normal), 0.0)
		velocity = dir.normalized() * speed
		msg["lip_normal"] = _lip_normal
		msg["lip_position"] = _lip_position
		_lip_timer = 0.0
	return msg


## Carving: riding a transition steeper than carve_min_angle_deg scores
## points per second and keeps the combo alive. Called from Ride.
func update_carve(delta: float) -> void:
	if transition_normal != Vector3.ZERO and ground_normal.y < cos(deg_to_rad(tuning.carve_min_angle_deg)):
		if not _carving:
			_carving = true
			Events.carve_started.emit()
		combo.add_carve_time(delta)
	else:
		_carving = false


## Pump: push the left stick forward on the back side of a bump, or on the
## way down a transition. Counts when the ground is getting steeper downhill,
## or once per descent of a transition, so a constant slope can't be farmed.
func try_pump(delta: float) -> void:
	_pump_cooldown_timer = maxf(_pump_cooldown_timer - delta, 0.0)
	var lean: float = get_lean()
	var pressed: bool = lean > 0.6 and _prev_lean <= 0.6
	_prev_lean = lean
	# Going back up a transition re-arms its pump.
	if ground_dir.y > 0.0:
		_transition_pump_armed = true
	if not pressed or _pump_cooldown_timer > 0.0:
		return
	var steepening: bool = ground_dir.y < _slope_trend - sin(deg_to_rad(tuning.pump_min_slope_deg))
	var descending_transition: bool = _transition_pump_armed \
			and transition_normal != Vector3.ZERO \
			and ground_dir.y < -sin(deg_to_rad(tuning.pump_transition_min_deg))
	if steepening or descending_transition:
		if descending_transition:
			_transition_pump_armed = false
		speed = minf(speed * (1.0 + tuning.pump_gain), tuning.max_speed)
		_pump_cooldown_timer = tuning.pump_cooldown
		pump_count += 1


# --- Feel -----------------------------------------------------------------------

## Tilts the Visual child to the ground, banks into turns, applies air pitch.
## `forward` is where the nose points (flattened onto the up plane); zero
## means the heading.
func update_visual(delta: float, steer: float, pitch: float, up_target: Vector3, forward: Vector3 = Vector3.ZERO) -> void:
	# lerp, not slerp: slerp errors on float noise when both vectors are almost equal.
	_visual_up = _visual_up.lerp(up_target, 1.0 - exp(-delta / 0.06)).normalized()
	if forward.length_squared() < 0.0001:
		forward = get_heading_dir()
	forward = forward - _visual_up * forward.dot(_visual_up)
	if forward.length_squared() < 0.0001:
		forward = tangent_dir(get_heading_dir(), _visual_up)
	var back: Vector3 = -forward.normalized()
	var target: Basis = Basis(_visual_up.cross(back), _visual_up, back).orthonormalized()
	# Roll into the turn (negative angle around the back axis banks right),
	# then pitch around the side axis (positive is nose up).
	var lean_deg: float = tuning.lean_into_turn_deg + tuning.lean_speed_extra_deg * clampf(speed / tuning.max_speed, 0.0, 1.0)
	target = target * Basis(Vector3.BACK, -steer * deg_to_rad(lean_deg))
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
	# The body origin is the bottom of the sphere. On a tilted surface the
	# wheels touch where the sphere meets it, so move the Visual there.
	var contact: Vector3 = (Vector3.UP - _visual_up) * _body_radius
	visual.position = base * pivot - full * pivot + contact


## Freezes the game for a few frames. Sells impact.
func hit_stop(duration: float) -> void:
	Engine.time_scale = 0.0
	# create_timer(time, process_always, process_in_physics, ignore_time_scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func respawn() -> void:
	place(_spawn_position, _spawn_heading, tuning.base_speed)
	combo.drop()
	state_machine.transition_to(&"Air", {})


## Puts the rider at `at` facing `new_heading`, moving at `new_speed`, upright
## and with no trick running. The caller picks the state afterwards.
func place(at: Vector3, new_heading: float, new_speed: float) -> void:
	global_position = at
	heading = new_heading
	speed = new_speed
	ground_normal = Vector3.UP
	_convex_ref_normal = Vector3.UP
	up_direction = Vector3.UP
	ground_dir = get_heading_dir()
	velocity = ground_dir * speed
	air_pitch = 0.0
	bail_immunity_timer = 0.0
	transition_normal = Vector3.ZERO
	_on_transition_body = false
	_lip_timer = 0.0
	_carving = false
	tricks.cancel()
	reset_physics_interpolation()
