extends Node3D
## Headless TerrainPatch check.
##   Geometry (patches built here):
##   - two patches joined exit-to-entry (different noise, a gully over the
##     seam) have the same edge heights (< 1 mm) and no step in the collision
##   - collision = mesh: raycasts hit surface_height() (< 2 cm), front faces up
##   - a rebuild gives the same heights
##   - GULLY digs `depth`, RIDGE raises `depth`, Flatten makes its plane, LINE
##     follows its curve's height
##   - boundary walls stop a horizontal ray at the edge
##   Riding (debug/terrain_sandbox.tscn, no input):
##   - never falls through the terrain, never leaves the play area, crosses
##     the seam between the two patches, rides into both edge walls at 50 m/s
## Run:  <exe> --headless --path . --fixed-fps 60 res://debug/terrain_test.tscn
## Exits with code 1 on failure.

const SANDBOX: PackedScene = preload("res://debug/terrain_sandbox.tscn")
## (name, start x, start z, heading rad (+ = left), speed m/s, seconds)
const RIDES: Array = [
	["straight over the seam", 0.0, -330.0, 0.0, 40.0, 5.0],
	["from rest", 0.0, -8.0, 0.0, 0.0, 8.0],
	["over the kicker pad", 0.0, -100.0, 0.0, 45.0, 3.0],
	["across the gully", -55.0, -60.0, 0.35, 45.0, 4.0],
	["into the left wall", -40.0, -100.0, 1.0, 50.0, 5.0],
	["into the right wall", 40.0, -100.0, -1.0, 50.0, 5.0],
	["along the carved line", 0.0, -430.0, 0.0, 45.0, 6.0],
]

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _check_seam_and_collision()
	await _check_shapes()
	await _check_rides()
	if _failures.is_empty():
		print("terrain test: all passed")
		get_tree().quit(0)
	else:
		for f: String in _failures:
			print("FAIL ", f)
		print("terrain test: %d failed" % _failures.size())
		get_tree().quit(1)


func _fail(msg: String) -> void:
	_failures.append(msg)


func _ray_down(x: float, z: float, exclude: Array[RID] = []) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, 2000.0, z), Vector3(x, -2000.0, z))
	q.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(q)


