class_name LineFollower
extends RefCounted
## Steering for the bots (autopilot, line test): aims at a point a little way
## down a RideLine and presses steer_left / steer_right like a pad would.


## Look-ahead along the line for this speed (m).
static func look_ahead(speed: float) -> float:
	return clampf(speed * 0.4, 10.0, 24.0)


## Presses the steer actions toward `line`, `ahead` metres down it.
## Returns the signed steer (+ = right).
static func steer(player: Player, line: RideLine, ahead: float) -> float:
	var idx: int = line.nearest_index(player.global_position)
	var target: Vector3 = line.point_ahead(idx, ahead)[0]
	return steer_toward(player, target)


static func steer_toward(player: Player, target: Vector3) -> float:
	var to_target: Vector3 = target - player.global_position
	to_target.y = 0.0
	var going: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	var amount: float = 0.0
	if going.length() > 0.5 and to_target.length() > 0.5 and player.state_machine.get_state_name() != &"Grind":
		# Signed angle from where we go to where we want to go (+ = target on the right).
		amount = clampf(going.normalized().signed_angle_to(to_target.normalized(), Vector3.DOWN) * 3.0, -1.0, 1.0)
	if amount >= 0.0:
		Input.action_release(&"steer_left")
		Input.action_press(&"steer_right", maxf(amount, 0.001))
	else:
		Input.action_release(&"steer_right")
		Input.action_press(&"steer_left", -amount)
	return amount


## Horizontal distance from `pos` to the line (m).
static func distance_to(line: RideLine, pos: Vector3) -> float:
	var pts: PackedVector3Array = line.get_global_points()
	var i: int = line.nearest_index(pos)
	var best: float = INF
	for j: int in [i - 1, i]:
		if j < 0 or j + 1 >= pts.size():
			continue
		var a: Vector2 = Vector2(pts[j].x, pts[j].z)
		var b: Vector2 = Vector2(pts[j + 1].x, pts[j + 1].z)
		var p: Vector2 = Vector2(pos.x, pos.z)
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best
