extends SceneTree
## Authoring helper for the landscape chunks: writes chunks/landscape/*.tscn
## from the specs below. Each chunk is an open valley (TerrainPatch
## "Terrain") that can bend left/right (heading curve) and narrow (width
## profile). There are no lanes: kickers, rails, gullies, ridges and rollers
## are standalone features spread across the valley, and obstacles come in
## clusters (tree clumps, rock groups, fence runs, barrier rows, logs). The
## clusters are kept off a few invisible, wandering corridors (RideLines
## under "Lines": data only, for respawn / the autopilot / tests), so there
## is always open ground to thread through, but the rider picks their own way.
##
## SAFE BY DEFAULT: it only writes chunks whose .tscn doesn't exist yet, so
## hand edits made in the editor are never overwritten. To regenerate:
##   <exe> --headless --path . -s res://chunks/tools/author_landscape.gd               (missing chunks only)
##   <exe> --headless --path . -s res://chunks/tools/author_landscape.gd -- --only=land_gorge --overwrite
##   <exe> --headless --path . -s res://chunks/tools/author_landscape.gd -- --overwrite (ALL, loses hand edits)

const KICKER: PackedScene = preload("res://chunks/parts/kicker.tscn")
const RAIL: PackedScene = preload("res://rails/rail.tscn")
const FINISH: PackedScene = preload("res://chunks/parts/finish_gate.tscn")
const TREE: PackedScene = preload("res://chunks/parts/props/tree.tscn")
const ROCK: PackedScene = preload("res://chunks/parts/props/rock.tscn")
const LOG: PackedScene = preload("res://chunks/parts/props/log.tscn")
const FENCE: PackedScene = preload("res://chunks/parts/props/fence.tscn")
const BARRIER: PackedScene = preload("res://chunks/parts/props/barrier.tscn")
const BOULDER: PackedScene = preload("res://hazards/rolling_boulder.tscn")
const TIGHT: PackedScene = preload("res://chunks/parts/tight_zone.tscn")

const SLOPE: float = 23.0
const WIDTH: float = 150.0
## Every chunk shares these edges, so any two join.
const OUTSIDE_WIDTH: float = 35.0
const OUTSIDE_DROP: float = 25.0
## No obstacles or features this close to the entry / exit (open seams).
const END_CLEAR: float = 32.0
const RAIL_HEIGHT: float = 0.6
## Obstacle footprint radius by kind (m), for spacing and corridor clearance.
const RADIUS: Dictionary = {"tree": 0.6, "rock": 1.8, "log": 5.0, "fence": 3.2, "barrier": 1.6}
## Per tier (index = difficulty): corridor clear half-width, clusters per
## 10 000 m2, kicker scale, wander strength.
const CLEAR: Array[float] = [9.0, 9.0, 7.0, 5.5]
const CLUSTERS: Array[float] = [5.0, 5.0, 8.0, 10.0]
const KICK_SCALE: Array[float] = [1.0, 1.0, 1.15, 1.15]
const WANDER: Array[float] = [0.5, 0.5, 0.75, 1.0]


