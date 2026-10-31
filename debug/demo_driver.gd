extends Node
## Plays a fixed input script so the test track can be recorded hands-free.
## Lives in debug/test_track.tscn. Does nothing unless the game is launched with
##   godot --path . res://debug/test_track.tscn -- --demo
## Extra user args:
##   --demo-trace          print position / state / speed every 0.1 s
##   --demo-shots=<dir>    save PNG stills at the SHOTS cues into <dir>
## Or, instead of --demo:
##   --landing-test        run debug/landing_test.gd (landing grade checks) and quit
##
## Godot note: everything after a bare `--` on the command line is ignored by
## the engine and handed to the game via OS.get_cmdline_user_args().
## Input.action_press() fakes an InputMap action exactly like a real gamepad,
## so the player code can't tell the difference.
##
## Steps hang off cues: a cue fires the first time the rider passes its z
## (the track runs toward -Z), and a step plays `dt` seconds after its cue.
## So a step stays lined up with its feature even when the speed before it
## changes. Steps run in order. Record with --fixed-fps so it's deterministic.
## Helper "actions" (still only InputMap presses underneath):
##   autosteer  1 = steer along TrackLine (and straight on past its end), 0 = off
##   aim_x      sideways offset from that line for autosteer (m, + = right)
##   brake_to   hold brake while faster than this (m/s), 0 = off

## Cue name -> z the rider must pass. "start" fires at t 0.
const CUES: Dictionary[StringName, float] = {
	&"start": INF,
	&"dropin": 298.0,
	&"rollers": 254.0,
	&"kicker1": 173.2,
	&"berm": 122.7,
	&"kicker2_ramp": 11.0,
	&"kicker2": 2.9,
	&"bottom": -128.0,
	&"runout_kicker": -223.3,
	&"table_end": -239.6,
	&"rail": -262.0,
	&"rail_end": -305.0,
	&"pipe": -345.3,
}

## [cue, dt, action, strength]. strength 0 releases the action.
const TIMELINE: Array[Array] = [
	[&"start", 0.0, &"autosteer", 1.0],
	# Drop-in: pump the steepening top.
	[&"dropin", 0.05, &"lean_forward", 1.0],
	[&"dropin", 0.15, &"lean_forward", 0.0],
	# Pump line: tap forward every 0.2 s over the rollers.
	[&"rollers", 0.0, &"lean_forward", 1.0], [&"rollers", 0.1, &"lean_forward", 0.0],
	[&"rollers", 0.2, &"lean_forward", 1.0], [&"rollers", 0.3, &"lean_forward", 0.0],
	[&"rollers", 0.4, &"lean_forward", 1.0], [&"rollers", 0.5, &"lean_forward", 0.0],
	[&"rollers", 0.6, &"lean_forward", 1.0], [&"rollers", 0.7, &"lean_forward", 0.0],
	[&"rollers", 0.8, &"lean_forward", 1.0], [&"rollers", 0.9, &"lean_forward", 0.0],
	[&"rollers", 1.0, &"lean_forward", 1.0], [&"rollers", 1.1, &"lean_forward", 0.0],
	[&"rollers", 1.2, &"lean_forward", 1.0], [&"rollers", 1.3, &"lean_forward", 0.0],
	[&"rollers", 1.4, &"lean_forward", 1.0], [&"rollers", 1.5, &"lean_forward", 0.0],
	[&"rollers", 1.6, &"lean_forward", 1.0], [&"rollers", 1.7, &"lean_forward", 0.0],
	[&"rollers", 1.8, &"lean_forward", 1.0], [&"rollers", 1.9, &"lean_forward", 0.0],
	[&"rollers", 2.0, &"lean_forward", 1.0], [&"rollers", 2.1, &"lean_forward", 0.0],
	# Kicker 1: Whirl Right off the lip, land down the slope.
	[&"kicker1", 0.03, &"trick_right", 1.0],
	[&"kicker1", 0.13, &"trick_right", 0.0],
	# Kicker 2: full hop off the lip, Frontloop chained into Whirl Left.
	[&"kicker2_ramp", 0.0, &"hop", 1.0],
	[&"kicker2", 0.0, &"hop", 0.0],
	[&"kicker2", 0.1, &"trick_up", 1.0],
	[&"kicker2", 0.2, &"trick_up", 0.0],
	[&"kicker2", 0.7, &"trick_left", 1.0],
	[&"kicker2", 0.8, &"trick_left", 0.0],
	# Runout: scrub speed for the tabletop, hop + Pocket off its deck.
	[&"bottom", 0.0, &"brake_to", 37.0],
	[&"runout_kicker", 0.0, &"brake_to", 0.0],
	[&"table_end", 0.0, &"hop", 1.0],
	[&"table_end", 0.03, &"hop", 0.0],
	[&"table_end", 0.08, &"trick_down", 1.0],
	[&"table_end", 0.18, &"trick_down", 0.0],
	# Rail on the left.
	[&"table_end", 0.3, &"aim_x", -8.0],
	[&"rail", 0.1, &"grind", 1.0],
	[&"rail", 0.2, &"grind", 0.0],
	# Line up with the halfpipe at x -3, ~19.5 m/s, then the v0.4 pipe run.
	[&"rail_end", 0.3, &"aim_x", -3.0],
	[&"rail_end", 0.3, &"brake_to", 19.6],
	[&"pipe", 0.0, &"brake_to", 0.0],
	[&"pipe", 0.0, &"autosteer", 0.0],
	[&"pipe", 0.13, &"steer_right", 1.0],
	[&"pipe", 0.83, &"steer_right", 0.0],
	[&"pipe", 2.28, &"lean_forward", 1.0],
	[&"pipe", 2.36, &"lean_forward", 0.0],
	[&"pipe", 2.38, &"steer_left", 1.0],
	[&"pipe", 2.48, &"steer_left", 0.0],
	[&"pipe", 3.40, &"trick_left", 1.0],
	[&"pipe", 3.50, &"trick_left", 0.0],
	[&"pipe", 4.48, &"lean_forward", 1.0],
	[&"pipe", 4.56, &"lean_forward", 0.0],
	[&"pipe", 5.55, &"trick_up", 1.0],
	[&"pipe", 5.65, &"trick_up", 0.0],
	# Out of the last carve: turn down the pipe and ride out the end.
	[&"pipe", 6.93, &"steer_right", 1.0],
	[&"pipe", 7.68, &"steer_right", 0.0],
	[&"pipe", 9.18, &"brake", 1.0],
]

