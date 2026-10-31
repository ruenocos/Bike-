@tool
class_name TerrainPatch
extends Node3D
## A wide downhill landscape: one generated mesh + collision, built from the
## settings below and the shaping nodes placed under it. Previews live in the
## editor: change a value or drag a shaping node and the terrain rebuilds.
##
## Space: the origin is the middle of the entry edge at height 0. Downhill is
## -Z (the exit edge is at z = -length), X runs across. The play area is
## `width` wide (-width/2 .. width/2, edge walls included); past the wall
## crests the ground falls away for `outside_width` more on each side. That
## outside strip is rideable but out of bounds (the game counts it down).
##
## Height at a point, in order:
##   1. base slope (slope_deg, shaped along the length by slope_profile)
##   2. + noise (rolling ground)
##   3. + TerrainShape GULLY / RIDGE children (dig / raise along a curve)
##   4. blend toward TerrainShape LINE children (the ground follows the curve's
##      own height) and TerrainFlatten children (a flat pad for kickers, rails)
##   5. + edge walls (soft banks up to the crests), the outside fall-away, and
##      optional invisible boundary walls at the very edge
## Steps 2-4 fade out over `seam_blend` at the entry and exit, so every patch
## with the same width / slope / walls / cell size has exactly the same entry
## and exit edge: patches placed exit-to-entry meet without a step.
##
## Shaping nodes can sit anywhere under this node (also nested). Their order
## matters for LINE and Flatten (later ones win where they overlap).
##
## Godot note: the mesh and collision are generated children that aren't
## saved with the scene (they're "internal" and have no owner); the scene
## only stores the settings. They're rebuilt when the scene loads.

const BOUNDARY_SEGMENT: float = 20.0

@export_tool_button("Rebuild terrain") var rebuild_button: Callable = rebuild
## Puts every child of the "Props" node under this patch on the ground (keeps
## x/z, sets the height). Press after reshaping the terrain.
@export_tool_button("Snap props to ground") var snap_props_button: Callable = snap_props

@export_group("Size")
## Across the play area, crest to crest (edge walls included).
@export_range(20.0, 400.0, 1.0, "suffix:m") var width: float = 150.0:
	set(v):
		width = v
		queue_rebuild()
## Downhill, along -Z.
@export_range(20.0, 1000.0, 1.0, "suffix:m") var length: float = 300.0:
	set(v):
		length = v
		queue_rebuild()
## Grid spacing of the mesh and collision. Smaller = smoother, slower to build.
## Patches that join must use the same cell size.
@export_range(0.5, 8.0, 0.25, "suffix:m") var cell_size: float = 2.0:
	set(v):
		cell_size = v
		queue_rebuild()

@export_group("Slope")
## Downhill angle. Chunks join at 23 deg (Chunk.JOIN_PITCH_DEG).
@export_range(0.0, 60.0, 0.5, "suffix:deg") var slope_deg: float = 23.0:
	set(v):
		slope_deg = v
		queue_rebuild()
## Optional: the slope along the length, as a multiplier of slope_deg
## (x 0 = entry, x 1 = exit). Keep both ends at 1 so patches still join.
## Empty = the same slope all the way.
@export var slope_profile: Curve:
	set(v):
		if slope_profile != null and slope_profile.changed.is_connected(queue_rebuild):
			slope_profile.changed.disconnect(queue_rebuild)
		slope_profile = v
		if slope_profile != null:
			slope_profile.changed.connect(queue_rebuild)
		queue_rebuild()

@export_group("Noise")
## Height of the rolling ground, up and down from the slope.
@export_range(0.0, 20.0, 0.1, "suffix:m") var noise_amplitude: float = 2.5:
	set(v):
		noise_amplitude = v
		queue_rebuild()
## Bumps per metre. 0.01 = long swells, 0.05 = choppy.
@export_range(0.001, 0.2, 0.001) var noise_frequency: float = 0.015:
	set(v):
		noise_frequency = v
		queue_rebuild()
@export_range(1, 6) var noise_octaves: int = 3:
	set(v):
		noise_octaves = v
		queue_rebuild()
@export var noise_seed: int = 1:
	set(v):
		noise_seed = v
		queue_rebuild()
