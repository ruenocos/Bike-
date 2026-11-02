class_name BossShockwave
extends MeshInstance3D
## A glowing wall-ring that runs out along the arena floor from where the
## boss slammed down. It hugs the bowl (every point sits on the floor under
## it). Touching it on the ground is a crash: hop over it. Made by Boss.

signal hit_player

## Height of the band (m) over the floor; you're hit while your body's
## centre (0.35 m up when riding) is under it. A half-charged hop clears it.
@export_range(0.2, 5.0, 0.05, "suffix:m") var height: float = 1.0
## Half the band's thickness for the hit check (m).
@export_range(0.1, 5.0, 0.05, "suffix:m") var half_width: float = 1.2
@export var color: Color = Color(1.0, 0.45, 0.15, 1.0)
## Points around the ring.
@export_range(16, 256, 1) var segments: int = 96

var arena: BossArena
var player: Player
var speed: float = 24.0
var radius: float = 2.0
var max_radius: float = 140.0
var _center: Vector3 = Vector3.ZERO
var _done_hit: bool = false
var _imesh: ImmediateMesh
var _mat: StandardMaterial3D


func setup(at: Vector3, ring_speed: float, the_arena: BossArena, the_player: Player) -> void:
	_center = at
	speed = ring_speed
	arena = the_arena
	player = the_player
	max_radius = arena.edge_radius() * 2.0 + 10.0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = color
	_mat.vertex_color_use_as_albedo = true
	material_override = _mat


func _physics_process(delta: float) -> void:
	radius += speed * delta
	if radius > max_radius:
		queue_free()
		return
	_check_player(delta)


func _process(_delta: float) -> void:
	_draw()


func _check_player(delta: float) -> void:
	if _done_hit or player == null or arena == null:
		return
	var flat: Vector2 = Vector2(player.global_position.x - _center.x, player.global_position.z - _center.z)
	var d: float = flat.length()
	# The band moves speed * delta per tick: widen the check by that much so
	# a fast ring can't step over you.
	if absf(d - radius) > half_width + speed * delta:
		return
	var ground: Vector3 = arena.surface_point(player.global_position)
	if player.global_position.y - ground.y > height:
		return
	_done_hit = true
	hit_player.emit()


func _draw() -> void:
	if arena == null:
		return
	_imesh.clear_surfaces()
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var fade: float = clampf(1.0 - radius / max_radius, 0.0, 1.0)
	for s: int in segments + 1:
		var a: float = TAU * float(s) / segments
		var p: Vector3 = _center + Vector3(sin(a), 0.0, cos(a)) * radius
		var g: Vector3 = arena.surface_point(p)
		if arena.is_off_edge(p):
			g.y = arena.global_position.y + arena.rim_height
		_imesh.surface_set_color(Color(color.r, color.g, color.b, 0.9 * fade))
		_imesh.surface_add_vertex(g + Vector3.UP * 0.05)
		_imesh.surface_set_color(Color(1.0, 0.95, 0.7, 0.25 * fade))
		_imesh.surface_add_vertex(g + Vector3.UP * height)
	_imesh.surface_end()
