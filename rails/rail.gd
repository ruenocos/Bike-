@tool
class_name Rail
extends Path3D
## A grindable rail. Put it in the "rails" group (RailSnap looks there) and give
## it a CSGPolygon3D child named RailMesh in PATH mode for the bar itself.
## rails/rail.tscn has both: instance it and edit its curve in the editor.
##
## Support posts live under a "Posts" child: press "Rebuild posts" in the
## inspector after editing the curve (they're saved with the scene). A rail
## without a Posts node builds them when the game starts (the test track).
## The Player calls set_highlighted() while the rail is within snap reach,
## which brightens the bar's glow: "you can grind this now".
##
## Godot note: the material is duplicated per rail so lighting up one rail
## doesn't light up every rail that shares the material resource.
## @tool runs this script in the editor too (for the button); _ready skips
## the gameplay setup there.

@export_tool_button("Rebuild posts") var rebuild_posts_button: Callable = rebuild_posts

@export_range(1.0, 20.0, 0.5, "suffix:m") var post_spacing: float = 5.0
## How far the posts reach down from the rail. Match the rail's height above ground.
@export_range(0.1, 5.0, 0.05, "suffix:m") var post_length: float = 0.6
@export var post_color: Color = Color(0.2, 0.22, 0.26)
## Glow strength when idle and when in snap reach.
@export var glow_idle: float = 0.6
@export var glow_highlight: float = 4.0
## Time to fade the glow in or out (s).
@export var glow_fade_time: float = 0.08

@export_group("Sap rail")
## Pushes a grinding rider along the rail (m/s²), enough to climb (v0.31,
## the World Tree's branches). 0 = a plain rail.
@export_range(0.0, 60.0, 0.5, "suffix:m/s²") var boost_accel: float = 0.0
## A boosted rail never lets you drop below this speed (m/s).
@export_range(0.0, 60.0, 0.5, "suffix:m/s") var boost_min_speed: float = 0.0
## Extra speed along the rail when you fly off its end (m/s): the crown launch.
@export_range(0.0, 60.0, 0.5, "suffix:m/s") var end_launch: float = 0.0
@export_group("")

@onready var rail_mesh: CSGPolygon3D = $RailMesh

var _material: StandardMaterial3D
var _glow_tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_material = (rail_mesh.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	_material.emission_energy_multiplier = glow_idle
	_material.rim_enabled = true
	_material.rim = 1.0
	_material.rim_tint = 0.2
	rail_mesh.material = _material
	if get_node_or_null(^"Posts") == null:
		_build_posts(null)


func set_highlighted(on: bool) -> void:
	if _glow_tween:
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.tween_property(_material, "emission_energy_multiplier", glow_highlight if on else glow_idle, glow_fade_time)


## Replaces the Posts node with fresh posts along the curve. In the editor
## they're owned by the edited scene, so they get saved.
func rebuild_posts() -> void:
	var old: Node = get_node_or_null(^"Posts")
	if old != null:
		old.free()
	var scene_root: Node = owner if owner != null else self
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		scene_root = get_tree().edited_scene_root
	_build_posts(scene_root)


func _build_posts(scene_owner: Node) -> void:
	if curve == null:
		return
	var length: float = curve.get_baked_length()
	if length <= 0.0 or post_spacing <= 0.0:
		return
	var posts: Node3D = Node3D.new()
	posts.name = "Posts"
	add_child(posts)
	if scene_owner != null:
		posts.owner = scene_owner
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.08, post_length, 0.08)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = post_color
	mesh.material = material
	# Spread the posts evenly so there is always one at each end.
	var count: int = maxi(ceili(length / post_spacing), 1)
	for i: int in count + 1:
		var post: MeshInstance3D = MeshInstance3D.new()
		post.name = "Post%d" % i
		post.mesh = mesh
		post.position = curve.sample_baked(length * i / count) + Vector3.DOWN * post_length * 0.5
		posts.add_child(post)
		if scene_owner != null:
			post.owner = scene_owner
