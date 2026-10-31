extends SceneTree
## One-off authoring helper for the v0.8 landscape chunks: writes
## chunks/landscape/*.tscn from the specs below. Each chunk is a 150 m wide
## valley (TerrainPatch "Terrain") with 2-3 ride lines that split after the
## entry and rejoin before the exit, each with its own style:
##   RAIL  straight stretches with rails on smoothed ground
##   JUMP  kickers on flat pads + rollers to pump
##   CARVE weaving turns, tree gates, sometimes sunk into a gully
## plus obstacles (trees, rocks, logs, fences, barriers), rolling boulders,
## canyon walls and TightZones. After this the .tscn files are the source of
## truth: open them in the editor and move things. Running this again
## OVERWRITES those edits.
##   <exe> --headless --path . -s res://chunks/tools/author_landscape.gd

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
## Ride lines keep scattered props at least this far away (m).
const PROP_KEEP: float = 7.0
## Spacing of LINE / ride-line curve points (m).
const STEP: float = 2.0
const RAIL_HEIGHT: float = 0.6
const ROLLER_LENGTH: float = 24.0
const ROLLER_HEIGHT: float = 1.4

enum { RAIL_LINE, JUMP_LINE, CARVE_LINE }


## Lane keys: x across at distance d downhill, as Vector2(x, d). Split from
## the middle after the entry, rejoin before the exit.
static func lane(x: float, length: float, split: float = 80.0) -> Array[Vector2]:
	return [Vector2(0, 0), Vector2(0, 20), Vector2(x, split), Vector2(x, length - split), Vector2(0, length - 20), Vector2(0, length)]


