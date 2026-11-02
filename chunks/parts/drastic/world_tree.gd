@tool
class_name WorldTree
extends Node3D
## The World Tree (v0.31 "drastic landscape"): a giant tree growing out of
## a chasm. Its glowing branches are sap rails (Rail.boost_accel): hop onto
## one at the rim and it carries you up around the trunk and fires you off
## its tip (end_launch) over the far side. Two spiral branches (left and
## right), plus a low root bridge straight across. Fall off and the chasm's
## Abyss respawns you before the rim.
##
## Built from the settings below when the scene loads (also live in the
## editor). This node's origin is the trunk's axis at rim height; -Z points
## down the valley (the way you ride).

const SAP_RAIL: PackedScene = preload("res://rails/sap_rail.tscn")

@export_tool_button("Rebuild") var rebuild_button: Callable = rebuild

@export_group("Trunk")
## Trunk height above the rim (m) and how far it reaches down into the chasm.
@export_range(20.0, 400.0, 1.0, "suffix:m") var height: float = 150.0:
	set(v):
		height = v
		_queue()
@export_range(0.0, 200.0, 1.0, "suffix:m") var depth: float = 90.0:
	set(v):
		depth = v
		_queue()
@export_range(1.0, 40.0, 0.5, "suffix:m") var trunk_radius: float = 8.0:
	set(v):
		trunk_radius = v
		_queue()
@export var bark_color: Color = Color(0.3, 0.17, 0.26):
	set(v):
		bark_color = v
		_queue()
@export var leaf_color: Color = Color(0.95, 0.42, 0.72):
	set(v):
		leaf_color = v
		_queue()
## Canopy blobs and how wide the crown spreads (m).
@export_range(0, 40) var canopy_blobs: int = 16:
	set(v):
		canopy_blobs = v
		_queue()
@export_range(10.0, 200.0, 1.0, "suffix:m") var canopy_spread: float = 55.0:
	set(v):
		canopy_spread = v
		_queue()

@export_group("Spiral branches")
## Where the two spiral branches start, before the trunk (m, +Z = uphill)
## and out to the side (m).
@export var branch_start: Vector2 = Vector2(22.0, 70.0):
	set(v):
		branch_start = v
		_queue()
## Spiral radius around the trunk axis (m).
@export_range(4.0, 60.0, 0.5, "suffix:m") var spiral_radius: float = 15.0:
	set(v):
		spiral_radius = v
		_queue()
## Height of the ground where the branches start, relative to this node
## (m). The author script sets it from the terrain (the rim is usually
## higher than the trunk's base when the chasm sits on a steep stretch).
@export var start_height: float = 0.0:
	set(v):
		start_height = v
		_queue()
## How high the spirals climb above their start (m) before the launch.
@export_range(0.0, 200.0, 1.0, "suffix:m") var climb: float = 55.0:
	set(v):
		climb = v
		_queue()
## Turns around the trunk.
## 1.25 ends each spiral on the far side, already pointing down the valley.
@export_range(0.25, 3.0, 0.05) var turns: float = 1.25:
	set(v):
		turns = v
		_queue()
## Length of the launch tip after the spiral (m) and its upward angle (deg).
@export_range(0.0, 80.0, 1.0, "suffix:m") var launch_length: float = 24.0:
	set(v):
		launch_length = v
		_queue()
@export_range(-30.0, 60.0, 1.0, "suffix:deg") var launch_angle: float = 12.0:
	set(v):
		launch_angle = v
		_queue()

@export_group("Root bridge")
## A low root straight across the chasm (m before / after the trunk), and
## how high its arch rises (m). 0 length = none.
@export var bridge_x: float = 0.0:
	set(v):
		bridge_x = v
		_queue()
@export_range(0.0, 200.0, 1.0, "suffix:m") var bridge_half_length: float = 75.0:
	set(v):
		bridge_half_length = v
		_queue()
@export_range(0.0, 40.0, 0.5, "suffix:m") var bridge_arch: float = 8.0:
	set(v):
		bridge_arch = v
		_queue()
