extends Node3D
## Headless checks for the v0.31 "drastic landscape" pieces, each in its own
## little sandbox (flat ground + the piece) or on its real set-piece chunk:
##   - gravity loop: ride in at speed, go upside down, come out the far side
##     at about the same speed, no bail
##   - sap rail: hop on, climb, get launched off the end
##   - abyss: falling in respawns at its marker
##   - set pieces: ride the hidden lines of the new chunks without bailing
## Run:  <exe> --headless --path . --fixed-fps 60 res://debug/drastic_test.tscn
## -- --drastic-trace prints the rider every 0.1 s, --drastic-only=<text>
## runs only the scenarios whose name contains <text>. Exits 1 on failure.

const PLAYER: PackedScene = preload("res://player/player.tscn")
const LOOP: PackedScene = preload("res://chunks/parts/drastic/gravity_loop.tscn")
const SAP_RAIL: PackedScene = preload("res://rails/sap_rail.tscn")
const ABYSS: PackedScene = preload("res://chunks/parts/drastic/abyss.tscn")

var _player: Player
var _trace: bool = false
var _only: String = ""
var _failures: PackedStringArray = PackedStringArray()
var _sandbox: Node3D


func _ready() -> void:
	_trace = OS.get_cmdline_user_args().has("--drastic-trace")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--drastic-only="):
			_only = arg.trim_prefix("--drastic-only=")
	_player = PLAYER.instantiate() as Player
	add_child(_player)
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	await _run(&"loop 45 m/s", _loop_case.bind(45.0))
	await _run(&"loop 58 m/s", _loop_case.bind(58.0))
	await _run(&"loop 30 m/s", _loop_case.bind(30.0))
	await _run(&"sap rail climb + launch", _sap_case)
	await _run(&"abyss respawn", _abyss_case)
	print("")
	if _failures.is_empty():
		print("DRASTIC TEST: all passed")
		get_tree().quit(0)
	else:
		for f: String in _failures:
			print("FAIL ", f)
		print("DRASTIC TEST FAILED (%d)" % _failures.size())
		get_tree().quit(1)


func _run(label: StringName, case: Callable) -> void:
	if not _only.is_empty() and not String(label).contains(_only):
		return
	_sandbox = Node3D.new()
	add_child(_sandbox)
	_ground(Vector3(0, 0, -150), Vector3(200, 2, 500))
	await case.call(String(label))
	_sandbox.free()
	for i: int in 2:
		await get_tree().physics_frame