static func specs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"file": "land_start", "length": 240.0, "difficulty": 1, "seed": 3, "noise": 1.5,
		"profile": [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.33, 1.75), Vector2(0.55, 1.75), Vector2(0.8, 1.0), Vector2(1.0, 1.0)],
		"pad": Vector4(0, 24, 44, 52), "spawn": 6.0, "drop_in": 50.0,
		"corridors": 1, "wander": 0.0, "clusters": 1.5})
	# Tier 1: open, gentle bends.
	out.append({"file": "land_meadow", "length": 340.0, "difficulty": 1, "seed": 11, "noise": 2.0,
		"heading": [Vector2(0, 0), Vector2(0.15, 0), Vector2(0.45, 15), Vector2(0.8, -10), Vector2(1, 0)],
		"corridors": 4, "kickers": 3, "rails": 2, "rollers": 2, "gullies": 0, "ridges": 1,
		"mix": {"tree": 5, "rock": 2, "log": 1, "fence": 1}})
	out.append({"file": "land_ridge", "length": 360.0, "difficulty": 1, "seed": 23, "noise": 2.2,
		"heading": [Vector2(0, 0), Vector2(0.15, 0), Vector2(0.85, 25), Vector2(1, 25)],
		"corridors": 4, "kickers": 2, "rails": 2, "rollers": 1, "gullies": 1, "ridges": 3,
		"mix": {"tree": 4, "rock": 3, "log": 1}})
	# Tier 2: busier, a boulder or two.
	out.append({"file": "land_forest", "length": 360.0, "difficulty": 2, "seed": 37, "noise": 2.4,
		"heading": [Vector2(0, 0), Vector2(0.12, 0), Vector2(0.42, -20), Vector2(0.78, 15), Vector2(1, 0)],
		"corridors": 4, "kickers": 2, "rails": 2, "rollers": 2, "gullies": 1, "ridges": 1, "boulders": 1,
		"mix": {"tree": 8, "log": 2, "fence": 1, "barrier": 1}, "tight": true})
	out.append({"file": "land_boulders", "length": 360.0, "difficulty": 2, "seed": 41, "noise": 2.8,
		"heading": [Vector2(0, 0), Vector2(0.15, 0), Vector2(0.85, -25), Vector2(1, -25)],
		"corridors": 4, "kickers": 3, "rails": 1, "rollers": 1, "gullies": 2, "ridges": 1, "boulders": 2,
		"mix": {"rock": 6, "tree": 2, "barrier": 1}})
	out.append({"file": "land_gorge", "length": 380.0, "difficulty": 2, "seed": 53, "noise": 2.6,
		"heading": [Vector2(0, 0), Vector2(0.15, 0), Vector2(0.45, 28), Vector2(0.8, -8), Vector2(1, 0)],
		"width": [Vector2(0, 1), Vector2(0.15, 1), Vector2(0.35, 0.62), Vector2(0.75, 0.62), Vector2(0.92, 1), Vector2(1, 1)],
		"corridors": 3, "kickers": 2, "rails": 1, "rollers": 2, "gullies": 1, "ridges": 0,
		"mix": {"rock": 4, "tree": 4, "log": 1}, "tight": true})
	# Tier 3: dense obstacles and sharp bends.
	out.append({"file": "land_slalom", "length": 360.0, "difficulty": 3, "seed": 67, "noise": 2.4,
		"heading": [Vector2(0, 0), Vector2(0.15, 0), Vector2(0.5, 18), Vector2(0.85, 0), Vector2(1, 0)],
		"corridors": 4, "kickers": 2, "rails": 2, "rollers": 1, "gullies": 0, "ridges": 1, "boulders": 1,
		"mix": {"tree": 9, "fence": 2, "barrier": 1}, "tight": true})
	out.append({"file": "land_fast_s", "length": 360.0, "difficulty": 3, "seed": 71, "noise": 2.2,
		"heading": [Vector2(0, 0), Vector2(0.1, 0), Vector2(0.38, 36), Vector2(0.7, -12), Vector2(0.9, 0), Vector2(1, 0)],
		"width": [Vector2(0, 1), Vector2(0.1, 1), Vector2(0.3, 0.66), Vector2(0.78, 0.66), Vector2(0.92, 1), Vector2(1, 1)],
		"corridors": 3, "kickers": 1, "rails": 1, "rollers": 2, "gullies": 1, "ridges": 0,
		"mix": {"tree": 5, "rock": 3, "barrier": 1}, "tight": true})
	for side: float in [1.0, -1.0]:
		out.append({"file": "land_switchback_left" if side > 0.0 else "land_switchback_right", "length": 380.0,
			"difficulty": 3, "seed": 79 if side > 0.0 else 83, "noise": 2.2,
			"heading": [Vector2(0, 0), Vector2(0.18, 0), Vector2(0.78, 80 * side), Vector2(1, 80 * side)],
			"width": [Vector2(0, 1), Vector2(0.15, 1), Vector2(0.32, 0.58), Vector2(0.72, 0.58), Vector2(0.9, 1), Vector2(1, 1)],
			"corridors": 3, "kickers": 1, "rails": 1, "rollers": 1, "gullies": 1, "ridges": 0, "boulders": 1,
			"mix": {"rock": 4, "tree": 5}, "tight": true})
	out.append({"file": "land_finish", "length": 300.0, "difficulty": 1, "seed": 7, "noise": 1.5,
		"profile": [Vector2(0.0, 1.0), Vector2(0.3, 1.0), Vector2(0.6, 0.3), Vector2(1.0, 0.25)],
		"finish": 150.0, "corridors": 1, "wander": 0.0, "clusters": 1.0})
	return out


