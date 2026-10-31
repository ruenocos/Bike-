extends Node
## Headless landing check. Drops the Player into common situations on the
## test track, plays a few inputs, and prints the grade and angle of every
## landing. Added by DemoDriver when the game is launched with
##   godot --headless --path . --fixed-fps 60 -- --landing-test
## and quits when done. Re-run it after changing landing tuning or the track.
## Add --landing-trace to print the player every 0.1 s, and
## --landing-only=<text> to run only scenarios whose name contains <text>.
##
## Each scenario: where to start, heading (0 = -Z, downhill), speed, inputs
## as [time, action, strength] (strength 0 releases), and whether a bail is
## the expected result. "hop_on_air" holds hop until the bike leaves the
## ground, then releases it: a perfectly timed coyote hop off a lip.
## "expect_landing" fails the scenario if the bike never leaves the ground and
## lands; "expect_no_landing" fails it if the bike leaves the ground at all.
## Halfpipe: "lip_min" lip airs needed, "carve_min" seconds of carving needed,
## "grades" lists the only grades allowed, "trick_on_lip" flicks that trick
## the moment a lip air starts, "expect_trick" needs a completed trick,
## "pump_min" needs that many pumps, "end_in_pipe" fails if the rider ends
## up on a deck or outside the pipe (|x| >= 8).

