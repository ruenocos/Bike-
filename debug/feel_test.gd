extends Node3D
## Headless feel checks on the real chunk scenes (rails, kickers):
##   - rails (v0.9.1): a hop onto the rail ledge catches it by itself (also
##     2 m off, the air assist), no hop into the ledge crashes, beside it rides past
##   - kicker airtime: no input off each kicker at 45-56 m/s, airtime in range
##     and a perfect landing
##   - trick chain: two tricks off the big air at 52 m/s land clean
## Run:  <exe> --headless --path . --fixed-fps 60 res://debug/feel_test.tscn
## Add -- --feel-trace to print the rider every 0.1 s, --feel-only=<text> to
## run only scenarios whose name contains <text>. Exits 1 on failure.
##
## A scenario starts `back` m up the hill from a node in the chunk (Entry,
## Kicker1, Rail1...), `side` m to the right, at `speed`. Inputs are
## [time, action, strength] (strength 0 releases). Checks: "grind" = name of
## the rail it must catch, "air" = [min, max] airtime of the longest air,
## "grades" = landing grades allowed, "tricks" = completed tricks needed.

const PLAYER: PackedScene = preload("res://player/player.tscn")

const SCENARIOS: Array[Dictionary] = [
	# v0.9.1 rails are ledges: hop onto them (no grind button), riding into one crashes.
	{"name": "rail 1, hop onto it, 50 m/s", "chunk": "chunk_rail", "at": "Rail1", "back": 35.0, "side": -5.0, "speed": 50.0,
		"inputs": [[0.15, &"hop", 1.0], [0.42, &"hop", 0.0]], "grind": "Rail1", "time": 2.0},
	{"name": "rail 1, hop 2 m left of it, 50 m/s (air assist)", "chunk": "chunk_rail", "at": "Rail1", "back": 35.0, "side": -3.0, "speed": 50.0,
		"inputs": [[0.15, &"hop", 1.0], [0.42, &"hop", 0.0]], "grind": "Rail1", "time": 2.0},
	{"name": "rail 1, hop 8 m away: out of reach", "chunk": "chunk_rail", "at": "Rail1", "back": 35.0, "side": 3.0, "speed": 50.0,
		"inputs": [[0.15, &"hop", 1.0], [0.42, &"hop", 0.0]], "no_grind": true, "time": 2.0},
	{"name": "rail 2, hop onto it, 56 m/s", "chunk": "chunk_rail", "at": "Rail2", "back": 45.0, "side": 5.0, "speed": 56.0,
		"inputs": [[0.25, &"hop", 1.0], [0.52, &"hop", 0.0]], "grind": "Rail2", "time": 2.0},
	{"name": "rail 1, no hop: rides into the ledge and crashes", "chunk": "chunk_rail", "at": "Rail1", "back": 35.0, "side": -5.0, "speed": 50.0,
		"inputs": [], "no_grind": true, "crash": true, "time": 2.0},
	{"name": "rail 1, beside it, no hop: rides past", "chunk": "chunk_rail", "at": "Rail1", "back": 35.0, "side": -1.0, "speed": 50.0,
		"inputs": [], "no_grind": true, "time": 2.0},	{"name": "kicker 1, no input, 45 m/s", "chunk": "chunk_kickers", "at": "Kicker1", "back": 40.0, "speed": 45.0,
		"inputs": [], "air": [0.7, 1.6], "grades": [&"perfect"], "time": 3.0},
	{"name": "kicker 1, no input, 50 m/s", "chunk": "chunk_kickers", "at": "Kicker1", "back": 40.0, "speed": 50.0,
		"inputs": [], "air": [1.0, 1.6], "grades": [&"perfect"], "time": 3.0},
	{"name": "kicker 1, no input, 55 m/s", "chunk": "chunk_kickers", "at": "Kicker1", "back": 40.0, "speed": 55.0,
		"inputs": [], "air": [1.0, 1.8], "grades": [&"perfect"], "time": 3.0},
	{"name": "kicker 1, slow 30 m/s, no bail", "chunk": "chunk_kickers", "at": "Kicker1", "back": 40.0, "speed": 30.0,
		"inputs": [], "grades": [&"perfect", &"good"], "time": 3.0},
	{"name": "kicker 2, no input, 50 m/s", "chunk": "chunk_kickers", "at": "Kicker2", "back": 40.0, "speed": 50.0,
		"inputs": [], "air": [1.0, 1.6], "grades": [&"perfect"], "time": 3.0},
	# Below its design speed the big air lands on the knuckle: short, still clean.
	{"name": "big air, no input, 45 m/s", "chunk": "chunk_big_air", "at": "Kicker1", "back": 40.0, "speed": 45.0,
		"inputs": [], "air": [0.5, 2.6], "grades": [&"perfect", &"good"], "time": 4.0},
	{"name": "big air, no input, 50 m/s", "chunk": "chunk_big_air", "at": "Kicker1", "back": 40.0, "speed": 50.0,
		"inputs": [], "air": [1.6, 2.4], "grades": [&"perfect"], "time": 4.0},
	{"name": "big air, no input, 55 m/s", "chunk": "chunk_big_air", "at": "Kicker1", "back": 40.0, "speed": 55.0,
		"inputs": [], "air": [1.7, 2.6], "grades": [&"perfect"], "time": 4.0},
	{"name": "big air, slow 30 m/s, no bail", "chunk": "chunk_big_air", "at": "Kicker1", "back": 40.0, "speed": 30.0,
		"inputs": [], "grades": [&"perfect", &"good", &"sketchy"], "time": 4.0},
	{"name": "big air, Frontloop + Whirl Left, 52 m/s", "chunk": "chunk_big_air", "at": "Kicker1", "back": 40.0, "speed": 52.0,
		"trick_on_air": [[0.0, &"trick_up"], [0.6, &"trick_left"]], "inputs": [], "tricks": 2,
		"grades": [&"perfect", &"good"], "time": 4.0},
]

