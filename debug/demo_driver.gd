extends Node
## Plays a fixed input timeline so the test track can be recorded hands-free.
## Lives in debug/test_track.tscn. Does nothing unless the game is launched with
##   godot --path . -- --demo
## Extra user args:
##   --demo-trace          print position / state / speed every 0.1 s
##   --demo-shots=<dir>    save PNG stills at the SHOTS times into <dir>
## Or, instead of --demo:
##   --landing-test        run debug/landing_test.gd (landing grade checks) and quit
##
## Godot note: everything after a bare `--` on the command line is ignored by
## the engine and handed to the game via OS.get_cmdline_user_args().
## Input.action_press() fakes an InputMap action exactly like a real gamepad,
## so the player code can't tell the difference.
##
## The timeline is in seconds of game time. It only lines up with the track
## when physics is deterministic, so record with --fixed-fps.

## [time, action, strength]. strength 0 releases the action.
const TIMELINE: Array[Array] = [
	[1.600, &"lean_forward", 1.00],
	[1.720, &"lean_forward", 0.00],
	[1.800, &"lean_forward", 1.00],
	[1.920, &"lean_forward", 0.00],
	[2.000, &"lean_forward", 1.00],
	[2.120, &"lean_forward", 0.00],
	[2.200, &"lean_forward", 1.00],
	[2.320, &"lean_forward", 0.00],
	[2.400, &"lean_forward", 1.00],
	[2.520, &"lean_forward", 0.00],
	[2.600, &"lean_forward", 1.00],
	[2.720, &"lean_forward", 0.00],
	[2.800, &"lean_forward", 1.00],
	[2.920, &"lean_forward", 0.00],
	[3.000, &"lean_forward", 1.00],
	[3.120, &"lean_forward", 0.00],
	[3.200, &"lean_forward", 1.00],
	[3.320, &"lean_forward", 0.00],
	[3.400, &"lean_forward", 1.00],
	[3.520, &"lean_forward", 0.00],
	[3.600, &"lean_forward", 1.00],
	[3.720, &"lean_forward", 0.00],
	[3.800, &"lean_forward", 1.00],
	[3.920, &"lean_forward", 0.00],
	[4.000, &"lean_forward", 1.00],
	[4.120, &"lean_forward", 0.00],
	[4.200, &"lean_forward", 1.00],
	[4.320, &"lean_forward", 0.00],
	[4.630, &"trick_right", 1.00],
	[4.730, &"trick_right", 0.00],
	[8.110, &"trick_up", 1.00],
	[8.210, &"trick_up", 0.00],
	[9.050, &"steer_left", 1.00],
	[9.400, &"steer_left", 0.00],
	[9.750, &"steer_right", 1.00],
	[9.820, &"grind", 1.00],
	[9.920, &"grind", 0.00],
	[10.100, &"steer_right", 0.00],
	[12.000, &"brake", 1.00],
	[20.000, &"brake", 0.00],
]

## [time, file name] for --demo-shots.
const SHOTS: Array[Array] = [
	[4.900, "v0.2_trick_whirl.png"],
	[6.700, "v0.2_speed_lines.png"],
	[8.470, "v0.2_trick_frontloop.png"],
	[10.600, "v0.2_grind.png"],
	[13.300, "v0.2_combo_banked.png"],
]

var _time: float = 0.0
var _next_step: int = 0
var _next_shot: int = 0
var _trace: bool = false
var _trace_timer: float = 0.0
var _shot_dir: String = ""
var _player: Player


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
	if _trace:
		Events.landed.connect(func(grade: StringName) -> void: print("t=%5.2f LANDED %s %.1f deg" % [_time, grade, _player.last_landing_angle]))
		Events.bailed.connect(func() -> void: print("t=%5.2f BAILED" % _time))
		Events.trick_completed.connect(func(trick_name: String, score: int) -> void: print("t=%5.2f TRICK %s +%d" % [_time, trick_name, score]))
		Events.grind_started.connect(func() -> void: print("t=%5.2f GRIND" % _time))
		Events.combo_banked.connect(func(score: int) -> void: print("t=%5.2f BANKED %d" % [_time, score]))


func _physics_process(delta: float) -> void:
	_time += delta
	while _next_step < TIMELINE.size() and float(TIMELINE[_next_step][0]) <= _time:
		var step: Array = TIMELINE[_next_step]
		var action: StringName = StringName(step[1])
		var strength: float = float(step[2])
		if strength > 0.0:
			Input.action_press(action, strength)
		else:
			Input.action_release(action)
		_next_step += 1

	if _trace and _player != null:
		_trace_timer -= delta
		if _trace_timer <= 0.0:
			_trace_timer = 0.1
			var p: Vector3 = _player.global_position
			print("t=%5.2f pos=(%6.2f %6.2f %7.2f) v=%5.1f vel=%s %s %s combo=%d run=%d pumps=%d" % [
				_time, p.x, p.y, p.z, _player.speed, _player.velocity.snappedf(0.1), _player.state_machine.get_state_name(),
				_player.tricks.current.display_name if _player.tricks.is_mid_trick() else "-",
				_player.combo.get_total(), _player.combo.run_total, _player.pump_count])


func _process(_delta: float) -> void:
	if _shot_dir.is_empty() or _next_shot >= SHOTS.size():
		return
	if float(SHOTS[_next_shot][0]) <= _time:
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png(_shot_dir.path_join(String(SHOTS[_next_shot][1])))
		_next_shot += 1
