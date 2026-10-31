class_name StageBuilder
extends Node3D
## Builds one stage from chunk scenes: the start chunk, `middle_count` random
## middle chunks (never the same one twice in a row) and the finish chunk,
## each one's Entry marker put on the previous one's Exit marker. The same
## seed always builds the same stage. It only instances and places chunks;
## the chunks themselves are authored in the editor (chunks/chunk_*.tscn).
## Add a new chunk by duplicating chunk_template.tscn and dragging it into
## `middle_chunks` in the inspector.
##
## Godot note: CSG builds its collision a frame or two after it enters the
## tree, so wait a couple of physics frames after build() before riding.
##
## It also keeps the whole stage's centerline (in global space) so the game
## can ask "how far down the stage is this point" (progress) and "where is the
## track at distance d" (the collapse follows it). Chunks far behind the
## player are freed; chunks the collapse has passed crumble away.

signal finished

## v0.8: the open-landscape chunks (chunks/landscape/). The v0.7 corridor
## chunks (chunks/chunk_*.tscn) still work here; drag them in to mix.
@export var start_chunk: PackedScene = preload("res://chunks/landscape/land_start.tscn")
@export var middle_chunks: Array[PackedScene] = [
	preload("res://chunks/landscape/land_meadow.tscn"),
	preload("res://chunks/landscape/land_ridge.tscn"),
	preload("res://chunks/landscape/land_forest.tscn"),
	preload("res://chunks/landscape/land_boulders.tscn"),
	preload("res://chunks/landscape/land_gorge.tscn"),
	preload("res://chunks/landscape/land_slalom.tscn"),
	preload("res://chunks/landscape/land_fast_s.tscn"),
	preload("res://chunks/landscape/land_switchback_left.tscn"),
	preload("res://chunks/landscape/land_switchback_right.tscn"),
]
@export var finish_chunk: PackedScene = preload("res://chunks/landscape/land_finish.tscn")
@export_range(0, 20) var middle_count: int = 8
## Later stages lean toward harder chunks: a chunk's pick weight is
## 1 + tier_bias * stage_index * (difficulty - 1). 0 = every chunk equally likely.
@export_range(0.0, 5.0, 0.05) var tier_bias: float = 0.5
## Bending valleys (v0.8.1): the stage's total turn (sum of the chunks'
## exit_heading_deg) never goes past this either way...
@export_range(0.0, 180.0, 1.0, "suffix:deg") var max_stage_heading_deg: float = 85.0
## ...and a new chunk's centerline must stay this far from every earlier
## chunk except its neighbour, so a stage never curls back over itself.
@export_range(0.0, 1000.0, 5.0, "suffix:m") var min_clearance: float = 250.0
## Chunks that end this far behind the player are freed.
@export_range(50.0, 2000.0, 10.0, "suffix:m") var free_behind_distance: float = 300.0
## Chunks the collapse has passed drop this far...
@export_range(0.0, 500.0, 1.0, "suffix:m") var crumble_drop: float = 80.0
## ...over this long, then are freed.
@export_range(0.1, 10.0, 0.1, "suffix:s") var crumble_time: float = 2.5

var chunks: Array[Chunk] = []
## Scene file of each chunk, in order (the smoke test checks the picks).
var chunk_paths: PackedStringArray = PackedStringArray()
## Stage distance at each chunk's entry and exit.
var chunk_start_distance: PackedFloat32Array = PackedFloat32Array()
var chunk_end_distance: PackedFloat32Array = PackedFloat32Array()
## Index of the first sample of each chunk in the line arrays.
var chunk_first_sample: PackedInt32Array = PackedInt32Array()
## The whole stage's centerline, global space.
var line_points: PackedVector3Array = PackedVector3Array()
var line_frames: Array[Basis] = []
var line_distance: PackedFloat32Array = PackedFloat32Array()
var length: float = 0.0
## Stage distance of the finish line.
var finish_distance: float = 0.0

## Sample index near the last progress_at() result, so lookups stay local.
var _hint: int = 0
## Chunks already crumbling or freed.
var _gone: Array[bool] = []


func clear() -> void:
	for chunk: Chunk in chunks:
		if is_instance_valid(chunk):
			chunk.free()
	chunks.clear()
	chunk_paths.clear()
	chunk_start_distance.clear()
	chunk_end_distance.clear()
	chunk_first_sample.clear()
	line_points.clear()
	line_frames.clear()
	line_distance.clear()
	_gone.clear()
	length = 0.0
	finish_distance = 0.0
	_hint = 0


