class_name Rail
extends Path3D
## A grindable rail. Put it in the "rails" group (RailSnap looks there) and give
## it a CSGPolygon3D child named RailMesh in PATH mode for the bar itself.
##
## On _ready it adds simple support posts every `post_spacing` metres. The
## Player calls set_highlighted() while the rail is within snap reach, which
## brightens the bar's glow: "you can grind this now".
##
## Godot note: the material is duplicated per rail so lighting up one rail
## doesn't light up every rail that shares the material resource.

@export var post_spacing: float = 5.0
## How far the posts reach down from the rail (m). Match the rail's height above ground.
@export var post_length: float = 0.6
@export var post_color: Color = Color(0.2, 0.22, 0.26)
## Glow strength when idle and when in snap reach.
@export var glow_idle: float = 0.6
@export var glow_highlight: float = 4.0
## Time to fade the glow in or out (s).
@export var glow_fade_time: float = 0.08

@onready var rail_mesh: CSGPolygon3D = $RailMesh

var _material: StandardMaterial3D
var _glow_tween: Tween


func _ready() -> void:
	_material = (rail_mesh.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	_material.emission_energy_multiplier = glow_idle
	rail_mesh.material = _material
	_build_posts()


func set_highlighted(on: bool) -> void:
	if _glow_tween:
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.tween_property(_material, "emission_energy_multiplier", glow_highlight if on else glow_idle, glow_fade_time)


func _build_posts() -> void:
	var length: float = curve.get_baked_length()
	if length <= 0.0 or post_spacing <= 0.0:
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.08, post_length, 0.08)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = post_color
	mesh.material = material
	# Spread the posts evenly so there is always one at each end.
	var count: int = maxi(ceili(length / post_spacing), 1)
	for i: int in count + 1:
		var post: MeshInstance3D = MeshInstance3D.new()
		post.mesh = mesh
		post.position = curve.sample_baked(length * i / count) + Vector3.DOWN * post_length * 0.5
		add_child(post)