const SCENARIOS: Array[Dictionary] = [
	{"name": "flat deck hop, min charge", "pos": Vector3(0, 25.1, 12), "speed": 14.0,
		"inputs": [[0.2, &"hop", 1.0], [0.21, &"hop", 0.0]], "time": 2.0},
	{"name": "flat deck hop, full charge", "pos": Vector3(0, 25.1, 12), "speed": 14.0,
		"inputs": [[0.2, &"hop", 1.0], [0.5, &"hop", 0.0]], "time": 2.0},
	{"name": "flat deck hop, full charge, 18 m/s", "pos": Vector3(0, 25.1, 12), "speed": 18.0,
		"inputs": [[0.2, &"hop", 1.0], [0.5, &"hop", 0.0]], "time": 1.6},
	{"name": "flat deck hop, full charge, 3 m/s", "pos": Vector3(0, 25.1, 12), "speed": 3.0,
		"inputs": [[0.2, &"hop", 1.0], [0.5, &"hop", 0.0]], "time": 2.0},
	{"name": "slope hop, min charge", "pos": Vector3(0, 30, -90), "speed": 25.0,
		"inputs": [[0.3, &"hop", 1.0], [0.31, &"hop", 0.0]], "time": 1.5, "expect_landing": true},
	{"name": "slope hop, full charge", "pos": Vector3(0, 30, -90), "speed": 25.0,
		"inputs": [[0.3, &"hop", 1.0], [0.6, &"hop", 0.0]], "time": 2.0},
	{"name": "slope kicker, no input, 22 m/s", "pos": Vector3(0, 30, -58), "speed": 22.0,
		"inputs": [], "time": 2.5},
	{"name": "slope kicker, no input, 26 m/s", "pos": Vector3(0, 30, -58), "speed": 26.0,
		"inputs": [], "time": 2.5},
	{"name": "slope kicker, full hop on lip", "pos": Vector3(0, 30, -58), "speed": 24.0,
		"inputs": [[0.1, &"hop", 1.0]], "hop_on_air": true, "time": 2.5},
	{"name": "runout kicker -> tabletop, 15 m/s", "pos": Vector3(0, 5, -145), "speed": 15.0,
		"inputs": [], "time": 3.5},
	{"name": "runout kicker -> tabletop, 30 m/s", "pos": Vector3(0, 5, -145), "speed": 30.0,
		"inputs": [], "time": 3.0},
	{"name": "roll off tabletop side, 8 m/s", "pos": Vector3(1, 5, -175), "heading": -PI / 2.0, "speed": 8.0,
		"inputs": [], "time": 1.5},
	{"name": "roll off tabletop side diagonal, 20 m/s", "pos": Vector3(1, 5, -172), "heading": -PI / 4.0, "speed": 20.0,
		"inputs": [], "time": 1.5},
	# Frontloop flicked late, ~85% done at touchdown: completed for you, sketchy.
	{"name": "full hop + late Frontloop (auto-complete)", "pos": Vector3(0, 25.1, 12), "speed": 14.0,
		"inputs": [[0.2, &"hop", 1.0], [0.5, &"hop", 0.0], [0.65, &"trick_up", 1.0], [0.75, &"trick_up", 0.0]],
		"time": 1.8},
	# Should bail: flick a 0.75 s Frontloop off a tiny hop (lands ~55% done).
	{"name": "min hop + Frontloop (nose-dive)", "pos": Vector3(0, 25.1, 12), "speed": 14.0,
		"inputs": [[0.2, &"hop", 1.0], [0.21, &"hop", 0.0], [0.3, &"trick_up", 1.0], [0.4, &"trick_up", 0.0]],
		"time": 1.2, "expect_bail": true},
	# Bail, then the same mistake again inside bail_immunity: second one is sketchy.
	{"name": "nose-dive, then again while immune", "pos": Vector3(0, 25.1, 12), "speed": 10.0,
		"inputs": [[0.2, &"hop", 1.0], [0.21, &"hop", 0.0], [0.3, &"trick_up", 1.0], [0.4, &"trick_up", 0.0],
			[1.35, &"hop", 1.0], [1.36, &"hop", 0.0], [1.45, &"trick_up", 1.0], [1.55, &"trick_up", 0.0]],
		"time": 2.4, "expect_bail": true},
	# Halfpipe (z -282..-352, flat bottom x -4..4, full height from z -294 to -340).
	{"name": "halfpipe straight up -> lip air, 20 m/s", "pos": Vector3(0, 1, -317), "heading": -PI / 2.0, "speed": 20.0,
		"inputs": [], "lip_min": 1, "grades": [&"perfect", &"good"], "expect_landing": true, "time": 2.0},
	{"name": "halfpipe carve 45 deg -> lip air, 24 m/s", "pos": Vector3(0, 1, -298), "heading": -PI / 4.0, "speed": 24.0,
		"inputs": [], "lip_min": 1, "grades": [&"perfect", &"good"], "expect_landing": true, "time": 2.2},
	{"name": "halfpipe slow carve, no air, 13 m/s", "pos": Vector3(0, 1, -298), "heading": -PI / 4.0, "speed": 13.0,
		"inputs": [], "carve_min": 0.2, "expect_no_landing": true, "time": 2.0},
	{"name": "halfpipe lip air + Whirl Left, 22 m/s", "pos": Vector3(0, 1, -317), "heading": -PI / 2.0, "speed": 22.0,
		"inputs": [], "trick_on_lip": &"trick_left", "expect_trick": true, "lip_min": 1, "grades": [&"perfect", &"good"],
		"expect_landing": true, "time": 2.0},
	{"name": "halfpipe pump on the way down, 12 m/s", "pos": Vector3(0, 1, -317), "heading": -PI / 2.0, "speed": 12.0,
		"inputs": [[0.9, &"lean_forward", 1.0], [1.0, &"lean_forward", 0.0], [1.2, &"lean_forward", 1.0], [1.3, &"lean_forward", 0.0]],
		"pump_min": 1, "expect_no_landing": true, "time": 2.0},
	# Barely reaching the coping must not roll over it onto the deck.
	{"name": "halfpipe stall at the lip, 15.5 m/s", "pos": Vector3(0, 1, -317), "heading": -PI / 2.0, "speed": 15.5,
		"inputs": [], "lip_min": 1, "grades": [&"perfect", &"good"], "end_in_pipe": true, "time": 2.0},
	{"name": "halfpipe shallow carve over the lip, 18.6 m/s", "pos": Vector3(0, 1, -300), "heading": -0.95, "speed": 18.6,
		"inputs": [], "grades": [&"perfect", &"good"], "end_in_pipe": true, "time": 2.0},
	{"name": "runout -> halfpipe entry, 20 m/s", "pos": Vector3(0, 1, -268), "heading": 0.0, "speed": 20.0,
		"inputs": [], "expect_no_landing": true, "time": 2.5},
	{"name": "halfpipe entry ramp off the line, 15 m/s", "pos": Vector3(7, 1, -272), "heading": 0.0, "speed": 15.0,
		"inputs": [], "time": 2.0},
]