const ACTIONS: Array[StringName] = [&"grind", &"hop", &"trick_up", &"trick_left", &"steer_left", &"steer_right"]
## Landings this early are just the drop onto the start point.
const SETTLE_TIME: float = 0.15

var _player: Player
var _chunk: Chunk
var _chunk_name: String = ""
var _index: int = -1
var _time: float = 0.0
var _step: int = 0
var _air_time: float = 0.0
var _longest_air: float = 0.0
var _air_start: float = -1.0
var _grades: Array[StringName] = []
var _angles: PackedFloat32Array = PackedFloat32Array()
var _tricks: int = 0
var _crashes: int = 0
var _grinds: PackedStringArray = PackedStringArray()
var _flicks: Array = []
var _flick_release: Dictionary[StringName, int] = {}
var _waiting: int = 0
var _rows: PackedStringArray = PackedStringArray()
var _failed: int = 0
var _trace: bool = false
var _trace_timer: float = 0.0
var _only: String = ""


func _ready() -> void:
	process_physics_priority = -100
	_trace = OS.get_cmdline_user_args().has("--feel-trace")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--feel-only="):
			_only = arg.trim_prefix("--feel-only=")
	_player = PLAYER.instantiate() as Player
	add_child(_player)
	# The chunks descend hundreds of metres; never "fall off the world" here.
	_player.kill_y = -100000.0
	Events.landed.connect(_on_landed)
	Events.trick_completed.connect(func(_n: String, _s: int) -> void: _tricks += 1)
	Events.grind_started.connect(_on_grind_started)
	Events.bailed.connect(func() -> void: _crashes += 1)


func _physics_process(delta: float) -> void:
	if _waiting > 0:
		# CSG builds its collision a frame or two after the chunk enters the tree.
		_waiting -= 1
		if _waiting == 0:
			_place()
		return
	if _index < 0 or _time >= float(SCENARIOS[_index]["time"]):
		if _index >= 0:
			_finish()
		_index += 1
		while not _only.is_empty() and _index < SCENARIOS.size() and not String(SCENARIOS[_index]["name"]).contains(_only):
			_index += 1
		if _index >= SCENARIOS.size():
			_report()
			return
		_start()
		return

	var s: Dictionary = SCENARIOS[_index]
	_time += delta
	var inputs: Array = s["inputs"]
	while _step < inputs.size() and float(inputs[_step][0]) <= _time:
		var action: StringName = StringName(inputs[_step][1])
		if float(inputs[_step][2]) > 0.0:
			Input.action_press(action, float(inputs[_step][2]))
		else:
			Input.action_release(action)
		_step += 1

	var air: bool = _player.state_machine.get_state_name() == &"Air" and _time > SETTLE_TIME
	if air and _air_start < 0.0:
		_air_start = _time
	if not air and _air_start >= 0.0:
		_longest_air = maxf(_longest_air, _time - _air_start)
		_air_start = -1.0
	# Flicks timed from takeoff (the first air longer than a few ticks).
	if _air_start >= 0.0:
		for flick: Array in _flicks:
			if not flick[2] and _time - _air_start >= float(flick[0]):
				flick[2] = true
				Input.action_press(flick[1])
				_flick_release[flick[1]] = 2
	for action: StringName in _flick_release.keys():
		_flick_release[action] -= 1
		if _flick_release[action] <= 0:
			Input.action_release(action)
			_flick_release.erase(action)

	if _trace:
		_trace_timer -= delta
		if _trace_timer <= 0.0:
			_trace_timer = 0.1
			var p: Vector3 = _chunk.to_local(_player.global_position)
			print("  t=%4.2f local=(%6.2f %7.2f %7.2f) v=%5.1f %s" % [_time, p.x, p.y, p.z, _player.velocity.length(), _player.state_machine.get_state_name()])