func _check_seam_and_collision() -> void:
	var a: TerrainPatch = TerrainPatch.new()
	a.length = 300.0
	a.noise_seed = 3
	var gully: TerrainShape = TerrainShape.new()
	gully.curve = Curve3D.new()
	gully.curve.add_point(Vector3(10.0, 0.0, -150.0))
	gully.curve.add_point(Vector3(-10.0, 0.0, -300.0))
	gully.width = 20.0
	gully.depth = 6.0
	a.add_child(gully)
	add_child(a)
	var b: TerrainPatch = TerrainPatch.new()
	b.noise_seed = 11
	b.noise_amplitude = 4.0
	b.position = a.position + a.exit_point()
	add_child(b)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var worst: float = 0.0
	var x: float = -a.width * 0.5
	while x <= a.width * 0.5:
		var ha: float = a.position.y + a.surface_height(x, -a.length)
		var hb: float = b.position.y + b.surface_height(x, 0.0)
		worst = maxf(worst, absf(ha - hb))
		x += 0.5
	print("seam: edge heights differ by at most %.5f m" % worst)
	if worst > 0.001:
		_fail("seam edge heights differ by %.4f m" % worst)

	# Collision across the seam: a hit just above and below it, no step
	# beyond what the slope gives, faces up.
	var seam_z: float = b.position.z
	var worst_step: float = 0.0
	x = -70.0
	while x <= 70.0:
		var up: Dictionary = _ray_down(x, seam_z + 0.25)
		var down: Dictionary = _ray_down(x, seam_z - 0.25)
		if up.is_empty() or down.is_empty():
			_fail("seam: no collision at x %.1f" % x)
		else:
			var dy: float = (up["position"] as Vector3).y - (down["position"] as Vector3).y
			var expected: float = 0.5 * tan(deg_to_rad(a.slope_deg))
			worst_step = maxf(worst_step, absf(dy - expected) if absf(x) < 50.0 else 0.0)
			if (up["normal"] as Vector3).y < 0.3 or (down["normal"] as Vector3).y < 0.3:
				_fail("seam: steep or flipped normal at x %.1f" % x)
		x += 2.5
	print("seam: collision step at most %.3f m (flat middle)" % worst_step)
	if worst_step > 0.05:
		_fail("seam collision step %.3f m" % worst_step)

	# Collision = mesh, and the faces point up.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var worst_hit: float = 0.0
	for i: int in 400:
		var px: float = rng.randf_range(-a.width * 0.5 + 1.0, a.width * 0.5 - 1.0)
		var pz: float = rng.randf_range(-a.length + 1.0, -1.0)
		var hit: Dictionary = _ray_down(px, pz)
		if hit.is_empty():
			_fail("no collision at (%.1f, %.1f)" % [px, pz])
			continue
		worst_hit = maxf(worst_hit, absf((hit["position"] as Vector3).y - a.surface_height(px, pz)))
		if (hit["normal"] as Vector3).y <= 0.0:
			_fail("collision face points down at (%.1f, %.1f)" % [px, pz])
	print("collision vs surface_height: at most %.4f m off" % worst_hit)
	if worst_hit > 0.02:
		_fail("collision differs from surface_height by %.3f m" % worst_hit)

	# Rebuilding gives the same terrain; time a default-size build.
	var before: PackedFloat32Array = b.heights.duplicate()
	var t0: int = Time.get_ticks_usec()
	b.rebuild()
	print("rebuild %.0f x %.0f m, cell %.1f m: %.1f ms" % [b.width, b.length, b.cell_size, (Time.get_ticks_usec() - t0) / 1000.0])
	if before != b.heights:
		_fail("rebuild changed the heights")

	# Boundary wall: a horizontal ray along the ground hits the edge.
	var gy: float = a.surface_height(60.0, -150.0) + 3.0
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(60.0, gy, -150.0), Vector3(120.0, gy + 20.0, -150.0))
	var wall_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if wall_hit.is_empty() or (wall_hit["position"] as Vector3).x > a.width * 0.5 + 1.01:
		_fail("boundary wall missing")
	a.queue_free()
	b.queue_free()
	await get_tree().physics_frame


func _check_shapes() -> void:
	var p: TerrainPatch = TerrainPatch.new()
	p.noise_amplitude = 0.0
	var slope: float = tan(deg_to_rad(p.slope_deg))
	var gully: TerrainShape = _line_shape(TerrainShape.Mode.GULLY, -30.0, 0.0, 0.0)
	var ridge: TerrainShape = _line_shape(TerrainShape.Mode.RIDGE, 30.0, 0.0, 0.0)
	# LINE: straight down x 0, 3 m below the slope.
	var line: TerrainShape = _line_shape(TerrainShape.Mode.LINE, 0.0, -3.0, slope)
	line.curve.set_point_position(0, Vector3(0.0, -3.0 - 60.0 * slope, -60.0))
	line.curve.set_point_position(1, Vector3(0.0, -3.0 - 120.0 * slope, -120.0))
	var pad: TerrainFlatten = TerrainFlatten.new()
	pad.size = Vector2(16.0, 16.0)
	pad.position = Vector3(0.0, 2.0 - 200.0 * slope, -200.0)
	for n: Node in [gully, ridge, line, pad]:
		p.add_child(n)
	add_child(p)
	_expect_height(p, "gully", -30.0, -150.0, p.base_height(-30.0, -150.0) - gully.depth)
	_expect_height(p, "ridge", 30.0, -150.0, p.base_height(30.0, -150.0) + ridge.depth)
	_expect_height(p, "line", 0.0, -90.0, p.base_height(0.0, -90.0) - 3.0)
	for off: Vector2 in [Vector2.ZERO, Vector2(6.0, 6.0), Vector2(-6.0, -6.0)]:
		_expect_height(p, "flatten", off.x, -200.0 + off.y, pad.position.y)
	# Untouched ground stays on the plain slope.
	_expect_height(p, "plain", 0.0, -250.0, p.base_height(0.0, -250.0))
	p.queue_free()
	await get_tree().physics_frame