static func specs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# --- Start: flat pad (sprint start), steep drop-in, ease into 23 deg.
	out.append({"name": "LandStart", "file": "land_start.tscn", "length": 240.0, "difficulty": 1, "seed": 3,
		"noise": 1.5, "profile": [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.33, 1.75), Vector2(0.55, 1.75), Vector2(0.8, 1.0), Vector2(1.0, 1.0)],
		"pad": Vector4(0, 24, 44, 52), "spawn": 6.0, "drop_in": 50.0,
		"lanes": [{"style": CARVE_LINE, "keys": [Vector2(0, 0), Vector2(0, 240)]}],
		"trees": 0.5, "rocks": 0.2})
	# --- Tier 1: open meadow. Rail right, kickers in the middle, easy carve left.
	out.append({"name": "LandMeadow", "file": "land_meadow.tscn", "length": 340.0, "difficulty": 1, "seed": 11, "noise": 2.0,
		"lanes": [
			{"style": RAIL_LINE, "keys": lane(34, 340), "rails": [Vector2(95, 165), Vector2(195, 255)]},
			{"style": JUMP_LINE, "keys": lane(0, 340), "kickers": [125.0, 250.0], "rollers": [55.0, 79.0, 175.0, 199.0]},
			{"style": CARVE_LINE, "keys": lane(-34, 340), "weave": Vector4(8, 150, 90, 250), "gates": 6.5}],
		"trees": 0.8, "rocks": 0.25, "logs": 3,
		"fences": [Vector3(17, 110, 170)]})
	# --- Tier 1: a ridge splits the valley; rails along its crest.
	out.append({"name": "LandRidge", "file": "land_ridge.tscn", "length": 360.0, "difficulty": 1, "seed": 23, "noise": 2.2,
		"ridges": [{"points": [Vector2(0, 70), Vector2(0, 290)], "width": 30.0, "depth": 5.0}],
		"lanes": [
			{"style": RAIL_LINE, "keys": lane(0, 360), "raise": Vector4(5, 40, 95, 0), "rails": [Vector2(105, 175), Vector2(205, 265)], "width": 9.0},
			{"style": JUMP_LINE, "keys": lane(38, 360), "kickers": [115.0, 235.0], "rollers": [160.0, 184.0]},
			{"style": CARVE_LINE, "keys": lane(-38, 360), "sunk": 3.0, "width": 14.0, "weave": Vector4(7, 140, 85, 275)}],
		"trees": 1.0, "rocks": 0.3, "logs": 2,
		"fences": [Vector3(-62, 120, 200)]})
	# --- Tier 2: forest. Barriers along the rail line, a boulder across.
	out.append({"name": "LandForest", "file": "land_forest.tscn", "length": 360.0, "difficulty": 2, "seed": 37, "noise": 2.4,
		"lanes": [
			{"style": RAIL_LINE, "keys": lane(-36, 360), "rails": [Vector2(90, 150), Vector2(190, 260)], "barriers": Vector2(88, 152)},
			{"style": JUMP_LINE, "keys": lane(0, 360), "kickers": [130.0, 250.0], "rollers": [70.0, 94.0, 185.0]},
			{"style": CARVE_LINE, "keys": lane(34, 360), "weave": Vector4(10, 130, 85, 275), "gates": 5.0}],
		"trees": 1.6, "rocks": 0.4, "logs": 5,
		"fences": [Vector3(-18, 180, 245), Vector3(17, 60, 115)],
		"boulders": [Vector4(175, -72, 132, -25)],
		"tight": [Vector2(85, 275)]})
	# --- Tier 2: boulder field. A gully down the middle, two boulders.
	out.append({"name": "LandBoulders", "file": "land_boulders.tscn", "length": 360.0, "difficulty": 2, "seed": 41, "noise": 2.8,
		"lanes": [
			{"style": RAIL_LINE, "keys": lane(-38, 360), "rails": [Vector2(85, 150), Vector2(200, 270)]},
			{"style": CARVE_LINE, "keys": lane(0, 360), "sunk": 3.0, "width": 14.0, "weave": Vector4(8, 150, 75, 285)},
			{"style": JUMP_LINE, "keys": lane(36, 360), "kickers": [110.0, 225.0], "rollers": [160.0], "barriers": Vector2(150, 200)}],
		"trees": 0.8, "rocks": 1.2, "logs": 3,
		"boulders": [Vector4(130, 72, -127, -20), Vector4(262, -72, 127, -22)],
		"fences": [Vector3(-60, 60, 120)]})
	# --- Tier 3: canyon. Two rock walls force an S-turn through the valley.
	var canyon: Array[Dictionary] = []
	for lane_def: Array in [[RAIL_LINE, 16.0], [JUMP_LINE, 25.0], [CARVE_LINE, 34.0]]:
		var o: float = lane_def[1]
		var keys: Array[Vector2] = [Vector2(0, 0), Vector2(0, 20), Vector2(o, 85), Vector2(o, 120), Vector2(-o, 225), Vector2(-o, 265), Vector2(0, 345), Vector2(0, 380)]
		var spec_lane: Dictionary = {"style": lane_def[0], "keys": keys}
		if lane_def[0] == RAIL_LINE:
			spec_lane["rails"] = [Vector2(88, 118), Vector2(228, 262)]
		elif lane_def[0] == JUMP_LINE:
			spec_lane["rollers"] = [150.0, 174.0]
		canyon.append(spec_lane)
	out.append({"name": "LandCanyon", "file": "land_canyon.tscn", "length": 380.0, "difficulty": 3, "seed": 53, "noise": 2.6,
		"ridges": [{"points": [Vector2(-80, 106), Vector2(-3, 106)], "width": 24.0, "depth": 12.0},
			{"points": [Vector2(80, 240), Vector2(3, 240)], "width": 24.0, "depth": 12.0}],
		"lanes": canyon, "trees": 2.0, "rocks": 0.5, "logs": 3,
		"tight": [Vector2(85, 270)]})
	# --- Tier 3: slalom forest. Fences keep you on your line.
	out.append({"name": "LandSlalom", "file": "land_slalom.tscn", "length": 360.0, "difficulty": 3, "seed": 67, "noise": 2.4,
		"lanes": [
			{"style": JUMP_LINE, "keys": lane(-36, 360), "kickers": [120.0, 240.0], "rollers": [175.0]},
			{"style": CARVE_LINE, "keys": lane(0, 360), "weave": Vector4(9, 110, 65, 295), "gates": 4.5},
			{"style": RAIL_LINE, "keys": lane(36, 360), "rails": [Vector2(90, 160), Vector2(200, 270)]}],
		"trees": 2.4, "rocks": 0.4, "logs": 2,
		"fences": [Vector3(-18, 75, 130), Vector3(-18, 165, 220), Vector3(18, 75, 130), Vector3(18, 165, 220), Vector3(18, 250, 285)],
		"boulders": [Vector4(205, -72, 48, -18)],
		"tight": [Vector2(60, 300)]})
	# --- Finish: lines merge, the gate, then the slope eases out.
	out.append({"name": "LandFinish", "file": "land_finish.tscn", "length": 300.0, "difficulty": 1, "seed": 7, "noise": 1.5,
		"profile": [Vector2(0.0, 1.0), Vector2(0.3, 1.0), Vector2(0.6, 0.3), Vector2(1.0, 0.25)],
		"lanes": [{"style": CARVE_LINE, "keys": [Vector2(0, 0), Vector2(0, 300)]}],
		"finish": 150.0, "trees": 0.4, "rocks": 0.2})
	return out


