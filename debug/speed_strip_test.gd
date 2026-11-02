extends Node3D
## Headless check for the v0.34 speed strips: on every real chunk that has
## them, start 15 m before each strip at `start_speed`, ride straight along
## it and over the kicker in front of it. Checks the strip adds speed, the
## kicker throws you into the air for a while, and you land without a bail.
## Run:  <exe> --headless --path . --fixed-fps 60 res://debug/speed_strip_test.tscn
## -- --strip-trace prints the rider every 0.1 s, --strip-only=<text> runs
## only the strips whose chunk/name contains <text>, --bike rides the bike
## instead of the tank. Exits 1 on failure.

const START_SPEEDS: Array[float] = [25.0, 45.0]

var _player: Player
var _trace: bool = false
var _only: String = ""
var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_trace = args.has("--strip-trace")
	for arg: String in args:
		if arg.begins_with("--strip-only="):
			_only = arg.trim_prefix("--strip-only=")
	var scene: String = "res://player/player.tscn" if args.has("--bike") else "res://tank/tank.tscn"
	_player = (load(scene) as PackedScene).instantiate() as Player
	_player.kill_y = -5000.0
	add_child(_player)
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	var dir: DirAccess = DirAccess.open("res://chunks/landscape")
	var files: PackedStringArray = dir.get_files()
	files.sort()
	var checked: int = 0
	for file: String in files:
		if not file.ends_with(".tscn"):
			continue
		var packed: PackedScene = load("res://chunks/landscape/" + file) as PackedScene
		var chunk: Node3D = packed.instantiate() as Node3D
		var names: PackedStringArray = PackedStringArray()
		for c: Node in chunk.get_children():
			if c is SpeedStrip and (_only.is_empty() or (file + "/" + c.name).contains(_only)):
				names.append(String(c.name))
		chunk.free()
		for strip_name: String in names:
			for v: float in START_SPEEDS:
				await _case(file, strip_name, v)
				checked += 1
	print("")
	if _failures.is_empty():
		print("SPEED STRIP TEST: %d runs passed" % checked)
		get_tree().quit(0)
	else:
		for f: String in _failures:
			print("FAIL ", f)
		print("SPEED STRIP TEST FAILED (%d of %d)" % [_failures.size(), checked])
		get_tree().quit(1)


func _case(file: String, strip_name: String, start_speed: float) -> void:
	var label: String = "%s/%s @%d" % [file.get_basename(), strip_name, int(start_speed)]
	var chunk: Node3D = (load("res://chunks/landscape/" + file) as PackedScene).instantiate() as Node3D
	add_child(chunk)
	for i: int in 3:
		await get_tree().physics_frame
	var strip: SpeedStrip = chunk.get_node(NodePath(strip_name)) as SpeedStrip
	var fwd: Vector3 = -strip.global_basis.z.normalized()
	var start: Vector3 = strip.global_position - fwd * 15.0
	# Drop onto the ground under the start.
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start + Vector3.UP * 30.0, start + Vector3.DOWN * 60.0)
	q.exclude = [_player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		start = hit["position"]
	_player.place(start + Vector3.UP * 0.5, atan2(-fwd.x, -fwd.z), start_speed)
	_player.state_machine.transition_to(&"Air", {})
	_player.velocity = fwd * start_speed
	var stats: Dictionary = {"strip_exit": 0.0, "max_air": 0.0, "air": 0.0, "bails": 0, "last": &"", "past": false, "max_speed": 0.0, "touched": false}
	var t: float = 0.0
	var next_trace: float = 0.0
	while t < 7.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var along: float = (_player.global_position - strip.global_position).dot(fwd)
		var state: StringName = _player.state_machine.get_state_name()
		if along < strip.length:
			stats["strip_exit"] = _player.speed
			if along > 0.0 and state != &"Air":
				stats["touched"] = true
		else:
			stats["past"] = true
		stats["max_speed"] = maxf(stats["max_speed"], _player.speed)
		if state == &"Air" and stats["past"]:
			stats["air"] += 1.0 / 60.0
			stats["max_air"] = maxf(stats["max_air"], stats["air"])
		elif state != &"Air":
			stats["air"] = 0.0
		if state == &"Bail" and stats["last"] != &"Bail":
			stats["bails"] += 1
		stats["last"] = state
		if _trace and t >= next_trace:
			next_trace += 0.1
			var p: Vector3 = _player.global_position
			print("  %s t=%4.1f along=%6.1f y=%7.1f v=%4.1f %s" % [label, t, along, p.y, _player.speed, state])
		if stats["past"] and stats["max_air"] > 0.0 and state != &"Air" and state != &"Land" and stats["air"] == 0.0 and along > strip.length + 40.0:
			break
	print("%-44s strip exit %5.1f m/s (in %4.1f), longest air %.2f s, bails %d" % [label, stats["strip_exit"], start_speed, stats["max_air"], stats["bails"]])
	if not stats["touched"]:
		# Flew over the whole strip off a bump before it: nothing to check
		# but the landing.
		print("    (never touched the strip: flew over it)")
	else:
		if stats["strip_exit"] < minf(start_speed + 5.0, _player.tuning.max_speed - 1.0):
			_failures.append("%s: strip only got you to %.1f m/s" % [label, stats["strip_exit"]])
		if stats["max_air"] < 0.6:
			_failures.append("%s: kicker gave only %.2f s of air" % [label, stats["max_air"]])
	if stats["bails"] > 0:
		_failures.append("%s: bailed" % label)
	chunk.free()
	for i: int in 2:
		await get_tree().physics_frame
