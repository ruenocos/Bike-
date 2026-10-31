@tool
class_name TerrainShape
extends Path3D
## Shapes the TerrainPatch it sits under, along its curve. Draw the curve in
## the editor (top view is easiest); the terrain rebuilds as you drag points.
##   GULLY  digs a channel `depth` deep: a fast, narrow line.
##   RIDGE  raises a crest `depth` high: a ridge to ride along or a wall to split lines.
##   LINE   pulls the ground to the curve's own height: a smooth carved path
##          (lift or lower the points to make drops, rollers, berms).
## Only the curve's position from above sets where it acts; for LINE the
## points' heights matter too.
##
## Godot note: Path3D's curve is a Curve3D resource; its points live in this
## node's space, so moving the node moves the whole shape.

enum Mode { GULLY, RIDGE, LINE }

@export var mode: Mode = Mode.GULLY:
	set(v):
		mode = v
		_changed()
## Full width of the shape, edge to edge.
@export_range(1.0, 120.0, 0.5, "suffix:m") var width: float = 16.0:
	set(v):
		width = v
		_changed()
## How deep a GULLY digs / how high a RIDGE rises (ignored by LINE).
@export_range(0.0, 40.0, 0.1, "suffix:m") var depth: float = 4.0:
	set(v):
		depth = v
		_changed()
## Part of the width (from the middle out) at full effect before it eases
## out. 0 = round V/U, 0.8 = flat bottom with short sides.
@export_range(0.0, 0.95, 0.05) var flat: float = 0.3:
	set(v):
		flat = v
		_changed()


func _ready() -> void:
	set_notify_local_transform(true)
	curve_changed.connect(_changed)
	visibility_changed.connect(_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		_changed()
	elif what == NOTIFICATION_EXIT_TREE:
		_changed()


## Effect at distance ratio r (0 = on the curve, 1 = the shape's edge).
func profile(r: float) -> float:
	if r <= flat:
		return 1.0
	if r >= 1.0:
		return 0.0
	return 0.5 + 0.5 * cos(PI * (r - flat) / (1.0 - flat))


func _changed() -> void:
	var patch: TerrainPatch = TerrainShape.find_patch(self)
	if patch != null:
		patch.queue_rebuild()


## The TerrainPatch above a shaping node, or null.
static func find_patch(node: Node) -> TerrainPatch:
	var n: Node = node.get_parent()
	while n != null:
		if n is TerrainPatch:
			return n as TerrainPatch
		n = n.get_parent()
	return null