var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var overwrite: bool = args.has("--overwrite")
	var only: String = ""
	for arg: String in args:
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute("res://chunks/landscape")
	for spec: Dictionary in specs():
		var file: String = String(spec["file"])
		if not only.is_empty() and file != only:
			continue
		var path: String = "res://chunks/landscape/%s.tscn" % file
		if FileAccess.file_exists(path) and not overwrite:
			print("%s: exists, skipped (pass -- --overwrite to regenerate; that loses hand edits)" % file)
			continue
		await _author(spec, path)
	quit()


func _author(spec: Dictionary, path: String) -> void:
	_rng.seed = int(spec["seed"])
	var length: float = spec["length"]
	var tier: int = spec["difficulty"]

	var root: Chunk = Chunk.new()
	root.name = String(spec["file"]).to_pascal_case()
	root.length = length
	root.difficulty = tier
	var terrain: TerrainPatch = TerrainPatch.new()
	terrain.name = "Terrain"
	terrain.width = WIDTH
	terrain.length = length
	terrain.outside_width = OUTSIDE_WIDTH
	terrain.outside_drop = OUTSIDE_DROP
	terrain.noise_seed = int(spec["seed"])
	terrain.noise_amplitude = spec.get("noise", 2.0)
	terrain.slope_profile = _curve(spec.get("profile", []), 0.0, 2.0)
	terrain.heading_curve = _curve(spec.get("heading", []), -120.0, 120.0)
	terrain.width_profile = _curve(spec.get("width", []), 0.0, 1.5)
	_add(root, root, terrain)
	var props: Node3D = Node3D.new()
	props.name = "Props"
	_add(root, terrain, props)
	var track: Path3D = Path3D.new()
	track.name = "TrackLine"
	track.curve = Curve3D.new()
	track.curve.add_point(Vector3.ZERO)
	track.curve.add_point(Vector3(0, 0, -1))
	_add(root, root, track)
	for marker: String in ["Entry", "Exit"]:
		var m: Marker3D = Marker3D.new()
		m.name = marker
		_add(root, root, m)
	get_root().add_child(root)
	await process_frame

	# --- Invisible corridors (valley x at each d), kept clear of obstacles.
	var clear: float = CLEAR[tier]
	var corridors: Array[PackedVector2Array] = []
	var count: int = spec.get("corridors", 3)
	var wander: float = spec.get("wander", WANDER[tier])
	for i: int in count:
		corridors.append(_make_corridor(terrain, i, count, wander, length))

	# --- Features: (valley x, d, radius) footprints, so they don't overlap.
	var taken: Array[Vector3] = []
	var shapes: Node3D = terrain
	for i: int in int(spec.get("gullies", 0)):
		var c: PackedVector2Array = corridors[_rng.randi() % corridors.size()]
		var d0: float = _rng.randf_range(END_CLEAR + 10.0, length - END_CLEAR - 130.0)
		var gully: TerrainShape = _shape_along(terrain, c, d0, d0 + _rng.randf_range(80.0, 130.0), TerrainShape.Mode.GULLY, 14.0, _rng.randf_range(2.5, 3.5), 0.3, 0.0)
		gully.name = "Gully%d" % (i + 1)
		_add(root, shapes, gully)
	for i: int in int(spec.get("ridges", 0)):
		# A rideable hump somewhere between the corridors.
		var x: float = _rng.randf_range(-45.0, 45.0)
		var d0: float = _rng.randf_range(END_CLEAR + 10.0, length - END_CLEAR - 110.0)
		var line: PackedVector2Array = PackedVector2Array()
		for k: int in 6:
			var d: float = d0 + k * 18.0
			line.append(Vector2(_scale_x(terrain, x, d) + _rng.randf_range(-4.0, 4.0), d))
		var ridge: TerrainShape = _shape_from(terrain, line, TerrainShape.Mode.RIDGE, _rng.randf_range(24.0, 32.0), _rng.randf_range(2.5, 3.5), 0.15)
		ridge.name = "Ridge%d" % (i + 1)
		_add(root, shapes, ridge)
	var roller_index: int = 0
	for i: int in int(spec.get("rollers", 0)):
		# Two or three rollers across a corridor, 24 m apart.
		var c: PackedVector2Array = corridors[_rng.randi() % corridors.size()]
		var d0: float = _free_d(c, taken, 70.0, length)
		if d0 < 0.0:
			continue
		for k: int in _rng.randi_range(2, 3):
			var d: float = d0 + k * 24.0
			var x: float = _corridor_x(c, d)
			var tan: Vector2 = _corridor_tangent(c, d)
			var across: Vector2 = Vector2(tan.y, -tan.x)
			var line: PackedVector2Array = PackedVector2Array([Vector2(x, d) - across * 10.0, Vector2(x, d) + across * 10.0])
			var roller: TerrainShape = _shape_from(terrain, line, TerrainShape.Mode.RIDGE, 12.0, 1.3, 0.0)
			roller_index += 1
			roller.name = "Roller%d" % roller_index
			_add(root, shapes, roller)
		taken.append(Vector3(_corridor_x(c, d0 + 30.0), d0 + 30.0, 40.0))
	var rails: Array[Dictionary] = []
	for i: int in int(spec.get("rails", 0)):
		var c: PackedVector2Array = corridors[_rng.randi() % corridors.size()]
		var span: float = _rng.randf_range(50.0, 70.0)
		var d0: float = _free_d(c, taken, span + 10.0, length, terrain, 8.0)
		if d0 < 0.0:
			continue
		# Smooth ground under the rail (LINE on the plain slope), rail on top later.
		var bed: TerrainShape = _shape_along(terrain, c, d0 - 6.0, d0 + span + 6.0, TerrainShape.Mode.LINE, 9.0, 0.0, 0.45, 0.0)
		bed.name = "RailBed%d" % (i + 1)
		_add(root, shapes, bed)
		rails.append({"corridor": c, "d0": d0, "d1": d0 + span})
		taken.append(Vector3(_corridor_x(c, d0 + span * 0.5), d0 + span * 0.5, span * 0.5 + 6.0))
	var pads: Array[TerrainFlatten] = []
	for i: int in int(spec.get("kickers", 0)):
		var c: PackedVector2Array = corridors[_rng.randi() % corridors.size()]
		var d: float = _free_d(c, taken, 40.0, length, terrain, 5.0)
		if d < 0.0:
			continue
		d += 20.0
		var pad: TerrainFlatten = TerrainFlatten.new()
		pad.name = "KickerPad%d" % (i + 1)
		pad.size = Vector2(12.0, 36.0)
		pad.blend = 6.0
		pad.transform = _pad_transform(terrain, Vector2(_corridor_x(c, d), d), _corridor_tangent(c, d))
		_add(root, shapes, pad)
		var kicker: Node3D = KICKER.instantiate() as Node3D
		kicker.name = "Kicker"
		kicker.scale = Vector3.ONE * KICK_SCALE[tier]
		_add(root, pad, kicker)
		pads.append(pad)
		taken.append(Vector3(_corridor_x(c, d), d, 22.0))
	if spec.has("pad"):
		var p4: Vector4 = spec["pad"]
		var start_pad: TerrainFlatten = TerrainFlatten.new()
		start_pad.name = "StartPad"
		start_pad.size = Vector2(p4.z, p4.w)
		start_pad.blend = 10.0
		start_pad.position = Vector3(p4.x, 0.0, -p4.y)
		_add(root, shapes, start_pad)
	terrain.rebuild()

	# --- Rails on the smoothed ground (points every 4 m, following the corridor).
	for i: int in rails.size():
		var r: Dictionary = rails[i]
		var rail: Path3D = RAIL.instantiate() as Path3D
		rail.name = "Rail%d" % (i + 1)
		rail.curve = Curve3D.new()
		var d: float = r["d0"]
		while d <= float(r["d1"]) + 0.01:
			var x: float = _corridor_x(r["corridor"], d)
			rail.curve.add_point(terrain.valley_to_local(x, terrain.surface_height(x, -d) + RAIL_HEIGHT, d))
			d += 4.0
		_add(root, root, rail)

	# --- Obstacle clusters, off the corridors and features.
	var area: float = 0.0
	for k: int in 20:
		area += terrain.half_play_at(length * (k + 0.5) / 20.0) * 2.0 * length / 20.0
	var clusters: int = int(area / 10000.0 * float(spec.get("clusters", CLUSTERS[tier])))
	var mix: Dictionary = spec.get("mix", {"tree": 4, "rock": 1})
	var placed: Array[Vector3] = []
	for i: int in clusters:
		_cluster(root, props, terrain, _pick(mix), corridors, clear, taken, placed, length)

	# --- Boulders: roll across the valley from one side.
	for i: int in int(spec.get("boulders", 0)):
		var d: float = _rng.randf_range(length * 0.3, length * 0.7)
		var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var half: float = terrain.half_play_at(d)
		# Up on the crest, so it sits clear of the open ground until it rolls.
		var start: Vector3 = terrain.valley_to_local(side * (half + 3.0), 0.0, d)
		var end: Vector3 = terrain.valley_to_local(-side * (half * 0.35), 0.0, d + 25.0)
		var boulder: RollingBoulder = BOULDER.instantiate() as RollingBoulder
		boulder.name = "Boulder%d" % (i + 1)
		boulder.position = Vector3(start.x, terrain.height_at_local(start) + 2.2, start.z)
		boulder.roll_to = Vector3(end.x - start.x, 0.0, end.z - start.z)
		_add(root, root, boulder)

	# --- Invisible corridors as RideLines (respawn, autopilot, tests).
	var lines: Node3D = Node3D.new()
	lines.name = "Lines"
	_add(root, root, lines)
	for i: int in corridors.size():
		var line: RideLine = RideLine.new()
		line.name = "Path%d" % (i + 1)
		line.curve = Curve3D.new()
		for p: Vector2 in corridors[i]:
			line.curve.add_point(terrain.valley_to_local(p.x, terrain.surface_height(p.x, -p.y), p.y))
		line.add_to_group(&"ride_lines", true)
		_add(root, lines, line)

	# --- Tight sections: the whole middle of busy chunks (camera tucks in).
	if spec.get("tight", false):
		var d0: float = END_CLEAR + 20.0
		var d1: float = length - END_CLEAR - 20.0
		var d: float = d0
		while d < d1:
			var seg: float = minf(60.0, d1 - d)
			var zone: TightZone = TIGHT.instantiate() as TightZone
			zone.name = "TightZone%d" % roundi(d)
			var frame: Transform3D = terrain.frame_at(d + seg * 0.5)
			zone.size = Vector3(terrain.half_play_at(d + seg * 0.5) * 2.0, 40.0, seg + 2.0)
			zone.transform = Transform3D(frame.basis, frame.origin + frame.basis.y * 8.0)
			_add(root, root, zone)
			d += seg

	# --- Markers, centerline, spawn / finish.
	track.curve.clear_points()
	for i: int in range(0, int(length) + 1):
		track.curve.add_point(terrain.frame_at(float(i)).origin)
	(root.get_node(^"Entry") as Marker3D).transform = terrain.frame_at(0.0)
	(root.get_node(^"Exit") as Marker3D).transform = terrain.exit_transform()
	root.exit_heading_deg = rad_to_deg(terrain.heading_at(length))
	if spec.has("spawn"):
		for marker: Array in [["Spawn", spec["spawn"]], ["DropIn", spec["drop_in"]]]:
			var m: Marker3D = Marker3D.new()
			m.name = marker[0]
			var md: float = marker[1]
			m.position = terrain.valley_to_local(0.0, terrain.surface_height(0.0, -md), md)
			_add(root, root, m)
	if spec.has("finish"):
		var gate: Node3D = FINISH.instantiate() as Node3D
		gate.name = "FinishGate"
		var fd: float = spec["finish"]
		gate.transform = Transform3D(Basis(Vector3.UP, terrain.heading_at(fd)) * Basis.from_scale(Vector3(3.6, 1.6, 1.0)),
				terrain.valley_to_local(0.0, terrain.surface_height(0.0, -fd), fd))
		_add(root, root, gate)

	var ok: bool = terrain.fold_margin >= 0.0
	get_root().remove_child(root)
	var scene: PackedScene = PackedScene.new()
	var err: Error = scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, path)
	print("%s: %s  %d props, %d clusters, exit heading %.0f deg, tightest bend r %.0f m%s" % [
		spec["file"], error_string(err), props.get_child_count(), clusters, root.exit_heading_deg,
		terrain.tightest_radius, "" if ok else "  ** FOLDS: bend tighter than the valley half width **"])
	root.free()


