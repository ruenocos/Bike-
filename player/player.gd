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

## Fell below kill_y or pressed debug reset (only when auto_respawn is off).
signal fell
## Perfect Streak (v0.26): the streak grew (count) or ended (0).
signal streak_changed(count: int)
## A crash shield turned a crash into a glance (v0.13).
signal shield_used
## An air hop (Double Hop) fired.
signal air_hopped
## A boost just happened (AnimeFx).
signal boost_flashed
## A ground hop just fired (TankCannon).
signal hopped
## Something crushable got crushed (v0.31).
signal crushed(at: Vector3)

@export var tuning: PlayerTuning = preload("res://player/player_tuning.tres")

@onready var visual: Node3D = $Visual
@onready var ground_probe: ShapeCast3D = $GroundProbe
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var camera_rig: PlayerCamera = $CameraRig
@onready var tricks: TrickRunner = $TrickRunner
@onready var combo: ComboTracker = $ComboTracker
@onready var vfx: RiderVfx = $RiderVfx
## The look under Visual: RiderRig or TankRig (set_frame_color, trail_points).
@onready var rider: Node3D = $Visual.get_child(0) as Node3D

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
## Below this height you've fallen off the world. The game lowers it as the
## stage descends; the test track keeps the default.
var kill_y: float = -40.0
## Falling below kill_y (or debug reset) respawns at the spawn point. The game
## turns this off and handles `fell` itself.
var auto_respawn: bool = true

# Hop input: hold to charge, release to hop. The release is buffered so a
# release just before touchdown still hops on landing.
var hop_charge: float = 0.0
var hop_release_charge: float = 0.0
var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
## A release only hops after a press we saw. place() clears it, so the A
## that confirmed a menu (also the hop button) doesn't hop you at the start.
var _hop_armed: bool = false

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
## The rail you could catch right now (in snap reach, not grinding), or null.
## The HUD shows a grind prompt while it's set.
var catchable_rail: Rail
## TightZones you're inside (they count themselves in and out). The camera
## tucks in while > 0.
var tight_zones: int = 0
## Tricks completed since leaving the ground; landing them adds speed.
var air_tricks: int = 0
## Set by ground_move / check_air_crash when this tick hit an obstacle hard.
var crashed: bool = false
## Crash shields left this stage (the game refills them each stage).
var shields_left: int = 0
## Air hops left in this airtime.
var air_hops_left: int = 0
## No Hander (v0.18): holding it now, and for how long this time.
var no_hander: bool = false
## Perfect landings in a row (only counted with the Perfect Streak upgrade).
var perfect_streak: int = 0
var no_hander_time: float = 0.0
## Time left to let go after touching down with it held.
var _no_hander_grace: float = 0.0
## A hazard hit waiting for the next physics tick: [what, body] or [].
var _pending_hazard: Array = []
## Sideways pulls asked for this tick (Gate Magnet), applied capped.
var _side_pull: Vector3 = Vector3.ZERO
## Counts down after a speed boost (perfect landing, landed tricks, sprint
## start); the speed lines flash while it's running.
var boost_timer: float = 0.0
## Steer after steer_response_time smoothing and the steer_curve.
var _steer_smoothed: float = 0.0
## After a crash, obstacles only glance you off for this long (s), so staying
## in contact with the tree doesn't crash again every tick.
var _crash_cooldown: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
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
	_crash_cooldown = maxf(_crash_cooldown - delta, 0.0)
	boost_timer = maxf(boost_timer - delta, 0.0)
	_lip_timer = maxf(_lip_timer - delta, 0.0)
	tricks.poll_gesture(delta)
	_apply_hazard_hit()
	_update_no_hander_grace(delta)
	_apply_side_pull(delta)
	state_machine.physics_update(delta)
	_update_rail_highlight()
	if global_position.y < kill_y or Input.is_action_just_pressed(&"debug_reset"):
		if auto_respawn:
			respawn()
		else:
			fell.emit()


# --- Input ------------------------------------------------------------------

func get_steer() -> float:
	return Input.get_axis(&"steer_left", &"steer_right")


## The stick through steer_curve, eased by steer_response_time. Ground steering uses this.
func get_shaped_steer(delta: float) -> float:
	var raw: float = get_steer()
	var shaped: float = signf(raw) * pow(absf(raw), tuning.steer_curve)
	if tuning.steer_response_time <= 0.0 or delta <= 0.0:
		_steer_smoothed = shaped
	else:
		_steer_smoothed = lerpf(_steer_smoothed, shaped, 1.0 - exp(-delta / tuning.steer_response_time))
	return _steer_smoothed