## How far in from the entry and exit the noise and shaping fade in, so the
## edges stay plain slope and line up with the next patch.
@export_range(0.0, 100.0, 1.0, "suffix:m") var seam_blend: float = 30.0:
	set(v):
		seam_blend = v
		queue_rebuild()

@export_group("Edges")
## How far in from each side the edge walls start to rise.
@export_range(0.0, 80.0, 0.5, "suffix:m") var wall_width: float = 16.0:
	set(v):
		wall_width = v
		queue_rebuild()
## How high the walls are at the very edge.
@export_range(0.0, 60.0, 0.5, "suffix:m") var wall_height: float = 14.0:
	set(v):
		wall_height = v
		queue_rebuild()
## Wall shape: 1 = straight ramp, 2 = curves up like a bank, 3+ = cliffier.
@export_range(1.0, 5.0, 0.1) var wall_curve: float = 2.2:
	set(v):
		wall_curve = v
		queue_rebuild()
## Out-of-bounds ground past each crest (m). 0 = the mesh ends at the crests.
@export_range(0.0, 200.0, 1.0, "suffix:m") var outside_width: float = 50.0:
	set(v):
		outside_width = v
		queue_rebuild()
## How far the outside ground falls from the crest to the outer edge (m).
@export_range(0.0, 200.0, 1.0, "suffix:m") var outside_drop: float = 30.0:
	set(v):
		outside_drop = v
		queue_rebuild()
## Invisible walls at the outer edges, this high above the ground there.
## 0 = none (the game handles out of bounds instead).
@export_range(0.0, 200.0, 1.0, "suffix:m") var boundary_height: float = 0.0:
	set(v):
		boundary_height = v
		queue_rebuild()

@export_group("Look")
@export var material: Material = preload("res://chunks/materials/terrain.tres"):
	set(v):
		material = v
		if _mesh_instance != null:
			_mesh_instance.material_override = material

## Grid size and heights of the last build (row-major: row r = z -r*dz).
var columns: int = 0
var rows: int = 0
var heights: PackedFloat32Array = PackedFloat32Array()

var _mesh_instance: MeshInstance3D
var _body: StaticBody3D
var _rebuild_queued: bool = false
var _noise: FastNoiseLite = FastNoiseLite.new()
## Height of the base slope at each row (index = row).
var _row_base: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TerrainMesh"
	add_child(_mesh_instance, false, Node.INTERNAL_MODE_BACK)
	_body = StaticBody3D.new()
	_body.name = "TerrainBody"
	add_child(_body, false, Node.INTERNAL_MODE_BACK)
	rebuild()
	# Adding or removing shaping nodes rebuilds (connected after our own children).
	child_order_changed.connect(queue_rebuild)


## Rebuild once at the end of this frame (many edits in a row = one build).
func queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	_compute_heights()
	_build_mesh()
	_build_collision()


## Height of the plain slope + edge walls (no noise or shaping) at local
## (x, z). The entry and exit edges are exactly this.
func base_height(x: float, z: float) -> float:
	return _slope_height(-z) + _wall_height(x)


## Height of the built surface at local (x, z): the mesh / collision, the same
## triangles. Outside the patch it clamps to the nearest edge.
func surface_height(x: float, z: float) -> float:
	if heights.is_empty():
		return 0.0
	var dx: float = half_total_width() * 2.0 / float(columns - 1)
	var dz: float = length / float(rows - 1)
	var fx: float = clampf((x + half_total_width()) / dx, 0.0, float(columns - 1) - 0.0001)
	var fz: float = clampf(-z / dz, 0.0, float(rows - 1) - 0.0001)
	var c: int = int(fx)
	var r: int = int(fz)
	var tx: float = fx - c
	var tz: float = fz - r
	var h00: float = heights[r * columns + c]
	var h10: float = heights[r * columns + c + 1]
	var h01: float = heights[(r + 1) * columns + c]
	var h11: float = heights[(r + 1) * columns + c + 1]
	# Same split as the mesh: diagonal from (c, r) to (c+1, r+1).
	if tx >= tz:
		return h00 + (h10 - h00) * tx + (h11 - h10) * tz
	return h00 + (h11 - h01) * tx + (h01 - h00) * tz


## Middle of the exit edge in this patch's space: put the next patch here.
func exit_point() -> Vector3:
	return Vector3(0.0, _slope_height(length), -length)