func _line_shape(mode: TerrainShape.Mode, x: float, y: float, slope: float) -> TerrainShape:
	var s: TerrainShape = TerrainShape.new()
	s.mode = mode
	s.width = 18.0
	s.depth = 5.0
	s.curve = Curve3D.new()
	s.curve.add_point(Vector3(x, y - 60.0 * slope, -60.0))
	s.curve.add_point(Vector3(x, y - 240.0 * slope, -240.0))
	return s


func _expect_height(p: TerrainPatch, label: String, x: float, z: float, want: float) -> void:
	var got: float = p.surface_height(x, z)
	print("%-8s (%5.1f, %6.1f): %8.3f want %8.3f" % [label, x, z, got, want])
	if absf(got - want) > 0.05:
		_fail("%s at (%.1f, %.1f): %.3f, want %.3f" % [label, x, z, got, want])


func _check_rides() -> void:
	var sandbox: Node3D = SANDBOX.instantiate() as Node3D
	add_child(sandbox)
	var player: Player = sandbox.get_node(^"Player") as Player
	player.kill_y = -100000.0
	player.auto_respawn = false
	var origin: Vector3 = (sandbox.get_node(^"PatchA") as Node3D).position
	var half_width: float = (sandbox.get_node(^"PatchA") as TerrainPatch).width * 0.5
	await get_tree().physics_frame
	await get_tree().physics_frame
	for ride: Array in RIDES:
		var start: Vector3 = origin + Vector3(float(ride[1]), 0.0, float(ride[2]))
		var hit: Dictionary = _ray_down(start.x, start.z, [player.get_rid()])
		start.y = (hit["position"] as Vector3).y + 0.05
		player.place(start, float(ride[3]), float(ride[4]))
		player.ground_normal = hit["normal"]
		player.set_ground_motion(player.get_heading_dir(), player.speed)
		player.velocity = player.ground_dir * player.speed
		player.state_machine.transition_to(&"Air", {})
		var frames: int = int(float(ride[5]) * Engine.physics_ticks_per_second)
		var lowest: float = INF
		var widest: float = 0.0
		var top_speed: float = 0.0
		for f: int in frames:
			await get_tree().physics_frame
			var pos: Vector3 = player.global_position
			var ground: Dictionary = _ray_down(pos.x, pos.z, [player.get_rid()])
			if not ground.is_empty():
				lowest = minf(lowest, pos.y - (ground["position"] as Vector3).y)
			widest = maxf(widest, absf(pos.x - origin.x))
			top_speed = maxf(top_speed, player.speed)
		var end: Vector3 = player.global_position - origin
		print("ride %-24s end (%6.1f, %7.1f)  top %4.1f m/s  lowest %5.2f m  widest %5.1f m" % [ride[0], end.x, end.z, top_speed, lowest, widest])
		if lowest < -0.6:
			_fail("ride %s: %.2f m below the surface" % [ride[0], lowest])
		if widest > half_width + 0.5:
			_fail("ride %s: left the play area (|x| %.1f)" % [ride[0], widest])
		if String(ride[0]).contains("seam") and end.z > -420.0:
			_fail("ride %s: didn't cross the seam (z %.1f)" % [ride[0], end.z])
		if String(ride[0]).contains("rest") and top_speed < 20.0:
			_fail("ride %s: only reached %.1f m/s" % [ride[0], top_speed])
	sandbox.queue_free()
