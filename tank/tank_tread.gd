@tool
class_name TankTread
extends MultiMeshInstance3D
## One track: pads running round an oval (MultiMesh), so the tread visibly
## moves. TankRig calls advance() with the distance this side travelled.
## Origin = under the middle of the track, on the ground; forward is -Z.

## Distance between the front and rear wheel centres (m).
@export_range(0.5, 8.0, 0.05, "suffix:m") var span: float = 2.8:
	set(v):
		span = v
		_rebuild()
## Wheel radius at the ends (m).
@export_range(0.1, 1.5, 0.01, "suffix:m") var radius: float = 0.44:
	set(v):
		radius = v
		_rebuild()
@export_range(4, 80) var pad_count: int = 30:
	set(v):
		pad_count = v
		_rebuild()
@export var pad_size: Vector3 = Vector3(0.62, 0.1, 0.2):
	set(v):
		pad_size = v
		_rebuild()
@export var color: Color = Color(0.13, 0.13, 0.15):
	set(v):
		color = v
		_rebuild()

var _offset: float = 0.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var box: BoxMesh = BoxMesh.new()
	box.size = pad_size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat
	if not Engine.is_editor_hint():
		material_override = CelLook.material_for(mat, true)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = pad_count
	multimesh = mm
	_place_pads()


## Moves the pads along by this many metres (+ = riding forward).
func advance(distance: float) -> void:
	_offset += distance
	_place_pads()


func _place_pads() -> void:
	if multimesh == null:
		return
	var perimeter: float = 2.0 * span + TAU * radius
	for i: int in pad_count:
		var s: float = fposmod(float(i) / float(pad_count) * perimeter + _offset, perimeter)
		multimesh.set_instance_transform(i, _pad_at(s))


## s along the track: the bottom run goes rear to front relative to the tank
## while riding forward... the ground run stays put in the world, so pads on
## it move backwards here, and the top run moves forwards.
func _pad_at(s: float) -> Transform3D:
	var half: float = span * 0.5
	var cy: float = radius + pad_size.y * 0.5
	var angle: float
	var at: Vector3
	var arc: float = PI * radius
	if s < span:
		# Top run, rear to front.
		at = Vector3(0.0, cy + radius, half - s)
		angle = 0.0
	elif s < span + arc:
		# Round the front wheel, top to bottom.
		angle = (s - span) / radius
		at = Vector3(0.0, cy + cos(angle) * radius, -half - sin(angle) * radius)
	elif s < 2.0 * span + arc:
		# Bottom run, front to rear.
		at = Vector3(0.0, cy - radius, -half + (s - span - arc))
		angle = PI
	else:
		# Round the rear wheel, bottom to top.
		angle = PI + (s - 2.0 * span - arc) / radius
		at = Vector3(0.0, cy + cos(angle) * radius, half - sin(angle) * radius)
	return Transform3D(Basis(Vector3.RIGHT, -angle), at)
