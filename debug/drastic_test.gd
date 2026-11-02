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
	# `-- --tank` rides the tank instead.
	_player = (load("res://tank/tank.tscn") as PackedScene if OS.get_cmdline_user_args().has("--tank") else PLAYER).instantiate() as Player
	add_child(_player)
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	await _run(&"loop 45 m/s", _loop_case.bind(45.0))
	await _run(&"loop 58 m/s", _loop_case.bind(58.0))
	await _run(&"loop 30 m/s", _loop_case.bind(30.0))
	await _run(&"sap rail climb + launch", _sap_case)
	await _run(&"abyss respawn", _abyss_case)
	await _run(&"world tree spiral (real chunk)", _tree_case.bind(&"SpiralBranchRight"))
	await _run(&"world tree spiral left (real chunk)", _tree_case.bind(&"SpiralBranchLeft"))
	for x: float in [-60.0, 0.0, 30.0]:
		for spd: float in [25.0, 50.0]:
			await _run(StringName("world tree chasm drop x %d at %d" % [x, spd]), _chasm_case.bind(x, spd))
	await _run(&"world tree hop off the spiral", _tree_hop_off_case)
	await _run(&"alien garden ring (real chunk)", _garden_case)
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
	_player.kill_y = -2000.0
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


func _chunk(path: String) -> Chunk:
	# The real chunk has its own ground; drop the sandbox floor.
	_sandbox.get_child(0).free()
	_player.kill_y = -2000.0
	var chunk: Chunk = (load(path) as PackedScene).instantiate() as Chunk
	_sandbox.add_child(chunk)
	for i: int in 3:
		await get_tree().physics_frame
	return chunk


func _tree_case(label: String, branch: StringName) -> void:
	var chunk: Chunk = await _chunk("res://chunks/landscape/set_world_tree.tscn")
	var tree: WorldTree = chunk.find_child("WorldTree", true, false) as WorldTree
	var rail: Rail = tree.get_node(NodePath("Built/" + branch)) as Rail
	var a: Vector3 = rail.to_global(rail.curve.get_point_position(0))
	var b: Vector3 = rail.to_global(rail.curve.get_point_position(1))
	var flat: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	_player.auto_respawn = true
	_player.place(a + Vector3.UP * 0.9 - flat * 2.0, atan2(-flat.x, -flat.z), 45.0)
	_player.state_machine.transition_to(&"Air", {})
	var stats: Dictionary = {"grind": false, "max_y": a.y, "bails": 0, "last": &""}
	await _ride(label, 8.0, func(_t: float) -> void:
		var state: StringName = _player.state_machine.get_state_name()
		if state == &"Grind":
			stats["grind"] = true
		if state == &"Bail" and stats["last"] != &"Bail":
			stats["bails"] += 1
		stats["last"] = state
		stats["max_y"] = maxf(stats["max_y"], _player.global_position.y))
	var climb: float = stats["max_y"] - a.y
	print("%s: grind %s, climbed %.1f m above the rim, bails %d, end %s" % [label, stats["grind"], climb, stats["bails"], _player.global_position])
	if not stats["grind"]:
		_failures.append("%s: never caught the branch" % label)
	elif climb < tree.climb * 0.8:
		_failures.append("%s: didn't reach the top (%.1f m)" % [label, climb])
	if stats["bails"] > 0:
		_failures.append("%s: bailed" % label)
	_player.auto_respawn = false


## Rides straight off the chasm's rim (v0.33, Wons: "the tree ride makes the
## wall fucky"): the rider must fall into the Abyss and be put back at its
## marker, never ride / stick on the chasm's steep walls.
func _chasm_case(label: String, x: float, spd: float) -> void:
	var chunk: Chunk = await _chunk("res://chunks/landscape/set_world_tree.tscn")
	var terrain: TerrainPatch = chunk.get_node(^"Terrain") as TerrainPatch
	await _chasm_ride(label, chunk, terrain.to_global(terrain.valley_to_local(x, terrain.surface_height(x, -250.0) + 0.6, 250.0)), spd, Callable())


