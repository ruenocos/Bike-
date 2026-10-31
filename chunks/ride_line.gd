@tool
class_name RideLine
extends Path3D
## One way down a landscape chunk: a curve on the ground that a rider can
## follow without hitting anything. Lines split near the chunk's entry and
## rejoin near its exit. They're the respawn spots after going out of bounds,
## the autopilot follows them, and the stage smoke test checks that no
## obstacle sits on one. Draw the curve in the editor (points on the ground).
## Put it in the "ride_lines" group (the authored chunks do).
## A faint stripe on the ground, coloured by style, shows the line (greybox
## readability: cyan rail, orange jump, green carve). It follows the curve in
## the editor too.

enum Style { RAIL, JUMP, CARVE }

## What this line is about: grinding, kickers, or turns between obstacles.
@export var style: Style = Style.CARVE
## Keep obstacles at least this far from the line (m, checked by the smoke test).
@export_range(0.5, 10.0, 0.1, "suffix:m") var clearance: float = 2.5
@export_group("Stripe")
@export var show_stripe: bool = true:
	set(v):
		show_stripe = v
		_build_stripe()
@export_range(0.1, 5.0, 0.05, "suffix:m") var stripe_width: float = 1.2:
	set(v):
		stripe_width = v
		_build_stripe()
## Stripe colour per style: rail, jump, carve.
@export var style_colors: Array[Color] = [Color(0.3, 0.9, 1.0, 0.45), Color(1.0, 0.6, 0.15, 0.45), Color(0.45, 1.0, 0.45, 0.4)]:
	set(v):
		style_colors = v
		_build_stripe()

var _stripe: MeshInstance3D

## The line in global space, one point per ~2 m (filled on first use).
var _points: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	if Engine.is_editor_hint():
		curve_changed.connect(_build_stripe)
	_build_stripe()


## Flat ribbon along the curve, a hair above the ground. Not saved with the scene.
func _build_stripe() -> void:
	if not is_inside_tree():
		return
	if _stripe == null:
		_stripe = MeshInstance3D.new()
		_stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_stripe, false, Node.INTERNAL_MODE_BACK)
	_stripe.visible = show_stripe
	if not show_stripe or curve == null or curve.point_count < 2:
		return
	var baked: PackedVector3Array = curve.get_baked_points()
	var verts: PackedVector3Array = PackedVector3Array()
	for i: int in baked.size():
		var a: Vector3 = baked[maxi(i - 1, 0)]
		var b: Vector3 = baked[mini(i + 1, baked.size() - 1)]
		var along: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
		if along.length_squared() < 0.0001:
			continue
		var side: Vector3 = Vector3(-along.z, 0.0, along.x).normalized() * stripe_width * 0.5
		var p: Vector3 = baked[i] + Vector3.UP * 0.08
		verts.append(p - side)
		verts.append(p + side)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = style_colors[clampi(style, 0, style_colors.size() - 1)] if not style_colors.is_empty() else Color.WHITE
	mesh.surface_set_material(0, mat)
	_stripe.mesh = mesh


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


## Point `ahead` metres further down the line from index `from`, and the
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