## +1 = leaning forward (stick up), -1 = leaning back (stick down).
func get_lean() -> float:
	return Input.get_axis(&"lean_back", &"lean_forward")


## Holding hop only charges after a fresh press (place() disarms it).
func is_hop_armed() -> bool:
	return _hop_armed


func _update_hop_input(delta: float) -> void:
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	if Input.is_action_just_pressed(&"hop"):
		hop_charge = 0.0
		_hop_armed = true
	if not _hop_armed:
		return
	if Input.is_action_pressed(&"hop"):
		hop_charge = minf(hop_charge + delta, tuning.hop_full_charge)
	if Input.is_action_just_released(&"hop"):
		_hop_armed = false
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


## Touched down holding the No Hander: let go within no_hander_grace and it
## counts, keep holding and it's a bail.
func start_no_hander_grace() -> void:
	_no_hander_grace = maxf(tuning.no_hander_grace, 0.001)


## Ends a No Hander that was let go in time: long enough holds score
## (time × no_hander_score_per_second × trick_score_scale, a combo action);
## in the air it also counts toward the landing's trick boost.
func finish_no_hander() -> void:
	_no_hander_grace = 0.0
	no_hander = false
	if no_hander_time >= tuning.no_hander_min_time:
		var score: int = roundi(no_hander_time * tuning.no_hander_score_per_second * tuning.trick_score_scale / 10.0) * 10
		combo.add_action(score)
		if state_machine.get_state_name() == &"Air":
			air_tricks += 1
		Events.trick_completed.emit(tuning.no_hander_name, score)
	no_hander_time = 0.0


func _update_no_hander_grace(delta: float) -> void:
	if _no_hander_grace <= 0.0:
		return
	if not Input.is_action_pressed(&"no_hander"):
		finish_no_hander()
		return
	_no_hander_grace -= delta
	if _no_hander_grace <= 0.0:
		_no_hander_grace = 0.0
		no_hander = false
		no_hander_time = 0.0
		if state_machine.get_state_name() == &"Bail" or bail_immunity_timer > 0.0:
			return
		speed *= 1.0 - tuning.crash_penalty
		last_bail_reason = "landed with no hands"
		state_machine.transition_to(&"Bail", {})


## Something pulls you sideways this tick (`accel` m/s² along `dir`; Gate
## Magnet). Several pulls add up; the turn they cause is capped at half the
## steering rate, so you can always steer out of it.
func add_side_pull(dir: Vector3, accel: float) -> void:
	_side_pull += Vector3(dir.x, 0.0, dir.z).normalized() * accel


func _apply_side_pull(delta: float) -> void:
	if _side_pull == Vector3.ZERO:
		return
	var pull: Vector3 = _side_pull
	_side_pull = Vector3.ZERO
	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 1.0:
		return
	var max_turn: float = deg_to_rad(tuning.steer_rate_high * 0.5) * delta
	var turn: float = clampf(pull.length() * delta / flat.length(), 0.0, max_turn)
	var side: float = signf(flat.cross(pull).y)
	if state_machine.get_state_name() == &"Air":
		velocity = velocity.rotated(Vector3.UP, side * turn)
	elif is_on_floor():
		ground_dir = tangent_dir(ground_dir.rotated(Vector3.UP, side * turn), ground_normal)


## A hazard came down on you (a falling trunk): a crash whatever your own
## speed, unless a Crash Shield takes it. Signals can arrive between ticks,
## so it's applied at the start of the next physics tick.
func hit_by_hazard(what: String, body: PhysicsBody3D) -> void:
	_pending_hazard = [what, body]


func _apply_hazard_hit() -> void:
	if _pending_hazard.is_empty():
		return
	var what: String = _pending_hazard[0]
	var body: PhysicsBody3D = _pending_hazard[1] as PhysicsBody3D
	_pending_hazard = []
	if _crash_cooldown > 0.0 or state_machine.get_state_name() == &"Bail":
		return
	_crash_cooldown = 0.8
	if shields_left > 0:
		shields_left -= 1
		_shield_through(body)
		shield_used.emit()
		return
	speed *= 1.0 - tuning.crash_penalty
	last_bail_reason = "%s came down on you" % what
	crashed = true
	state_machine.transition_to(&"Bail", {})


