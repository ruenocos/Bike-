@tool
class_name TankRig
extends Node3D
## The tank's look (tank/tank_rig.tscn, under Player/Visual, in place of the
## rider). Blocked out of primitives in the scene: move and resize them there.
## Visual only: the Player's physics body never changes. Reads the player's
## state: treads scroll with speed and run differentially in carves, the turret
## swings to the rear and the barrel dips while a cannon hop charges, the turret
## spins during a Turret Spin, the body squashes on landing and stretches on a
## boost. TankCannon calls fire() for the muzzle flash and recoil.

@export_group("Look")
## Ink line thickness (px).
@export_range(0.0, 8.0, 0.25) var line_width: float = 3.5
@export var rim_color: Color = Color(1.0, 0.95, 0.8, 0.7)
@export var highlight_color: Color = Color(0.9, 0.9, 0.9, 0.5)
@export_group("Feel")
## Extra tread speed on the outer side per unit of steering (m/s).
@export_range(0.0, 40.0, 0.5, "suffix:m/s") var carve_tread_speed: float = 14.0
## Turret Spin rate (deg/s).
@export_range(90.0, 2000.0, 10.0) var spin_rate: float = 720.0
## How fast the turret swings to where it's going (s).
@export_range(0.01, 1.0, 0.01, "suffix:s") var turret_turn_time: float = 0.07
## Barrel angle while a hop charges (deg, negative = down).
@export_range(-60.0, 0.0, 1.0) var hop_barrel_pitch: float = -32.0
## Barrel kick back when it fires (m) and how long the turret stays at the rear.
@export_range(0.0, 1.5, 0.01, "suffix:m") var recoil: float = 0.5
@export_range(0.0, 1.0, 0.01, "suffix:s") var fire_hold_time: float = 0.22
## Body squash on landing (more on a perfect), stretch during a boost.
@export_range(0.0, 0.4, 0.01) var body_squash: float = 0.14
@export_range(0.0, 0.3, 0.01) var boost_stretch: float = 0.1
## Muzzle flash length on screen, in rendered frames, and size.
@export_range(1, 12) var flash_frames: int = 3
@export_range(0.1, 5.0, 0.05) var flash_size: float = 1.5

@onready var _body: Node3D = $Body
@onready var _turret: Node3D = $Body/Turret
@onready var _barrel: Node3D = $Body/Turret/Barrel
@onready var _muzzle: Node3D = $Body/Turret/Barrel/Muzzle
@onready var _tread_l: TankTread = $Body/TreadL
@onready var _tread_r: TankTread = $Body/TreadR
@onready var _stripe: MeshInstance3D = $Body/Turret/Stripe

var _player: Player
var _yaw: float = 0.0
var _pitch: float = 0.0
var _kick: float = 0.0
var _squash: float = 0.0
var _hold: float = 0.0
var _flash: Node3D
var _flash_left: int = 0
var _last_state: StringName = &""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	CelLook.apply(self, true)
	_own_materials(self)
	_set_up_flash()
	_finish(self)
	var parent: Node = get_parent()
	while parent != null and not parent is Player:
		parent = parent.get_parent()
	_player = parent as Player


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _player == null:
		return
	_drive_treads(delta)
	_drive_turret(delta)
	_drive_body(delta)
	if _flash_left > 0:
		_flash_left -= 1
		_flash.visible = _flash_left > 0


## Where the trick trails come from.
func trail_points() -> Array[Node3D]:
	return [$Body/TreadL/TrailPoint as Node3D, $Body/TreadR/TrailPoint as Node3D]


## Paints the turret stripe (the vehicle's colour on the title screen).
func set_frame_color(color: Color) -> void:
	var mat: ShaderMaterial = _stripe.get_surface_override_material(0) as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"color", color)
		if mat.next_pass is ShaderMaterial:
			(mat.next_pass as ShaderMaterial).set_shader_parameter(&"color", color)


