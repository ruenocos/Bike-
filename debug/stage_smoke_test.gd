extends Node3D
## Headless stage check. Builds 20 random stages and checks every chunk join:
##   - markers line up: Exit of one chunk = Entry of the next (< 5 cm, < 0.5 deg)
##   - the collision surface is continuous across the join: raycasts just
##     before and after it, across the width, all hit within 5 cm of the
##     join's ground plane, with upward normals
##   - every chunk stays upright (it only turns around up to join)
##   - the stage is always descending after the start deck
##   - start first, finish last, no middle chunk twice in a row
##   - landscape chunks (checked once per chunk scene): every invisible path
##     (RideLine) stays inside the play area with no obstacle within its
##     clearance, and across the valley there is always a clear gap of at
##     least MIN_GAP metres every GAP_STEP metres down it (also reports how
##     often there are 2+ / 3+ separate gaps: several ways through)
##   - bending valleys: a stage never turns past StageBuilder.max_stage_heading_deg
##     and no chunk's centerline comes within min_clearance of an earlier
##     chunk except its neighbour (no self-overlap)
## Run:  <exe> --headless --path . res://debug/stage_smoke_test.tscn
## Exits with code 1 on failure.

const STAGES: int = 20
const MIN_GAP: float = 6.0
const GAP_STEP: float = 3.0
## Rider radius + margin for the gap sweep (m).
const GAP_PROBE: float = 1.0
const MAX_STEP: float = 0.05
const MAX_ANGLE_DEG: float = 0.5
const LATERAL: Array[float] = [-55.0, -35.0, -20.0, -7.0, -4.0, 0.0, 4.0, 7.0, 20.0, 35.0, 55.0]

