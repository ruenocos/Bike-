class_name HazardDirector
extends Node
## Adds triggered hazards to a freshly built stage (v0.13): falling trees
## that come down across one of the open ways through a chunk. More of them
## each stage, so later stages get harder by what happens, not by length.
## Set pieces and the start / finish chunks are left alone, and nothing lands
## near a rail or a boost gate.

@export var falling_tree: PackedScene = preload("res://hazards/falling_tree.tscn")
## Falling trees per stage (stage 1 first; the last entry repeats).
@export var trees_per_stage: Array[int] = [1, 2, 3, 4, 5, 6, 6, 7]
## Hazards stay at least this far apart (m).
@export_range(20.0, 500.0, 5.0, "suffix:m") var min_spacing: float = 120.0
## ...and this far from rails and boost gates (m).
@export_range(0.0, 100.0, 1.0, "suffix:m") var keep_clear: float = 30.0
## Where the trunk's base stands, sideways from the line (m).
@export_range(2.0, 10.0, 0.1, "suffix:m") var side_offset: float = 5.0

var placed: Array[FallingTree] = []


func populate(builder: StageBuilder, stage_index: int, stage_seed: int) -> void:
	placed.clear()
	if trees_per_stage.is_empty() or falling_tree == null:
		return
	var want: int = trees_per_stage[mini(stage_index, trees_per_stage.size() - 1)]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(stage_seed + 911)
	var avoid: PackedVector3Array = _avoid_points()
	var spots: Array[Array] = []
	for i: int in range(1, builder.chunks.size() - 1):
		if builder.chunk_paths[i].get_file().begins_with("set_"):
			continue
		var lines: Node = builder.chunks[i].get_node_or_null(^"Lines")
		if lines == null:
			continue
		for child: Node in lines.get_children():
			var line: RideLine = child as RideLine
			if line == null:
				continue
			var pts: PackedVector3Array = line.get_global_points()
			for k: int in range(int(pts.size() * 0.2), int(pts.size() * 0.8), 6):
				spots.append([pts, k, builder.chunks[i]])
	var used: PackedVector3Array = PackedVector3Array()
	var tries: int = 0
	while placed.size() < want and not spots.is_empty() and tries < 400:
		tries += 1
		var spot: Array = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		var pts: PackedVector3Array = spot[0]
		var k: int = spot[1]
		var at: Vector3 = pts[k]
		if _near(at, used, min_spacing) or _near(at, avoid, keep_clear):
			continue
		var dir: Vector3 = pts[mini(k + 2, pts.size() - 1)] - pts[maxi(k - 2, 0)]
		dir.y = 0.0
		if dir.length() < 0.1:
			continue
		var across: Vector3 = Vector3.UP.cross(dir.normalized())
		var side: float = 1.0 if rng.randf() < 0.5 else -1.0
		var base: Vector3 = _ground(builder, at + across * side * side_offset)
		var tree: FallingTree = falling_tree.instantiate() as FallingTree
		# A child of its chunk, so it goes when the chunk does.
		(spot[2] as Node).add_child(tree)
		tree.global_position = base
		var toward: Vector3 = at - base
		toward.y = 0.0
		tree.look_at(base + toward.normalized(), Vector3.UP)
		tree.crossing = at
		placed.append(tree)
		used.append(at)


func _avoid_points() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for node: Node in get_tree().get_nodes_in_group(&"rails"):
		var rail: Path3D = node as Path3D
		if rail != null and rail.curve != null:
			for p: Vector3 in rail.curve.get_baked_points():
				out.append(rail.to_global(p))
	for node: Node in get_tree().get_nodes_in_group(&"boost_gates"):
		out.append((node as Node3D).global_position)
	return out


static func _near(p: Vector3, list: PackedVector3Array, distance: float) -> bool:
	var d2: float = distance * distance
	for q: Vector3 in list:
		if Vector2(p.x - q.x, p.z - q.z).length_squared() < d2:
			return true
	return false


func _ground(builder: StageBuilder, at: Vector3) -> Vector3:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 60.0, at + Vector3.DOWN * 120.0)
	var hit: Dictionary = builder.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else at
