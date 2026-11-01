@tool
class_name GrassTuftMesh
extends ArrayMesh
## A low-poly clump of grass blades (one triangle each) for GroundCover
## layers. UV.y runs 0 at the root to 1 at the tip (the grass shader sways
## and shades by it). Change the numbers and the mesh rebuilds.

@export_range(1, 40) var blades: int = 9:
	set(v):
		blades = v
		_build()
@export_range(0.05, 3.0, 0.01) var height: float = 0.55:
	set(v):
		height = v
		_build()
@export_range(0.005, 0.5, 0.005) var blade_width: float = 0.09:
	set(v):
		blade_width = v
		_build()
## Radius the roots spread over.
@export_range(0.0, 2.0, 0.01) var spread: float = 0.3:
	set(v):
		spread = v
		_build()
## How far the tips lean out (fraction of the height).
@export_range(0.0, 1.0, 0.01) var lean: float = 0.35:
	set(v):
		lean = v
		_build()
@export var seed: int = 3:
	set(v):
		seed = v
		_build()


func _init() -> void:
	_build.call_deferred()


func _build() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var normals: PackedVector3Array = PackedVector3Array()
	for i: int in blades:
		var a: float = TAU * (i + rng.randf() * 0.6) / blades
		var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var root: Vector3 = out * spread * sqrt(rng.randf())
		var side: Vector3 = Vector3(-out.z, 0.0, out.x) * blade_width * 0.5
		var h: float = height * rng.randf_range(0.6, 1.15)
		var tip: Vector3 = root + out * h * lean * rng.randf_range(0.5, 1.2) + Vector3.UP * h
		verts.append_array([root - side, tip, root + side])
		uvs.append_array([Vector2(0.0, 0.0), Vector2(0.5, 1.0), Vector2(1.0, 0.0)])
		normals.append_array([Vector3.UP, Vector3.UP, Vector3.UP])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	clear_surfaces()
	add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
