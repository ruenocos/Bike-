extends Node
## Headless landing check. Drops the Player into common situations on the
## test track, plays a few inputs, and prints the grade and angle of every
## landing. Added by DemoDriver when the game is launched with
##   godot --headless --path . --fixed-fps 60 -- --landing-test
## and quits when done. Re-run it after changing landing tuning or the track.
##
## Each scenario: where to start, heading (0 = -Z, downhill), speed, inputs
## as [time, action, strength] (strength 0 releases), and whether a bail is
## the expected result. "hop_on_air" holds hop until the bike leaves the
## ground, then releases it: a perfectly timed coyote hop off a lip.

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
		"inputs": [[0.3, &"hop", 1.0], [0.31, &"hop", 0.0]], "time": 1.5},
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
]

## Landings this early in a scenario are just the drop onto the start point.
const SETTLE_TIME: float = 0.15
const ACTIONS: Array[StringName] = [&"hop", &"trick_up", &"pedal", &"brake", &"grind"]

var _player: Player
var _index: int = -1
var _time: float = 0.0
var _step: int = 0
var _left_ground: bool = false
var _landings: Array[String] = []
var _bails: int = 0
var _rows: PackedStringArray = PackedStringArray()
var _failed: int = 0


func _ready() -> void:
	process_physics_priority = -100
	_player = get_tree().get_first_node_in_group(&"player") as Player
	Events.landed.connect(_on_landed)


func _physics_process(delta: float) -> void:
	if _index < 0 or _time >= float(SCENARIOS[_index]["time"]):
		if _index >= 0:
			_finish_scenario()
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

	# Drop onto the ground under the start point.
	var start: Vector3 = s["pos"]
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start + Vector3.UP * 50.0, start + Vector3.DOWN * 100.0)
	query.exclude = [_player.get_rid()]
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		start = hit["position"] + Vector3.UP * 0.05

	var p: Player = _player
	p.global_position = start
	p.heading = float(s.get("heading", 0.0))
	p.speed = float(s["speed"])
	p.velocity = p.get_heading_dir() * p.speed
	p.hop_charge = 0.0
	p.jump_buffer_timer = 0.0
	p.tricks.cancel()
	p.combo.drop()
	p.reset_physics_interpolation()
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


func _finish_scenario() -> void:
	var s: Dictionary = SCENARIOS[_index]
	var expect_bail: bool = s.get("expect_bail", false)
	var ok: bool = (_bails > 0) == expect_bail
	if not ok:
		_failed += 1
	var landings: String = ", ".join(_landings) if not _landings.is_empty() else "roll-in only"
	_rows.append("%-4s | %-40s | %s" % ["ok" if ok else "FAIL", s["name"], landings])


func _report() -> void:
	set_physics_process(false)
	print("LANDING TEST")
	for row: String in _rows:
		print(row)
	print("LANDING TEST %s (%d/%d ok)" % ["PASSED" if _failed == 0 else "FAILED", _rows.size() - _failed, _rows.size()])
	get_tree().quit(1 if _failed > 0 else 0)
