extends SceneTree
## Headless survey for chunks/tools/declutter.py: prints every prop under
## Terrain/Props of each landscape chunk with its valley position
## (x across from the spine, half play width, wall width there).
## Run: <exe> --headless --path . --script res://debug/prop_survey.gd

func _initialize() -> void:
	var out: Dictionary = {}
	var dir: DirAccess = DirAccess.open("res://chunks/landscape")
	for file: String in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var scene: PackedScene = load("res://chunks/landscape/" + file) as PackedScene
		var chunk: Node3D = scene.instantiate() as Node3D
		root.add_child(chunk)
		var terrain: TerrainPatch = chunk.get_node_or_null(^"Terrain") as TerrainPatch
		var rows: Array = []
		if terrain != null:
			var props: Node = terrain.get_node_or_null(^"Props")
			if props != null:
				for prop: Node in props.get_children():
					var p3: Node3D = prop as Node3D
					if p3 == null:
						continue
					var v: Vector3 = terrain.local_to_valley(p3.position)
					rows.append({
						"name": String(prop.name),
						"scene": prop.scene_file_path.get_file(),
						"x": v.x, "d": v.z,
						"half": terrain.half_play_at(v.z),
						"wall": terrain.wall_width_at(v.z),
						"scale": p3.scale.y,
					})
		out[file] = rows
		chunk.free()
	var f: FileAccess = FileAccess.open(OS.get_environment("SURVEY_OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	quit(0)
