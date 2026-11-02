@tool
class_name BossArena
extends Node3D
## The boss arena: a round bowl floating in the sky, no walls (v0.33).
## Flat floor in the middle where the boss stands, a bowl that rises to the
## rim (ride down it for ramming speed, carve back up), a flat deck around
## the rim, then the open edge: ride off it and you fall (respawn on the
## deck, with a time cost). The yellow/black band marks the last metres.
##
## The mesh and collision are built from the exports below, in the editor
## too (change a number and it rebuilds). Materials are on the nodes in
## boss_arena.tscn. Spawn sits on the deck facing the middle.

## Flat floor radius (m): the boss's ground.
@export_range(5.0, 200.0, 1.0, "suffix:m") var floor_radius: float = 40.0:
	set(v):
		floor_radius = v
		_queue_rebuild()
## Where the bowl meets the deck (m).
@export_range(20.0, 400.0, 1.0, "suffix:m") var bowl_radius: float = 110.0:
	set(v):
		bowl_radius = v
		_queue_rebuild()
## Height of the rim above the floor (m). Rolling down from it gives about
## sqrt(2 g h): 22 m = 21 m/s before pedalling.
@export_range(0.0, 100.0, 0.5, "suffix:m") var rim_height: float = 22.0:
	set(v):
		rim_height = v
		_queue_rebuild()
## Flat deck outside the rim, to turn round on before the edge (m).
@export_range(0.0, 60.0, 0.5, "suffix:m") var deck_width: float = 16.0:
	set(v):
		deck_width = v
		_queue_rebuild()
## The hazard band along the edge (m).
@export_range(0.0, 10.0, 0.1, "suffix:m") var stripe_width: float = 2.5:
	set(v):
		stripe_width = v
		_queue_rebuild()
## How far the rock under the island hangs down (m).
@export_range(5.0, 300.0, 1.0, "suffix:m") var underside_depth: float = 80.0:
	set(v):
		underside_depth = v
		_queue_rebuild()
## Mesh resolution around the circle.
@export_range(16, 512, 1) var segments: int = 160:
	set(v):
		segments = v
		_queue_rebuild()
## Floor texture tile size (m).
@export_range(1.0, 64.0, 0.5, "suffix:m") var tile_size: float = 12.0:
	set(v):
		tile_size = v
		_queue_rebuild()
## Falling this far under the floor respawns you.
@export_range(5.0, 200.0, 1.0, "suffix:m") var fall_margin: float = 35.0

@onready var floor_mesh: MeshInstance3D = $Floor
@onready var stripe_mesh: MeshInstance3D = $Stripe
@onready var rock_mesh: MeshInstance3D = $Rock
@onready var shape: CollisionShape3D = $Body/Shape
@onready var spawn: Marker3D = $Spawn

var _rebuild_queued: bool = false


func _ready() -> void:
	rebuild()


func _queue_rebuild() -> void:
	if not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	(func() -> void:
		_rebuild_queued = false
		rebuild()).call_deferred()


## Outer edge of the deck (m from the middle).
func edge_radius() -> float:
	return bowl_radius + deck_width


## Floor height at `r` m from the middle (local).
func height_at(r: float) -> float:
	if r <= floor_radius:
		return 0.0
	if r >= bowl_radius:
		return rim_height
	var t: float = (r - floor_radius) / maxf(bowl_radius - floor_radius, 0.001)
	return rim_height * t * t


## The floor point under a global position (on the arena's surface).
func surface_point(at: Vector3) -> Vector3:
	var local: Vector3 = to_local(at)
	var r: float = Vector2(local.x, local.z).length()
	return to_global(Vector3(local.x, height_at(r), local.z))


## Floor normal under a global position.
func normal_at(at: Vector3) -> Vector3:
	var local: Vector3 = to_local(at)
	var flat: Vector2 = Vector2(local.x, local.z)
	var r: float = flat.length()
	if r <= floor_radius or r >= bowl_radius or r < 0.001:
		return global_basis.y.normalized()
	var slope: float = 2.0 * rim_height * (r - floor_radius) / pow(bowl_radius - floor_radius, 2.0)
	var dir: Vector2 = flat / r
	return (global_basis * Vector3(-dir.x * slope, 1.0, -dir.y * slope)).normalized()


## Height under the floor that counts as fallen off (global y).
func kill_y() -> float:
	return global_position.y - fall_margin


## True when `at` is past the edge (horizontally).
func is_off_edge(at: Vector3) -> bool:
	var local: Vector3 = to_local(at)
	return Vector2(local.x, local.z).length() > edge_radius()


