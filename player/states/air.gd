extends PlayerState
## Airborne: gravity, a little air steering, lean to pitch the bike,
## right-stick tricks, grind snapping, and wall rides.

var _pre_move_velocity: Vector3 = Vector3.ZERO


func enter(msg: Dictionary) -> void:
	if msg.get("coyote", false):
		player.coyote_timer = player.tuning.coyote_time
	else:
		player.coyote_timer = 0.0
	player.air_pitch = 0.0


func physics_update(delta: float) -> void:
	var t: PlayerTuning = player.tuning

	# Coyote hop: hop pressed just after rolling off an edge.
	if player.coyote_timer > 0.0 and player.has_buffered_hop():
		player.do_hop()

	var snap: RailSnap = player.find_grind_rail()
	if snap != null:
		machine.transition_to(&"Grind", {"snap": snap})
		return

	player.tricks.air_update(delta)

	player.velocity.y -= t.gravity * delta

	# Air steer rotates the horizontal velocity around the up axis.
	var steer: float = player.get_steer()
	var yaw_step: float = -steer * deg_to_rad(t.air_steer_rate) * delta
	player.velocity = player.velocity.rotated(Vector3.UP, yaw_step)
	var flat: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	if flat.length() > 0.5:
		player.heading = atan2(-flat.x, -flat.z)

	# Lean back (stick down) = nose up.
	player.air_pitch += -player.get_lean() * deg_to_rad(t.air_pitch_rate) * delta

	_pre_move_velocity = player.velocity
	player.move_and_slide()
	player.update_visual(delta, steer * 0.5, player.air_pitch, Vector3.UP)

	if player.is_on_floor():
		machine.transition_to(&"Land", {"velocity": _pre_move_velocity})
		return
	var wall: Vector3 = player.find_wall_ride(_pre_move_velocity)
	if wall != Vector3.ZERO:
		machine.transition_to(&"WallRide", {"normal": wall, "velocity": _pre_move_velocity})
