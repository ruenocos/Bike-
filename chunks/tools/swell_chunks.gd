extends SceneTree
## One-off authoring helper (v0.31 "drastic landscape"): gives the open
## valley chunks big rolling swells (TerrainPatch "Swells" group) and moves
## everything that sat on the old ground with them: props, boost gates, the
## hidden ride lines. The TrackLine stays the plain
## centerline. Kicker pads and rail beds
## keep their ground (the swells calm down around them).
##
## Run once; it saves the chunks, so the editor shows the result and you can
## keep tweaking the Swells values on each chunk's Terrain node.
##   <exe> --headless --path . -s res://chunks/tools/swell_chunks.gd
##   <exe> --headless --path . -s res://chunks/tools/swell_chunks.gd -- --only=land_meadow
## Re-running on a chunk that already has swells skips it (it would stack).

## file: [amplitude m, wavelength m, skew deg, phase m, (calm margin m)]
## Long waves (160-220 m): at 55 m/s a crest lifts you into a floaty air
## that lands on the next downslope; short ones threw you into the next face.
const SWELLS: Dictionary = {
	"land_meadow": [6.0, 190.0, 18.0, 0.0],
	"land_ridge": [6.5, 210.0, -22.0, 40.0],
	"land_forest": [4.5, 170.0, 12.0, 15.0],
	"land_boulders": [5.5, 180.0, -15.0, 70.0],
	"land_gorge": [5.0, 170.0, 20.0, 30.0],
	"land_slalom": [4.0, 160.0, -10.0, 55.0],
	"land_fast_s": [7.0, 220.0, 20.0, 10.0],
	"land_switchback_left": [5.0, 190.0, -12.0, 25.0, 60.0],
	"land_switchback_right": [5.0, 190.0, 12.0, 85.0, 60.0],
	"set_log_rhythm": [4.0, 170.0, 0.0, 20.0],
	"set_ice_chute": [5.5, 200.0, 15.0, 0.0],
}


func _initialize() -> void:
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	for file: String in SWELLS:
		if not only.is_empty() and file != only:
			continue
		await _swell(file, SWELLS[file])
	quit()


func _swell(file: String, values: Array) -> void:
	var path: String = "res://chunks/landscape/%s.tscn" % file
	var scene: PackedScene = load(path) as PackedScene
	var root: Node3D = scene.instantiate() as Node3D
	var terrain: TerrainPatch = root.get_node(^"Terrain") as TerrainPatch
	if terrain.swell_amplitude > 0.0:
		print("%s: already has swells, skipped" % file)
		root.free()
		return
	get_root().add_child(root)
	await process_frame
	terrain.swell_amplitude = values[0]
	terrain.swell_wavelength = values[1]
	terrain.swell_skew_deg = values[2]
	terrain.swell_phase = values[3]
	if values.size() > 4:
		terrain.swell_calm_margin = values[4]
	terrain.rebuild()
	var moved: int = 0
	var props: Node = terrain.get_node_or_null(^"Props")
	if props != null:
		for child: Node in props.get_children():
			moved += _lift(terrain, child as Node3D)
	var gates: Node = root.get_node_or_null(^"Gates")
	if gates != null:
		for child: Node in gates.get_children():
			moved += _lift(terrain, child as Node3D)
	var lines: Node = root.get_node_or_null(^"Lines")
	if lines != null:
		for child: Node in lines.get_children():
			if child is Path3D:
				_lift_curve(terrain, child as Path3D)
	# TrackLine stays: it's the stage's plain centerline (progress, collapse,
	# fall height), always descending; the swells ride on top of it.
	root.get_parent().remove_child(root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("%s: swells %.1f m / %.0f m, %d nodes lifted, save %s" % [file, values[0], values[1], moved, error_string(err)])
	root.free()


## Moves a node up / down by the swell under it. 1 if it moved.
func _lift(terrain: TerrainPatch, node: Node3D) -> int:
	if node == null:
		return 0
	var at: Vector3 = terrain.to_local(node.global_position)
	var dy: float = terrain.swell_offset_local(at)
	if absf(dy) < 0.01:
		return 0
	node.global_position += Vector3.UP * dy
	return 1


## Moves every point of a curve by the swell under it.
func _lift_curve(terrain: TerrainPatch, path: Path3D) -> void:
	var curve: Curve3D = path.curve
	if curve == null:
		return
	curve = curve.duplicate() as Curve3D
	for i: int in curve.point_count:
		var p: Vector3 = curve.get_point_position(i)
		var at: Vector3 = terrain.to_local(path.to_global(p))
		curve.set_point_position(i, p + path.global_basis.inverse() * (Vector3.UP * terrain.swell_offset_local(at)))
	path.curve = curve
