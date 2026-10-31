extends SceneTree
## One-off authoring helper: writes the chunk scenes in chunks/ from the specs
## below (TrackLine from keys, Ribbon, markers, instanced parts, pillars).
## After that the .tscn files are the source of truth: open them in the editor
## and move things around. Running this again OVERWRITES those edits.
##   <exe> --headless --path . -s res://chunks/tools/author_chunks.gd

const KICKER: PackedScene = preload("res://chunks/parts/kicker.tscn")
const RAIL: PackedScene = preload("res://rails/rail.tscn")
const HALFPIPE: PackedScene = preload("res://chunks/parts/halfpipe.tscn")
const FINISH: PackedScene = preload("res://chunks/parts/finish_gate.tscn")
const GROUND: Material = preload("res://chunks/materials/ground.tres")

## name, file, length, pitch keys, heading keys, bumps, kickers (u, x, scale),
## rails (u0, u1, x, height), halfpipe u (centre, -1 none), finish u, spawn u.
const SPECS: Array[Dictionary] = [
	{"name": "ChunkTemplate", "file": "chunk_template.tscn", "length": 100.0},
	{"name": "ChunkStart", "file": "chunk_start.tscn", "length": 150.0,
		"pitch": [Vector2(0, 0), Vector2(40, 0), Vector2(60, 35), Vector2(80, 35), Vector2(105, 23), Vector2(150, 23)],
		"spawn": 12.0},
	{"name": "ChunkRollers", "file": "chunk_rollers.tscn", "length": 220.0,
		"bumps": [Vector3(30, 24, 1.5), Vector3(54, 24, 1.5), Vector3(78, 24, 1.5), Vector3(102, 24, 1.5), Vector3(126, 24, 1.5)]},
	# Each kicker (10 deg lip) is followed by a landing that steepens to 32 deg:
	# ~1.3 s of air at 50 m/s, landing ~9 deg (natural perfect) from 45-58 m/s.
	{"name": "ChunkKickers", "file": "chunk_kickers.tscn", "length": 500.0,
		"pitch": [Vector2(0, 23), Vector2(70, 23), Vector2(105, 32), Vector2(165, 32), Vector2(225, 23),
			Vector2(300, 23), Vector2(335, 32), Vector2(395, 32), Vector2(455, 23), Vector2(500, 23)],
		"kickers": [Vector3(60, 0, 1.0), Vector3(290, 0, 1.2)]},
	# Big air: the slope drops away to 44 deg after the lip: ~1.8 s of air at
	# 50 m/s, ~2 s at 55 m/s (time for a two-trick chain), still landing <12 deg.
	{"name": "ChunkBigAir", "file": "chunk_big_air.tscn", "length": 430.0,
		"pitch": [Vector2(0, 23), Vector2(75, 23), Vector2(130, 44), Vector2(270, 44), Vector2(390, 23), Vector2(430, 23)],
		"kickers": [Vector3(60, 0, 1.15)]},
	{"name": "ChunkBerms", "file": "chunk_berms.tscn", "length": 300.0,
		"heading": [Vector2(0, 0), Vector2(40, 0), Vector2(100, 18), Vector2(180, -18), Vector2(260, 0), Vector2(300, 0)]},
	# Rail 2 starts 50 m after rail 1 ends, on the other side: ~1 s to cross.
	{"name": "ChunkRail", "file": "chunk_rail.tscn", "length": 270.0,
		"rails": [Vector4(40, 120, -5, 0.6), Vector4(170, 240, 5, 0.6)]},
	{"name": "ChunkGully", "file": "chunk_gully.tscn", "length": 300.0,
		"pitch": [Vector2(0, 23), Vector2(30, 23), Vector2(60, 15), Vector2(240, 15), Vector2(270, 23), Vector2(300, 23)],
		"halfpipe": 150.0},
	{"name": "ChunkFinish", "file": "chunk_finish.tscn", "length": 260.0,
		"pitch": [Vector2(0, 23), Vector2(80, 23), Vector2(120, 10), Vector2(160, 5), Vector2(260, 4)],
		"finish": 60.0},
]


func _initialize() -> void:
	for spec: Dictionary in SPECS:
		_author(spec)
	quit()


