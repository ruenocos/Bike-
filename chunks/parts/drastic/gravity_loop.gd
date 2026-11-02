@tool
class_name GravityLoop
extends StaticBody3D
## A gravity ring (v0.31 "drastic landscape"): an alien loop-the-loop you
## ride straight through. Inside it gravity points into the surface (group
## "gravity_surfaces", see Player.on_gravity_surface), so you keep your
## speed all the way round and the camera rolls with you. It's optional:
## the valley stays open beside it, and it's wide enough to take on any
## line across its width.
##
## The loop is built from the settings below (mesh + collision), in this
## node's space: you ride in along -Z at the origin, go round once and come
## out `side_shift` metres to the right, still heading -Z. Put it on a flat
## pad tilted with the slope (the author script does). Press "Rebuild" after
## changing values in the editor (it also rebuilds by itself).

@export_tool_button("Rebuild") var rebuild_button: Callable = rebuild

## Loop radius (m): bigger = gentler, and readable from further away.
@export_range(4.0, 60.0, 0.5, "suffix:m") var radius: float = 14.0:
	set(v):
		radius = v
		_queue()
## Ribbon width (m).
@export_range(2.0, 40.0, 0.5, "suffix:m") var width: float = 12.0:
	set(v):
		width = v
		_queue()
## Sideways offset of the exit (m), so the way out clears the way in.
@export_range(0.0, 80.0, 0.5, "suffix:m") var side_shift: float = 15.0:
	set(v):
		side_shift = v
		_queue()
## Flat run-in before and run-out after the loop (m).
@export_range(0.0, 80.0, 0.5, "suffix:m") var lead_length: float = 18.0:
	set(v):
		lead_length = v
		_queue()
## Shell thickness (m), just for looks.
@export_range(0.1, 4.0, 0.05, "suffix:m") var thickness: float = 0.8:
	set(v):
		thickness = v
		_queue()
## Segments around the loop.
@export_range(16, 400) var segments: int = 120:
	set(v):
		segments = v
		_queue()
## Push along the loop while you ride it (m/s²); there's no drag in it.
@export_range(0.0, 40.0, 0.5, "suffix:m/s²") var boost_accel: float = 6.0
@export var material: Material = preload("res://chunks/parts/drastic/alien_ring.tres"):
	set(v):
		material = v
		_queue()

var _mesh_instance: MeshInstance3D
var _shape: CollisionShape3D
var _queued: bool = false


func _ready() -> void:
	add_to_group(&"gravity_surfaces")
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "LoopMesh"
	add_child(_mesh_instance, false, Node.INTERNAL_MODE_BACK)
	_shape = CollisionShape3D.new()
	_shape.name = "LoopShape"
	add_child(_shape, false, Node.INTERNAL_MODE_BACK)
	rebuild()


func _queue() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	rebuild.call_deferred()


## Centre line point, ride direction and surface normal at loop parameter
## u (metres along the whole piece: run-in, loop, run-out).
func frame_at(u: float) -> Dictionary:
	var loop_len: float = TAU * radius
	if u < lead_length:
		# Run-in: z from +lead to 0 at x 0.
		return {"p": Vector3(0.0, 0.0, lead_length - u), "t": Vector3.FORWARD, "n": Vector3.UP}
	u -= lead_length
	if u > loop_len:
		var out: float = u - loop_len
		return {"p": Vector3(side_shift, 0.0, -out), "t": Vector3.FORWARD, "n": Vector3.UP}
	var a: float = u / radius
	var f: float = a / TAU
	var s: float = f * f * (3.0 - 2.0 * f)
	var p: Vector3 = Vector3(side_shift * s, radius - radius * cos(a), -radius * sin(a))
	var n: Vector3 = Vector3(0.0, cos(a), sin(a))
	var tangent: Vector3 = Vector3(0.0, sin(a), -cos(a))
	return {"p": p, "t": tangent, "n": n}


## Which way the loop carries you at a world point (unit, world space): the
## centre line's direction there, including the sideways drift toward the
## exit. The Player steers along it while on the loop, so whatever lane you
## enter in, you come out in the same lane on the other side.
func guide_dir(world_pos: Vector3) -> Vector3:
	var p: Vector3 = to_local(world_pos)
	var a: float = atan2(-p.z, radius - p.y)
	if a < 0.0:
		a += TAU
	# Near the bottom a ~ 0 (way in) or ~ TAU (way out): the side says which.
	if p.y < radius * 0.5 and a > PI and p.x < side_shift * 0.5:
		a = 0.0
	elif p.y < radius * 0.5 and a < PI and p.x > side_shift * 0.5:
		a = TAU
	var f: float = a / TAU
	var drift: float = side_shift * 6.0 * f * (1.0 - f) / (TAU * radius)
	var t: Vector3 = Vector3(drift, sin(a), -cos(a))
	if p.y < 0.5 and (p.z > 0.0 and p.x < side_shift * 0.5 or p.z < 0.0 and p.x > side_shift * 0.5):
		t = Vector3.FORWARD
	return (global_basis * t).normalized()


## Total length of the ride line through it (m).
func total_length() -> float:
	return lead_length * 2.0 + TAU * radius


func rebuild() -> void:
	_queued = false
	if _mesh_instance == null:
		return
	# Sample u so the loop part gets `segments` steps.
	var us: PackedFloat32Array = PackedFloat32Array()
	var lead_steps: int = maxi(2, int(lead_length / 3.0))
	for i: int in lead_steps:
		us.append(lead_length * i / lead_steps)
	for i: int in segments + 1:
		us.append(lead_length + TAU * radius * i / segments)
	for i: int in range(1, lead_steps + 1):
		us.append(lead_length + TAU * radius + lead_length * i / lead_steps)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: PackedVector3Array = PackedVector3Array()
	var half: float = width * 0.5
	var prev: Array = []
	for i: int in us.size():
		var f: Dictionary = frame_at(us[i])
		var p: Vector3 = f["p"]
		var n: Vector3 = f["n"]
		var across: Vector3 = Vector3.RIGHT
		# Ring of 4 corners: inner left / right (the riding surface), outer right / left.
		var ring: Array = [p - across * half, p + across * half, p + across * half - n * thickness, p - across * half - n * thickness, n]
		if not prev.is_empty():
			_quad(st, prev[0], prev[1], ring[1], ring[0], prev[4], ring[4], faces, true)
			_quad(st, prev[2], prev[3], ring[3], ring[2], -prev[4], -ring[4], faces, false)
			_quad(st, prev[1], prev[2], ring[2], ring[1], Vector3.RIGHT, Vector3.RIGHT, faces, false)
			_quad(st, prev[3], prev[0], ring[0], ring[3], Vector3.LEFT, Vector3.LEFT, faces, false)
		prev = ring
	var mesh: ArrayMesh = st.commit()
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = material
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	_shape.shape = shape


## Two triangles a-b-c, a-c-d with normals na (a, b) / nb (c, d). The riding
## surface also goes into the collision faces.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3,
		faces: PackedVector3Array, collide: bool) -> void:
	# Wind so the face points along the normal (Godot: clockwise = front).
	var flip: bool = (b - a).cross(c - a).dot(na) > 0.0
	var tris: Array = [[a, na], [b, na], [c, nb], [a, na], [c, nb], [d, nb]]
	if flip:
		tris = [[a, na], [c, nb], [b, na], [a, na], [d, nb], [c, nb]]
	for v: Array in tris:
		st.set_normal(v[1])
		st.add_vertex(v[0])
		if collide:
			faces.append(v[0])
