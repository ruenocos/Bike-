extends SceneTree
## One-off authoring helper (v0.33, Wons: "the noise the terrain makes needs
## to be intense more bump more hill"): makes the rolling ground of every
## landscape chunk taller (noise_amplitude x HILL_SCALE) and adds the short
## TerrainPatch bumps (bump_amplitude), then moves everything that sat on the
## old ground by the height change under it: props, boost gates, rolling
## boulders, the hidden ride lines. Rail beds, kicker pads and other flatten /
## line shapes keep their ground, so rails and kickers don't move. TrackLine
## stays the plain centerline.
##
## Run once; it saves the chunks, so the editor shows the result and you can
## keep tweaking Noise > noise_amplitude / bump_amplitude on each chunk's
## Terrain node.
##   <exe> --headless --path . -s res://chunks/tools/bump_chunks.gd
##   <exe> --headless --path . -s res://chunks/tools/bump_chunks.gd -- --only=land_meadow
## A chunk that already has bumps is skipped (it would stack). To retune one:
##   ... -- --only=<chunk> --noise=<m> [--bumps=<m>]   (sets those values and
## moves everything by the change, whatever it had).

const HILL_SCALE: float = 1.8
const HILL_MAX: float = 4.5
const BUMPS: float = 1.1
## Set pieces whose jumps are measured to the metre keep their ground.
const SKIP: PackedStringArray = ["land_start", "set_megapipe"]


var _set_noise: float = -1.0
var _set_bumps: float = -1.0
## --swell=<m> [--swell-length=<m>]: Haste-size dunes (TerrainPatch Swells).
var _set_swell: float = -1.0
var _set_swell_length: float = 300.0


func _initialize() -> void:
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--noise="):
			_set_noise = arg.trim_prefix("--noise=").to_float()
		elif arg.begins_with("--bumps="):
			_set_bumps = arg.trim_prefix("--bumps=").to_float()
		elif arg.begins_with("--swell="):
			_set_swell = arg.trim_prefix("--swell=").to_float()
		elif arg.begins_with("--swell-length="):
			_set_swell_length = arg.trim_prefix("--swell-length=").to_float()
	for file: String in DirAccess.get_files_at("res://chunks/landscape"):
		if not file.ends_with(".tscn"):
			continue
		var base: String = file.get_basename()
		if SKIP.has(base) or (not only.is_empty() and base != only):
			continue
		await _bump(base)
	quit()


func _bump(file: String) -> void:
	var path: String = "res://chunks/landscape/%s.tscn" % file
	var root: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	var terrain: TerrainPatch = root.get_node_or_null(^"Terrain") as TerrainPatch
	var retune: bool = _set_noise >= 0.0 or _set_bumps >= 0.0 or _set_swell >= 0.0
	if terrain == null or (terrain.bump_amplitude > 0.0 and not retune):
		print("%s: no terrain or already bumpy, skipped" % file)
		root.free()
		return
	get_root().add_child(root)
	await process_frame
	terrain.rebuild()
	# Everything to move, with the ground height under it before the change.
	var nodes: Array[Node3D] = []
	var props: Node = terrain.get_node_or_null(^"Props")
	if props != null:
		for child: Node in props.get_children():
			nodes.append(child as Node3D)
	var gates: Node = root.get_node_or_null(^"Gates")
	if gates != null:
		for child: Node in gates.get_children():
			nodes.append(child as Node3D)
	for child: Node in root.get_children():
		if child is RollingBoulder:
			nodes.append(child as Node3D)
	var before: PackedFloat32Array = PackedFloat32Array()
	for n: Node3D in nodes:
		before.append(_ground(terrain, n.global_position))
	var line_before: Dictionary = {}
	var lines: Node = root.get_node_or_null(^"Lines")
	if lines != null:
		for child: Node in lines.get_children():
			if child is Path3D and (child as Path3D).curve != null:
				var path3: Path3D = child as Path3D
				var hs: PackedFloat32Array = PackedFloat32Array()
				for i: int in path3.curve.point_count:
					hs.append(_ground(terrain, path3.to_global(path3.curve.get_point_position(i))))
				line_before[path3] = hs
	var rail_before: Dictionary = {}
	for child: Node in root.get_children():
		if child is Rail and (child as Rail).curve != null:
			var rail: Rail = child as Rail
			rail_before[rail] = _ground(terrain, rail.to_global(rail.curve.sample_baked(rail.curve.get_baked_length() * 0.5)))

	if retune:
		if _set_noise >= 0.0:
			terrain.noise_amplitude = _set_noise
		if _set_bumps >= 0.0:
			terrain.bump_amplitude = _set_bumps
		if _set_swell >= 0.0:
			if terrain.swell_amplitude <= 0.0:
				# A skew and phase of its own per chunk, from its name.
				var h: int = hash(file)
				terrain.swell_skew_deg = float(h % 31) - 15.0
				terrain.swell_phase = float((h / 31) % 100)
			terrain.swell_amplitude = _set_swell
			terrain.swell_wavelength = _set_swell_length
	else:
		terrain.noise_amplitude = minf(terrain.noise_amplitude * HILL_SCALE, HILL_MAX)
		terrain.bump_amplitude = BUMPS
	terrain.rebuild()

	var moved: int = 0
	for i: int in nodes.size():
		var dy: float = _ground(terrain, nodes[i].global_position) - before[i]
		if absf(dy) > 0.01:
			nodes[i].global_position += Vector3.UP * dy
			moved += 1
	for path3: Path3D in line_before:
		var hs2: PackedFloat32Array = line_before[path3]
		var curve: Curve3D = path3.curve.duplicate() as Curve3D
		for i: int in curve.point_count:
			var p: Vector3 = curve.get_point_position(i)
			var dy2: float = _ground(terrain, path3.to_global(p)) - hs2[i]
			curve.set_point_position(i, p + path3.global_basis.inverse() * (Vector3.UP * dy2))
		path3.curve = curve
	for rail: Rail in rail_before:
		var dy3: float = _ground(terrain, rail.to_global(rail.curve.sample_baked(rail.curve.get_baked_length() * 0.5))) - rail_before[rail]
		if absf(dy3) > 0.05:
			print("  %s: ground under %s moved %.2f m (rail left as is)" % [file, rail.name, dy3])
	root.get_parent().remove_child(root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("%s: swells %.1f m / %.0f m, hills %.1f m, bumps %.1f m, %d nodes moved, %d lines, save %s" % [file, terrain.swell_amplitude, terrain.swell_wavelength, terrain.noise_amplitude, terrain.bump_amplitude, moved, line_before.size(), error_string(err)])
	root.free()


func _ground(terrain: TerrainPatch, global_pos: Vector3) -> float:
	var local: Vector3 = terrain.to_local(global_pos)
	return terrain.height_at_local(local)