## After each graded landing (Land): perfect grows the streak and adds its
## speed, anything else ends it.
func update_perfect_streak(perfect: bool) -> void:
	if tuning.perfect_streak_boost <= 0.0:
		return
	if perfect:
		perfect_streak = mini(perfect_streak + 1, int(tuning.perfect_streak_max))
		speed = minf(speed + tuning.perfect_streak_boost * perfect_streak, tuning.max_speed)
		streak_changed.emit(perfect_streak)
	elif perfect_streak > 0:
		perfect_streak = 0
		streak_changed.emit(0)


## Double Hop: a second pop in the air (keeps the speed, resets the fall).
func air_hop() -> void:
	air_hops_left -= 1
	velocity.y = maxf(velocity.y, 0.0) + tuning.air_hop_velocity
	jump_buffer_timer = 0.0
	vfx.puff(0.5)
	air_hopped.emit()


## Hop on top of a given velocity (the Grind state passes the rail velocity).
func do_hop_from(base_velocity: Vector3, hop_dir: Vector3 = Vector3.UP) -> void:
	var hop_velocity: float = lerpf(tuning.hop_min_velocity, tuning.hop_max_velocity, hop_release_charge)
	velocity = base_velocity + hop_dir * hop_velocity
	hopped.emit()
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


## True while grind is pressed (buffered) or held, or (rail_auto_catch) any
## time you're in the air: then landing on a rail grinds by itself.
func wants_grind() -> bool:
	if tuning.rail_auto_catch and not is_on_floor():
		return true
	return grind_buffer_timer > 0.0 or Input.is_action_pressed(&"grind")


## Snap reach right now: rail_snap_radius at low speed up to
## rail_snap_radius_fast at rail_snap_fast_speed.
func get_rail_snap_radius() -> float:
	var t: PlayerTuning = tuning
	var ratio: float = clampf(velocity.length() / maxf(t.rail_snap_fast_speed, 0.001), 0.0, 1.0)
	return lerpf(t.rail_snap_radius, t.rail_snap_radius_fast, ratio)


## Rail to snap onto right now, or null. Ride and Air call this each tick
## and switch to Grind when it returns a rail. Holding grind counts too, so
## you can hold it on the way in and catch the rail the moment it's in reach.
func find_grind_rail(airborne: bool = true) -> RailSnap:
	if not airborne and not tuning.rail_ground_catch:
		return null
	if not wants_grind() or grind_cooldown_timer > 0.0 or tricks.is_mid_trick():
		return null
	var snap: RailSnap = RailSnap.find_closest(get_tree(), global_position, get_rail_snap_radius())
	if snap != null:
		grind_buffer_timer = 0.0
	return snap


## The rail magnet: while grind is held within rail_magnet_radius of a rail,
## steer sideways toward it (never along it, so speed is untouched). Ride and
## Air call this before moving.
func apply_rail_magnet(delta: float) -> void:
	var t: PlayerTuning = tuning
	if not wants_grind() or grind_cooldown_timer > 0.0 or tricks.is_mid_trick():
		return
	if t.rail_magnet_air_only and is_on_floor():
		return
	var snap: RailSnap = RailSnap.find_closest(get_tree(), global_position, t.rail_magnet_radius)
	if snap == null:
		return
	var moving: Vector3 = ground_dir * speed if is_on_floor() else velocity
	var along: Vector3 = Vector3(moving.x, 0.0, moving.z)
	if along.length() < 1.0:
		return
	along = along.normalized()
	var to_rail: Vector3 = RailSnap.point_at(snap.rail, snap.offset) - global_position
	var side: Vector3 = to_rail - along * to_rail.dot(along)
	side.y = 0.0
	var gap: float = side.length()
	if gap < 0.05:
		return
	side /= gap
	var want: float = minf(gap / maxf(t.rail_magnet_time, 0.001), t.rail_magnet_speed)
	var weight: float = 1.0 - exp(-delta / 0.08)
	if is_on_floor():
		var current: float = (ground_dir * speed).dot(side)
		var pulled: Vector3 = ground_dir * speed + side * (want - current) * weight
		ground_dir = tangent_dir(pulled, ground_normal)
	else:
		var current_air: float = velocity.dot(side)
		velocity += side * (want - current_air) * weight


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
	var snap: RailSnap = RailSnap.find_closest(get_tree(), global_position, get_rail_snap_radius())
	var rail: Rail = snap.rail as Rail if snap != null else null
	catchable_rail = rail if state_machine.get_state_name() != &"Grind" else null
	if rail == _highlighted_rail:
		return
	if _highlighted_rail != null:
		_highlighted_rail.set_highlighted(false)
	_highlighted_rail = rail
	if rail != null:
		rail.set_highlighted(true)