var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://chunks/landscape")
	for spec: Dictionary in specs():
		await _author(spec)
	quit()


func _author(spec: Dictionary) -> void:
	_rng.seed = int(spec["seed"])
	var length: float = spec["length"]
	var profile: Curve = _make_profile(spec.get("profile", []))

	var root: Chunk = Chunk.new()
	root.name = spec["name"]
	root.length = length
	root.difficulty = spec["difficulty"]

	var terrain: TerrainPatch = TerrainPatch.new()
	terrain.name = "Terrain"
	terrain.width = WIDTH
	terrain.length = length
	terrain.slope_profile = profile
	terrain.noise_seed = int(spec["seed"])
	terrain.noise_amplitude = spec.get("noise", 2.0)
	_add(root, root, terrain)

	# Base slope height down the middle, the same integration as the patch.
	var base: PackedFloat32Array = _base_heights(length, profile)

	# Shaping: canyon walls / ridges, then one LINE per lane (smooth ground
	# along every line, rollers built in), then kicker pads.
	for ridge: Dictionary in spec.get("ridges", []):
		var shape: TerrainShape = TerrainShape.new()
		shape.name = "Ridge"
		shape.mode = TerrainShape.Mode.RIDGE
		shape.width = ridge["width"]
		shape.depth = ridge["depth"]
		shape.flat = 0.25
		shape.curve = Curve3D.new()
		for p: Vector2 in ridge["points"]:
			shape.curve.add_point(Vector3(p.x, 0.0, -p.y))
		_add(root, terrain, shape)
	var lanes: Array = spec["lanes"]
	for lane_spec: Dictionary in lanes:
		lane_spec["_len"] = length
	for i: int in lanes.size():
		var lane_spec: Dictionary = lanes[i]
		var shape: TerrainShape = TerrainShape.new()
		shape.name = "Line%d%s" % [i + 1, _style_name(lane_spec["style"])]
		shape.mode = TerrainShape.Mode.LINE
		shape.width = lane_spec.get("width", 12.0)
		shape.flat = 0.45
		shape.curve = Curve3D.new()
		var d: float = 0.0
		while d <= length + 0.01:
			var x: float = _lane_x(lane_spec, d)
			shape.curve.add_point(Vector3(x, _base_at(base, d) + _lane_lift(lane_spec, d), -d))
			d += STEP
		_add(root, terrain, shape)
		for k: float in lane_spec.get("kickers", []):
			var pad: TerrainFlatten = TerrainFlatten.new()
			pad.name = "KickerPad%d" % roundi(k)
			pad.size = Vector2(12.0, 36.0)
			pad.blend = 6.0
			pad.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-SLOPE)), Vector3(_lane_x(lane_spec, k), _base_at(base, k) + _lane_lift(lane_spec, k), -k))
			_add(root, terrain, pad)
			var kicker: Node3D = KICKER.instantiate() as Node3D
			kicker.name = "Kicker"
			if int(spec["difficulty"]) > 1:
				kicker.scale = Vector3.ONE * 1.15
			_add(root, pad, kicker)
	if spec.has("pad"):
		# Start pad: level, around the spawn.
		var p4: Vector4 = spec["pad"]
		var start_pad: TerrainFlatten = TerrainFlatten.new()
		start_pad.name = "StartPad"
		start_pad.size = Vector2(p4.z, p4.w)
		start_pad.blend = 10.0
		start_pad.position = Vector3(p4.x, 0.0, -p4.y)
		_add(root, terrain, start_pad)

	var props: Node3D = Node3D.new()
	props.name = "Props"
	_add(root, terrain, props)

	# The centerline (collapse, progress) straight down the middle.
	var track: Path3D = Path3D.new()
	track.name = "TrackLine"
	track.curve = Curve3D.new()
	for i: int in range(0, int(length) + 1):
		track.curve.add_point(Vector3(0.0, _base_at(base, float(i)), -float(i)))
	_add(root, root, track)
	var entry: Marker3D = Marker3D.new()
	entry.name = "Entry"
	entry.transform = _frame(base, 0.0, length)
	_add(root, root, entry)
	var exit: Marker3D = Marker3D.new()
	exit.name = "Exit"
	exit.transform = _frame(base, length, length)
	_add(root, root, exit)

	# Enter the tree: the terrain builds (Chunk samples its line too).
	get_root().add_child(root)
	await process_frame
	# Centerline and markers again, from the built patch's own slope, so
	# chunk joins line up exactly.
	track.curve.clear_points()
	for i: int in range(0, int(length) + 1):
		track.curve.add_point(Vector3(0.0, terrain.base_height(0.0, -float(i)), -float(i)))
	entry.transform = _patch_frame(terrain, 0.0)
	exit.transform = _patch_frame(terrain, length)

	# Ride lines on the built ground.
	var lines: Node3D = Node3D.new()
	lines.name = "Lines"
	_add(root, root, lines)
	var lane_paths: Array[PackedVector2Array] = []
	for i: int in lanes.size():
		var lane_spec: Dictionary = lanes[i]
		var line: RideLine = RideLine.new()
		line.name = "Line%d%s" % [i + 1, _style_name(lane_spec["style"])]
		line.style = [RideLine.Style.RAIL, RideLine.Style.JUMP, RideLine.Style.CARVE][lane_spec["style"]]
		line.curve = Curve3D.new()
		var path2: PackedVector2Array = PackedVector2Array()
		var d: float = 0.0
		while d <= length + 0.01:
			var x: float = _lane_x(lane_spec, d)
			line.curve.add_point(Vector3(x, terrain.surface_height(x, -d), -d))
			path2.append(Vector2(x, d))
			d += 2.5
		lane_paths.append(path2)
		line.add_to_group(&"ride_lines", true)
		_add(root, lines, line)
		# Rails on the smoothed ground.
		var rail_index: int = 0
		for span: Vector2 in lane_spec.get("rails", []):
			var rail: Path3D = RAIL.instantiate() as Path3D
			rail_index += 1
			rail.name = "Rail%d_%d" % [i + 1, rail_index]
			rail.curve = Curve3D.new()
			for dd: float in [span.x, span.y]:
				var rx: float = _lane_x(lane_spec, dd)
				rail.curve.add_point(Vector3(rx, terrain.surface_height(rx, -dd) + RAIL_HEIGHT, -dd))
			_add(root, root, rail)
		# Barriers lining both sides of the line.
		if lane_spec.has("barriers"):
			var span_b: Vector2 = lane_spec["barriers"]
			var bd: float = span_b.x
			while bd <= span_b.y:
				for side: float in [-1.0, 1.0]:
					var bx: float = _lane_x(lane_spec, bd) + side * 6.5
					_place_prop(root, props, terrain, BARRIER, Vector3(bx, 0.0, -bd), PI * 0.5, 1.0)
				bd += 12.0
		# Tree gates on weaving lines: a pair of trees at every apex.
		if lane_spec.has("gates") and lane_spec.has("weave"):
			var w: Vector4 = lane_spec["weave"]
			var gap: float = lane_spec["gates"]
			var apex: float = w.z + w.y * 0.25
			while apex < w.w:
				for side: float in [-1.0, 1.0]:
					var gx: float = _lane_x(lane_spec, apex) + side * gap
					_place_prop(root, props, terrain, TREE, Vector3(gx, 0.0, -apex), _rng.randf() * TAU, _rng.randf_range(0.9, 1.15))
				apex += w.y * 0.5

	# Fences: runs of 6 m segments along the slope (x, d0, d1).
	for f: Vector3 in spec.get("fences", []):
		var fd: float = f.y
		while fd + 6.0 <= f.z:
			_place_prop(root, props, terrain, FENCE, Vector3(f.x, 0.0, -(fd + 3.0)), PI * 0.5, 1.0)
			fd += 6.2

	# Boulders: (d, start x, roll x, roll downhill).
	var boulder_paths: Array[Vector4] = []
	var boulder_index: int = 0
	for b: Vector4 in spec.get("boulders", []):
		var boulder: RollingBoulder = BOULDER.instantiate() as RollingBoulder
		boulder_index += 1
		boulder.name = "Boulder%d" % boulder_index
		boulder.position = Vector3(b.y, terrain.surface_height(b.y, -b.x) + 2.2, -b.x)
		boulder.roll_to = Vector3(b.z, 0.0, b.w)
		_add(root, root, boulder)
		boulder_paths.append(Vector4(b.y, b.x, b.y + b.z, b.x - b.w))

	# Scattered trees, rocks and logs, away from every line and boulder path.
	var inner: float = WIDTH * 0.5 - 4.0
	var area: float = inner * 2.0 * (length - 40.0) / 1000.0
	_scatter(root, props, terrain, TREE, int(area * float(spec.get("trees", 0.0))), inner, length, lane_paths, boulder_paths, 1.0)
	_scatter(root, props, terrain, ROCK, int(area * float(spec.get("rocks", 0.0))), inner, length, lane_paths, boulder_paths, 1.6)
	_scatter(root, props, terrain, LOG, int(spec.get("logs", 0)), inner - 10.0, length, lane_paths, boulder_paths, 1.0)

	# Tight sections (camera tucks in).
	for t: Vector2 in spec.get("tight", []):
		var zone: TightZone = TIGHT.instantiate() as TightZone
		zone.name = "TightZone"
		var mid: float = (t.x + t.y) * 0.5
		zone.size = Vector3(WIDTH, 40.0, (t.y - t.x) / cos(deg_to_rad(SLOPE)))
		zone.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-SLOPE)), Vector3(0.0, _base_at(base, mid) + 8.0, -mid))
		_add(root, root, zone)

	if spec.has("spawn"):
		var spawn: Marker3D = Marker3D.new()
		spawn.name = "Spawn"
		var sd: float = spec["spawn"]
		spawn.position = Vector3(0.0, terrain.surface_height(0.0, -sd), -sd)
		_add(root, root, spawn)
		var drop: Marker3D = Marker3D.new()
		drop.name = "DropIn"
		var dd2: float = spec["drop_in"]
		drop.position = Vector3(0.0, terrain.surface_height(0.0, -dd2), -dd2)
		_add(root, root, drop)
	if spec.has("finish"):
		var gate: Node3D = FINISH.instantiate() as Node3D
		gate.name = "FinishGate"
		var fdist: float = spec["finish"]
		gate.position = Vector3(0.0, terrain.surface_height(0.0, -fdist), -fdist)
		gate.scale = Vector3(3.6, 1.6, 1.0)
		_add(root, root, gate)

	get_root().remove_child(root)
	var scene: PackedScene = PackedScene.new()
	var err: Error = scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, "res://chunks/landscape/" + String(spec["file"]))
	print("%s: %s (%d props)" % [spec["file"], error_string(err), props.get_child_count()])
	root.free()