func _author(spec: Dictionary) -> void:
	var root: Chunk = Chunk.new()
	root.name = spec["name"]
	root.length = spec["length"]
	if spec.has("pitch"):
		root.pitch_keys = PackedVector2Array(spec["pitch"])
	if spec.has("heading"):
		root.heading_keys = PackedVector2Array(spec["heading"])
	if spec.has("bumps"):
		root.bumps = PackedVector3Array(spec["bumps"])

	var line: Path3D = Path3D.new()
	line.name = "TrackLine"
	_add(root, root, line)
	var entry: Marker3D = Marker3D.new()
	entry.name = "Entry"
	_add(root, root, entry)
	var exit: Marker3D = Marker3D.new()
	exit.name = "Exit"
	_add(root, root, exit)
	root.rebuild_line()

	var track: CSGCombiner3D = CSGCombiner3D.new()
	track.name = "Track"
	track.use_collision = true
	_add(root, root, track)
	var ribbon: CSGPolygon3D = CSGPolygon3D.new()
	ribbon.name = "Ribbon"
	ribbon.polygon = Chunk.make_profile()
	ribbon.mode = CSGPolygon3D.MODE_PATH
	ribbon.path_node = NodePath("../../TrackLine")
	ribbon.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	ribbon.path_interval = 1.0
	ribbon.path_simplify_angle = 0.0
	ribbon.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	ribbon.path_rotation_accurate = true
	ribbon.path_local = true
	ribbon.path_continuous_u = true
	ribbon.path_u_distance = 1.0
	ribbon.material = GROUND
	_add(root, track, ribbon)

	var kickers: Array = spec.get("kickers", [])
	for i: int in kickers.size():
		var k: Vector3 = kickers[i]
		var kicker: Node3D = KICKER.instantiate() as Node3D
		kicker.name = "Kicker%d" % (i + 1)
		var at: Transform3D = root.transform_at_u(k.x)
		kicker.transform = Transform3D(at.basis * Basis.from_scale(Vector3.ONE * k.z), at.origin + at.basis.x * k.y)
		_add(root, root, kicker)

	var rails: Array = spec.get("rails", [])
	for i: int in rails.size():
		var r: Vector4 = rails[i]
		var rail: Rail = RAIL.instantiate() as Rail
		rail.name = "Rail%d" % (i + 1)
		var curve: Curve3D = Curve3D.new()
		var steps: int = maxi(ceili((r.y - r.x) / 2.0), 1)
		for s: int in steps + 1:
			var at: Transform3D = root.transform_at_u(lerpf(r.x, r.y, float(s) / steps))
			curve.add_point(at.origin + at.basis.x * r.z + at.basis.y * r.w)
		rail.curve = curve
		rail.post_length = r.w
		_add(root, root, rail)
		rail.rebuild_posts()

	if spec.has("halfpipe"):
		var halfpipe: Node3D = HALFPIPE.instantiate() as Node3D
		halfpipe.name = "Halfpipe"
		halfpipe.transform = root.transform_at_u(spec["halfpipe"])
		_add(root, root, halfpipe)

	if spec.has("finish"):
		var gate: Node3D = FINISH.instantiate() as Node3D
		gate.name = "FinishGate"
		gate.transform = root.transform_at_u(spec["finish"])
		_add(root, root, gate)

	if spec.has("spawn"):
		var spawn: Marker3D = Marker3D.new()
		spawn.name = "Spawn"
		spawn.transform = root.transform_at_u(spec["spawn"])
		_add(root, root, spawn)

	_add(root, root, _make_pillars(root))

	var scene: PackedScene = PackedScene.new()
	var err: Error = scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, "res://chunks/" + String(spec["file"]))
	print("%s: %s" % [spec["file"], error_string(err)])
	root.free()


func _add(root: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = root


## Tall pillars on both sides every 25 m: without vertical references the
## downhill reads like a ramp rising into the fog. Visual only.
func _make_pillars(root: Chunk) -> MultiMeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1.5, 1.0, 1.5)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.4, 0.48)
	mesh.material = material
	var transforms: Array[Transform3D] = []
	var height: float = 260.0
	var u: float = 12.5
	while u < root.length:
		var at: Transform3D = root.transform_at_u(u)
		var side: Vector3 = Vector3(at.basis.x.x, 0.0, at.basis.x.z).normalized()
		for s: float in [-1.0, 1.0]:
			var base: Vector3 = at.origin + side * s * 20.0
			transforms.append(Transform3D(Basis.from_scale(Vector3(1.0, height, 1.0)), base + Vector3.DOWN * (height * 0.5 - 6.0)))
		u += 25.0
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var pillars: MultiMeshInstance3D = MultiMeshInstance3D.new()
	pillars.name = "Pillars"
	pillars.multimesh = multimesh
	return pillars