func rebuild() -> void:
	if not is_node_ready():
		return
	var outer: float = edge_radius()
	var stripe_in: float = maxf(outer - stripe_width, bowl_radius)
	# Radii of the rings, finer across the bowl where it curves.
	var main: PackedFloat32Array = PackedFloat32Array([0.0])
	var r: float = 4.0
	while r < floor_radius:
		main.append(r)
		r += 4.0
	main.append(floor_radius)
	var steps: int = maxi(int((bowl_radius - floor_radius) / 2.5), 2)
	for i: int in range(1, steps + 1):
		main.append(lerpf(floor_radius, bowl_radius, float(i) / steps))
	if stripe_in > bowl_radius + 0.01:
		main.append(stripe_in)
	floor_mesh.mesh = _ring_mesh(main, true)
	stripe_mesh.mesh = _ring_mesh(PackedFloat32Array([stripe_in, outer]), false) if outer - stripe_in > 0.01 else null
	rock_mesh.mesh = _rock_mesh(outer)
	# Collision: the top (floor + stripe) as one trimesh; the rock is only looks.
	var faces: PackedVector3Array = floor_mesh.mesh.get_faces()
	if stripe_mesh.mesh != null:
		faces.append_array(stripe_mesh.mesh.get_faces())
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	concave.set_faces(faces)
	shape.shape = concave
	# Spawn on the deck, facing the middle (-Z of the marker points inward).
	var deck_r: float = bowl_radius + minf(deck_width * 0.5, 8.0)
	spawn.position = Vector3(0.0, rim_height + 0.1, deck_r)
	spawn.basis = Basis.IDENTITY


## Top surface between the given radii. `tiled` maps the floor texture in
## world metres; the stripe maps U around the circle.
func _ring_mesh(radii: PackedFloat32Array, tiled: bool) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg: int = segments
	var start_ring: int = 0
	var has_center: bool = radii[0] <= 0.0001
	var index: int = 0
	if has_center:
		st.set_uv(Vector2.ZERO)
		st.add_vertex(Vector3(0.0, height_at(0.0), 0.0))
		index = 1
		start_ring = 1
	var circumference: float = TAU * radii[radii.size() - 1]
	var stripe_repeats: float = maxf(roundf(circumference / 8.0), 1.0)
	for ring: int in range(start_ring, radii.size()):
		var rr: float = radii[ring]
		for s: int in seg + 1:
			var a: float = TAU * float(s) / seg
			var p: Vector3 = Vector3(sin(a) * rr, height_at(rr), cos(a) * rr)
			if tiled:
				st.set_uv(Vector2(p.x, p.z) / tile_size)
			else:
				st.set_uv(Vector2(float(s) / seg * stripe_repeats, float(ring - start_ring)))
			st.add_vertex(p)
	# Centre fan.
	if has_center:
		for s: int in seg:
			st.add_index(0)
			st.add_index(1 + s + 1)
			st.add_index(1 + s)
	var rings: int = radii.size() - start_ring
	for ring: int in rings - 1:
		var a0: int = index + ring * (seg + 1)
		var b0: int = a0 + seg + 1
		for s: int in seg:
			st.add_index(a0 + s)
			st.add_index(b0 + s + 1)
			st.add_index(b0 + s)
			st.add_index(a0 + s)
			st.add_index(a0 + s + 1)
			st.add_index(b0 + s + 1)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## The rock hanging under the island: from the edge down to a blunt point,
## with a little wobble so it reads as rock, not a cone.
func _rock_mesh(outer: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg: int = maxi(segments / 2, 12)
	var levels: int = 8
	for l: int in levels + 1:
		var t: float = float(l) / levels
		var y: float = rim_height - underside_depth * t
		var base_r: float = outer * (1.0 - pow(t, 1.6)) + 2.0 * t
		for s: int in seg + 1:
			var a: float = TAU * float(s) / seg
			var wobble: float = 1.0 + 0.06 * sin(a * 5.0 + t * 7.0) * (0.3 + t) if l > 0 else 1.0
			var rr: float = base_r * wobble
			st.set_uv(Vector2(float(s) / seg * 8.0, t * 4.0))
			st.add_vertex(Vector3(sin(a) * rr, y, cos(a) * rr))
	for l: int in levels:
		var a0: int = l * (seg + 1)
		var b0: int = a0 + seg + 1
		for s: int in seg:
			st.add_index(a0 + s)
			st.add_index(a0 + s + 1)
			st.add_index(b0 + s)
			st.add_index(a0 + s + 1)
			st.add_index(b0 + s + 1)
			st.add_index(b0 + s)
	st.generate_normals()
	return st.commit()
