extends PlayerState
## Touchdown. Grades the landing from the angle between the velocity and the
## ground, changes speed, fires juice, then hands back to Ride (or Bail).
##
## Angle used: how far the velocity points INTO the ground, measured from the
## ground plane. 0 deg = touching down exactly parallel to the slope.
## Grades, best to worst: perfect, good, sketchy, bail (thresholds in PlayerTuning).
## Touching down mid-trick: if the trick is nearly done it is completed for
## you and the landing is sketchy at best; otherwise it is a bail.
## Right after a bail (bail_immunity) a landing never bails, it is sketchy.
## msg: "velocity" just before touchdown, "normal" when Air hit a steep
## transition face, "lip_air" when coming back from a lip air.

const GRADES: Array[StringName] = [&"perfect", &"good", &"sketchy", &"bail"]

var _timer: float = 0.0


func enter(msg: Dictionary) -> void:
	var t: PlayerTuning = player.tuning
	_timer = t.land_duration
	player.air_pitch = 0.0
	# Air passes "normal" when it touched down on a steep transition face.
	if msg.has("normal"):
		player.ground_normal = msg["normal"]
	else:
		player.update_ground_normal(0.0)

	var v: Vector3 = msg.get("velocity", player.velocity)
	var n: Vector3 = player.ground_normal
	var impact: float = -v.dot(n)
	var tangent: Vector3 = v - n * v.dot(n)

	# Keep the momentum that runs along the ground.
	var dir: Vector3 = tangent if tangent.length() > 0.5 else player.get_heading_dir()
	player.set_ground_motion(dir, tangent.length())

	var mid_trick: bool = player.tricks.is_mid_trick()
	var trick_progress: float = player.tricks.get_progress()
	var trick_saved: bool = mid_trick and trick_progress >= t.trick_land_tolerance
	if trick_saved:
		player.tricks.complete_current()
	player.tricks.cancel()

	# Coming back into a quarter pipe from a lip air is nearly tangent, so it
	# is always graded even though it's soft.
	if impact < t.land_min_impact and not mid_trick and not msg.get("lip_air", false):
		# Soft roll-in (small drop, respawn): no grade.
		machine.transition_to(&"Ride", {})
		return

	var angle: float = rad_to_deg(asin(clampf(impact / maxf(v.length(), 0.001), 0.0, 1.0)))
	var grade: StringName
	var bail_reason: String = ""
	if angle <= t.perfect_angle_deg:
		grade = &"perfect"
	elif angle <= t.good_angle_deg:
		grade = &"good"
	elif angle <= t.sketchy_angle_deg:
		grade = &"sketchy"
	elif impact < t.bail_min_impact:
		grade = &"sketchy"
	else:
		grade = &"bail"
		bail_reason = "angle %.0f° > %.0f°" % [angle, t.sketchy_angle_deg]
	if trick_saved:
		grade = _worst(grade, &"sketchy")
	elif mid_trick:
		grade = &"bail"
		bail_reason = "unfinished trick %d%% < %d%%" % [roundi(trick_progress * 100.0), roundi(t.trick_land_tolerance * 100.0)]
	if grade == &"bail" and player.bail_immunity_timer > 0.0:
		grade = &"sketchy"
	player.bail_immunity_timer = 0.0

	player.last_landing_angle = angle
	player.last_landing_grade = grade
	if grade == &"bail":
		player.last_bail_reason = bail_reason
	Events.landed.emit(grade)

	match grade:
		&"perfect":
			player.speed = minf(player.speed * (1.0 + t.perfect_bonus), t.max_speed)
			player.combo.add_action(t.perfect_landing_score)
			player.hit_stop(t.hit_stop_perfect)
			player.camera_rig.punch()
		&"good":
			player.combo.keep_alive()
		&"sketchy":
			player.speed *= 1.0 - t.sketchy_penalty
			player.combo.keep_alive()
			player.camera_rig.shake(t.sketchy_shake_strength, t.sketchy_shake_time)
		&"bail":
			player.speed *= 1.0 - t.bad_penalty
			machine.transition_to(&"Bail", {})


func physics_update(delta: float) -> void:
	player.ground_move(delta, true)
	_timer -= delta
	if not player.is_grounded():
		machine.transition_to(&"Air", player.leave_ground_msg(true))
	elif _timer <= 0.0:
		machine.transition_to(&"Ride", {})


func _worst(a: StringName, b: StringName) -> StringName:
	return a if GRADES.find(a) >= GRADES.find(b) else b