## Ground height at the bridge's uphill / downhill ends, relative to this
## node (m); set by the author script from the terrain.
@export var bridge_in_height: float = 0.0:
	set(v):
		bridge_in_height = v
		_queue()
@export var bridge_out_height: float = 0.0:
	set(v):
		bridge_out_height = v
		_queue()

var _built: Node3D
var _queued: bool = false


func _ready() -> void:
	rebuild()


func _queue() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	rebuild.call_deferred()


func rebuild() -> void:
	_queued = false
	if not is_inside_tree():
		return
	if _built != null:
		_built.free()
	_built = Node3D.new()
	_built.name = "Built"
	add_child(_built, false, Node.INTERNAL_MODE_BACK)
	_build_trunk()
	_build_canopy()
	for side: float in [-1.0, 1.0]:
		_build_spiral(side)
	if bridge_half_length > 0.0:
		_build_bridge()


func _cel(color: Color, outline: bool = true) -> Material:
	var src: StandardMaterial3D = StandardMaterial3D.new()
	src.albedo_color = color
	return CelLook.material_for(src, outline)


func _build_trunk() -> void:
	var total: float = height + depth
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = total
	mesh.top_radius = trunk_radius * 0.55
	mesh.bottom_radius = trunk_radius * 1.6
	mesh.radial_segments = 14
	mesh.rings = 3
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _cel(bark_color)
	mi.position = Vector3(0.0, total * 0.5 - depth, 0.0)
	_built.add_child(mi)
	# Solid: riding into the trunk is a crash.
	var body: StaticBody3D = StaticBody3D.new()
	body.add_to_group(&"obstacles")
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.height = total
	cyl.radius = trunk_radius
	shape.shape = cyl
	body.add_child(shape)
	body.position = mi.position
	_built.add_child(body)
	# Flaring roots at the bottom, visual.
	for i: int in 6:
		var root_mesh: CylinderMesh = CylinderMesh.new()
		root_mesh.height = depth * 0.9
		root_mesh.top_radius = trunk_radius * 0.5
		root_mesh.bottom_radius = trunk_radius * 0.15
		root_mesh.radial_segments = 6
		var r: MeshInstance3D = MeshInstance3D.new()
		r.mesh = root_mesh
		r.material_override = mi.material_override
		var a: float = TAU * i / 6.0 + 0.3
		r.position = Vector3(cos(a) * trunk_radius * 1.6, -depth * 0.55, sin(a) * trunk_radius * 1.6)
		r.rotation = Vector3(sin(a) * 0.5, 0.0, -cos(a) * 0.5)
		_built.add_child(r)


func _build_canopy() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var leaves: Material = _cel(leaf_color)
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = leaf_color.lightened(0.3)
	glow.emission_enabled = true
	glow.emission = leaf_color.lightened(0.2)
	glow.emission_energy_multiplier = 1.5
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i: int in canopy_blobs:
		var r: float = rng.randf_range(0.18, 0.4) * canopy_spread
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = r
		mesh.height = r * rng.randf_range(1.2, 1.7)
		mesh.radial_segments = 16
		mesh.rings = 8
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = leaves
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a: float = rng.randf() * TAU
		var out: float = sqrt(rng.randf()) * canopy_spread * 0.75
		mi.position = Vector3(cos(a) * out, height - rng.randf_range(0.0, 0.3) * canopy_spread * 0.6 + 6.0, sin(a) * out)
		_built.add_child(mi)
	# Glowing seed pods hanging under the crown (they read from far away).
	for i: int in 22:
		var pod: SphereMesh = SphereMesh.new()
		pod.radius = rng.randf_range(0.8, 2.0)
		pod.height = pod.radius * 2.6
		var mi2: MeshInstance3D = MeshInstance3D.new()
		mi2.mesh = pod
		mi2.material_override = glow
		var a2: float = rng.randf() * TAU
		var out2: float = rng.randf_range(0.3, 0.9) * canopy_spread
		mi2.position = Vector3(cos(a2) * out2, height - canopy_spread * 0.25 - rng.randf_range(0.0, 10.0), sin(a2) * out2)
		_built.add_child(mi2)


