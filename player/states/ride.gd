extends PlayerState
## On the ground with full control: steer, pedal, brake, pump, hop.


func physics_update(delta: float) -> void:
	if player.has_buffered_hop():
		player.do_hop()
		machine.transition_to(&"Air", {})
		return

	player.ground_move(delta, true)
	player.try_pump(delta)
	player.tick_combo(delta)

	if not player.is_on_floor():
		# Rolled off an edge or a kicker lip: allow a late hop for a moment.
		machine.transition_to(&"Air", {"coyote": true})
