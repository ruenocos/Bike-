extends Node3D
## Headless rail checks on the real chunks (v0.33, Wons: "rails can make u
## stuck"): rides at every rail of the landscape chunks from several angles
## and speeds, on the ground and hopping on, holding grind or not, and fails
## if the rider is ever stuck (moves less than 6 m in any 1 s after the
## first 1.2 s), crashes into the rail itself, or gets on and off it over and
## over. Other crashes on the way (it rides blind past the rail for 4 s) are
## printed, not failed.
## Run:  <exe> --headless --path . --fixed-fps 60 res://debug/rail_test.tscn
## -- --tank rides the tank, --rail-trace prints every 0.1 s, --rail-only=<text>.

const PLAYER: PackedScene = preload("res://player/player.tscn")
const CHUNKS: PackedStringArray = ["land_ridge", "land_boulders", "land_meadow", "land_slalom",
		"land_switchback_left", "land_switchback_right", "set_rail_gap", "set_ramp_yard"]

var _player: Player
var _trace: bool = false
var _only: String = ""
var _failures: PackedStringArray = PackedStringArray()
var _cases: int = 0


func _ready() -> void:
	_trace = OS.get_cmdline_user_args().has("--rail-trace")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--rail-only="):
			_only = arg.trim_prefix("--rail-only=")
	_player = (load("res://tank/tank.tscn") as PackedScene if OS.get_cmdline_user_args().has("--tank") else PLAYER).instantiate() as Player
	add_child(_player)
	_player.auto_respawn = false
	_player.kill_y = -100000.0
	add_child(Camera3D.new())
	for file: String in CHUNKS:
		var chunk: Chunk = (load("res://chunks/landscape/%s.tscn" % file) as PackedScene).instantiate() as Chunk
		add_child(chunk)
		for i: int in 3:
			await get_tree().physics_frame
		for child: Node in chunk.get_children():
			if child is Rail:
				await _rail_cases(file, child as Rail)
		chunk.free()
		for i: int in 2:
			await get_tree().physics_frame
	print("")
	print("RAIL TEST rode %d cases" % _cases)
	if _failures.is_empty():
		print("RAIL TEST PASSED")
		get_tree().quit(0)
	else:
		for f: String in _failures:
			print("  FAIL " + f)
		print("RAIL TEST FAILED (%d)" % _failures.size())
		get_tree().quit(1)


func _rail_cases(file: String, rail: Rail) -> void:
	var length: float = rail.curve.get_baked_length()
	var start: Vector3 = rail.to_global(rail.curve.sample_baked(0.0))
	var next: Vector3 = rail.to_global(rail.curve.sample_baked(4.0))
	var dir: Vector3 = Vector3(next.x - start.x, 0.0, next.z - start.z).normalized()
	var side: Vector3 = dir.cross(Vector3.UP).normalized()
	# Head-on into the ledge's end, on the ground.
	for spd: float in [20.0, 45.0]:
		await _case("%s/%s head-on %d" % [file, rail.name, spd], start - dir * 25.0, dir, spd, false, false)
		await _case("%s/%s head-on hold %d" % [file, rail.name, spd], start - dir * 25.0, dir, spd, true, false)
	# Hop on from beside the start.
	await _case("%s/%s hop on 45" % [file, rail.name], start - dir * 22.0 + side * 0.4, dir, 45.0, true, true)
	# Across / along the ledge's side at angles, mid-rail.
	var mid_off: float = length * 0.4
	var mid: Vector3 = rail.to_global(rail.curve.sample_baked(mid_off))
	var mid_next: Vector3 = rail.to_global(rail.curve.sample_baked(mid_off + 4.0))
	var mdir: Vector3 = Vector3(mid_next.x - mid.x, 0.0, mid_next.z - mid.z).normalized()
	var mside: Vector3 = mdir.cross(Vector3.UP).normalized()
	for ang: float in [8.0, 20.0, 45.0]:
		for sgn: float in [-1.0, 1.0]:
			var a: float = deg_to_rad(ang)
			var heading: Vector3 = (mdir * cos(a) - mside * sgn * sin(a)).normalized()
			var from: Vector3 = mid - heading * 20.0
			for spd2: float in [15.0, 40.0]:
				await _case("%s/%s side %d%s %d" % [file, rail.name, ang, "L" if sgn < 0.0 else "R", spd2], from, heading, spd2, false, false)
	# Ride along right next to it (the hull overlaps the bar).
	for sgn2: float in [-1.0, 1.0]:
		await _case("%s/%s alongside %s" % [file, rail.name, "L" if sgn2 < 0.0 else "R"], start - dir * 20.0 + side * sgn2 * 1.2, dir, 35.0, false, false)


