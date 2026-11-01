extends Node3D
## Headless TerrainPatch check.
##   Geometry (patches built here):
##   - two patches joined exit-to-entry (different noise, a gully over the
##     seam) have the same edge heights (< 1 mm) and no step in the collision
##   - collision = mesh: raycasts hit surface_height() (< 2 cm), front faces up
##   - a rebuild gives the same heights
##   - GULLY digs `depth`, RIDGE raises `depth`, Flatten makes its plane, LINE
##     follows its curve's height
##   - boundary walls (when on) stop a horizontal ray at the outer edge
##   Ground cover (v0.12, no MultiMesh headless): grass patches cover part of
##   the ground (not none, not all), every layer places instances, bushes
##   only outside the crests; a patch with no cover stays bare
##   Riding (debug/terrain_sandbox.tscn, no input):
##   - never falls through the terrain, never leaves the mesh (the sandbox has boundary walls on), crosses
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
	await _check_bends()
	await _check_cover()
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
	a.boundary_height = 60.0
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
	var x: float = -a.half_total_width()
	while x <= a.half_total_width():
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
		var px: float = rng.randf_range(-a.half_total_width() + 1.0, a.half_total_width() - 1.0)
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
	var edge: float = a.half_total_width()
	var gy: float = a.surface_height(edge - 5.0, -150.0) + 3.0
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(edge - 5.0, gy, -150.0), Vector3(edge + 20.0, gy + 5.0, -150.0))
	var wall_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if wall_hit.is_empty() or (wall_hit["position"] as Vector3).x > edge + 1.01:
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


func _check_cover() -> void:
	var p: TerrainPatch = TerrainPatch.new()
	p.length = 300.0
	p.ground_cover = preload("res://chunks/terrain/cover/meadow.tres")
	add_child(p)
	p._build_cover()
	var grass: float = p.cover_stats.get("grass", -1.0)
	if grass < 0.15 or grass > 0.9:
		_fail("cover: grass share %.2f (want some grass and some dirt)" % grass)
	for li: int in p.ground_cover.layers.size():
		var placed: int = p.cover_stats.get(li, 0)
		if placed <= 0:
			_fail("cover: layer %d placed nothing" % li)
	var bush: GroundCoverLayer = preload("res://chunks/terrain/cover/layer_bush.tres")
	if bush.zone != GroundCoverLayer.Zone.OUTSIDE:
		_fail("cover: bushes must stay outside the crests (they don't collide)")
	p.free()
	var bare: TerrainPatch = TerrainPatch.new()
	bare.length = 100.0
	bare.ground_cover = null
	add_child(bare)
	bare._build_cover()
	var colors: PackedColorArray = (bare._mesh_arrays[Mesh.ARRAY_COLOR] as PackedColorArray)
	if colors.is_empty() or colors[colors.size() / 2].r > 0.0:
		_fail("cover: a patch without cover isn't bare (vertex colour grass)")
	bare.free()
	await get_tree().process_frame


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
	var half_width: float = (sandbox.get_node(^"PatchA") as TerrainPatch).half_total_width()
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


