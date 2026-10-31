extends PlayerState
## Riding along a near-vertical wall. Entered from Air when you hit a wall
## fast enough, or from Ride when you steer into one at speed.
## Gravity is reduced and speed bleeds slowly; it ends on a hop (jump away
## from the wall), when time runs out, when you get too slow, or when you
## lose the wall. All of those go to Air, touching the ground goes to Land.
## Counts as one combo action plus points per second, like a grind.
##
## msg: {"normal": Vector3} the wall's horizontal normal (points away from the wall),
##      {"velocity": Vector3} the velocity just before hitting it,
##      {"from_ground": bool} true when steered into from Ride.

## The capsule's radius in player.tscn: how far the body's centre stays off the wall.
const BODY_RADIUS: float = 0.35

var _normal: Vector3 = Vector3.FORWARD
## Unit direction along the wall we are riding.
var _along: Vector3 = Vector3.FORWARD
var _vertical: float = 0.0
var _timer: float = 0.0


func enter(msg: Dictionary) -> void:
	var t: PlayerTuning = player.tuning
	_normal = msg["normal"]
	var v: Vector3 = msg.get("velocity", player.velocity)
	var flat: Vector3 = Vector3(v.x, 0.0, v.z)
	var along: Vector3 = flat - _normal * flat.dot(_normal)
	_along = along.normalized()
	player.speed = minf(along.length(), t.max_speed)
	if msg.get("from_ground", false):
		_vertical = t.wall_ride_ground_lift
	else:
		_vertical = maxf(v.y, 0.0) * t.wall_ride_keep_vertical + t.wall_ride_entry_lift
	_timer = 0.0
	player.air_pitch = 0.0
	# Wheels on the wall: shift the Visual over by the capsule's radius.
	player.visual_offset = -_normal * BODY_RADIUS
	player.combo.add_action(0)
	Events.wall_ride_started.emit()


func exit() -> void:
	player.wall_ride_cooldown_timer = player.tuning.wall_ride_cooldown
	player.visual_offset = Vector3.ZERO


func physics_update(delta: float) -> void:
	var t: PlayerTuning = player.tuning
	_timer += delta
	player.speed = maxf(player.speed - t.wall_ride_drag * delta, 0.0)
	_vertical -= t.gravity * t.wall_ride_gravity_scale * delta
	player.heading = atan2(-_along.x, -_along.z)
	player.combo.add_wall_ride_time(delta)

	if player.has_buffered_hop():
		# Fixed wall-jump impulse; the hop charge doesn't matter here (hop_dir zero).
		player.do_hop_from(_along * player.speed + _normal * t.wall_ride_hop_away + Vector3.UP * t.wall_ride_hop_up, Vector3.ZERO)
		machine.transition_to(&"Air", {})
		return
	if _timer >= t.wall_ride_max_time or player.speed < t.wall_ride_fall_off_speed:
		_leave_wall()
		return

	var pre_move: Vector3 = _along * player.speed + Vector3.UP * _vertical
	player.velocity = pre_move - _normal * t.wall_ride_stick_velocity
	player.move_and_slide()

	if player.is_on_floor():
		machine.transition_to(&"Land", {"velocity": pre_move})
		return
	if not player.is_on_wall():
		# Ran off the end or over the top of the wall.
		_leave_wall()
		return
	# Follow curved walls.
	var n: Vector3 = player.get_wall_normal()
	if absf(n.y) <= t.wall_ride_max_normal_y:
		_normal = Vector3(n.x, 0.0, n.z).normalized()
		_along = (_along - _normal * _along.dot(_normal)).normalized()

	var up: Vector3 = Vector3.UP.lerp(_normal, t.wall_ride_tilt).normalized()
	player.update_visual(delta, 0.0, 0.0, up)


func _leave_wall() -> void:
	var t: PlayerTuning = player.tuning
	player.velocity = _along * player.speed + Vector3.UP * _vertical + _normal * t.wall_ride_exit_push
	machine.transition_to(&"Air", {})
