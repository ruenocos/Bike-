extends PlayerState
## Touchdown. Grades the landing from the angle between the velocity and the
## ground, changes speed, fires juice, then hands back to Ride (or Bail).
##
## Angle used: how far the velocity points INTO the ground, measured from the
## ground plane. 0 deg = touching down exactly parallel to the slope.
## Touching down while a trick is still spinning is always a bad landing.

var _timer: float = 0.0


func enter(msg: Dictionary) -> void:
	var t: PlayerTuning = player.tuning
	_timer = t.land_duration
	player.air_pitch = 0.0
	player.update_ground_normal()

	var v: Vector3 = msg.get("velocity", player.velocity)
	var n: Vector3 = player.ground_normal
	var impact: float = -v.dot(n)
	var tangent: Vector3 = v - n * v.dot(n)

	# Keep the momentum that runs along the ground.
	if tangent.length() > 0.5:
		var flat: Vector3 = Vector3(tangent.x, 0.0, tangent.z)
		if flat.length() > 0.1:
			player.heading = atan2(-flat.x, -flat.z)
	player.speed = minf(tangent.length(), t.max_speed)

	var mid_trick: bool = player.tricks.is_mid_trick()
	player.tricks.cancel()

	if impact < t.land_min_impact and not mid_trick:
		# Soft roll-in (small drop, respawn): no grade.
		machine.transition_to(&"Ride", {})
		return

	var angle: float = rad_to_deg(asin(clampf(impact / maxf(v.length(), 0.001), 0.0, 1.0)))
	var grade: StringName
	if mid_trick:
		grade = &"bad"
		player.speed *= 1.0 - t.bad_penalty
	elif angle <= t.perfect_angle_deg:
		grade = &"perfect"
		player.speed = minf(player.speed * (1.0 + t.perfect_bonus), t.max_speed)
	elif angle <= t.good_angle_deg:
		grade = &"good"
	else:
		grade = &"bad"
		player.speed *= 1.0 - t.bad_penalty

	player.last_landing_angle = angle
	player.last_landing_grade = grade
	Events.landed.emit(grade)

	match grade:
		&"perfect":
			player.combo.add_action(t.perfect_landing_score)
			player.hit_stop(t.hit_stop_perfect)
			player.camera_rig.punch()
		&"good":
			player.combo.keep_alive()
		&"bad":
			machine.transition_to(&"Bail", {})


func physics_update(delta: float) -> void:
	player.ground_move(delta, true)
	_timer -= delta
	if not player.is_on_floor():
		machine.transition_to(&"Air", {"coyote": true})
	elif _timer <= 0.0:
		machine.transition_to(&"Ride", {})
