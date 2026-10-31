@tool
class_name Chunk
extends Node3D
## One piece of downhill, authored as a scene (chunks/chunk_*.tscn):
##   TrackLine  Path3D: the centerline. Track/Ribbon (CSGPolygon3D) is the
##              track's cross-section extruded along it, like v0.5.
##   Entry/Exit Marker3D: where the previous chunk ends / the next begins.
##              StageBuilder puts this chunk's Entry on the previous Exit.
##   Kickers, rails, the halfpipe, the finish gate: instanced part scenes
##              (chunks/parts/, rails/rail.tscn), placed by hand.
##   Spawn      Marker3D (start chunk only): where the rider starts.
##
## Editing the line: change the keys below and press "Rebuild TrackLine
## from keys" in the inspector. It rewrites TrackLine's points (1 m apart,
## rollers and turn banking included) and moves Entry/Exit to its ends.
## Features don't follow on their own: move them after rebuilding.
## Or drag TrackLine's points by hand; then put Exit on the last point.
##
## Every chunk that sits between two others must start and end at
## JOIN_PITCH_DEG, heading 0, no bank, no roller and the plain Ribbon
## cross-section, so any two chunks meet without a step (the stage smoke
## test checks this).
##
## Godot note: @tool runs this script inside the editor too (for the button).
## Gameplay setup in _ready is skipped there.

signal finish_crossed

## Slope every chunk joins at (deg, downhill).
const JOIN_PITCH_DEG: float = 23.0
const SAMPLE_SPACING: float = 1.0
const ARC_SEGMENTS: int = 12
## Track cross-section: flat half-width, side wall radius, wall angle (deg),
## lip width, slab thickness (m). Same as v0.5's ribbon.
const PROFILE: Array[float] = [8.0, 5.0, 40.0, 0.6, 4.0]

@export_tool_button("Rebuild TrackLine from keys") var rebuild_button: Callable = rebuild_line

## How hard this chunk is (1 = easy). Later stages pick higher tiers more
## often (StageBuilder.tier_bias). Stages get harder through harder chunks,
## never through more length.
@export_range(1, 5) var difficulty: int = 1

## Length of the centerline the keys describe.
@export_range(20.0, 1000.0, 1.0, "suffix:m") var length: float = 200.0

@export_group("Line keys")
## (u in m along the chunk, slope in deg, + = downhill). Eased (smoothstep)
## from key to key; held before the first and after the last.
@export var pitch_keys: PackedVector2Array = PackedVector2Array([Vector2(0, JOIN_PITCH_DEG)])
## (u, heading in deg, + = turning left). Eased like pitch_keys.
@export var heading_keys: PackedVector2Array = PackedVector2Array([Vector2(0, 0)])
## Turns bank into the corner: this many deg per 1/m of curvature...
@export_range(0.0, 3000.0, 10.0) var bank_per_curvature: float = 900.0
## ...but never more than this.
@export_range(0.0, 45.0, 0.5, "suffix:deg") var max_bank_deg: float = 14.0
## Rollers built into the line: (start u, length, height), all in m.
@export var bumps: PackedVector3Array = PackedVector3Array()

## The centerline sampled every metre in this chunk's space (filled in _ready).
## A frame is Basis(right, up, back): -z points down the track, like a Marker3D.
var _points: PackedVector3Array = PackedVector3Array()
var _frames: Array[Basis] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_sample_line()
	var gate: FinishGate = get_node_or_null(^"FinishGate") as FinishGate
	if gate != null:
		gate.crossed.connect(finish_crossed.emit)


func get_entry_transform() -> Transform3D:
	return ($Entry as Marker3D).transform


func get_exit_transform() -> Transform3D:
	return ($Exit as Marker3D).transform


func get_spawn_transform() -> Transform3D:
	var spawn: Marker3D = get_node_or_null(^"Spawn") as Marker3D
	return spawn.transform if spawn != null else get_entry_transform()


func get_finish_gate() -> FinishGate:
	return get_node_or_null(^"FinishGate") as FinishGate


func get_points() -> PackedVector3Array:
	return _points


func get_frames() -> Array[Basis]:
	return _frames


## Samples TrackLine every metre: position, plus a frame whose up includes
## the curve's tilt (the berm banking).
func _sample_line() -> void:
	var line: Path3D = $TrackLine as Path3D
	var curve: Curve3D = line.curve
	var total: float = curve.get_baked_length()
	var count: int = maxi(ceili(total / SAMPLE_SPACING), 1)
	_points.clear()
	_frames.clear()
	for i: int in count + 1:
		var at: Transform3D = line.transform * curve.sample_baked_with_rotation(total * i / count, false, true)
		_points.append(at.origin)
		_frames.append(at.basis)
	# Square the frames up: forward from the points, up from the curve.
	for i: int in _points.size():
		var a: Vector3 = _points[maxi(i - 1, 0)]
		var b: Vector3 = _points[mini(i + 1, _points.size() - 1)]
		var forward: Vector3 = (b - a).normalized()
		var up: Vector3 = _frames[i].y
		var right: Vector3 = forward.cross(up).normalized()
		_frames[i] = Basis(right, right.cross(forward), -forward)


# --- Authoring (editor) -------------------------------------------------------