## Half the mesh width: the play area plus the outside strip.
func half_total_width() -> float:
	return width * 0.5 + outside_width


## Sets the height of every child of the "Props" node to the surface under it.
func snap_props() -> void:
	var props: Node = get_node_or_null(^"Props")
	if props == null:
		return
	if heights.is_empty() or _rebuild_queued:
		rebuild()
	for child: Node in props.get_children():
		var prop: Node3D = child as Node3D
		if prop == null:
			continue
		var at: Vector3 = _to_patch(prop).origin
		var offset: float = float(prop.get_meta(&"ground_offset", 0.0))
		prop.position.y += surface_height(at.x, at.z) + offset - at.y


# --- Heights ---------------------------------------------------------------

func _compute_heights() -> void:
	columns = maxi(2, int(round(half_total_width() * 2.0 / cell_size)) + 1)
	rows = maxi(2, int(round(length / cell_size)) + 1)
	var dx: float = half_total_width() * 2.0 / float(columns - 1)
	var dz: float = length / float(rows - 1)
	_compute_row_base(dz)

	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = noise_seed
	_noise.frequency = noise_frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM if noise_octaves > 1 else FastNoiseLite.FRACTAL_NONE
	_noise.fractal_octaves = noise_octaves

	var count: int = columns * rows
	# Height on top of the base slope (noise + shaping), before the seam fade.
	var detail: PackedFloat32Array = PackedFloat32Array()
	detail.resize(count)
	for r: int in rows:
		var d: float = r * dz
		for c: int in columns:
			var x: float = -half_total_width() + c * dx
			detail[r * columns + c] = _noise.get_noise_2d(x, d) * noise_amplitude

	var shapes: Array[Node3D] = []
	_collect_shapers(self, shapes)
	# Additive shapes first (gullies dig into the noise), then the blends.
	for s: Node3D in shapes:
		if s is TerrainShape and (s as TerrainShape).mode != TerrainShape.Mode.LINE:
			_apply_shape(s as TerrainShape, detail, dx, dz)
	for s: Node3D in shapes:
		if s is TerrainShape and (s as TerrainShape).mode == TerrainShape.Mode.LINE:
			_apply_shape(s as TerrainShape, detail, dx, dz)
		elif s is TerrainFlatten:
			_apply_flatten(s as TerrainFlatten, detail, dx, dz)

	heights.resize(count)
	for r: int in rows:
		var d: float = r * dz
		var fade: float = _seam_fade(d)
		for c: int in columns:
			var x: float = -half_total_width() + c * dx
			heights[r * columns + c] = _row_base[r] + detail[r * columns + c] * fade + _wall_height(x)


## Integrates the slope (with slope_profile) down the rows.
func _compute_row_base(dz: float) -> void:
	_row_base.resize(rows)
	_row_base[0] = 0.0
	for r: int in range(1, rows):
		var mid: float = (r - 0.5) * dz / length
		_row_base[r] = _row_base[r - 1] - tan(deg_to_rad(_slope_at(mid))) * dz


func _slope_at(t: float) -> float:
	var k: float = 1.0 if slope_profile == null else slope_profile.sample(clampf(t, 0.0, 1.0))
	return clampf(slope_deg * k, -60.0, 75.0)


## Base slope height at distance d downhill (between rows: linear, same as the mesh).
func _slope_height(d: float) -> float:
	if _row_base.is_empty():
		return -tan(deg_to_rad(slope_deg)) * d
	var dz: float = length / float(rows - 1)
	var f: float = clampf(d / dz, 0.0, float(rows - 1))
	var r: int = mini(int(f), rows - 2)
	return lerpf(_row_base[r], _row_base[r + 1], f - r)


## Edge profile across the valley: 0 in the middle, rising to wall_height at
## the crests (|x| = width/2), then falling away by outside_drop.
func _wall_height(x: float) -> float:
	var e: float = width * 0.5 - absf(x)
	if e < 0.0:
		var t: float = minf(-e / maxf(outside_width, 0.001), 1.0)
		return wall_height - outside_drop * t * t
	if wall_width <= 0.0 or e >= wall_width:
		return 0.0
	return wall_height * pow(1.0 - e / wall_width, wall_curve)