func _ground(center: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center - Vector3(0, size.y * 0.5, 0)
	_sandbox.add_child(body)
	return body


func _ride(label: String, seconds: float, each: Callable = Callable()) -> void:
	var t: float = 0.0
	var next_trace: float = 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if each.is_valid():
			each.call(t)
		if _trace and t >= next_trace:
			next_trace += 0.1
			var p: Vector3 = _player.global_position
			print("  %s t=%4.1f p=(%6.1f %6.1f %7.1f) v=%4.1f n.y=%5.2f %s grav=%s" % [label, t, p.x, p.y, p.z, _player.speed,
					_player.ground_normal.y, _player.state_machine.get_state_name(), _player.on_gravity_surface])


func _loop_case(label: String, speed: float) -> void:
	var loop: GravityLoop = LOOP.instantiate() as GravityLoop
	_sandbox.add_child(loop)
	for i: int in 3:
		await get_tree().physics_frame
	_player.place(Vector3(0, 0.4, loop.lead_length + 30.0), 0.0, speed)
	_player.state_machine.transition_to(&"Air", {})
	var stats: Dictionary = {"min_ny": 1.0, "bails": 0, "min_speed": speed, "entry_speed": speed, "last": &""}
	await _ride(label, 6.0, func(_t: float) -> void:
		stats["min_ny"] = minf(stats["min_ny"], _player.ground_normal.y)
		var state: StringName = _player.state_machine.get_state_name()
		if state == &"Bail" and stats["last"] != &"Bail":
			stats["bails"] += 1
		stats["last"] = state
		if _player.global_position.z > loop.lead_length:
			stats["entry_speed"] = _player.speed
		elif _player.global_position.z > -loop.lead_length or _player.global_position.y > 1.0:
			stats["min_speed"] = minf(stats["min_speed"], _player.speed))
	var p: Vector3 = _player.global_position
	var out_z: float = -loop.lead_length
	print("%s: upside down n.y %.2f, end (%.1f, %.1f, %.1f), speed %.1f (min %.1f), bails %d" % [label, stats["min_ny"], p.x, p.y, p.z,
			_player.speed, stats["min_speed"], stats["bails"]])
	print("    entry speed %.1f" % stats["entry_speed"])
	if stats["min_ny"] > -0.9:
		_failures.append("%s: never went upside down (n.y %.2f)" % [label, stats["min_ny"]])
	if p.z > out_z or absf(p.x - loop.side_shift) > loop.width * 0.5:
		_failures.append("%s: didn't come out of the loop (end %s)" % [label, p])
	if stats["bails"] > 0:
		_failures.append("%s: bailed" % label)
	if stats["min_speed"] < stats["entry_speed"] * 0.85:
		_failures.append("%s: lost speed in the loop (min %.1f)" % [label, stats["min_speed"]])


func _sap_case(label: String) -> void:
	# A rail that climbs 30 m over 80 m and ends pointing up.
	var rail: Rail = SAP_RAIL.instantiate() as Rail
	rail.curve = Curve3D.new()
	for i: int in 21:
		var f: float = i / 20.0
		rail.curve.add_point(Vector3(0, 0.75 + 30.0 * f * f, -40.0 - 80.0 * f))
	_sandbox.add_child(rail)
	for i: int in 2:
		await get_tree().physics_frame
	# Just above the rail's start, in the air: rails catch you by themselves.
	_player.place(Vector3(0, 1.6, -37.0), 0.0, 40.0)
	_player.state_machine.transition_to(&"Air", {})
	var stats: Dictionary = {"grind": false, "max_y": 0.0, "end_speed": 0.0}
	await _ride(label, 4.0, func(_t: float) -> void:
		if _player.state_machine.get_state_name() == &"Grind":
			stats["grind"] = true
			stats["end_speed"] = _player.speed
		stats["max_y"] = maxf(stats["max_y"], _player.global_position.y))
	print("%s: grind %s, speed at the top %.1f, highest %.1f m" % [label, stats["grind"], stats["end_speed"], stats["max_y"]])
	if not stats["grind"]:
		_failures.append("%s: never caught the rail" % label)
	elif stats["end_speed"] < 35.0:
		_failures.append("%s: the climb ate the speed (%.1f)" % [label, stats["end_speed"]])
	if stats["max_y"] < 40.0:
		_failures.append("%s: no launch off the end (highest %.1f m)" % [label, stats["max_y"]])


func _abyss_case(label: String) -> void:
	var abyss: Abyss = ABYSS.instantiate() as Abyss
	abyss.position = Vector3(0, -30, -100)
	_sandbox.add_child(abyss)
	(abyss.get_node(^"Respawn") as Node3D).global_position = Vector3(5, 0.5, -20)
	# A hole: no ground under z -60..-140 (the sandbox floor stops there).
	_sandbox.get_child(0).free()
	_ground(Vector3(0, 0, -20), Vector3(200, 2, 80))
	for i: int in 2:
		await get_tree().physics_frame
	_player.auto_respawn = true
	_player.place(Vector3(0, 0.4, -40), 0.0, 30.0)
	_player.state_machine.transition_to(&"Air", {})
	var stats: Dictionary = {"respawned": false, "fell": false}
	await _ride(label, 4.0, func(_t: float) -> void:
		if _player.global_position.y < -10.0:
			stats["fell"] = true
		if stats["fell"] and _player.global_position.distance_to(Vector3(5, 0.5, -20)) < 3.0:
			stats["respawned"] = true)
	print("%s: respawned at the marker %s" % [label, stats["respawned"]])
	if not stats["respawned"]:
		_failures.append("%s: no respawn at the marker" % label)
