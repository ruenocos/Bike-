extends Node3D
## Headless line check: rides every ride line of every landscape chunk with a
## bot (LineFollower) that only steers, holds grind when a rail is in reach
## and pedals. A line passes when the bot reaches the end without crashing
## into anything, without bailing a landing, without going out of bounds and
## without drifting more than MAX_OFF metres off the line.
## Rolling boulders are removed first (they're timing hazards, not layout).
## Plus one crash check: riding straight into a tree at 50 m/s must bail
## ("hit Tree ...") and keep 1 - crash_penalty of the speed.
## Run:  <exe> --headless --path . --fixed-fps 60 res://debug/line_test.tscn
## Options (after --): --line-only=<text> (chunk or line name), --line-trace.
## Exits with code 1 on failure.

const PLAYER: PackedScene = preload("res://player/player.tscn")
## Start speed per chunk difficulty (m/s): the speed you'd carry in.
const START_SPEED: Array[float] = [45.0, 45.0, 48.0, 52.0]
const MAX_OFF: float = 6.0

var _failures: PackedStringArray = PackedStringArray()
var _bails: PackedStringArray = PackedStringArray()
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
	scenes.append(builder.finish_chunk)
	builder.free()
	_player = PLAYER.instantiate() as Player
	add_child(_player)
	_player.kill_y = -100000.0
	_player.auto_respawn = false
	Events.bailed.connect(func() -> void: _bails.append(_player.last_bail_reason))
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
	for action: StringName in [&"pedal", &"grind", &"steer_left", &"steer_right"]:
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
	var half: float = chunk.get_play_half_width()
	var worst_off: float = 0.0
	var top: float = 0.0
	var airtime: float = 0.0
	var grinds: int = 0
	var was_grind: bool = false
	var end: Vector3 = pts[-3]
	var time: float = 0.0
	var reached: bool = false
	var oob: bool = false
	while time < 30.0:
		var state: StringName = _player.state_machine.get_state_name()
		Input.action_press(&"pedal")
		LineFollower.steer(_player, line, LineFollower.look_ahead(_player.speed))
		if state != &"Grind" and RailSnap.find_closest(get_tree(), _player.global_position, _player.get_rail_snap_radius()) != null:
			Input.action_press(&"grind")
		else:
			Input.action_release(&"grind")
		await get_tree().physics_frame
		time += 1.0 / Engine.physics_ticks_per_second
		var pos: Vector3 = _player.global_position
		top = maxf(top, _player.speed)
		if state == &"Air":
			airtime += 1.0 / Engine.physics_ticks_per_second
		if state == &"Grind" and not was_grind:
			grinds += 1
		was_grind = state == &"Grind"
		# Grinding and flying may leave the line a bit; only riding counts.
		if state == &"Ride":
			worst_off = maxf(worst_off, LineFollower.distance_to(line, pos))
		if absf(pos.x - chunk.global_position.x) > half:
			oob = true
		if _trace and fmod(time, 1.0) < 1.0 / Engine.physics_ticks_per_second:
			print("  %s t=%4.1f d=%6.1f x=%6.1f v=%4.1f %s off=%.1f" % [label, time, -pos.z, pos.x, _player.speed, state, LineFollower.distance_to(line, pos)])
		if pos.z < end.z:
			reached = true
			break
	var line_style: String = ["rail", "jump", "carve"][line.style]
	print("%-30s %-5s %s  %4.1f s  top %4.1f m/s  air %3.1f s  grinds %d  off %4.1f m  bails %d %s" % [
		label, line_style, "end" if reached else "STUCK", time, top, airtime, grinds, worst_off, _bails.size(), str(_bails) if not _bails.is_empty() else ""])
	if not reached:
		_failures.append("%s: didn't reach the end" % label)
	if not _bails.is_empty():
		_failures.append("%s: %d bails %s" % [label, _bails.size(), str(_bails)])
	if oob:
		_failures.append("%s: went out of bounds" % label)
	if worst_off > MAX_OFF:
		_failures.append("%s: %.1f m off the line" % [label, worst_off])
	if line.style == RideLine.Style.RAIL and grinds == 0:
		_failures.append("%s: rail line but no grind" % label)


func _crash_check(chunk: Chunk) -> void:
	var tree: Node3D = null
	for prop: Node in chunk.get_node(^"Terrain/Props").get_children():
		if prop.name.begins_with("Tree") and absf((prop as Node3D).global_position.x) < 50.0:
			tree = prop as Node3D
			break
	if tree == null:
		_failures.append("crash check: no tree found")
		return
	var start: Vector3 = tree.global_position + Vector3(0.0, 0.0, 25.0)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(start + Vector3.UP * 30.0, start + Vector3.DOWN * 60.0, 1, [_player.get_rid()]))
	start.y = (hit["position"] as Vector3).y + 0.3 if not hit.is_empty() else start.y
	_player.place(start, 0.0, 50.0)
	_player.state_machine.transition_to(&"Air", {})
	_bails.clear()
	for i: int in 90:
		Input.action_release(&"steer_left")
		Input.action_release(&"steer_right")
		await get_tree().physics_frame
		if not _bails.is_empty():
			break
	var reason: String = _bails[0] if not _bails.is_empty() else "-"
	print("crash check: into %s at 50 m/s -> %s, speed after %.1f m/s" % [tree.name, reason, _player.speed])
	if not reason.begins_with("hit"):
		_failures.append("crash check: riding into a tree didn't crash (%s)" % reason)