func _add(root: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = root


# --- Corridors (valley space: Vector2(x, d) every 2.5 m) ----------------------

## A wandering corridor: a base spot across the valley plus two sine waves,
## squeezed with the valley's width. Curvature stays under 1/45 m.
func _make_corridor(terrain: TerrainPatch, i: int, count: int, wander: float, length: float) -> PackedVector2Array:
	var base: float = 0.0 if count == 1 else lerpf(-0.62, 0.62, (i + _rng.randf_range(-0.2, 0.2)) / float(count - 1))
	var l1: float = _rng.randf_range(160.0, 230.0)
	var l2: float = _rng.randf_range(90.0, 130.0)
	var a1: float = minf(_rng.randf_range(12.0, 20.0), l1 * l1 / 1800.0) * wander
	var a2: float = minf(_rng.randf_range(3.0, 6.0), l2 * l2 / 3600.0) * wander
	var p1: float = _rng.randf() * TAU
	var p2: float = _rng.randf() * TAU
	var out: PackedVector2Array = PackedVector2Array()
	var d: float = 0.0
	while d <= length + 0.01:
		var room: float = terrain.half_play_at(d) - terrain.wall_width * 0.6
		var x: float = base * room + a1 * sin(TAU * d / l1 + p1) + a2 * sin(TAU * d / l2 + p2)
		out.append(Vector2(clampf(x, -room, room), d))
		d += 2.5
	return out


static func _corridor_x(c: PackedVector2Array, d: float) -> float:
	var i: int = clampi(int(d / 2.5), 0, c.size() - 2)
	return lerpf(c[i].x, c[i + 1].x, clampf((d - c[i].y) / 2.5, 0.0, 1.0))


## How much corridor c turns between d0 and d1 in the patch's own space (deg).
static func _turn_deg(terrain: TerrainPatch, c: PackedVector2Array, d0: float, d1: float) -> float:
	var dirs: Array[Vector3] = []
	for d: float in [d0, d1]:
		var a: Vector3 = terrain.valley_to_local(_corridor_x(c, d - 2.0), 0.0, d - 2.0)
		var b: Vector3 = terrain.valley_to_local(_corridor_x(c, d + 2.0), 0.0, d + 2.0)
		dirs.append((b - a).normalized())
	return rad_to_deg(dirs[0].angle_to(dirs[1]))


## Unit direction (dx, dd) of the corridor at d, valley space.
static func _corridor_tangent(c: PackedVector2Array, d: float) -> Vector2:
	return Vector2(_corridor_x(c, d + 2.0) - _corridor_x(c, d - 2.0), 4.0).normalized()


## x scaled with the valley width at d (for features placed by fraction).
static func _scale_x(terrain: TerrainPatch, x: float, d: float) -> float:
	return x * terrain.half_play_at(d) / (terrain.width * 0.5)


## A d where a `span` long stretch of corridor c is free of other features
## and turns less than `max_turn_deg` in the world (valley bend + corridor
## wander): rails and kickers want straight-ish ground.
func _free_d(c: PackedVector2Array, taken: Array[Vector3], span: float, length: float,
		terrain: TerrainPatch = null, max_turn_deg: float = 180.0) -> float:
	for attempt: int in 60:
		var d0: float = _rng.randf_range(END_CLEAR + 8.0, length - END_CLEAR - span - 8.0)
		var ok: bool = terrain == null or _turn_deg(terrain, c, d0, d0 + span) <= max_turn_deg
		for t: Vector3 in taken:
			for k: int in 5:
				var d: float = d0 + span * k / 4.0
				if Vector2(_corridor_x(c, d), d).distance_to(Vector2(t.x, t.y)) < t.z + 10.0:
					ok = false
		if ok:
			return d0
	return -1.0


# --- Shapes and pads ----------------------------------------------------------

## A TerrainShape along corridor c from d0 to d1 (y on the plain slope + lift).
func _shape_along(terrain: TerrainPatch, c: PackedVector2Array, d0: float, d1: float, mode: TerrainShape.Mode,
		shape_width: float, depth: float, flat: float, lift: float) -> TerrainShape:
	var line: PackedVector2Array = PackedVector2Array()
	var d: float = d0
	while d <= d1 + 0.01:
		line.append(Vector2(_corridor_x(c, d), d))
		d += 2.5
	var shape: TerrainShape = _shape_from(terrain, line, mode, shape_width, depth, flat)
	for i: int in shape.curve.point_count:
		var p: Vector3 = shape.curve.get_point_position(i)
		shape.curve.set_point_position(i, p + Vector3.UP * lift)
	return shape


## A TerrainShape through valley points (x, d), heights on the plain slope.
func _shape_from(terrain: TerrainPatch, line: PackedVector2Array, mode: TerrainShape.Mode,
		shape_width: float, depth: float, flat: float) -> TerrainShape:
	var shape: TerrainShape = TerrainShape.new()
	shape.mode = mode
	shape.width = shape_width
	shape.depth = depth
	shape.flat = flat
	shape.curve = Curve3D.new()
	for p: Vector2 in line:
		shape.curve.add_point(terrain.valley_to_local(p.x, terrain.base_height(p.x, -p.y), p.y))
	return shape


## A pad on the plain slope at valley point p, facing along valley direction dir.
func _pad_transform(terrain: TerrainPatch, p: Vector2, dir: Vector2) -> Transform3D:
	var a: Vector3 = terrain.valley_to_local(p.x, 0.0, p.y)
	var b: Vector3 = terrain.valley_to_local(p.x + dir.x * 4.0, 0.0, p.y + dir.y * 4.0)
	var yaw: float = atan2(-(b.x - a.x), -(b.z - a.z))
	var basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(-SLOPE))
	return Transform3D(basis, Vector3(a.x, terrain.base_height(p.x, -p.y), a.z))


