class_name RailSnap
extends RefCounted
## Result of looking for the closest rail. Use RailSnap.find_closest().
##
## Godot note: a rail is a Path3D in the "rails" group. Its Curve3D stores
## points in the Path3D's LOCAL space, so positions are converted with
## to_local / to_global around every curve lookup. An "offset" is the
## distance along the curve in metres, from 0 to get_baked_length().

var rail: Path3D
var offset: float = 0.0
var distance: float = INF


## Closest point on any rail within `radius` of `world_position`, or null.
static func find_closest(tree: SceneTree, world_position: Vector3, radius: float) -> RailSnap:
	var best: RailSnap = null
	for node: Node in tree.get_nodes_in_group(&"rails"):
		var path: Path3D = node as Path3D
		if path == null or path.curve == null or path.curve.get_baked_length() <= 0.0:
			continue
		var local_position: Vector3 = path.to_local(world_position)
		var hit_offset: float = path.curve.get_closest_offset(local_position)
		var point: Vector3 = path.to_global(path.curve.sample_baked(hit_offset))
		var hit_distance: float = point.distance_to(world_position)
		if hit_distance <= radius and (best == null or hit_distance < best.distance):
			best = RailSnap.new()
			best.rail = path
			best.offset = hit_offset
			best.distance = hit_distance
	return best


## World-space point on the rail at `at_offset`.
static func point_at(path: Path3D, at_offset: float) -> Vector3:
	return path.to_global(path.curve.sample_baked(at_offset))


## World-space unit direction of the rail at `at_offset`, pointing toward
## higher offsets.
static func tangent_at(path: Path3D, at_offset: float) -> Vector3:
	var length: float = path.curve.get_baked_length()
	var a: float = clampf(at_offset - 0.25, 0.0, length)
	var b: float = clampf(at_offset + 0.25, 0.0, length)
	var dir: Vector3 = point_at(path, b) - point_at(path, a)
	return dir.normalized() if dir.length_squared() > 0.000001 else Vector3.FORWARD