func _tree_hop_off_case(label: String) -> void:
	var chunk: Chunk = await _chunk("res://chunks/landscape/set_world_tree.tscn")
	var tree: WorldTree = chunk.find_child("WorldTree", true, false) as WorldTree
	var rail: Rail = tree.get_node(^"Built/SpiralBranchRight") as Rail
	var a: Vector3 = rail.to_global(rail.curve.get_point_position(0))
	var b: Vector3 = rail.to_global(rail.curve.get_point_position(1))
	var flat: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	await _chasm_ride(label, chunk, a + Vector3.UP * 0.9 - flat * 2.0, 45.0, func(t: float) -> void:
		if t > 1.4 and t < 1.5:
			Input.action_press(&"hop")
		elif t >= 1.5:
			Input.action_release(&"hop"), flat)


func _chasm_ride(label: String, chunk: Chunk, at: Vector3, spd: float, each: Callable, forward: Vector3 = Vector3.FORWARD) -> void:
	var marker: Node3D = chunk.get_node(^"Abyss/Respawn") as Node3D
	_player.auto_respawn = true
	_player.respawn_hint = null
	_player.place(at, atan2(-forward.x, -forward.z), spd)
	_player.state_machine.transition_to(&"Air", {})
	var stats: Dictionary = {"respawned": false, "wall_time": 0.0, "worst_wall": 0.0, "low": INF}
	await _ride(label, 9.0, func(t: float) -> void:
		if each.is_valid():
			each.call(t)
		stats["low"] = minf(stats["low"], _player.global_position.y)
		if _player.global_position.distance_to(marker.global_position) < 3.0 and stats["low"] < marker.global_position.y - 20.0:
			stats["respawned"] = true
		# On the ground with the ground steeper than 60 deg: riding a wall.
		if _player.is_on_floor() and _player.ground_normal.y < 0.5:
			stats["wall_time"] += 1.0 / 60.0
			stats["worst_wall"] = maxf(stats["worst_wall"], stats["wall_time"])
		else:
			stats["wall_time"] = 0.0)
	Input.action_release(&"hop")
	print("%s: respawned %s, longest on a wall %.2f s, lowest %.1f" % [label, stats["respawned"], stats["worst_wall"], stats["low"]])
	if stats["worst_wall"] > 0.4:
		_failures.append("%s: rode the chasm wall for %.2f s" % [label, stats["worst_wall"]])
	# Either put back before the rim, or made it across (the far rim is at
	# d ~370 down the chunk).
	var far: float = chunk.to_local(_player.global_position).z
	if not stats["respawned"] and far > -375.0:
		_failures.append("%s: neither respawned nor across (z %.1f)" % [label, far])
	_player.auto_respawn = false


func _garden_case(label: String) -> void:
	var chunk: Chunk = await _chunk("res://chunks/landscape/set_alien_garden.tscn")
	var loop: GravityLoop = chunk.find_child("GravityRingA", true, false) as GravityLoop
	# On the pad just before the run-in (the pad is tilted with the slope).
	var entry: Vector3 = loop.to_global(Vector3(0, 0.45, loop.lead_length + 6.0))
	var fwd: Vector3 = -loop.global_basis.z.normalized()
	_player.place(entry, atan2(-fwd.x, -fwd.z), 50.0)
	_player.state_machine.transition_to(&"Air", {})
	# Coming down the slope: moving along the tilted pad, not level.
	_player.velocity = fwd * 50.0
	var stats: Dictionary = {"min_ny": 1.0, "bails": 0, "last": &""}
	await _ride(label, 5.0, func(_t: float) -> void:
		stats["min_ny"] = minf(stats["min_ny"], _player.ground_normal.y)
		var state: StringName = _player.state_machine.get_state_name()
		if state == &"Bail" and stats["last"] != &"Bail":
			stats["bails"] += 1
		stats["last"] = state)
	var out: Vector3 = loop.to_local(_player.global_position)
	print("%s: upside down n.y %.2f, end (loop space) %s, speed %.1f, bails %d" % [label, stats["min_ny"], out, _player.speed, stats["bails"]])
	if stats["min_ny"] > -0.9:
		_failures.append("%s: never went upside down" % label)
	if out.z > -loop.lead_length:
		_failures.append("%s: didn't come out" % label)
	if stats["bails"] > 0:
		_failures.append("%s: bailed" % label)
