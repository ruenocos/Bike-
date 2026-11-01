extends PlayerState
## Riding a rail. Position comes straight from the rail's curve instead of
## physics: each tick we move `_offset` metres along it and place the rider
## on that point. Leaves to Air at the rail's end or on a hop.
##
## msg: {"snap": RailSnap} from Player.find_grind_rail().

var _rail: Path3D
var _offset: float = 0.0
var _length: float = 0.0
## +1 rides toward the curve's last point, -1 toward its first.
var _direction: float = 1.0
## Leftover gap between where we snapped from and the rail, eased to zero.
var _snap_gap: Vector3 = Vector3.ZERO


func enter(msg: Dictionary) -> void:
	# Caught by a rail mid No Hander: it counts (hands back on for the grind).
	if player.no_hander:
		player.finish_no_hander()
	var t: PlayerTuning = player.tuning
	var snap: RailSnap = msg["snap"]
	_rail = snap.rail
	_offset = snap.offset
	_length = _rail.curve.get_baked_length()

	# Ride the way we were already going, at the speed we had along the rail.
	var tangent: Vector3 = RailSnap.tangent_at(_rail, _offset)
	var along: float = player.velocity.dot(tangent)
	_direction = 1.0 if along >= 0.0 else -1.0
	player.speed = clampf(absf(along), t.grind_min_speed, t.max_speed)

	_snap_gap = player.global_position - RailSnap.point_at(_rail, _offset)
	player.leave_surface()
	player.combo.add_action(0)
	Events.grind_started.emit()


func exit() -> void:
	player.grind_cooldown_timer = player.tuning.grind_resnap_cooldown


func physics_update(delta: float) -> void:
	var t: PlayerTuning = player.tuning
	var tangent: Vector3 = RailSnap.tangent_at(_rail, _offset) * _direction

	# Same slope gravity as riding (a downhill rail speeds you up), plus drag.
	var accel: float = -t.gravity * tangent.y - t.grind_drag + t.grind_accel
	player.speed = clampf(player.speed + accel * delta, 0.0, t.max_speed)
	player.velocity = tangent * player.speed
	player.heading = atan2(-tangent.x, -tangent.z)
	player.combo.add_grind_time(delta)

	if player.has_buffered_hop():
		player.do_hop_from(player.velocity)
		machine.transition_to(&"Air", {})
		return

	_offset += _direction * player.speed * delta
	if _offset < 0.0 or _offset > _length:
		player.velocity += Vector3.UP * t.grind_exit_pop
		machine.transition_to(&"Air", {})
		return
	if player.speed < t.grind_fall_off_speed:
		machine.transition_to(&"Air", {})
		return

	# Teleport onto the rail (no move_and_slide: the curve is the path).
	_snap_gap = _snap_gap.lerp(Vector3.ZERO, 1.0 - exp(-delta / maxf(t.grind_snap_time, 0.0001)))
	player.global_position = RailSnap.point_at(_rail, _offset) + _snap_gap
	player.update_visual(delta, 0.0, Vector3.UP)
