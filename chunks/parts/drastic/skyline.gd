class_name Skyline
extends Node3D
## The macro layer (v0.31 "drastic landscape"): huge shapes beside the
## valley so speed and scale read against something: tilted alien monoliths
## with glowing veins, floating shards, rock spires, and one energy core per
## stage hanging on the horizon. All outside the play area (no collision),
## 160-900 m from the stage's line, so they slide past with parallax.
## The game calls populate() after building each stage (and the title one).
##
## Everything here is an Inspector export: counts, distances, sizes. The
## far, painted megastructures live in the sky shader (sky thread); this is
## the near geometry.

const SLAB_MAT: Material = preload("res://chunks/parts/drastic/alien_slab.tres")
const SHARD_MAT: Material = preload("res://chunks/parts/drastic/alien_shard.tres")
const CORE_MAT: Material = preload("res://chunks/parts/drastic/alien_core.tres")
const ROCK_COLOR: Color = Color(0.42, 0.33, 0.3)

@export_group("Spacing")
## A slot every this many metres along the stage, on each side.
@export_range(40.0, 1000.0, 10.0, "suffix:m") var spacing: float = 140.0
## Chance a slot gets something.
@export_range(0.0, 1.0, 0.05) var fill: float = 0.7
## Distance from the stage line (m): nearest and furthest.
@export_range(100.0, 2000.0, 10.0, "suffix:m") var near_distance: float = 170.0
@export_range(100.0, 3000.0, 10.0, "suffix:m") var far_distance: float = 850.0

@export_group("Mix")
## Relative odds of each kind in a slot.
@export var monolith_weight: float = 4.0
@export var spire_weight: float = 3.0
@export var shard_cluster_weight: float = 2.0
## Monolith size range (m): height, width.
@export var monolith_height: Vector2 = Vector2(50.0, 170.0)
@export var monolith_width: Vector2 = Vector2(18.0, 60.0)
## Spire height range (m).
@export var spire_height: Vector2 = Vector2(90.0, 280.0)

@export_group("Energy core")
## One per stage, this far out (m) and this big (radius).
@export var core_distance: float = 900.0
@export var core_radius: float = 70.0
## Height above the stage line where it hangs (m).
@export var core_height: float = 120.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spinners: Array[Node3D] = []


func _process(delta: float) -> void:
	for node: Node3D in _spinners:
		if is_instance_valid(node):
			node.rotate_y(delta * float(node.get_meta(&"spin", 0.1)))


## Clears the old stage's shapes and places new ones along `builder`'s line.
func populate(builder: StageBuilder, stage_seed: int) -> void:
	for child: Node in get_children():
		child.queue_free()
	_spinners.clear()
	if builder.line_points.size() < 2:
		return
	_rng.seed = hash(stage_seed * 7919 + 31)
	var d: float = spacing * 0.5
	while d < builder.length:
		for side: float in [-1.0, 1.0]:
			if _rng.randf() < fill:
				_place_one(builder, d + _rng.randf_range(-spacing * 0.3, spacing * 0.3), side)
		d += spacing
	# The energy core, two thirds down the stage on a random side.
	var core_d: float = builder.length * _rng.randf_range(0.45, 0.75)
	var frame: Transform3D = builder.transform_at_distance(core_d)
	var side2: float = -1.0 if _rng.randf() < 0.5 else 1.0
	var at: Vector3 = frame.origin + _flat_right(frame) * side2 * core_distance + Vector3.UP * core_height
	_core(at)


func _flat_right(frame: Transform3D) -> Vector3:
	var right: Vector3 = frame.basis.x
	right.y = 0.0
	return right.normalized() if right.length() > 0.01 else Vector3.RIGHT


func _place_one(builder: StageBuilder, d: float, side: float) -> void:
	d = clampf(d, 0.0, builder.length)
	var frame: Transform3D = builder.transform_at_distance(d)
	var dist: float = lerpf(near_distance, far_distance, pow(_rng.randf(), 1.4))
	var base: Vector3 = frame.origin + _flat_right(frame) * side * dist
	# The ground out there is lower than the valley (the far ground plane
	# sits under the stage); sink things well down so they read as rising
	# from below.
	base.y -= 30.0 + dist * 0.06
	var total: float = monolith_weight + spire_weight + shard_cluster_weight
	var pick: float = _rng.randf() * total
	if pick < monolith_weight:
		_monolith(base, side)
	elif pick < monolith_weight + spire_weight:
		_spire(base)
	else:
		_shards(base + Vector3.UP * _rng.randf_range(60.0, 160.0), _rng.randi_range(4, 9), 1.0)


func _monolith(at: Vector3, side: float) -> void:
	var h: float = _rng.randf_range(monolith_height.x, monolith_height.y)
	var w: float = _rng.randf_range(monolith_width.x, monolith_width.y)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(w, h, _rng.randf_range(5.0, 12.0))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = SLAB_MAT
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Leaning: mostly toward or away from the valley, some sideways twist.
	var lean: float = deg_to_rad(_rng.randf_range(12.0, 42.0)) * (-side if _rng.randf() < 0.7 else side)
	mi.global_basis = Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.FORWARD, lean)
	mi.global_position = at + Vector3.UP * h * 0.35


func _spire(at: Vector3) -> void:
	var h: float = _rng.randf_range(spire_height.x, spire_height.y)
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = h
	mesh.bottom_radius = h * _rng.randf_range(0.08, 0.14)
	mesh.top_radius = mesh.bottom_radius * _rng.randf_range(0.15, 0.45)
	mesh.radial_segments = 7
	mesh.rings = 1
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	var src: StandardMaterial3D = StandardMaterial3D.new()
	src.albedo_color = ROCK_COLOR.lerp(Color(0.25, 0.22, 0.35), _rng.randf() * 0.6)
	mi.material_override = CelLook.material_for(src, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = at + Vector3.UP * h * 0.5
	mi.rotate_y(_rng.randf() * TAU)
	mi.rotate_object_local(Vector3.RIGHT, deg_to_rad(_rng.randf_range(-8.0, 8.0)))
	# Some spires carry a floating crown of shards.
	if _rng.randf() < 0.35:
		_shards(at + Vector3.UP * (h + 25.0), _rng.randi_range(3, 6), 0.6)


## A loose ring of floating shards around `at` that turns slowly.
func _shards(at: Vector3, count: int, size: float) -> void:
	var ring: Node3D = Node3D.new()
	add_child(ring)
	ring.global_position = at
	ring.set_meta(&"spin", _rng.randf_range(0.03, 0.12) * (-1.0 if _rng.randf() < 0.5 else 1.0))
	_spinners.append(ring)
	var reach: float = _rng.randf_range(20.0, 55.0) * size
	for i: int in count:
		var mesh: PrismMesh = PrismMesh.new()
		var length: float = _rng.randf_range(10.0, 34.0) * size
		mesh.size = Vector3(length * 0.28, length, length * 0.16)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = SHARD_MAT
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.add_child(mi)
		var a: float = TAU * i / count + _rng.randf_range(-0.3, 0.3)
		mi.position = Vector3(cos(a) * reach, _rng.randf_range(-12.0, 12.0) * size, sin(a) * reach)
		mi.rotation = Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf() * TAU, _rng.randf_range(-1.2, 1.2))


func _core(at: Vector3) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = core_radius
	mesh.height = core_radius * 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = CORE_MAT
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "EnergyCore"
	add_child(mi)
	mi.global_position = at
	_shards(at, 14, 2.2)
	_shards(at + Vector3.UP * core_radius * 0.6, 8, 1.4)