func _start() -> void:
	var s: Dictionary = SCENARIOS[_index]
	for action: StringName in ACTIONS:
		Input.action_release(action)
	_time = 0.0
	_step = 0
	_longest_air = 0.0
	_air_start = -1.0
	_grades.clear()
	_crashes = 0
	_angles.clear()
	_tricks = 0
	_grinds.clear()
	_flick_release.clear()
	_flicks = []
	for flick: Array in s.get("trick_on_air", []):
		_flicks.append([flick[0], flick[1], false])
	if s["chunk"] != _chunk_name:
		if _chunk != null:
			_chunk.free()
		_chunk_name = s["chunk"]
		_chunk = (load("res://chunks/%s.tscn" % _chunk_name) as PackedScene).instantiate() as Chunk
		add_child(_chunk)
		_waiting = 12
		# Park the rider off to the side while the chunk's collision builds.
		_player.place(Vector3(0.0, 500.0, 0.0), 0.0, 0.0)
		_player.set_physics_process(false)
		return
	_place()


## Drops the rider onto the track `back` m up the hill from the scenario's node.
func _place() -> void:
	var s: Dictionary = SCENARIOS[_index]
	var node: Node3D = _chunk.get_node(String(s["at"])) as Node3D
	var anchor: Vector3 = node.global_position
	if node is Path3D:
		var path: Path3D = node as Path3D
		anchor = path.to_global(path.curve.get_point_position(0))
	# Find the centerline point nearest to the anchor, then walk back up it.
	var points: PackedVector3Array = _chunk.get_points()
	var best: int = 0
	for i: int in points.size():
		if points[i].distance_squared_to(_chunk.to_local(anchor)) < points[best].distance_squared_to(_chunk.to_local(anchor)):
			best = i
	var start_i: int = clampi(best - roundi(float(s["back"])), 0, points.size() - 1)
	var frame: Basis = _chunk.global_basis * _chunk.get_frames()[start_i]
	var start: Vector3 = _chunk.to_global(points[start_i]) + frame.x * float(s.get("side", 0.0))
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start + frame.y * 3.0, start - frame.y * 6.0)
	query.exclude = [_player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		start = hit["position"] + frame.y * 0.05
	var forward: Vector3 = -frame.z
	_player.set_physics_process(true)
	_player.place(start, atan2(-forward.x, -forward.z), float(s["speed"]))
	if not hit.is_empty():
		_player.ground_normal = hit["normal"]
		_player.set_ground_motion(forward, _player.speed)
		_player.velocity = _player.ground_dir * _player.speed
	_player.combo.drop()
	_player.state_machine.transition_to(&"Air", {})
	_player.bail_immunity_timer = 0.0


func _on_landed(grade: StringName) -> void:
	if _index >= 0 and _index < SCENARIOS.size() and _time > SETTLE_TIME and _waiting == 0:
		_grades.append(grade)
		_angles.append(_player.last_landing_angle)


func _on_grind_started() -> void:
	var snap: RailSnap = RailSnap.find_closest(get_tree(), _player.global_position, 6.0)
	_grinds.append(String(snap.rail.name) if snap != null else "?")


func _finish() -> void:
	var s: Dictionary = SCENARIOS[_index]
	if _air_start >= 0.0:
		_longest_air = maxf(_longest_air, _time - _air_start)
	var ok: bool = true
	if s.has("grind") and not _grinds.has(String(s["grind"])):
		ok = false
	if s.get("crash", false) and _crashes == 0:
		ok = false
	if s.get("no_grind", false) and not _grinds.is_empty():
		ok = false
	if s.has("air"):
		var range_air: Array = s["air"]
		if _longest_air < float(range_air[0]) or _longest_air > float(range_air[1]):
			ok = false
	if s.has("grades"):
		var allowed: Array = s["grades"]
		if _grades.is_empty():
			ok = false
		for grade: StringName in _grades:
			if not allowed.has(grade):
				ok = false
	if _tricks < int(s.get("tricks", 0)):
		ok = false
	if not ok:
		_failed += 1
	var landings: PackedStringArray = PackedStringArray()
	for i: int in _grades.size():
		landings.append("%s %.1f°" % [_grades[i], _angles[i]])
	var detail: String = "air %.2fs  landings %s  tricks %d  grinds %s  end %.1f m/s" % [
		_longest_air, ",".join(landings), _tricks,
		",".join(_grinds) if not _grinds.is_empty() else "-", _player.velocity.length()]
	_rows.append("%-4s | %-44s | %s" % ["ok" if ok else "FAIL", s["name"], detail])


func _report() -> void:
	set_physics_process(false)
	print("FEEL TEST")
	for row: String in _rows:
		print(row)
	print("FEEL TEST %s (%d/%d ok)" % ["PASSED" if _failed == 0 else "FAILED", _rows.size() - _failed, _rows.size()])
	get_tree().quit(1 if _failed > 0 else 0)
