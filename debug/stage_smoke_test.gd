extends Node3D
## Headless stage check. Builds 20 random stages and checks every chunk join:
##   - markers line up: Exit of one chunk = Entry of the next (< 5 cm, < 0.5 deg)
##   - the collision surface is continuous across the join: raycasts just
##     before and after it, across the width, all hit within 5 cm of the
##     join's ground plane, with upward normals
##   - every chunk stays upright (it only turns around up to join)
##   - the stage is always descending after the start deck
##   - start first, finish last, no middle chunk twice in a row
##   - landscape chunks (v0.8): every ride line stays inside the play area and
##     no obstacle sits within its clearance (checked once per chunk scene)
## Run:  <exe> --headless --path . res://debug/stage_smoke_test.tscn
## Exits with code 1 on failure.

const STAGES: int = 20
const MAX_STEP: float = 0.05
const MAX_ANGLE_DEG: float = 0.5
const LATERAL: Array[float] = [-55.0, -35.0, -20.0, -7.0, -4.0, 0.0, 4.0, 7.0, 20.0, 35.0, 55.0]

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var builder: StageBuilder = StageBuilder.new()
	add_child(builder)
	var scenes: Array[PackedScene] = [builder.start_chunk, builder.finish_chunk]
	scenes.append_array(builder.middle_chunks)
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
			var target: Vector3 = join.origin + forward * along + join.basis.x * x
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
	var half: float = chunk.get_play_half_width()
	var lines: Array[RideLine] = chunk.get_ride_lines()
	var name_of: String = scene.resource_path.get_file()
	var blocked: int = 0
	for line: RideLine in lines:
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = line.clearance
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		for p: Vector3 in line.get_global_points():
			if absf(p.x) > half - 8.0:
				_failures.append("%s %s: line at x %.1f, outside the play area" % [name_of, line.name, p.x])
				break
			query.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * (line.clearance + 0.3))
			for hit: Dictionary in space.intersect_shape(query, 8):
				var collider: Node = hit["collider"] as Node
				if collider != null and collider.is_in_group(&"obstacles"):
					blocked += 1
					if blocked <= 5:
						_failures.append("%s %s: %s within %.1f m of the line at (%.0f, %.0f)" % [name_of, line.name, collider.name, line.clearance, p.x, p.z])
	print("%-20s %d lines, %d obstacles on lines" % [name_of, lines.size(), blocked])
	chunk.free()