# --- Props ------------------------------------------------------------------------

func _pick(mix: Dictionary) -> String:
	var total: float = 0.0
	for k: String in mix:
		total += float(mix[k])
	var roll: float = _rng.randf() * total
	for k: String in mix:
		roll -= float(mix[k])
		if roll <= 0.0:
			return k
	return String(mix.keys()[0])


## One cluster of `kind` around a random spot; members that would block a
## corridor, a feature or the open seams are skipped.
func _cluster(root: Node, props: Node3D, terrain: TerrainPatch, kind: String, corridors: Array[PackedVector2Array],
		clear: float, taken: Array[Vector3], placed: Array[Vector3], length: float) -> void:
	var d: float = _rng.randf_range(END_CLEAR, length - END_CLEAR)
	var half: float = terrain.half_play_at(d)
	var x: float = _rng.randf_range(-half + 6.0, half - 6.0)
	var members: Array[Vector3] = []
	match kind:
		"tree":
			for i: int in _rng.randi_range(3, 8):
				members.append(Vector3(x + _rng.randf_range(-9.0, 9.0), d + _rng.randf_range(-9.0, 9.0), _rng.randf() * TAU))
		"rock":
			for i: int in _rng.randi_range(2, 5):
				members.append(Vector3(x + _rng.randf_range(-7.0, 7.0), d + _rng.randf_range(-7.0, 7.0), _rng.randf() * TAU))
		"log":
			members.append(Vector3(x, d, _rng.randf() * TAU))
		"fence", "barrier":
			# A short run, roughly across or along the valley.
			var angle: float = _rng.randf() * PI
			var step: float = 6.2 if kind == "fence" else 3.1
			for i: int in _rng.randi_range(2, 5):
				members.append(Vector3(x + cos(angle) * step * i, d + sin(angle) * step * i, angle))
	var scene: PackedScene = {"tree": TREE, "rock": ROCK, "log": LOG, "fence": FENCE, "barrier": BARRIER}[kind] as PackedScene
	var radius: float = float(RADIUS[kind])
	for m: Vector3 in members:
		var p: Vector2 = Vector2(m.x, m.y)
		if p.y < END_CLEAR or p.y > length - END_CLEAR or absf(p.x) > terrain.half_play_at(p.y) - 3.0:
			continue
		var ok: bool = true
		for c: PackedVector2Array in corridors:
			if absf(_corridor_x(c, p.y) - p.x) < clear + radius + 1.0:
				ok = false
				break
		for t: Vector3 in taken:
			if ok and p.distance_to(Vector2(t.x, t.y)) < t.z + radius + 3.0:
				ok = false
		for q: Vector3 in placed:
			if ok and p.distance_to(Vector2(q.x, q.y)) < q.z + radius + 1.5:
				ok = false
		if not ok:
			continue
		var prop: Node3D = scene.instantiate() as Node3D
		prop.name = "%s%d" % [kind.capitalize(), props.get_child_count() + 1]
		var at: Vector3 = terrain.valley_to_local(p.x, terrain.surface_height(p.x, -p.y), p.y)
		prop.position = at
		# Yaw relative to the valley's heading there.
		prop.rotation.y = m.z + terrain.heading_at(p.y)
		if kind == "tree" or kind == "rock":
			prop.scale = Vector3.ONE * _rng.randf_range(0.8, 1.3)
		_add(root, props, prop)
		placed.append(Vector3(p.x, p.y, radius))


static func _curve(points: Array, lo: float, hi: float) -> Curve:
	if points.is_empty():
		return null
	var curve: Curve = Curve.new()
	curve.min_value = lo
	curve.max_value = hi
	for p: Vector2 in points:
		curve.add_point(p)
	return curve
