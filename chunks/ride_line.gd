class_name RideLine
extends Path3D
## Invisible helper path through a landscape chunk: one of the open ways
## down that the chunk's props were kept clear of. Nothing in the game shows
## it; the landscape itself is open and the rider finds their own way. It is
## only data: out-of-bounds respawns land on the nearest one, the autopilot
## and the line test ride them, and the stage smoke test checks no obstacle
## sits on one. (Path3D curves still show in the editor, which helps when
## moving props.) Put it in the "ride_lines" group (the authored chunks do).

## Keep obstacles at least this far from the path (m, checked by the smoke test).
@export_range(0.5, 10.0, 0.1, "suffix:m") var clearance: float = 2.5

## The path in global space, one point per ~2 m (filled on first use).
var _points: PackedVector3Array = PackedVector3Array()


func get_global_points() -> PackedVector3Array:
	if _points.is_empty() and curve != null:
		var baked: PackedVector3Array = curve.get_baked_points()
		var step: int = maxi(1, int(round(2.0 / maxf(curve.bake_interval, 0.01))))
		for i: int in range(0, baked.size(), step):
			_points.append(global_transform * baked[i])
		_points.append(global_transform * baked[-1])
	return _points


## Index of the point nearest to `pos` (horizontal distance).
func nearest_index(pos: Vector3) -> int:
	var pts: PackedVector3Array = get_global_points()
	var best: int = 0
	var best_d: float = INF
	for i: int in pts.size():
		var d: float = Vector2(pts[i].x - pos.x, pts[i].z - pos.z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best


## Point `ahead` metres further down the path from index `from`, and the
## direction there: [position, direction].
func point_ahead(from: int, ahead: float) -> Array[Vector3]:
	var pts: PackedVector3Array = get_global_points()
	var i: int = clampi(from, 0, pts.size() - 1)
	var left: float = ahead
	while i < pts.size() - 1 and left > 0.0:
		left -= pts[i].distance_to(pts[i + 1])
		i += 1
	var j: int = mini(i + 1, pts.size() - 1)
	var dir: Vector3 = (pts[j] - pts[maxi(j - 1, 0)]).normalized()
	return [pts[i], dir]