func _seam_fade(d: float) -> float:
	if seam_blend <= 0.0:
		return 1.0
	return smoothstep(0.0, seam_blend, d) * smoothstep(0.0, seam_blend, length - d)


func _collect_shapers(node: Node, out: Array[Node3D]) -> void:
	for child: Node in node.get_children():
		if child is TerrainShape or child is TerrainFlatten:
			if (child as Node3D).visible:
				out.append(child as Node3D)
		_collect_shapers(child, out)


## Transform from a descendant's space into this patch's space (works in the
## editor before global transforms are valid).
func _to_patch(node: Node3D) -> Transform3D:
	var xform: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != self:
		if n is Node3D:
			xform = (n as Node3D).transform * xform
		n = n.get_parent()
	return xform


## Rasterizes the curve segment by segment: each grid point within reach gets
## its distance to the curve and the curve's height there (base slope removed).
func _apply_shape(shape: TerrainShape, detail: PackedFloat32Array, dx: float, dz: float) -> void:
	if shape.curve == null or shape.curve.point_count < 2:
		return
	var xform: Transform3D = _to_patch(shape)
	var baked: PackedVector3Array = shape.curve.get_baked_points()
	if baked.size() < 2:
		return
	var pts: PackedVector3Array = PackedVector3Array()
	pts.resize(baked.size())
	for i: int in baked.size():
		pts[i] = xform * baked[i]
	var half: float = shape.width * 0.5
	var count: int = columns * rows
	var best_dist: PackedFloat32Array = PackedFloat32Array()
	best_dist.resize(count)
	best_dist.fill(INF)
	var best_y: PackedFloat32Array = PackedFloat32Array()
	best_y.resize(count)
	for i: int in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var a2: Vector2 = Vector2(a.x, a.z)
		var ab: Vector2 = Vector2(b.x, b.z) - a2
		var ab_len2: float = ab.length_squared()
		var c0: int = maxi(0, int(floor((minf(a.x, b.x) - half + half_total_width()) / dx)))
		var c1: int = mini(columns - 1, int(ceil((maxf(a.x, b.x) + half + half_total_width()) / dx)))
		var r0: int = maxi(0, int(floor((-maxf(a.z, b.z) - half) / dz)))
		var r1: int = mini(rows - 1, int(ceil((-minf(a.z, b.z) + half) / dz)))
		for r: int in range(r0, r1 + 1):
			var z: float = -r * dz
			for c: int in range(c0, c1 + 1):
				var p: Vector2 = Vector2(-half_total_width() + c * dx, z)
				var t: float = 0.0 if ab_len2 <= 0.0 else clampf((p - a2).dot(ab) / ab_len2, 0.0, 1.0)
				var dist: float = p.distance_to(a2 + ab * t)
				var idx: int = r * columns + c
				if dist < best_dist[idx]:
					best_dist[idx] = dist
					best_y[idx] = lerpf(a.y, b.y, t)
	for r: int in rows:
		var row_base: float = _row_base[r]
		for c: int in columns:
			var idx: int = r * columns + c
			var dist: float = best_dist[idx]
			if dist >= half:
				continue
			var k: float = shape.profile(dist / half)
			match shape.mode:
				TerrainShape.Mode.GULLY:
					detail[idx] -= shape.depth * k
				TerrainShape.Mode.RIDGE:
					detail[idx] += shape.depth * k
				TerrainShape.Mode.LINE:
					var target: float = best_y[idx] - row_base
					detail[idx] = lerpf(detail[idx], target, k)