## Landings this early in a scenario are just the drop onto the start point.
const SETTLE_TIME: float = 0.15
const ACTIONS: Array[StringName] = [&"hop", &"trick_up", &"trick_left", &"pedal", &"brake", &"grind", &"steer_right", &"lean_forward"]

var _player: Player
var _index: int = -1
var _time: float = 0.0
var _step: int = 0
var _left_ground: bool = false
var _landings: Array[String] = []
var _bails: int = 0
var _left_ground_ever: bool = false
var _grades: Array[StringName] = []
var _lip_airs: int = 0
var _tricks: int = 0
var _carve_time: float = 0.0
var _pumps_at_start: int = 0
## Ticks since the on-lip trick flick was pressed (-1 = not yet).
var _flick_ticks: int = -1
var _rows: PackedStringArray = PackedStringArray()
var _failed: int = 0
var _trace: bool = false
var _trace_timer: float = 0.0
var _only: String = ""


func _ready() -> void:
	process_physics_priority = -100
	_player = get_tree().get_first_node_in_group(&"player") as Player
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_trace = args.has("--landing-trace")
	for arg: String in args:
		if arg.begins_with("--landing-only="):
			_only = arg.trim_prefix("--landing-only=")
	Events.landed.connect(_on_landed)
	Events.lip_air.connect(_on_lip_air)
	Events.trick_completed.connect(func(_trick_name: String, _score: int) -> void: _tricks += 1)


func _physics_process(delta: float) -> void:
	if _index < 0 or _time >= float(SCENARIOS[_index]["time"]):
		if _index >= 0:
			_finish_scenario()
		_index += 1
		while not _only.is_empty() and _index < SCENARIOS.size() and not String(SCENARIOS[_index]["name"]).contains(_only):
			_index += 1
		if _index >= SCENARIOS.size():
			_report()
			return
		_start_scenario()
		return

	var s: Dictionary = SCENARIOS[_index]
	_time += delta
	var inputs: Array = s["inputs"]
	while _step < inputs.size() and float(inputs[_step][0]) <= _time:
		var action: StringName = StringName(inputs[_step][1])
		var strength: float = float(inputs[_step][2])
		if strength > 0.0:
			Input.action_press(action, strength)
		else:
			Input.action_release(action)
		_step += 1
	if s.get("hop_on_air", false) and _time > 0.3 and not _left_ground and _player.state_machine.get_state_name() == &"Air":
		_left_ground = true
		Input.action_release(&"hop")

	var state: StringName = _player.state_machine.get_state_name()
	if _trace:
		_trace_timer -= delta
		if _trace_timer <= 0.0:
			_trace_timer = 0.1
			var p: Vector3 = _player.global_position
			print("  t=%4.2f pos=(%6.2f %5.2f %7.2f) v=%5.1f vel=%s n=%s %s" % [_time, p.x, p.y, p.z, _player.speed,
				_player.velocity.snappedf(0.1), _player.ground_normal.snappedf(0.01), state])
	if _time > SETTLE_TIME and state == &"Air":
		_left_ground_ever = true
	if (state == &"Ride" or state == &"Land") and _player.ground_normal.y < cos(deg_to_rad(_player.tuning.carve_min_angle_deg)):
		_carve_time += delta
	# The flick is a tap: release it two ticks later.
	if _flick_ticks >= 0:
		_flick_ticks += 1
		if _flick_ticks == 2:
			Input.action_release(StringName(s["trick_on_lip"]))