## [cue, dt, file name] for --demo-shots.
const SHOTS: Array[Array] = [
	[&"dropin", 0.9, "v0.5_drop_in.png"],
	[&"kicker1", 0.4, "v0.5_kicker_air_over_slope.png"],
	[&"berm", 1.3, "v0.5_berm_turn.png"],
	[&"kicker2", 1.6, "v0.5_top_speed_lines.png"],
	[&"rail", 0.8, "v0.5_grind.png"],
	[&"pipe", 3.6, "v0.5_halfpipe_whirl.png"],
]

var _time: float = 0.0
var _next_step: int = 0
var _next_shot: int = 0
var _cue_times: Dictionary[StringName, float] = {}
var _trace: bool = false
var _trace_timer: float = 0.0
var _shot_dir: String = ""
var _player: Player
var _line: Path3D
var _autosteer: bool = false
var _aim_x: float = 0.0
var _brake_to: float = 0.0
var _top_speed: float = 0.0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--landing-test"):
		add_child(preload("res://debug/landing_test.gd").new())
	if not args.has("--demo"):
		set_physics_process(false)
		set_process(false)
		return
	_trace = args.has("--demo-trace")
	for arg: String in args:
		if arg.begins_with("--demo-shots="):
			_shot_dir = arg.trim_prefix("--demo-shots=")
	# Run before the Player each physics tick, so a press lands on the same tick.
	process_physics_priority = -100
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_line = get_node_or_null(^"../TrackLine") as Path3D
	if _trace:
		Events.landed.connect(func(grade: StringName) -> void: print("t=%5.2f LANDED %s %.1f deg" % [_time, grade, _player.last_landing_angle]))
		Events.bailed.connect(func() -> void: print("t=%5.2f BAILED" % _time))
		Events.trick_completed.connect(func(trick_name: String, score: int) -> void: print("t=%5.2f TRICK %s +%d" % [_time, trick_name, score]))
		Events.grind_started.connect(func() -> void: print("t=%5.2f GRIND" % _time))
		Events.carve_started.connect(func() -> void: print("t=%5.2f CARVE" % _time))
		Events.lip_air.connect(func() -> void: print("t=%5.2f LIP AIR" % _time))
		Events.combo_banked.connect(func(score: int) -> void: print("t=%5.2f BANKED %d" % [_time, score]))