## Blends the ground toward the flatten node's own XZ plane (tilt the node to
## match the slope) inside its size, easing out over `blend`.
func _apply_flatten(flat: TerrainFlatten, detail: PackedFloat32Array, dx: float, dz: float) -> void:
	var xform: Transform3D = _to_patch(flat)
	var inv: Transform3D = xform.affine_inverse()
	var plane_n: Vector3 = xform.basis.y.normalized()
	if absf(plane_n.y) < 0.2:
		return
	var origin: Vector3 = xform.origin
	var reach: float = flat.size.length() * 0.5 + flat.blend
	var c0: int = maxi(0, int(floor((origin.x - reach + half_total_width()) / dx)))
	var c1: int = mini(columns - 1, int(ceil((origin.x + reach + half_total_width()) / dx)))
	var r0: int = maxi(0, int(floor((-origin.z - reach) / dz)))
	var r1: int = mini(rows - 1, int(ceil((-origin.z + reach) / dz)))
	for r: int in range(r0, r1 + 1):
		var z: float = -r * dz
		for c: int in range(c0, c1 + 1):
			var x: float = -half_total_width() + c * dx
			# Height of the pad's plane at (x, z), then its footprint in pad space.
			var plane_y: float = origin.y - (plane_n.x * (x - origin.x) + plane_n.z * (z - origin.z)) / plane_n.y
			var local: Vector3 = inv * Vector3(x, plane_y, z)
			var ex: float = maxf(absf(local.x) - flat.size.x * 0.5, 0.0)
			var ez: float = maxf(absf(local.z) - flat.size.y * 0.5, 0.0)
			var out: float = Vector2(ex, ez).length()
			if out >= flat.blend and out > 0.0:
				continue
			var k: float = 1.0 if flat.blend <= 0.0 else 1.0 - smoothstep(0.0, flat.blend, out)
			var idx: int = r * columns + c
			detail[idx] = lerpf(detail[idx], plane_y - _row_base[r], k)


# --- Mesh and collision ----------------------------------------------------

func _build_mesh() -> void:

	var dx: float = half_total_width() * 2.0 / float(columns - 1)
	var dz: float = length / float(rows - 1)
	var count: int = columns * rows
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	verts.resize(count)
	normals.resize(count)
	for r: int in rows:
		for c: int in columns:
			var idx: int = r * columns + c
			verts[idx] = Vector3(-half_total_width() + c * dx, heights[idx], -r * dz)
			# Central differences (one-sided on the border).
			var cl: int = maxi(c - 1, 0)
			var cr: int = mini(c + 1, columns - 1)
			var ru: int = maxi(r - 1, 0)
			var rd: int = mini(r + 1, rows - 1)
			var slope_x: float = (heights[r * columns + cr] - heights[r * columns + cl]) / ((cr - cl) * dx)
			# z = -r * dz, so going down the rows is going toward -z.
			var slope_z: float = -(heights[rd * columns + c] - heights[ru * columns + c]) / ((rd - ru) * dz)
			normals[idx] = Vector3(-slope_x, 1.0, -slope_z).normalized()
	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize((columns - 1) * (rows - 1) * 6)
	var i: int = 0
	for r: int in rows - 1:
		for c: int in columns - 1:
			var a: int = r * columns + c
			var b: int = a + 1
			var d: int = a + columns
			var e: int = d + 1
			# Godot's front faces wind clockwise; seen from above these do.
			indices[i] = a
			indices[i + 1] = e
			indices[i + 2] = b
			indices[i + 3] = a
			indices[i + 4] = d
			indices[i + 5] = e
			i += 6
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = material


func _build_collision() -> void:

	for child: Node in _body.get_children():
		child.free()
	var mesh: ArrayMesh = _mesh_instance.mesh as ArrayMesh
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	_body.add_child(col)
	if boundary_height > 0.0:
		_build_boundary(-1.0)
		_build_boundary(1.0)


## Upright boxes along one side edge, one per BOUNDARY_SEGMENT, from below the
## lowest edge point to boundary_height above the highest.
func _build_boundary(side: float) -> void:
	var x: float = side * (half_total_width() + 0.5)
	var edge_c: int = 0 if side < 0.0 else columns - 1
	var dz: float = length / float(rows - 1)
	var steps: int = maxi(1, int(ceil(length / BOUNDARY_SEGMENT)))
	for s: int in steps:
		var d0: float = length * s / steps
		var d1: float = length * (s + 1) / steps
		var low: float = INF
		var high: float = -INF
		for r: int in range(int(floor(d0 / dz)), mini(rows - 1, int(ceil(d1 / dz))) + 1):
			low = minf(low, heights[r * columns + edge_c])
			high = maxf(high, heights[r * columns + edge_c])
		var bottom: float = low - 10.0
		var top: float = high + boundary_height
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(1.0, top - bottom, d1 - d0 + 1.0)
		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = box
		col.position = Vector3(x, (top + bottom) * 0.5, -(d0 + d1) * 0.5)
		_body.add_child(col)