func _on_trick_completed(trick: TrickData) -> void:
	air_tricks += 1
	var score: int = roundi(trick.score * tuning.trick_score_scale)
	combo.add_action(score)
	Events.trick_completed.emit(trick.display_name, score)


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

	var steer: float = get_shaped_steer(delta) if input_enabled else 0.0
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
	# Hard carving at speed scrubs a little speed.
	accel -= t.carve_drag * absf(steer) * smoothstep(t.carve_drag_from, 1.0, speed_ratio)
	speed = clampf(speed + accel * delta, 0.0, t.max_speed)

	velocity = ground_dir * speed - ground_normal * t.ground_stick_velocity
	var approach: Vector3 = ground_dir * speed
	move_and_slide()
	var hit: Hit = _check_obstacle_hit(approach)
	crashed = hit == Hit.CRASH

	if is_on_wall():
		var wall_normal: Vector3 = get_wall_normal()
		if wall_normal.y > ground_normal.y + 0.3 or (hit == Hit.NONE and wall_normal.y > tuning.ramp_min_normal_y):
			# Sharp inside corner (rode down a steep face into the floor), or a
			# kink up into a face that's still walkable in world terms (the
			# end of a ridge, a bank): it counts as a wall relative to the
			# tilted up, so it becomes the new ground and you ride up it /
			# launch off it instead of stopping dead.
			ground_normal = wall_normal
			up_direction = wall_normal
			ground_dir = tangent_dir(ground_dir, wall_normal)
		elif delta > 0.0 and hit == Hit.NONE:
			# Hitting a wall eats speed. (Skipped during hit-stop: with delta 0
			# the real velocity is a division by zero.)
			speed = minf(speed, get_real_velocity().length())
	_on_transition_body = _touching_transition_body()
	_check_convex_release()

	_update_heading(ground_dir)
	_update_transition()
	_slope_trend = lerpf(_slope_trend, ground_dir.y, 1.0 - exp(-delta / 0.2))
	update_visual(delta, steer, ground_normal, ground_dir)


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


enum Hit { NONE, GLANCE, CRASH }


## What this tick's move did to an obstacle (group "obstacles"). More than
## crash_min_impact of speed into it is a CRASH: the speed drops by
## crash_penalty, you're deflected off it and the state goes to Bail. Softer
## hits (and any hit in the short cooldown after a crash) GLANCE off: same
## deflection, speed kept.
func _check_obstacle_hit(approach: Vector3) -> Hit:
	for i: int in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Node = collision.get_collider() as Node
		if collider == null or not collider.is_in_group(&"obstacles"):
			continue
		if tuning.crushes_props and collider.is_in_group(&"crushable"):
			_crush(collider as CollisionObject3D, approach.length())
			continue
		var normal: Vector3 = collision.get_normal()
		var impact: float = -approach.dot(normal)
		# Keep going: slide along it, and if the hit was head-on (little left
		# to slide with) veer around it sideways. Never back up the hill:
		# bouncing backwards left you stuck behind a rail ledge while the
		# collapse caught up (v0.9.1).
		var away: Vector3 = Vector3(normal.x, 0.0, normal.z).normalized()
		var slide: Vector3 = approach - normal * approach.dot(normal)
		if slide.length() < approach.length() * 0.5:
			var side: Vector3 = Vector3.UP.cross(away).normalized()
			if side.dot(slide) < 0.0:
				side = -side
			slide += side * approach.length() * 0.6
		slide += away * approach.length() * 0.05
		if impact <= 0.5:
			continue
		var result: Hit = Hit.GLANCE
		var keep: float = approach.length()
		if impact > tuning.crash_min_impact and _crash_cooldown <= 0.0 and shields_left > 0:
			# Crash Shield: smash through at full speed instead (passes
			# through this obstacle for a moment).
			shields_left -= 1
			_crash_cooldown = 0.8
			_shield_through(collider as PhysicsBody3D)
			shield_used.emit()
			speed = approach.length()
			return Hit.GLANCE
		elif impact > tuning.crash_min_impact and _crash_cooldown <= 0.0:
			result = Hit.CRASH
			keep *= 1.0 - tuning.crash_penalty
			last_bail_reason = "hit %s at %.0f m/s" % [_obstacle_name(collider), impact]
			_crash_cooldown = 0.8
		if slide.length_squared() > 0.0001:
			ground_dir = tangent_dir(slide, ground_normal) if is_on_floor() else slide.normalized()
		speed = keep
		return result
	return Hit.NONE


