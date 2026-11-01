@tool
class_name GroundCoverLayer
extends Resource
## One kind of thing scattered by a GroundCover (grass tufts, bushes...).
## Purely visual: no collision, so keep anything that looks solid out of the
## play area (`zone`), or riders will dodge bushes they could ride through.

enum Zone { ANYWHERE, PLAY, EDGE, OUTSIDE }

## Mesh to scatter (e.g. a GrassTuftMesh). If empty, `model` is used.
@export var mesh: Mesh
## Model scene (.gltf); its first mesh is used with the cel look.
@export var model: PackedScene
## Material override (else the mesh's own, or cel for `model`).
@export var material: Material
## Instances per 100 m² where the ground fits fully.
@export_range(0.0, 200.0, 0.1) var density: float = 10.0
## 1 = only on grass, 0 = only on dirt, 0.5 = anywhere.
@export_range(0.0, 1.0, 0.01) var on_grass: float = 1.0
## PLAY = valley floor, EDGE = the banks up to just past the crests,
## OUTSIDE = past the crests.
@export var zone: Zone = Zone.ANYWHERE
@export_range(0.05, 5.0, 0.01) var scale_min: float = 0.8
@export_range(0.05, 5.0, 0.01) var scale_max: float = 1.3
## Push into the ground (m) so slopes don't show a gap.
@export_range(0.0, 1.0, 0.01) var sink: float = 0.05
## 0 = stand upright, 1 = follow the ground.
@export_range(0.0, 1.0, 0.01) var follow_ground: float = 0.6
## Hidden past this distance from the camera (m).
@export_range(10.0, 2000.0, 1.0) var visibility_end: float = 120.0
@export var cast_shadows: bool = false
@export var outline: bool = false

var _mesh: Mesh
var _material: Material


func get_mesh() -> Mesh:
	if mesh != null:
		return mesh
	if _mesh == null and model != null:
		var root: Node = model.instantiate()
		var mi: MeshInstance3D = _first_mesh(root)
		if mi != null:
			_mesh = mi.mesh
		root.free()
	return _mesh


func get_material() -> Material:
	if material != null:
		return material
	if mesh != null:
		return null
	var m: Mesh = get_mesh()
	if _material == null and m != null:
		_material = CelLook.material_for(m.surface_get_material(0), outline)
	return _material


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var found: MeshInstance3D = _first_mesh(child)
		if found != null:
			return found
	return null