## One spiral branch. side -1 = starts on the left and winds clockwise seen
## from above, +1 = mirror. It comes in from the rim, winds `turns` times
## around the trunk climbing to `climb`, and ends in a launch tip that points
## down the valley.
func _build_spiral(side: float) -> void:
	var rail: Rail = SAP_RAIL.instantiate() as Rail
	rail.name = "SpiralBranch%s" % ("Left" if side < 0.0 else "Right")
	var curve: Curve3D = Curve3D.new()
	var start: Vector3 = Vector3(side * branch_start.x, start_height + 0.75, branch_start.y)
	# The left spiral runs a little wider so the two never touch.
	var radius: float = spiral_radius + (5.0 if side < 0.0 else 0.0)
	# The spiral starts at the side of the trunk facing the rider's way in.
	var a0: float = atan2(start.z, start.x)
	var entry: Vector3 = Vector3(cos(a0), 0.0, sin(a0)) * radius + Vector3.UP * (start.y + 3.0)
	var steps_in: int = maxi(2, int(start.distance_to(entry) / 4.0))
	for i: int in steps_in:
		var f: float = float(i) / steps_in
		var p: Vector3 = start.lerp(entry, f)
		p.y = lerpf(start.y, entry.y, f * f)
		curve.add_point(p)
	# Winding direction: so that you sweep round and end facing -Z.
	var dir_sign: float = side
	var sweep: float = TAU * turns
	var steps: int = maxi(24, int(sweep * radius / 3.0))
	var a_end: float = a0
	for i: int in steps + 1:
		var f2: float = float(i) / steps
		var a: float = a0 + dir_sign * sweep * f2
		var y: float = lerpf(entry.y, start.y + climb, f2 * (2.0 - f2) * 0.5 + f2 * 0.5)
		curve.add_point(Vector3(cos(a) * radius, y, sin(a) * radius))
		a_end = a
	# Launch tip: carry on along the spiral's tangent, turning toward -Z.
	var last: Vector3 = curve.get_point_position(curve.point_count - 1)
	var tangent: Vector3 = Vector3(-sin(a_end), 0.0, cos(a_end)) * dir_sign
	var steps_out: int = maxi(2, int(launch_length / 3.0))
	for i: int in range(1, steps_out + 1):
		var f3: float = float(i) / steps_out
		var flat: Vector3 = tangent.lerp(Vector3.FORWARD, f3).normalized()
		var dir: Vector3 = (flat * cos(deg_to_rad(launch_angle)) + Vector3.UP * sin(deg_to_rad(launch_angle))).normalized()
		last += dir * (launch_length / steps_out)
		curve.add_point(last)
	rail.curve = curve
	_built.add_child(rail)


## A root straight across the chasm, arching up a little: the low way over.
func _build_bridge() -> void:
	var rail: Rail = SAP_RAIL.instantiate() as Rail
	rail.name = "RootBridge"
	rail.boost_accel = 4.0
	rail.boost_min_speed = 26.0
	rail.end_launch = 0.0
	var curve: Curve3D = Curve3D.new()
	var steps: int = maxi(8, int(bridge_half_length * 2.0 / 4.0))
	for i: int in steps + 1:
		var f: float = float(i) / steps
		var z: float = lerpf(bridge_half_length, -bridge_half_length, f)
		var y: float = 0.75 + lerpf(bridge_in_height, bridge_out_height, f) + bridge_arch * sin(PI * f)
		# Bend round the trunk.
		var x: float = bridge_x
		if absf(bridge_x) < trunk_radius + 6.0:
			x = bridge_x + (trunk_radius + 6.0) * sin(PI * f) * (1.0 if bridge_x >= 0.0 else -1.0)
		curve.add_point(Vector3(x, y, z))
	rail.curve = curve
	_built.add_child(rail)