func _on_lip_air() -> void:
	if _index < 0 or _index >= SCENARIOS.size():
		return
	_lip_airs += 1
	var s: Dictionary = SCENARIOS[_index]
	if s.has("trick_on_lip") and _flick_ticks < 0:
		Input.action_press(StringName(s["trick_on_lip"]))
		_flick_ticks = 0


func _start_scenario() -> void:
	var s: Dictionary = SCENARIOS[_index]
	for action: StringName in ACTIONS:
		if Input.is_action_pressed(action):
			Input.action_release(action)
	_time = 0.0
	_step = 0
	_left_ground = false
	_landings.clear()
	_bails = 0
	_left_ground_ever = false
	_grades.clear()
	_lip_airs = 0
	_tricks = 0
	_carve_time = 0.0
	_pumps_at_start = _player.pump_count
	_flick_ticks = -1

	# Drop onto the ground under the start point.
	var start: Vector3 = s["pos"]
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start + Vector3.UP * 50.0, start + Vector3.DOWN * 100.0)
	query.exclude = [_player.get_rid()]
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		start = hit["position"] + Vector3.UP * 0.05

	var p: Player = _player
	p.place(start, float(s.get("heading", 0.0)), float(s["speed"]))
	p.hop_charge = 0.0
	p.jump_buffer_timer = 0.0
	p.combo.drop()
	p.state_machine.transition_to(&"Ride", {})
	# After the transition: leaving Bail starts the immunity window.
	p.bail_immunity_timer = 0.0


func _on_landed(grade: StringName) -> void:
	# Skip the touchdown from being placed on the ground.
	if _index < 0 or _index >= SCENARIOS.size() or _time < SETTLE_TIME:
		return
	var entry: String = "%s %.1f°" % [String(grade).to_upper(), _player.last_landing_angle]
	if grade == &"bail":
		_bails += 1
		entry += " (%s)" % _player.last_bail_reason
	_landings.append(entry)
	_grades.append(grade)


func _finish_scenario() -> void:
	var s: Dictionary = SCENARIOS[_index]
	var expect_bail: bool = s.get("expect_bail", false)
	var ok: bool = (_bails > 0) == expect_bail
	if s.get("expect_landing", false) and _landings.is_empty():
		ok = false
	if s.get("expect_no_landing", false) and (_left_ground_ever or not _landings.is_empty()):
		ok = false
	if _lip_airs < int(s.get("lip_min", 0)):
		ok = false
	if _carve_time < float(s.get("carve_min", 0.0)):
		ok = false
	if s.get("expect_trick", false) and _tricks == 0:
		ok = false
	if _player.pump_count - _pumps_at_start < int(s.get("pump_min", 0)):
		ok = false
	if s.get("end_in_pipe", false) and absf(_player.global_position.x) >= 8.0:
		ok = false
	if s.has("grades"):
		var allowed: Array = s["grades"]
		for grade: StringName in _grades:
			if not allowed.has(grade):
				ok = false
	if not ok:
		_failed += 1
	var landings: String = ", ".join(_landings) if not _landings.is_empty() else "roll-in only"
	if _lip_airs > 0 or _carve_time > 0.0:
		landings = "lip airs %d, carve %.2fs, tricks %d, %s" % [_lip_airs, _carve_time, _tricks, landings]
	if s.has("pump_min"):
		landings = "pumps %d, %s" % [_player.pump_count - _pumps_at_start, landings]
	_rows.append("%-4s | %-40s | %s" % ["ok" if ok else "FAIL", s["name"], landings])


func _report() -> void:
	set_physics_process(false)
	print("LANDING TEST")
	for row: String in _rows:
		print(row)
	print("LANDING TEST %s (%d/%d ok)" % ["PASSED" if _failed == 0 else "FAILED", _rows.size() - _failed, _rows.size()])
	get_tree().quit(1 if _failed > 0 else 0)
