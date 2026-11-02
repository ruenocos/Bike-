extends Node3D
## Headless line check: the bot (LineFollower) rides every invisible path
## (RideLine) of every landscape chunk: several different ways through each
## open valley, bends included. It only steers, holds grind when a rail is in
## reach and pedals. (v0.9.1: no grind button; it hops onto rails, which then grind by themselves.) A path passes when the bot reaches the end without
## crashing into anything, without bailing a landing, without going out of
## bounds and without drifting more than MAX_OFF metres off it.
## Rolling boulders are removed first (they're timing hazards, not layout).
## Plus one crash check: riding straight into a tree at 50 m/s must bail
## ("hit Tree ...") and keep 1 - crash_penalty of the speed.
## Run:  <exe> --headless --path . --fixed-fps 60 res://debug/line_test.tscn
## Options (after --): --line-only=<text> (chunk or line name), --line-trace.
## Exits with code 1 on failure.

const PLAYER: PackedScene = preload("res://player/player.tscn")
## Start speed per chunk difficulty (m/s): the speed you'd carry in.
const START_SPEED: Array[float] = [45.0, 45.0, 48.0, 52.0]
const MAX_OFF: float = 8.0
## Drift off the path only counts this long after the last landing (s): off
## a kicker or a rail end you fly straight on while the valley bends.
const LANDING_GRACE: float = 1.5

var _failures: PackedStringArray = PackedStringArray()
var _bails: PackedStringArray = PackedStringArray()
var _gates: int = 0
var _player: Player
var _trace: bool = false
var _only: String = ""


func _ready() -> void:
	process_physics_priority = -100
	_trace = OS.get_cmdline_user_args().has("--line-trace")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--line-only="):
			_only = arg.trim_prefix("--line-only=")
	_run.call_deferred()


