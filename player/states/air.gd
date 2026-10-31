extends PlayerState
## Airborne: gravity, a little air steering, lean to pitch the bike,
## right-stick tricks and grind snapping.
##
## Lip air: launched straight up off a quarter-pipe face (msg "lip_normal",
## "lip_position" from Player.leave_ground_msg). The vert assist then nudges
## the sideways speed so you drift back over the lip line and drop into the
## same ramp, and the bike's nose follows the velocity (up, then down).

var _pre_move_velocity: Vector3 = Vector3.ZERO
## Lip you launched off (horizontal, points into the pipe), or zero.
var _lip_normal: Vector3 = Vector3.ZERO
var _lip_position: Vector3 = Vector3.ZERO


func enter(msg: Dictionary) -> void:
	var t: PlayerTuning = player.tuning
	if msg.get("coyote", false):
		player.coyote_timer = t.coyote_time
	else:
		player.coyote_timer = 0.0
	player.air_pitch = 0.0
	player.leave_surface()
	_lip_normal = msg.get("lip_normal", Vector3.ZERO)
	_lip_position = msg.get("lip_position", Vector3.ZERO)
	player.transition_normal = _lip_normal
	if _lip_normal != Vector3.ZERO:
		player.combo.add_points(t.lip_air_score)
		Events.lip_air.emit()


func exit() -> void:
	player.transition_normal = Vector3.ZERO


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

	if _lip_normal != Vector3.ZERO:
		_vert_assist(delta)

	# Lean back (stick down) = nose up.
	player.air_pitch += -player.get_lean() * deg_to_rad(t.air_pitch_rate) * delta

	_pre_move_velocity = player.velocity
	player.move_and_slide()
	if _lip_normal != Vector3.ZERO:
		# Nose along the velocity, wheels toward the ramp.
		player.update_visual(delta, steer * 0.5, player.air_pitch, _lip_normal, player.velocity)
	else:
		player.update_visual(delta, steer * 0.5, player.air_pitch, Vector3.UP)

	var lip_air: bool = _lip_normal != Vector3.ZERO
	if player.is_on_floor():
		machine.transition_to(&"Land", {"velocity": _pre_move_velocity, "lip_air": lip_air})
		return
	var steep: Vector3 = player.find_transition_contact(_pre_move_velocity)
	if steep != Vector3.ZERO:
		machine.transition_to(&"Land", {"velocity": _pre_move_velocity, "normal": steep, "lip_air": lip_air})


## Steers the speed across the lip line toward a small target, so a vert air
## comes back down onto the face it left. Capped, so it can't rescue a launch
## that's way off.
func _vert_assist(delta: float) -> void:
	var t: PlayerTuning = player.tuning
	# + = out over the pipe, - = back over the deck.
	var offset: float = (player.global_position - _lip_position).dot(_lip_normal)
	var target: float = clampf((t.vert_assist_margin - offset) / maxf(t.vert_assist_time, 0.0001),
			-t.vert_assist_max_speed, t.vert_assist_max_speed)
	var across: float = player.velocity.dot(_lip_normal)
	var new_across: float = lerpf(across, target, 1.0 - exp(-delta / maxf(t.vert_assist_response, 0.0001)))
	player.velocity += _lip_normal * (new_across - across)