## Bent valleys (v0.8.1): a left bend into a right S-bend into a straight
## patch, each put on the previous one's exit_transform(). The edges must
## meet (position and height, < 1 mm), the collision across both seams has
## no step, the collision matches surface_height on the bends, a LINE shape
## drawn along the bend lands where it should, and no bend folds over.
func _check_bends() -> void:
	var specs: Array = [
		[_curve([Vector2(0, 0), Vector2(0.15, 0), Vector2(0.85, 45), Vector2(1, 45)]), 7],
		[_curve([Vector2(0, 0), Vector2(0.1, 0), Vector2(0.45, -25), Vector2(0.8, 0), Vector2(1, 0)]), 8],
		[null, 9]]
	var patches: Array[TerrainPatch] = []
	var at: Transform3D = Transform3D.IDENTITY
	for spec: Array in specs:
		var p: TerrainPatch = TerrainPatch.new()
		p.length = 320.0
		p.heading_curve = spec[0]
		p.noise_seed = spec[1]
		p.noise_amplitude = 3.0
		add_child(p)
		# Entry frame onto the previous exit (the pitch cancels: both 23 deg).
		if not patches.is_empty():
			p.global_transform = at * p.frame_at(0.0).affine_inverse()
		at = p.global_transform * p.exit_transform()
		patches.append(p)
	# A LINE shape along the first bend, 2 m under the plain slope at x = -20.
	var line: TerrainShape = TerrainShape.new()
	line.mode = TerrainShape.Mode.LINE
	line.width = 10.0
	line.curve = Curve3D.new()
	var first: TerrainPatch = patches[0]
	for d: float in range(60, 260, 4):
		line.curve.add_point(first.valley_to_local(-20.0, first.base_height(-20.0, -d) - 2.0, d))
	first.add_child(line)
	first.rebuild()
	await get_tree().physics_frame
	await get_tree().physics_frame

	for i: int in patches.size() - 1:
		var a: TerrainPatch = patches[i]
		var b: TerrainPatch = patches[i + 1]
		var worst: float = 0.0
		var x: float = -a.half_total_width()
		while x <= a.half_total_width():
			var pa: Vector3 = a.to_global(a.valley_to_local(x, a.surface_height(x, -a.length), a.length))
			var pb: Vector3 = b.to_global(b.valley_to_local(x, b.surface_height(x, 0.0), 0.0))
			worst = maxf(worst, pa.distance_to(pb))
			x += 1.0
		print("bent seam %d: edges differ by at most %.5f m (exit heading %.0f deg)" % [i, worst, rad_to_deg(a.heading_at(a.length))])
		if worst > 0.001:
			_fail("bent seam %d: edges differ by %.4f m" % [i, worst])
		# Collision just before and after the seam, across the flat middle.
		var seam: Transform3D = a.global_transform * a.exit_transform()
		for side: float in [-40.0, -10.0, 0.0, 10.0, 40.0]:
			var p0: Vector3 = seam.origin + seam.basis.x * side
			var before: Dictionary = _ray_down(p0.x + seam.basis.z.x * 0.3, p0.z + seam.basis.z.z * 0.3)
			var after: Dictionary = _ray_down(p0.x - seam.basis.z.x * 0.3, p0.z - seam.basis.z.z * 0.3)
			if before.is_empty() or after.is_empty():
				_fail("bent seam %d: no ground at %.0f" % [i, side])
				continue
			var plane_step: float = ((before["position"] as Vector3) - (after["position"] as Vector3)).dot(seam.basis.y)
			if absf(plane_step) > 0.05:
				_fail("bent seam %d: step %.3f m at %.0f" % [i, plane_step, side])

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var worst_hit: float = 0.0
	for p: TerrainPatch in patches:
		if p.fold_margin < 0.0:
			_fail("bend folds: %.0f m too tight" % -p.fold_margin)
		for i: int in 150:
			var vx: float = rng.randf_range(-p.half_total_width() + 3.0, p.half_total_width() - 3.0)
			var vd: float = rng.randf_range(3.0, p.length - 3.0)
			var g: Vector3 = p.to_global(p.valley_to_local(vx, 0.0, vd))
			var hit: Dictionary = _ray_down(g.x, g.z)
			if hit.is_empty():
				_fail("bent patch %d: no collision at valley (%.0f, %.0f) = global %s" % [patches.find(p), vx, vd, g])
				continue
			var want: float = p.to_global(Vector3(0.0, p.surface_height(vx, -vd), 0.0)).y
			if absf((hit["position"] as Vector3).y - want) > 0.05:
				print("  patch %d valley (%.0f, %.0f): hit y %.2f want %.2f" % [patches.find(p), vx, vd, (hit["position"] as Vector3).y, want])
			worst_hit = maxf(worst_hit, absf((hit["position"] as Vector3).y - want))
	print("bent collision vs surface_height: at most %.3f m off; tightest radius %.0f m" % [worst_hit, patches[1].tightest_radius])
	if worst_hit > 0.05:
		_fail("bent collision differs from surface_height by %.3f m" % worst_hit)
	_expect_height(first, "bent line", -20.0, -160.0, first.base_height(-20.0, -160.0) - 2.0)
	var oob_in: bool = first.is_out_of_bounds_local(first.valley_to_local(70.0, 0.0, 160.0))
	var oob_out: bool = first.is_out_of_bounds_local(first.valley_to_local(80.0, 0.0, 160.0))
	if oob_in or not oob_out:
		_fail("bent out-of-bounds check wrong (x 70: %s, x 80: %s)" % [oob_in, oob_out])
	for p: TerrainPatch in patches:
		p.queue_free()
	await get_tree().physics_frame


static func _curve(points: Array[Vector2]) -> Curve:
	var c: Curve = Curve.new()
	c.min_value = -120.0
	c.max_value = 120.0
	for p: Vector2 in points:
		c.add_point(p)
	return c