func _run() -> void:
	var builder: StageBuilder = StageBuilder.new()
	var scenes: Array[PackedScene] = builder.middle_chunks.duplicate()
	scenes.append_array(builder.set_pieces)
	# v0.16: the biomes' own set pieces.
	for biome_path: String in ["meadow", "canyon", "snow", "quarry"]:
		for scene: PackedScene in (load("res://biomes/%s.tres" % biome_path) as Biome).set_pieces:
			if not scenes.has(scene):
				scenes.append(scene)
	scenes.append(builder.finish_chunk)
	builder.free()
	# `-- --tank` rides the tank instead (v0.32).
	_player = (load("res://tank/tank.tscn") as PackedScene if OS.get_cmdline_user_args().has("--tank") else PLAYER).instantiate() as Player
	add_child(_player)
	_player.kill_y = -100000.0
	_player.auto_respawn = false
	Events.bailed.connect(func() -> void: _bails.append(_player.last_bail_reason))
	Events.gate_collected.connect(func(_s: int) -> void: _gates += 1)
	var rides: int = 0
	for scene: PackedScene in scenes:
		var chunk: Chunk = scene.instantiate() as Chunk
		add_child(chunk)
		for node: Node in chunk.get_children():
			if node is RollingBoulder:
				node.free()
		for i: int in 3:
			await get_tree().physics_frame
		if scene.resource_path.ends_with("land_forest.tscn") and _only.is_empty():
			await _crash_check(chunk)
		for line: RideLine in chunk.get_ride_lines():
			var label: String = "%s/%s" % [scene.resource_path.get_file().get_basename(), line.name]
			if not _only.is_empty() and not label.contains(_only):
				continue
			await _ride(chunk, line, label)
			rides += 1
		chunk.queue_free()
		await get_tree().physics_frame
	for action: StringName in [&"pedal", &"grind", &"no_hander", &"steer_left", &"steer_right"]:
		Input.action_release(action)
	print("LINE TEST rode %d lines" % rides)
	for f: String in _failures:
		print("FAIL ", f)
	print("LINE TEST %s" % ("PASSED" if _failures.is_empty() else "FAILED (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _ride(chunk: Chunk, line: RideLine, label: String) -> void:
	var pts: PackedVector3Array = line.get_global_points()
	var start: Vector3 = pts[2]
	var dir: Vector3 = (pts[3] - pts[2]).normalized()
	var speed: float = START_SPEED[clampi(chunk.difficulty, 0, START_SPEED.size() - 1)]
	_player.place(start + Vector3.UP * 0.3, atan2(-dir.x, -dir.z), speed)
	_player.combo.drop()
	_player.state_machine.transition_to(&"Air", {})
	_bails.clear()
	_gates = 0
	var slowest: float = INF
	var worst_off: float = 0.0
	var top: float = 0.0
	var airtime: float = 0.0
	var grinds: int = 0
	var was_grind: bool = false
	var time: float = 0.0
	var reached: bool = false
	var since_air: float = 10.0
	var oob: bool = false
	while time < 30.0:
		var state: StringName = _player.state_machine.get_state_name()
		Input.action_press(&"pedal")
		LineFollower.steer(_player, line, LineFollower.look_ahead(_player.speed))
		LineFollower.hop_for_rails(_player)
		await get_tree().physics_frame
		time += 1.0 / Engine.physics_ticks_per_second
		var pos: Vector3 = _player.global_position
		top = maxf(top, _player.speed)
		if time > 1.0 and state == &"Ride":
			slowest = minf(slowest, _player.speed)
		if state == &"Air":
			airtime += 1.0 / Engine.physics_ticks_per_second
		if state == &"Grind" and not was_grind:
			grinds += 1
		was_grind = state == &"Grind"
		# Grinding and flying may leave the path; only settled riding counts.
		if state != &"Ride":
			since_air = 0.0
		else:
			since_air += 1.0 / Engine.physics_ticks_per_second
			if since_air > LANDING_GRACE:
				worst_off = maxf(worst_off, LineFollower.distance_to(line, pos))
		if chunk.is_out_of_bounds(pos):
			oob = true
		if _trace and _player.speed < 3.0 and _player.get_slide_collision_count() > 0:
			var hit: Object = _player.get_slide_collision(0).get_collider()
			print("  slow: touching %s (%s) normal %s" % [(hit as Node).get_path() if hit is Node else hit, (hit as Node).get_groups() if hit is Node else [], _player.get_slide_collision(0).get_normal()])
		if _trace and fmod(time, 1.0) < 1.0 / Engine.physics_ticks_per_second:
			print("  %s t=%4.1f d=%6.1f x=%6.1f v=%4.1f %s off=%.1f" % [label, time, -pos.z, pos.x, _player.speed, state, LineFollower.distance_to(line, pos)])
		if line.nearest_index(pos) >= pts.size() - 3:
			reached = true
			break
	print("%-32s %s  %4.1f s  speed %4.1f-%4.1f m/s  air %3.1f s  grinds %d  gates %d  off %4.1f m  bails %d %s" % [
		label, "end" if reached else "STUCK", time, slowest, top, airtime, grinds, _gates, worst_off, _bails.size(), str(_bails) if not _bails.is_empty() else ""])
	if not reached:
		_failures.append("%s: didn't reach the end" % label)
	if not _bails.is_empty():
		_failures.append("%s: %d bails %s" % [label, _bails.size(), str(_bails)])
	if oob:
		_failures.append("%s: went out of bounds" % label)
	if worst_off > MAX_OFF:
		_failures.append("%s: %.1f m off the path" % [label, worst_off])


func _crash_check(chunk: Chunk) -> void:
	# Our own tree on open ground in the middle of the valley, and a run at it
	# from 25 m uphill along the valley.
	var terrain: TerrainPatch = chunk.get_node(^"Terrain") as TerrainPatch
	var line: RideLine = chunk.get_ride_lines()[0]
	var target: Vector3 = terrain.local_to_valley(terrain.to_local(line.get_global_points()[60]))
	var tree: Node3D = (load("res://chunks/parts/props/tree.tscn") as PackedScene).instantiate() as Node3D
	tree.name = "TestTree"
	chunk.add_child(tree)
	tree.global_position = terrain.to_global(terrain.valley_to_local(target.x, terrain.surface_height(target.x, -target.z), target.z))
	var start: Vector3 = terrain.to_global(terrain.valley_to_local(target.x, terrain.surface_height(target.x, -(target.z - 25.0)) + 0.3, target.z - 25.0))
	for i: int in 2:
		await get_tree().physics_frame
	# This check wants a solid tree: the tank would crush a sapling.
	_player.tuning.crushes_props = false
	var aim: Vector3 = tree.global_position - start
	_player.place(start, atan2(-aim.x, -aim.z), 50.0)
	_player.state_machine.transition_to(&"Air", {})
	_bails.clear()
	for i: int in 90:
		Input.action_release(&"steer_left")
		Input.action_release(&"steer_right")
		await get_tree().physics_frame
		if not _bails.is_empty():
			break
	var reason: String = _bails[0] if not _bails.is_empty() else "-"
	print("crash check: into a tree at 50 m/s -> %s, speed after %.1f m/s" % [reason, _player.speed])
	if not reason.begins_with("hit"):
		_failures.append("crash check: riding into a tree didn't crash (%s)" % reason)
	tree.free()