## Rolls over something crushable: it stops colliding and flattens, you lose
## a little speed and score a little.
func _crush(body: CollisionObject3D, approach_speed: float) -> void:
	body.collision_layer = 0
	body.collision_mask = 0
	var model: PropModel = body.get_node_or_null("Model") as PropModel
	if model != null:
		model.crush()
	speed = approach_speed * (1.0 - tuning.crush_speed_cost)
	combo.add_points(tuning.crush_score)
	crushed.emit(body.global_position)


## "Tree", "Rock", ... from the obstacle's scene file (or its node name).
func _obstacle_name(collider: Node) -> String:
	var node: Node = collider
	for i: int in 4:
		if node == null:
			break
		if not node.scene_file_path.is_empty():
			return node.scene_file_path.get_file().get_basename().capitalize()
		node = node.get_parent()
	return String(collider.name)


## Crash Shield: ignore this body for a moment so you ride through it.
func _shield_through(body: PhysicsBody3D) -> void:
	if body == null:
		return
	add_collision_exception_with(body)
	await get_tree().create_timer(0.6, false, true).timeout
	if is_instance_valid(body):
		remove_collision_exception_with(body)


## Air version: call after the Air move with the velocity before it.
func check_air_crash(approach: Vector3) -> bool:
	var hit: Hit = _check_obstacle_hit(approach)
	crashed = hit == Hit.CRASH
	if hit != Hit.NONE:
		velocity = ground_dir * speed
	return crashed


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


## Where the current air trajectory meets the ground within `max_time`
## seconds: {"time": s, "normal": Vector3, "position": Vector3}, or {} when
## nothing is hit. Steps the ballistic path (gravity only) and raycasts each step.
func predict_landing(max_time: float, step: float = 1.0 / 30.0) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var pos: Vector3 = global_position
	var vel: Vector3 = velocity
	var time: float = 0.0
	while time < max_time:
		var next_vel: Vector3 = vel + Vector3.DOWN * tuning.gravity * step
		var next_pos: Vector3 = pos + (vel + next_vel) * 0.5 * step
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pos, next_pos)
		query.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			var part: float = pos.distance_to(hit["position"]) / maxf(pos.distance_to(next_pos), 0.0001)
			return {"time": time + step * part, "normal": hit["normal"], "position": hit["position"]}
		pos = next_pos
		vel = next_vel
		time += step
	return {}


# --- Feel -----------------------------------------------------------------------

## Tilts the Visual child to the ground and banks into turns.
## `forward` is where the nose points (flattened onto the up plane); zero
## means the heading.
func update_visual(delta: float, steer: float, up_target: Vector3, forward: Vector3 = Vector3.ZERO) -> void:
	# lerp, not slerp: slerp errors on float noise when both vectors are almost equal.
	_visual_up = _visual_up.lerp(up_target, 1.0 - exp(-delta / 0.06)).normalized()
	if forward.length_squared() < 0.0001:
		forward = get_heading_dir()
	forward = forward - _visual_up * forward.dot(_visual_up)
	if forward.length_squared() < 0.0001:
		forward = tangent_dir(get_heading_dir(), _visual_up)
	var back: Vector3 = -forward.normalized()
	var target: Basis = Basis(_visual_up.cross(back), _visual_up, back).orthonormalized()
	# Roll into the turn (negative angle around the back axis banks right).
	var lean_deg: float = tuning.lean_into_turn_deg + tuning.lean_speed_extra_deg * clampf(speed / tuning.max_speed, 0.0, 1.0)
	target = target * Basis(Vector3.BACK, -steer * deg_to_rad(lean_deg))
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


## Speed lines flash for speed_lines_boost_time (a boost just happened).
func flash_boost() -> void:
	boost_timer = tuning.speed_lines_boost_time
	boost_flashed.emit()


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
	perfect_streak = 0
	ground_normal = Vector3.UP
	_convex_ref_normal = Vector3.UP
	up_direction = Vector3.UP
	ground_dir = get_heading_dir()
	velocity = ground_dir * speed
	bail_immunity_timer = 0.0
	hop_charge = 0.0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	_hop_armed = false
	transition_normal = Vector3.ZERO
	_on_transition_body = false
	_lip_timer = 0.0
	_carving = false
	crashed = false
	_crash_cooldown = 0.0
	air_tricks = 0
	_steer_smoothed = 0.0
	tricks.cancel()
	reset_physics_interpolation()
	camera_rig.snap()
