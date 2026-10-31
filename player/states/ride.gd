extends PlayerState
## On the ground with full control: steer, pedal, brake, pump, hop, grind,
## and carve transitions (steep quarter-pipe riding scores carve points).
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

	player.apply_rail_magnet(delta)
	player.ground_move(delta, true)
	if player.crashed:
		machine.transition_to(&"Bail", {})
		return
	player.try_pump(delta)
	player.update_carve(delta)
	player.combo.tick(delta)

	if not player.is_grounded():
		# Rolled off an edge, a kicker lip or the top of a quarter pipe:
		# allow a late hop for a moment.
		machine.transition_to(&"Air", player.leave_ground_msg(true))
