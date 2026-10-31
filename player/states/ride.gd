extends PlayerState
## On the ground with full control: steer, pedal, brake, pump, hop, grind,
## and steering into a wall at speed starts a wall ride.
## Plain riding is also what runs the combo timer down.


func physics_update(delta: float) -> void:
	if player.has_buffered_hop():
		player.do_hop()
		machine.transition_to(&"Air", {})
		return

	var snap: RailSnap = player.find_grind_rail()
	if snap != null:
		machine.transition_to(&"Grind", {"snap": snap})
		return

	var pre_move: Vector3 = player.velocity
	player.ground_move(delta, true)
	if _steering_into_wall():
		var wall: Vector3 = player.find_wall_ride(pre_move)
		if wall != Vector3.ZERO:
			machine.transition_to(&"WallRide", {"normal": wall, "velocity": pre_move, "from_ground": true})
			return
	player.try_pump(delta)
	player.combo.tick(delta)

	if not player.is_on_floor():
		# Rolled off an edge or a kicker lip: allow a late hop for a moment.
		machine.transition_to(&"Air", {"coyote": true})


func _steering_into_wall() -> bool:
	if not player.is_on_wall():
		return false
	# Steer right pushes toward the heading's right side.
	var right: Vector3 = player.get_heading_dir().cross(Vector3.UP)
	var push: float = player.get_steer() * right.dot(-player.get_wall_normal())
	return push >= player.tuning.wall_ride_steer_threshold
