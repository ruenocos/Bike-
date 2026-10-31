extends PlayerState
## On the ground with full control: steer, pedal, brake, pump, hop, grind.
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

	player.ground_move(delta, true)
	player.try_pump(delta)
	player.combo.tick(delta)

	if not player.is_on_floor():
		# Rolled off an edge or a kicker lip: allow a late hop for a moment.
		machine.transition_to(&"Air", {"coyote": true})