var _failures: PackedStringArray = PackedStringArray()
## Share of the probed width that was free in the last gap sweep, and in
## its tightest row (a chokepoint).
var _free_share: float = 0.0
var _tightest_row: float = 1.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var builder: StageBuilder = StageBuilder.new()
	add_child(builder)
	var scenes: Array[PackedScene] = [builder.start_chunk, builder.finish_chunk]
	scenes.append_array(builder.middle_chunks)
	scenes.append_array(builder.set_pieces)
	for scene: PackedScene in scenes:
		await _check_lines(scene)
	var joins: int = 0
	var lengths: PackedFloat32Array = PackedFloat32Array()
	for stage_seed: int in STAGES:
		builder.build(stage_seed)
		# CSG builds its collision a frame or two after entering the tree.
		for i: int in 4:
			await get_tree().physics_frame
		joins += _check_stage(builder, stage_seed)
		lengths.append(builder.length)
		var names: PackedStringArray = PackedStringArray()
		for path: String in builder.chunk_paths:
			names.append(path.get_file().get_basename().trim_prefix("chunk_"))
		print("stage %2d  %6.0f m  drop %5.0f m  %s" % [stage_seed, builder.length,
			builder.line_points[0].y - builder.line_points[-1].y, " > ".join(names)])
	builder.clear()
	print("STAGE TEST checked %d stages, %d joins" % [STAGES, joins])
	for failure: String in _failures:
		print("FAIL " + failure)
	print("STAGE TEST %s" % ("PASSED" if _failures.is_empty() else "FAILED (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check_stage(builder: StageBuilder, stage_seed: int) -> int:
	var paths: PackedStringArray = builder.chunk_paths
	if paths[0] != builder.start_chunk.resource_path:
		_failures.append("stage %d: first chunk is %s" % [stage_seed, paths[0]])
	if paths[-1] != builder.finish_chunk.resource_path:
		_failures.append("stage %d: last chunk is %s" % [stage_seed, paths[-1]])
	for i: int in range(1, paths.size() - 1):
		if paths[i] == paths[i - 1]:
			_failures.append("stage %d: %s twice in a row" % [stage_seed, paths[i]])

	var joins: int = 0
	for i: int in builder.chunks.size() - 1:
		var a: Chunk = builder.chunks[i]
		var b: Chunk = builder.chunks[i + 1]
		var exit: Transform3D = a.global_transform * a.get_exit_transform()
		var entry: Transform3D = b.global_transform * b.get_entry_transform()
		var where: String = "stage %d join %d (%s > %s)" % [stage_seed, i, paths[i].get_file(), paths[i + 1].get_file()]
		var gap: float = exit.origin.distance_to(entry.origin)
		if gap > MAX_STEP:
			_failures.append("%s: markers %.3f m apart" % [where, gap])
		var angle: float = rad_to_deg((-exit.basis.z).angle_to(-entry.basis.z))
		var roll: float = rad_to_deg(exit.basis.y.angle_to(entry.basis.y))
		if angle > MAX_ANGLE_DEG or roll > MAX_ANGLE_DEG:
			_failures.append("%s: markers turned %.2f deg, rolled %.2f deg" % [where, angle, roll])
		_check_surface(exit, where)
		joins += 1
	# Joins are all at the same slope, so a chunk is only ever turned around
	# up. A tilted chunk means its entry slope doesn't match (and its kickers,
	# pillars and finish gate would lean).
	for i: int in builder.chunks.size():
		var tilt: float = rad_to_deg(builder.chunks[i].global_basis.y.angle_to(Vector3.UP))
		if tilt > MAX_ANGLE_DEG:
			_failures.append("stage %d: %s tilted %.2f deg" % [stage_seed, paths[i].get_file(), tilt])

	# Bends: the stage's total turn stays in limits, and no chunk comes back
	# near an earlier one (except its neighbour).
	var heading: float = 0.0
	for i: int in builder.chunks.size():
		heading += builder.chunks[i].exit_heading_deg
		if absf(heading) > builder.max_stage_heading_deg + 0.5:
			_failures.append("stage %d: turned %.0f deg by chunk %d" % [stage_seed, heading, i])
	for i: int in range(2, builder.chunks.size()):
		var first_i: int = builder.chunk_first_sample[i]
		var end_i: int = builder.chunk_first_sample[i + 1] if i + 1 < builder.chunks.size() else builder.line_points.size()
		var limit: int = builder.chunk_first_sample[i - 1]
		var closest: float = INF
		for a: int in range(first_i, end_i, 10):
			for b: int in range(0, limit, 10):
				var pa: Vector3 = builder.line_points[a]
				var pb: Vector3 = builder.line_points[b]
				closest = minf(closest, Vector2(pa.x - pb.x, pa.z - pb.z).length())
		if closest < builder.min_clearance - 15.0:
			_failures.append("stage %d: chunk %d passes %.0f m from an earlier chunk" % [stage_seed, i, closest])

	# Always descending once off the start deck.
	var first: int = builder.chunk_first_sample[1]
	for i: int in range(first, builder.line_points.size() - 1):
		if builder.line_points[i + 1].y >= builder.line_points[i].y:
			_failures.append("stage %d: not descending at %.0f m" % [stage_seed, builder.line_distance[i]])
			break
	for i: int in range(1, builder.line_distance.size()):
		if builder.line_distance[i] - builder.line_distance[i - 1] > 1.5:
			_failures.append("stage %d: centerline gap at %.0f m" % [stage_seed, builder.line_distance[i]])
			break
	return joins


## Raycasts down across the track 0.3 m before and after the join. Every hit
## must sit on the join's ground plane (the track is straight and unbanked
## there) and face up.
func _check_surface(join: Transform3D, where: String) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var up: Vector3 = join.basis.y
	var forward: Vector3 = -join.basis.z
	for along: float in [-0.3, 0.3]:
		for x: float in LATERAL:
			# Off the grid lines a little: a ray straight down a shared
			# triangle edge can slip between the triangles (a sphere can't).
			var target: Vector3 = join.origin + forward * along + join.basis.x * (x + 0.37)
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(target + up * 3.0, target - up * 3.0)
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty():
				_failures.append("%s: no ground at along %.1f x %.0f" % [where, along, x])
				continue
			var step: float = (hit["position"] - join.origin).dot(up)
			if absf(step) > MAX_STEP:
				_failures.append("%s: surface step %.3f m at along %.1f x %.0f" % [where, step, along, x])
			if (hit["normal"] as Vector3).dot(up) < 0.99:
				_failures.append("%s: bad normal %s at along %.1f x %.0f" % [where, hit["normal"], along, x])


## One chunk scene on its own: its ride lines stay inside the play area and
## keep their clearance from every obstacle (sphere query along the line, at
## the rider's height).
func _check_lines(scene: PackedScene) -> void:
	var chunk: Chunk = scene.instantiate() as Chunk
	add_child(chunk)
	for i: int in 3:
		await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var terrain: TerrainPatch = chunk.get_node_or_null(^"Terrain") as TerrainPatch
	var lines: Array[RideLine] = chunk.get_ride_lines()
	var name_of: String = scene.resource_path.get_file()
	var blocked: int = 0
	for line: RideLine in lines:
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = line.clearance
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		for p: Vector3 in line.get_global_points():
			if terrain != null:
				var v: Vector3 = terrain.local_to_valley(terrain.to_local(p))
				if absf(v.x) > terrain.half_play_at(v.z) - 8.0:
					_failures.append("%s %s: path at x %.1f (d %.0f), too close to the crest" % [name_of, line.name, v.x, v.z])
					break
			query.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * (line.clearance + 0.3))
			for hit: Dictionary in space.intersect_shape(query, 8):
				var collider: Node = hit["collider"] as Node
				if collider != null and collider.is_in_group(&"obstacles"):
					blocked += 1
					if blocked <= 5:
						_failures.append("%s %s: %s within %.1f m of the line at (%.0f, %.0f)" % [name_of, line.name, collider.name, line.clearance, p.x, p.z])
	var gaps: Vector3i = _sweep_gaps(chunk, name_of)
	print("%-26s %d paths, %d on paths | %d rows: %d%% of the width free (tightest row %d%%), %d%% rows with 2+ gaps, %d%% with 3+" % [
		name_of, lines.size(), blocked, gaps.x, roundi(_free_share * 100.0), roundi(_tightest_row * 100.0), roundi(100.0 * gaps.y / maxf(gaps.x, 1.0)), roundi(100.0 * gaps.z / maxf(gaps.x, 1.0))])
	chunk.free()


## Every GAP_STEP m down the valley, probe across it every metre for
## obstacles (sphere of GAP_PROBE at rider height); the free runs are the
## gaps. Every row needs one of MIN_GAP or more. Returns (rows, rows with
## 2+ gaps, rows with 3+ gaps).
func _sweep_gaps(chunk: Chunk, name_of: String) -> Vector3i:
	var terrain: TerrainPatch = chunk.get_node_or_null(^"Terrain") as TerrainPatch
	if terrain == null:
		return Vector3i.ZERO
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = GAP_PROBE
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	var result: Vector3i = Vector3i.ZERO
	var failed: int = 0
	var free_total: float = 0.0
	var probed: float = 0.0
	_tightest_row = 1.0
	var d: float = 30.0
	while d < terrain.length - 30.0:
		var half: float = terrain.half_play_at(d) - 3.0
		var run: float = 0.0
		var gaps: int = 0
		var row_free: float = 0.0
		var row_probed: float = 0.0
		var x: float = -half
		while x <= half + 0.01:
			var p: Vector3 = terrain.to_global(terrain.valley_to_local(x, terrain.surface_height(x, -d) + GAP_PROBE + 0.3, d))
			query.transform = Transform3D(Basis.IDENTITY, p)
			var blocked: bool = false
			for hit: Dictionary in space.intersect_shape(query, 4):
				var collider: Node = hit["collider"] as Node
				if collider != null and collider.is_in_group(&"obstacles"):
					blocked = true
					break
			probed += 1.0
			row_probed += 1.0
			if not blocked:
				free_total += 1.0
				row_free += 1.0
			if blocked:
				if run >= MIN_GAP:
					gaps += 1
				run = 0.0
			else:
				run += 1.0
			x += 1.0
		if run >= MIN_GAP:
			gaps += 1
		_tightest_row = minf(_tightest_row, row_free / maxf(row_probed, 1.0))
		result.x += 1
		if gaps >= 2:
			result.y += 1
		if gaps >= 3:
			result.z += 1
		if gaps == 0:
			failed += 1
			if failed <= 3:
				_failures.append("%s: no gap of %.0f m across the valley at d %.0f" % [name_of, MIN_GAP, d])
		d += GAP_STEP
	_free_share = free_total / maxf(probed, 1.0)
	return result