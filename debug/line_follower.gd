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


## Distance to the start of the next rail (or a falling tree's trunk, v0.13)
## straight ahead (within `lane` m sideways of where you're heading), or INF. Rails are ledges you hop onto
## (v0.9.1), so the bots charge a hop and let go about speed x 0.3 s before.
static func rail_ahead(player: Player, lane: float = 5.0) -> float:
	var going: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	if going.length() < 1.0:
		return INF
	going = going.normalized()
	var best: float = INF
	for node: Node in player.get_tree().get_nodes_in_group(&"rails"):
		var rail: Path3D = node as Path3D
		if rail == null or not rail.is_inside_tree() or rail.curve == null or rail.curve.point_count < 2:
			continue
		var start: Vector3 = rail.to_global(rail.curve.get_point_position(0))
		var to: Vector3 = start - player.global_position
		to.y = 0.0
		var ahead: float = to.dot(going)
		if ahead > 0.0 and (to - going * ahead).length() < lane:
			best = minf(best, ahead)
	# v0.13: a falling tree's trunk across the way gets hopped like a rail start.
	for node: Node in player.get_tree().get_nodes_in_group(&"hop_hazards"):
		var tree: FallingTree = node as FallingTree
		if tree == null or not tree.is_inside_tree():
			continue
		# Where our straight-ahead path crosses the trunk (base to tip, 2D).
		var base: Vector2 = Vector2(tree.global_position.x, tree.global_position.z)
		var tip3: Vector3 = tree.global_position - tree.global_basis.z * tree.trunk_length
		var span: Vector2 = Vector2(tip3.x, tip3.z) - base
		var p: Vector2 = Vector2(player.global_position.x, player.global_position.z)
		var dir: Vector2 = Vector2(going.x, going.z)
		var denom: float = dir.x * span.y - dir.y * span.x
		if absf(denom) < 0.0001:
			continue
		var w: Vector2 = base - p
		var t: float = (w.x * span.y - w.y * span.x) / denom
		var u: float = (w.x * dir.y - w.y * dir.x) / denom
		if t > 0.0 and u > -0.15 and u < 1.15:
			best = minf(best, t)
	return best


## Presses / releases hop to jump onto a rail coming up: hold from
## speed x 0.6 s out (full charge), let go at speed x 0.3 s.
static func hop_for_rails(player: Player) -> void:
	var state: StringName = player.state_machine.get_state_name()
	if state != &"Ride":
		return
	var d: float = rail_ahead(player)
	var v: float = maxf(player.speed, 1.0)
	if d < v * 0.6 and d > v * 0.3:
		Input.action_press(&"hop")
	elif d <= v * 0.3 and Input.is_action_pressed(&"hop"):
		Input.action_release(&"hop")