## Rewrites TrackLine from the keys and moves Entry/Exit to its ends.
func rebuild_line() -> void:
	var line: Path3D = get_node_or_null(^"TrackLine") as Path3D
	if line == null:
		push_error("Chunk %s has no TrackLine" % name)
		return
	var samples: Array[Transform3D] = compute_line()
	var curve: Curve3D = Curve3D.new()
	for i: int in samples.size():
		curve.add_point(samples[i].origin)
		curve.set_point_tilt(i, compute_bank(i * length / (samples.size() - 1)))
	line.transform = Transform3D.IDENTITY
	line.curve = curve
	var entry: Marker3D = get_node_or_null(^"Entry") as Marker3D
	if entry != null:
		entry.transform = samples[0]
	var exit: Marker3D = get_node_or_null(^"Exit") as Marker3D
	if exit != null:
		exit.transform = samples[-1]


## The line from the keys: one transform per metre (chunk space), with the
## frame Basis(right, up, back) including the bank.
func compute_line() -> Array[Transform3D]:
	var count: int = maxi(ceili(length / SAMPLE_SPACING), 1)
	var ds: float = length / count
	var samples: Array[Transform3D] = []
	var base: Vector3 = Vector3.ZERO
	for i: int in count + 1:
		var u: float = i * ds
		if i > 0:
			# Midpoint step: exact for straight parts, tiny error on curves.
			base += _dir_at(u - ds * 0.5) * ds
		var forward: Vector3 = (_dir_at(u) + Vector3.UP * _bump_slope_at(u)).normalized()
		var right: Vector3 = forward.cross(Vector3.UP).normalized()
		var up: Vector3 = right.cross(forward)
		var bank: float = compute_bank(u)
		right = right.rotated(forward, bank)
		up = up.rotated(forward, bank)
		samples.append(Transform3D(Basis(right, up, -forward), base + Vector3.UP * _bump_at(u)))
	return samples


## Line transform at `u` from the keys (for placing features while authoring).
func transform_at_u(u: float) -> Transform3D:
	var samples: Array[Transform3D] = compute_line()
	return samples[clampi(roundi(u / length * (samples.size() - 1)), 0, samples.size() - 1)]


## Bank (radians, + = tilted toward the right) from the heading's curvature.
func compute_bank(u: float) -> float:
	var curvature: float = _heading_at(u + 0.5) - _heading_at(u - 0.5)
	return deg_to_rad(clampf(-curvature * bank_per_curvature, -max_bank_deg, max_bank_deg))


## Unit direction down the line at `u` (before rollers).
func _dir_at(u: float) -> Vector3:
	var pitch: float = deg_to_rad(_key_value(pitch_keys, u))
	var heading: float = _heading_at(u)
	return Vector3(-sin(heading) * cos(pitch), -sin(pitch), -cos(heading) * cos(pitch))


func _heading_at(u: float) -> float:
	return deg_to_rad(_key_value(heading_keys, u))


func _bump_at(u: float) -> float:
	var height: float = 0.0
	for bump: Vector3 in bumps:
		if u > bump.x and u < bump.x + bump.y:
			height += bump.z * 0.5 * (1.0 - cos(TAU * (u - bump.x) / bump.y))
	return height


## d(height)/du of the rollers.
func _bump_slope_at(u: float) -> float:
	var slope: float = 0.0
	for bump: Vector3 in bumps:
		if u > bump.x and u < bump.x + bump.y:
			slope += bump.z * PI / bump.y * sin(TAU * (u - bump.x) / bump.y)
	return slope


## Value of (u, value) keys at `u`, eased with smoothstep between keys.
static func _key_value(keys: PackedVector2Array, u: float) -> float:
	if keys.is_empty():
		return 0.0
	if u <= keys[0].x:
		return keys[0].y
	for i: int in range(1, keys.size()):
		if u <= keys[i].x:
			var a: Vector2 = keys[i - 1]
			var b: Vector2 = keys[i]
			var f: float = (u - a.x) / maxf(b.x - a.x, 0.0001)
			return lerpf(a.y, b.y, f * f * (3.0 - 2.0 * f))
	return keys[-1].y


## The Ribbon's cross-section (x = right, y = up), counter-clockwise: bottom,
## right side, riding surface from right to left, left side.
static func make_profile() -> PackedVector2Array:
	var half_flat: float = PROFILE[0]
	var radius: float = PROFILE[1]
	var wall: float = deg_to_rad(PROFILE[2])
	var top: Vector2 = Vector2(half_flat + radius * sin(wall), radius * (1.0 - cos(wall)))
	var outer: Vector2 = top + Vector2(PROFILE[3], 0.0)
	var right_side: PackedVector2Array = PackedVector2Array([outer])
	for s: int in range(ARC_SEGMENTS, -1, -1):
		var a: float = wall * s / ARC_SEGMENTS
		right_side.append(Vector2(half_flat + radius * sin(a), radius * (1.0 - cos(a))))
	var profile: PackedVector2Array = PackedVector2Array([Vector2(-outer.x, -PROFILE[4]), Vector2(outer.x, -PROFILE[4])])
	profile.append_array(right_side)
	for i: int in range(right_side.size() - 1, -1, -1):
		profile.append(Vector2(-right_side[i].x, right_side[i].y))
	return profile
