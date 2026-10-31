extends PlayerState
## Crashed a landing. No control for a moment, the bike skids and slows.
## Placeholder until there is a proper ragdoll / recovery animation.

var _timer: float = 0.0


func enter(_msg: Dictionary) -> void:
	_timer = player.tuning.bail_duration
	player.drop_combo()
	Events.bailed.emit()


func physics_update(delta: float) -> void:
	player.speed = maxf(player.speed - player.tuning.brake_decel * 0.5 * delta, 0.0)
	player.ground_move(delta, false)
	# Wobble the visual so the bail reads on screen.
	player.visual.rotate_object_local(Vector3.BACK, sin(_timer * 30.0) * 0.05)
	_timer -= delta
	if not player.is_on_floor():
		machine.transition_to(&"Air", {})
	elif _timer <= 0.0:
		machine.transition_to(&"Ride", {})