## Picks and builds a stage. `middle` < 0 uses middle_count. `stage_index`
## (0 = first stage) tilts the picks toward higher-difficulty chunks.
func build(stage_seed: int, middle: int = -1, stage_index: int = 0) -> void:
	clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(stage_seed)
	var weights: PackedFloat32Array = PackedFloat32Array()
	for scene: PackedScene in middle_chunks:
		weights.append(1.0 + tier_bias * stage_index * (_difficulty_of(scene) - 1))
	var at: Transform3D = _place(start_chunk, global_transform)
	var last: int = -1
	var heading: float = 0.0
	for i: int in (middle_count if middle < 0 else middle):
		# Never the same chunk twice in a row; never turning past the limit
		# or back over earlier chunks (rejected picks are dropped for this slot).
		var allowed: PackedFloat32Array = weights.duplicate()
		if last >= 0 and middle_chunks.size() > 1:
			allowed[last] = 0.0
		while true:
			var total: float = 0.0
			for w: float in allowed:
				total += w
			if total <= 0.0:
				push_warning("StageBuilder: no chunk fits slot %d; stage is one chunk short" % i)
				break
			var index: int = rng.rand_weighted(allowed)
			var turn: float = float(_chunk_property(middle_chunks[index], &"exit_heading_deg", 0.0))
			if absf(heading + turn) > max_stage_heading_deg:
				allowed[index] = 0.0
				continue
			var next: Transform3D = _place(middle_chunks[index], at)
			if next == Transform3D():
				allowed[index] = 0.0
				continue
			at = next
			heading += turn
			last = index
			break
	_place(finish_chunk, at, false)
	length = line_distance[-1]
	var gate: FinishGate = chunks[-1].get_finish_gate()
	finish_distance = nearest_distance(gate.global_position) if gate != null else length


## Instances `scene` with its Entry on `at` and appends it to the stage.
## With `check`, a chunk that comes too close to an earlier one (not its
## neighbour) is freed instead and an empty Transform3D() is returned.
## Returns the global transform of the new chunk's Exit.
func _place(scene: PackedScene, at: Transform3D, check: bool = true) -> Transform3D:
	var chunk: Chunk = scene.instantiate() as Chunk
	add_child(chunk)
	# Entry onto the previous exit. Every join is at the same slope, so this
	# only moves and turns the chunk around up.
	chunk.global_transform = at * chunk.get_entry_transform().affine_inverse()
	if check and chunks.size() >= 2 and _too_close(chunk):
		chunk.free()
		return Transform3D()
	_append_line(chunk)
	chunks.append(chunk)
	chunk_paths.append(scene.resource_path)
	_gone.append(false)
	chunk.finish_crossed.connect(finished.emit)
	return chunk.global_transform * chunk.get_exit_transform()


## True when the chunk's centerline passes within min_clearance of any
## chunk before the last one (horizontal distance, every 10 m).
func _too_close(chunk: Chunk) -> bool:
	var points: PackedVector3Array = chunk.get_points()
	var limit: int = chunk_first_sample[chunks.size() - 1]
	for i: int in range(0, points.size(), 10):
		var p: Vector3 = chunk.global_transform * points[i]
		for j: int in range(0, limit, 10):
			if Vector2(p.x - line_points[j].x, p.z - line_points[j].z).length() < min_clearance:
				return true
	return false


## A chunk scene's `difficulty` without instancing it.
static func _difficulty_of(scene: PackedScene) -> int:
	return int(_chunk_property(scene, &"difficulty", 1))


## A property saved on a chunk scene's root, without instancing it (the
## default when it was never changed).
static func _chunk_property(scene: PackedScene, property: StringName, default: Variant) -> Variant:
	var state: SceneState = scene.get_state()
	for i: int in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == property:
			return state.get_node_property_value(0, i)
	return default


func _append_line(chunk: Chunk) -> void:
	var points: PackedVector3Array = chunk.get_points()
	var frames: Array[Basis] = chunk.get_frames()
	var start: float = line_distance[-1] if not line_distance.is_empty() else 0.0
	chunk_start_distance.append(start)
	# The first sample sits on the previous chunk's last one.
	var first: int = 0 if line_points.is_empty() else 1
	chunk_first_sample.append(line_points.size() - first)
	var xform: Transform3D = chunk.global_transform
	for i: int in range(first, points.size()):
		var point: Vector3 = xform * points[i]
		if not line_points.is_empty():
			line_distance.append(line_distance[-1] + point.distance_to(line_points[-1]))
		else:
			line_distance.append(0.0)
		line_points.append(point)
		line_frames.append(xform.basis * frames[i])
	chunk_end_distance.append(line_distance[-1])


## Global transform of the spawn point on the start chunk.
func get_spawn_transform() -> Transform3D:
	return chunks[0].global_transform * chunks[0].get_spawn_transform()