## The cannon fires: flash, barrel kick, the turret holds at the rear a moment
## (a blast backward pushes you forward).
func fire() -> void:
	_kick = recoil
	_hold = fire_hold_time
	_flash_left = flash_frames + 1
	_flash.visible = true
	_flash.scale = Vector3.ONE * flash_size


func _drive_treads(delta: float) -> void:
	var grounded: bool = _player.is_grounded()
	var along: float = _player.speed if grounded else _player.speed * 0.5
	var turn: float = _player.get_steer() * carve_tread_speed if grounded else 0.0
	_tread_l.advance((along + turn) * delta)
	_tread_r.advance((along - turn) * delta)


func _drive_turret(delta: float) -> void:
	_hold = maxf(_hold - delta, 0.0)
	var charging: bool = _player.hop_charge > 0.0
	var ease_rate: float = 1.0 - exp(-delta / turret_turn_time)
	if _player.no_hander:
		_yaw = wrapf(_yaw + deg_to_rad(spin_rate) * delta, -PI, PI)
	else:
		var to_rear: bool = charging or _hold > 0.0
		_yaw = lerp_angle(_yaw, PI if to_rear else 0.0, ease_rate)
	_turret.rotation.y = _yaw
	_pitch = lerpf(_pitch, deg_to_rad(hop_barrel_pitch) if charging or _hold > 0.0 else 0.0, ease_rate)
	_barrel.rotation.x = _pitch
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-delta / 0.1))
	_barrel.position.z = _barrel_home_z() + _kick


func _barrel_home_z() -> float:
	return -0.82


func _drive_body(delta: float) -> void:
	var state: StringName = _player.state_machine.get_state_name()
	if state != _last_state:
		if state == &"Land":
			_squash = body_squash * (1.4 if _player.last_landing_grade == &"perfect" else 1.0)
		_last_state = state
	_squash = lerpf(_squash, 0.0, 1.0 - exp(-delta / 0.1))
	var stretch: float = 0.0
	if _player.boost_timer > 0.0:
		stretch = boost_stretch * _player.boost_timer / maxf(_player.tuning.speed_lines_boost_time, 0.01)
	_body.scale = Vector3((1.0 + _squash * 0.5) * (1.0 - stretch * 0.5), (1.0 - _squash) * (1.0 - stretch * 0.5), (1.0 + _squash * 0.5) * (1.0 + stretch))


## The tank's own material copies (CelLook's are shared with props) with a
## brighter rim and a sharp highlight.
func _own_materials(node: Node) -> void:
	var mi: MeshInstance3D = node as MeshInstance3D
	if mi != null:
		for s: int in mi.mesh.get_surface_count():
			var mat: ShaderMaterial = mi.get_surface_override_material(s) as ShaderMaterial
			if mat != null:
				mat = mat.duplicate() as ShaderMaterial
				mat.set_shader_parameter(&"fresnel", rim_color)
				mat.set_shader_parameter(&"specular", highlight_color)
				mi.set_surface_override_material(s, mat)
	for child: Node in node.get_children():
		_own_materials(child)


func _finish(node: Node) -> void:
	# Layer 2: props' contact-shadow decals (cull mask 1) don't paint on it.
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 2
	CelLook.keep_outline(self, line_width)


## A bright star at the muzzle, built here so CelLook leaves it unlit.
func _set_up_flash() -> void:
	_flash = Node3D.new()
	_muzzle.add_child(_flash)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.86, 0.35)
	for stretch: Vector3 in [Vector3(0.28, 0.28, 1.5), Vector3(0.95, 0.16, 0.3), Vector3(0.16, 0.95, 0.3)]:
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 8
		mesh.rings = 4
		mesh.material = mat
		var part: MeshInstance3D = MeshInstance3D.new()
		part.mesh = mesh
		part.scale = stretch
		part.position = Vector3(0.0, 0.0, -stretch.z * 0.4)
		part.layers = 2
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flash.add_child(part)
	_flash.visible = false