func _ground_at(p: Vector3) -> Vector3:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 60.0, p + Vector3.DOWN * 200.0)
	q.collision_mask = 1
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


func _case(label: String, from: Vector3, heading: Vector3, spd: float, hold: bool, hop: bool) -> void:
	if not _only.is_empty() and not label.contains(_only):
		return
	_cases += 1
	var at: Vector3 = _ground_at(from)
	_player.place(at + Vector3.UP * 0.5, atan2(-heading.x, -heading.z), spd)
	_player.state_machine.transition_to(&"Air", {})
	if hold:
		Input.action_press(&"grind")
	var hist: Array[Vector3] = []
	var window: int = 60
	var bails: int = 0
	var reasons: PackedStringArray = PackedStringArray()
	var last: StringName = &""
	var stuck_at: float = -1.0
	var grinds: int = 0
	var t: float = 0.0
	var hop_pressed: bool = false
	while t < 4.0:
		if hop and not hop_pressed and t > 0.25:
			Input.action_press(&"hop")
			hop_pressed = true
		elif hop and hop_pressed and t > 0.35:
			Input.action_release(&"hop")
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var state: StringName = _player.state_machine.get_state_name()
		if state != last:
			if state == &"Bail":
				bails += 1
				reasons.append(_player.last_bail_reason)
			if state == &"Grind":
				grinds += 1
			last = state
		hist.append(_player.global_position)
		if hist.size() > window and stuck_at < 0.0 and t > 1.2:
			if hist[hist.size() - 1].distance_to(hist[hist.size() - 1 - window]) < 6.0:
				stuck_at = t
		if _trace and int(t * 60.0) % 6 == 0:
			var p: Vector3 = _player.global_position
			var hits: String = ""
			for i: int in _player.get_slide_collision_count():
				var c: KinematicCollision3D = _player.get_slide_collision(i)
				hits += " %s%s" % [(c.get_collider() as Node).name, c.get_normal()]
			print("  %s t=%4.1f p=(%6.1f %6.1f %7.1f) v=%4.1f %s%s" % [label, t, p.x, p.y, p.z, _player.speed, state, hits])
	Input.action_release(&"grind")
	Input.action_release(&"hop")
	var flag: String = ""
	if stuck_at >= 0.0:
		flag = "STUCK at %.1f s" % stuck_at
		_failures.append("%s: stuck at %.1f s (speed %.1f, %s)" % [label, stuck_at, _player.speed, last])
	elif _rail_bails(reasons) > 0:
		flag = "crashed on the rail"
		_failures.append("%s: crashed on the rail (%s)" % [label, ", ".join(reasons)])
	elif grinds > 3:
		flag = "%d grind entries" % grinds
		_failures.append("%s: on and off the rail %d times" % [label, grinds])
	print("%-46s speed %4.1f  bails %d  grinds %d  %s %s" % [label, _player.speed, bails, grinds, flag, ", ".join(reasons)])


func _rail_bails(reasons: PackedStringArray) -> int:
	var n: int = 0
	for r: String in reasons:
		if r.contains("Rail") or r.contains("Ledge"):
			n += 1
	return n
