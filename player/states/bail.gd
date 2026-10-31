extends PlayerState
## Crashed a landing. No control for a moment while the bike rolls on (Land
## already took the speed penalty). When it ends, a short immunity window
## keeps the next landing from bailing again.
## Placeholder until there is a proper ragdoll / recovery animation.

var _timer: float = 0.0


func enter(_msg: Dictionary) -> void:
	_timer = player.tuning.bail_duration
	player.tricks.cancel()
	player.combo.drop()
	Events.bailed.emit()


func exit() -> void:
	player.bail_immunity_timer = player.tuning.bail_immunity


func physics_update(delta: float) -> void:
	player.ground_move(delta, false)
	# Wobble the visual so the bail reads on screen.
	player.visual.rotate_object_local(Vector3.BACK, sin(_timer * 30.0) * 0.05)
	_timer -= delta
	if not player.is_grounded():
		machine.transition_to(&"Air", player.leave_ground_msg(false))
	elif _timer <= 0.0:
		machine.transition_to(&"Ride", {})