## Distance down the stage of the point nearest to `pos` (m). Searches near
## the last answer first; pass `reset_hint` after a teleport.
func progress_at(pos: Vector3, reset_hint: bool = false) -> float:
	if line_points.size() < 2:
		return 0.0
	var from: int = 0 if reset_hint else maxi(_hint - 40, 0)
	var to: int = line_points.size() - 1 if reset_hint else mini(_hint + 80, line_points.size() - 1)
	var best: int = from
	var best_dist: float = INF
	for i: int in range(from, to + 1):
		var d: float = line_points[i].distance_squared_to(pos)
		if d < best_dist:
			best_dist = d
			best = i
	_hint = best
	# Project onto the segment ahead (or behind) of the nearest sample.
	var i0: int = clampi(best, 0, line_points.size() - 2)
	var seg: Vector3 = line_points[i0 + 1] - line_points[i0]
	var f: float = (pos - line_points[i0]).dot(seg) / maxf(seg.length_squared(), 0.0001)
	if f < 0.0 and i0 > 0:
		i0 -= 1
		seg = line_points[i0 + 1] - line_points[i0]
		f = (pos - line_points[i0]).dot(seg) / maxf(seg.length_squared(), 0.0001)
	return lerpf(line_distance[i0], line_distance[i0 + 1], clampf(f, 0.0, 1.0))


## Stage distance of the centerline sample nearest to `pos` (full search,
## leaves the progress_at hint alone).
func nearest_distance(pos: Vector3) -> float:
	var best: int = 0
	var best_dist: float = INF
	for i: int in line_points.size():
		var d: float = line_points[i].distance_squared_to(pos)
		if d < best_dist:
			best_dist = d
			best = i
	return line_distance[best] if not line_distance.is_empty() else 0.0


## Centerline transform at stage distance `d` (clamped to the stage).
func transform_at_distance(d: float) -> Transform3D:
	if line_points.is_empty():
		return Transform3D.IDENTITY
	var i: int = clampi(line_distance.bsearch(d) - 1, 0, line_points.size() - 2)
	var span: float = maxf(line_distance[i + 1] - line_distance[i], 0.0001)
	var f: float = clampf((d - line_distance[i]) / span, 0.0, 1.0)
	var basis: Basis = line_frames[i] if f < 0.5 else line_frames[i + 1]
	return Transform3D(basis, line_points[i].lerp(line_points[i + 1], f))


## Index of the chunk that contains stage distance `d`.
func chunk_index_at(d: float) -> int:
	for i: int in chunks.size():
		if d <= chunk_end_distance[i]:
			return i
	return chunks.size() - 1


## True when a global point is past the valley's crests in the chunk at
## stage distance `d` (follows bends and narrowing).
func out_of_bounds(pos: Vector3, d: float) -> bool:
	var i: int = chunk_index_at(d)
	if i < 0 or _gone[i] or not is_instance_valid(chunks[i]):
		return false
	return chunks[i].is_out_of_bounds(pos)


## The ride line nearest to `pos` in the chunks around `d`, or null.
func nearest_ride_line(pos: Vector3, d: float) -> RideLine:
	var best: RideLine = null
	var best_dist: float = INF
	var i: int = chunk_index_at(d)
	for j: int in range(maxi(i - 1, 0), mini(i + 2, chunks.size())):
		if _gone[j] or not is_instance_valid(chunks[j]):
			continue
		for line: RideLine in chunks[j].get_ride_lines():
			var pts: PackedVector3Array = line.get_global_points()
			var p: Vector3 = pts[line.nearest_index(pos)]
			var dist: float = Vector2(p.x - pos.x, p.z - pos.z).length()
			# Prefer the chunk you're in: lines in the next/previous one only
			# win when clearly closer.
			if j != i:
				dist += 30.0
			if dist < best_dist:
				best_dist = dist
				best = line
	return best


## Frees chunks far behind `player_progress`.
func free_behind(player_progress: float) -> void:
	for i: int in chunks.size():
		if not _gone[i] and chunk_end_distance[i] < player_progress - free_behind_distance:
			_gone[i] = true
			chunks[i].queue_free()


## Chunks that end before `collapse_distance` drop away and are freed.
func crumble_before(collapse_distance: float) -> void:
	for i: int in chunks.size():
		if not _gone[i] and chunk_end_distance[i] < collapse_distance:
			_gone[i] = true
			var chunk: Chunk = chunks[i]
			var tween: Tween = chunk.create_tween()
			tween.tween_property(chunk, "position", chunk.position + Vector3.DOWN * crumble_drop, crumble_time) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(chunk.queue_free)