func _add(root: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = root


func _place_prop(root: Node, props: Node3D, terrain: TerrainPatch, scene: PackedScene, at: Vector3, yaw: float, size: float) -> void:
	var prop: Node3D = scene.instantiate() as Node3D
	var kind: String = scene.resource_path.get_file().get_basename().capitalize()
	prop.name = "%s%d" % [kind, props.get_child_count() + 1]
	prop.position = Vector3(at.x, terrain.surface_height(at.x, at.z), at.z)
	prop.rotation.y = yaw
	prop.scale = Vector3.ONE * size
	_add(root, props, prop)


func _scatter(root: Node, props: Node3D, terrain: TerrainPatch, scene: PackedScene, count: int, inner: float,
		length: float, lanes: Array[PackedVector2Array], boulders: Array[Vector4], keep_scale: float) -> void:
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < count * 40:
		tries += 1
		var x: float = _rng.randf_range(-inner, inner)
		var d: float = _rng.randf_range(25.0, length - 25.0)
		var p: Vector2 = Vector2(x, d)
		var ok: bool = true
		for path: PackedVector2Array in lanes:
			if _dist_to_path(p, path) < PROP_KEEP * keep_scale:
				ok = false
				break
		for b: Vector4 in boulders:
			if _dist_to_segment(p, Vector2(b.x, b.y), Vector2(b.z, b.w)) < 6.0:
				ok = false
		if ok:
			for child: Node in props.get_children():
				var other: Vector3 = (child as Node3D).position
				if Vector2(other.x, -other.z).distance_to(p) < 5.0:
					ok = false
					break
		if not ok:
			continue
		_place_prop(root, props, terrain, scene, Vector3(x, 0.0, -d), _rng.randf() * TAU, _rng.randf_range(0.8, 1.3))
		placed += 1


static func _dist_to_path(p: Vector2, path: PackedVector2Array) -> float:
	var best: float = INF
	for i: int in path.size() - 1:
		best = minf(best, _dist_to_segment(p, path[i], path[i + 1]))
	return best


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = 0.0 if ab.length_squared() < 0.0001 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## x of a lane at distance d: keys eased with smoothstep, plus the weave.
static func _lane_x(lane_spec: Dictionary, d: float) -> float:
	var keys: Array = lane_spec["keys"]
	var x: float = (keys[-1] as Vector2).x
	for i: int in range(1, keys.size()):
		var a: Vector2 = keys[i - 1]
		var b: Vector2 = keys[i]
		if d <= b.y:
			var f: float = clampf((d - a.y) / maxf(b.y - a.y, 0.001), 0.0, 1.0)
			x = lerpf(a.x, b.x, f * f * (3.0 - 2.0 * f))
			break
	if lane_spec.has("weave"):
		var w: Vector4 = lane_spec["weave"]
		var env: float = smoothstep(w.z, w.z + 25.0, d) * (1.0 - smoothstep(w.w - 25.0, w.w, d))
		x += env * w.x * sin(TAU * (d - w.z) / w.y)
	return x


## Height of the lane's ground above the base slope: rollers, a sunk gully,
## a raise onto a ridge (Vector4(height, from d, to d, -)).
static func _lane_lift(lane_spec: Dictionary, d: float) -> float:
	var lift: float = -float(lane_spec.get("sunk", 0.0)) * smoothstep(20.0, 60.0, d) * (1.0 - smoothstep(float(lane_spec.get("_len", 1e9)) - 60.0, float(lane_spec.get("_len", 1e9)) - 20.0, d))
	if lane_spec.has("raise"):
		var r: Vector4 = lane_spec["raise"]
		lift += r.x * smoothstep(r.y, r.z, d) * (1.0 - smoothstep(r.z + 200.0, r.z + 240.0, d))
	for start: float in lane_spec.get("rollers", []):
		if d > start and d < start + ROLLER_LENGTH:
			lift += ROLLER_HEIGHT * 0.5 * (1.0 - cos(TAU * (d - start) / ROLLER_LENGTH))
	return lift


static func _style_name(style: int) -> String:
	return ["Rail", "Jump", "Carve"][style]


static func _make_profile(points: Array) -> Curve:
	if points.is_empty():
		return null
	var curve: Curve = Curve.new()
	curve.min_value = 0.0
	curve.max_value = 2.0
	for p: Vector2 in points:
		curve.add_point(p, 0.0, 0.0, Curve.TANGENT_FREE, Curve.TANGENT_FREE)
	# Flat tangents everywhere, so each key eases in and out.
	return curve


## Slope height down the middle every metre (index = d), integrated like the patch.
static func _base_heights(length: float, profile: Curve) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array([0.0])
	var steps: int = int(ceil(length)) + 2
	for i: int in range(1, steps):
		var k: float = 1.0 if profile == null else profile.sample(clampf((i - 0.5) / length, 0.0, 1.0))
		out.append(out[-1] - tan(deg_to_rad(SLOPE * k)))
	return out


static func _base_at(base: PackedFloat32Array, d: float) -> float:
	var i: int = clampi(int(d), 0, base.size() - 2)
	return lerpf(base[i], base[i + 1], d - i)


## Marker frame at d on the built patch: forward down its slope (-Z), no bank.
static func _patch_frame(terrain: TerrainPatch, d: float) -> Transform3D:
	var a: float = clampf(d - 1.0, 0.0, terrain.length)
	var b: float = clampf(d + 1.0, 0.0, terrain.length)
	var forward: Vector3 = Vector3(0.0, terrain.base_height(0.0, -b) - terrain.base_height(0.0, -a), -(b - a)).normalized()
	var up: Vector3 = Vector3.RIGHT.cross(forward)
	return Transform3D(Basis(Vector3.RIGHT, up, -forward), Vector3(0.0, terrain.base_height(0.0, -d), -d))


## Marker frame at d: forward down the slope there (-Z), no bank.
static func _frame(base: PackedFloat32Array, d: float, length: float) -> Transform3D:
	var a: float = clampf(d - 1.0, 0.0, length)
	var b: float = clampf(d + 1.0, 0.0, length)
	var forward: Vector3 = Vector3(0.0, _base_at(base, b) - _base_at(base, a), -(b - a)).normalized()
	var right: Vector3 = Vector3.RIGHT
	var up: Vector3 = right.cross(forward)
	return Transform3D(Basis(right, up, -forward), Vector3(0.0, _base_at(base, d), -d))