func _physics_process(delta: float) -> void:
	_time += delta
	if _player == null:
		return
	var z: float = _player.global_position.z
	for cue: StringName in CUES:
		if not _cue_times.has(cue) and z < CUES[cue]:
			_cue_times[cue] = _time
			if _trace:
				print("t=%5.2f CUE %s" % [_time, cue])

	while _next_step < TIMELINE.size() and _is_due(TIMELINE[_next_step][0], TIMELINE[_next_step][1]):
		var step: Array = TIMELINE[_next_step]
		_apply(StringName(step[2]), float(step[3]))
		_next_step += 1

	if _autosteer:
		_steer_along_line()
	if _brake_to > 0.0:
		if _player.speed > _brake_to:
			Input.action_press(&"brake")
		else:
			Input.action_release(&"brake")
	_top_speed = maxf(_top_speed, _player.speed)

	if _trace:
		_trace_timer -= delta
		if _trace_timer <= 0.0:
			_trace_timer = 0.1
			var p: Vector3 = _player.global_position
			print("t=%5.2f pos=(%6.2f %6.2f %7.2f) v=%5.1f top=%5.1f %s %s combo=%d run=%d pumps=%d" % [
				_time, p.x, p.y, p.z, _player.speed, _top_speed, _player.state_machine.get_state_name(),
				_player.tricks.current.display_name if _player.tricks.is_mid_trick() else "-",
				_player.combo.get_total(), _player.combo.run_total, _player.pump_count])


func _is_due(cue: Variant, dt: Variant) -> bool:
	var name: StringName = StringName(cue)
	return _cue_times.has(name) and _time >= _cue_times[name] + float(dt)


func _apply(action: StringName, strength: float) -> void:
	match action:
		&"autosteer":
			_autosteer = strength > 0.0
			if not _autosteer:
				Input.action_release(&"steer_left")
				Input.action_release(&"steer_right")
		&"aim_x":
			_aim_x = strength
		&"brake_to":
			_brake_to = strength
			if strength <= 0.0:
				Input.action_release(&"brake")
		_:
			if strength > 0.0:
				Input.action_press(action, strength)
			else:
				Input.action_release(action)


## Steers toward a point on TrackLine (aim_x to the side), with a feed-forward
## for the line's curvature. Past the line's end it keeps going straight.
func _steer_along_line() -> void:
	if _line == null:
		return
	var curve: Curve3D = _line.curve
	var pos: Vector3 = _player.global_position
	var length: float = curve.get_baked_length()
	var offset: float = curve.get_closest_offset(_line.to_local(pos))
	var point: Vector3 = _line.to_global(curve.sample_baked(offset))
	var tangent: Vector3 = _line_dir(offset)
	if offset >= length - 1.0:
		# Straight on past the end.
		point = point + tangent * tangent.dot(pos - point)
	var right: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)
	var target: Vector3 = point + right * _aim_x
	var lateral: float = (pos - target).dot(right)
	var flat_velocity: Vector3 = Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	var across: float = flat_velocity.normalized().dot(right) if flat_velocity.length() > 0.5 else 0.0
	# Curvature ahead (signed, + = bends right) -> yaw rate needed -> stick.
	var ahead: Vector3 = _line_dir(minf(offset + 6.0, length))
	var curvature: float = (ahead - tangent).dot(right) / 6.0
	var t: PlayerTuning = _player.tuning
	var steer_rate: float = deg_to_rad(lerpf(t.steer_rate_low, t.steer_rate_high, clampf(_player.speed / t.max_speed, 0.0, 1.0)))
	# Lateral error -> how much to head across the line -> stick.
	var want_across: float = clampf(-lateral * 0.2, -0.5, 0.5)
	var steer: float = _player.speed * curvature / steer_rate + (want_across - across) * 4.0
	steer = clampf(steer, -1.0, 1.0)
	if steer >= 0.0:
		Input.action_release(&"steer_left")
		Input.action_press(&"steer_right", maxf(steer, 0.001))
	else:
		Input.action_release(&"steer_right")
		Input.action_press(&"steer_left", -steer)


func _line_dir(offset: float) -> Vector3:
	var curve: Curve3D = _line.curve
	var a: Vector3 = curve.sample_baked(maxf(offset - 1.0, 0.0))
	var b: Vector3 = curve.sample_baked(minf(offset + 1.0, curve.get_baked_length()))
	var dir: Vector3 = _line.global_basis * (b - a)
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD


func _process(_delta: float) -> void:
	if _shot_dir.is_empty() or _next_shot >= SHOTS.size():
		return
	if _is_due(SHOTS[_next_shot][0], SHOTS[_next_shot][1]):
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png(_shot_dir.path_join(String(SHOTS[_next_shot][2])))
		_next_shot += 1
