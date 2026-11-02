class_name CrewMember
extends Node3D
## One of the tank's crew (tank/crew_member.tscn, v0.32), visual only. `model` is
## a humanoid character scene: a VRoid / VRM export renamed to .glb works (the
## bones are found by their VRoid names). Drag another one in to swap someone.
## Sits or stands by `pose`, wears the uniform colours, hair runs on Godot's
## SpringBoneSimulator3D and streams with speed, reacts to the tank: leans
## against carves, ducks on landings, throws an arm up mid-trick. With no model
## they stay hidden unless `show_stand_in` (the old primitive figure) is on.

enum Pose { HATCH, SEATED }

## The character. Faces +Z in its own file, as VRoid exports do.
@export var model: PackedScene
@export var pose: Pose = Pose.HATCH
@export_range(0.5, 2.0, 0.01) var model_scale: float = 1.0
## Hips height over this node (m), once scaled.
@export_range(-1.5, 1.5, 0.01, "suffix:m") var hips_height: float = 0.0
## Show the primitive stand-in when there's no model. Off: nobody is there.
@export var show_stand_in: bool = false

@export_group("Uniform")
## Multiplied over the character's clothes (their textures keep the detail).
@export var tops_color: Color = Color(0.2, 0.26, 0.5)
@export var bottoms_color: Color = Color(0.14, 0.18, 0.36)
@export var shoes_color: Color = Color(0.2, 0.2, 0.24)
@export var accessory_color: Color = Color(1.0, 0.5, 0.15)
@export var scarf_color: Color = Color(1.0, 0.45, 0.12, 1.0)
## The scarf ribbon: how wide, how long it lasts, how fast it streams back.
@export_range(0.01, 1.0, 0.01, "suffix:m") var scarf_width: float = 0.09
@export_range(0.05, 2.0, 0.01, "suffix:s") var scarf_time: float = 0.2
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var scarf_stream: float = 4.0

@export_group("Reactions")
## How far they lean against a carve (deg).
@export_range(0.0, 60.0, 1.0) var lean_deg: float = 18.0
## How far they duck on landing (m), and how fast they recover (s).
@export_range(0.0, 1.0, 0.01, "suffix:m") var duck: float = 0.16
@export_range(0.01, 1.0, 0.01, "suffix:s") var recover_time: float = 0.14
## Arm raised during tricks.
@export var cheers: bool = true
## Ink line thickness (px).
@export_range(0.0, 8.0, 0.25) var line_width: float = 2.0

@export_group("Hair")
## Spring settings per hair chain. Wind blows it back with speed.
@export_range(0.0, 4.0, 0.01) var hair_stiffness: float = 0.7
@export_range(0.0, 1.0, 0.01) var hair_drag: float = 0.45
@export_range(0.0, 4.0, 0.01) var hair_gravity: float = 0.4
@export_range(0.0, 10.0, 0.05) var hair_wind: float = 2.2
@export_range(0.0, 0.2, 0.005) var hair_radius: float = 0.02

@onready var _figure: Node3D = $Figure
@onready var _scarf_point: Node3D = $Figure/ScarfPoint

var _player: Player
var _root: Node3D
var _skeleton: Skeleton3D
var _springs: SpringBoneSimulator3D
var _scarf: TrailRibbon
var _lean: float = 0.0
var _duck: float = 0.0
var _cheer: float = 0.0
var _home_y: float = 0.0
var _last_state: StringName = &""
## Bone indices the reactions turn.
var _spine: int = -1
var _head: int = -1
var _arm_l: int = -1
var _arm_r: int = -1
var _fore_l: int = -1
var _fore_r: int = -1
var _neck: int = -1


func _ready() -> void:
	var parent: Node = get_parent()
	while parent != null and not parent is Player:
		parent = parent.get_parent()
	_player = parent as Player
	if model != null:
		_figure.visible = false
		_set_up_model()
	elif show_stand_in:
		CelLook.apply(_figure, true)
		CelLook.keep_outline(_figure, line_width)
		_set_layer(_figure)
		_home_y = _figure.position.y
	else:
		visible = false
		set_process(false)
		return
	if _player != null and scarf_color.a > 0.0:
		_scarf = TrailRibbon.new()
		_scarf.target = _scarf_point
		_scarf.anchor = _player
		_scarf.emitting = true
		_scarf.width = scarf_width
		_scarf.lifetime = scarf_time
		_scarf.drift = scarf_stream
		_scarf.head_color = scarf_color
		_scarf.tail_color = Color(scarf_color, 0.0)
		add_child(_scarf)


func _process(delta: float) -> void:
	var state: StringName = _player.state_machine.get_state_name() if _player != null else &""
	if state != _last_state:
		if state == &"Land":
			_duck = duck * (1.4 if _player.last_landing_grade == &"perfect" else 1.0)
		_last_state = state
	_duck = lerpf(_duck, 0.0, 1.0 - exp(-delta / recover_time))
	var steer: float = _player.get_steer() if _player != null else 0.0
	_lean = lerpf(_lean, -steer * deg_to_rad(lean_deg), 1.0 - exp(-delta / 0.1))
	var up: bool = cheers and _player != null and (_player.tricks.is_mid_trick() or _player.no_hander)
	_cheer = lerpf(_cheer, 1.0 if up else 0.0, 1.0 - exp(-delta / 0.07))
	if _player != null and _scarf != null:
		_scarf.drift_direction = -_player.get_heading_dir()
	if _skeleton == null:
		_figure.position.y = _home_y - _duck
		_figure.rotation.z = _lean
		return
	_root.position.y = _model_y() - _duck
	_pose_upper_body()
	if _springs != null and _player != null:
		_springs.external_force = -_player.get_heading_dir() * hair_wind * _player.speed_ratio
	_scarf_point.global_position = _skeleton.global_transform * _skeleton.get_bone_global_pose(_neck).origin


func _model_y() -> float:
	return hips_height - _hips_rest_y() * model_scale


func _hips_rest_y() -> float:
	var hips: int = _skeleton.find_bone("J_Bip_C_Hips")
	return _skeleton.get_bone_global_rest(hips).origin.y if hips >= 0 else 0.0


func _set_up_model() -> void:
	_root = Node3D.new()
	add_child(_root)
	var character: Node3D = model.instantiate() as Node3D
	_root.add_child(character)
	# Characters face +Z in their files; the tank's forward is -Z.
	_root.rotation.y = PI
	_root.scale = Vector3.ONE * model_scale
	CelLook.apply(character, true)
	_dress(character)
	_set_layer(character)
	CelLook.keep_outline(character, line_width)
	_skeleton = _find_skeleton(character)
	if _skeleton == null:
		return
	_root.position.y = _model_y()
	_spine = _skeleton.find_bone("J_Bip_C_Chest")
	_head = _skeleton.find_bone("J_Bip_C_Head")
	_neck = _skeleton.find_bone("J_Bip_C_Neck")
	_arm_l = _skeleton.find_bone("J_Bip_L_UpperArm")
	_arm_r = _skeleton.find_bone("J_Bip_R_UpperArm")
	_fore_l = _skeleton.find_bone("J_Bip_L_LowerArm")
	_fore_r = _skeleton.find_bone("J_Bip_R_LowerArm")
	_pose_legs()
	_pose_upper_body()
	_set_up_springs()


## Their clothes in the crew's colours, ink on skin and clothes only.
func _dress(node: Node) -> void:
	var mi: MeshInstance3D = node as MeshInstance3D
	if mi != null:
		for s: int in mi.mesh.get_surface_count():
			var source: Material = mi.mesh.surface_get_material(s)
			var mat: ShaderMaterial = mi.get_surface_override_material(s) as ShaderMaterial
			if source == null or mat == null:
				continue
			var mat_name: String = source.resource_name
			mat = mat.duplicate() as ShaderMaterial
			# Flat, clean anime shading: no halftone dots on faces and bodies.
			mat.set_shader_parameter(&"halftone_strength", 0.0)
			var tint: Color = Color.WHITE
			if mat_name.contains("Tops") or mat_name.contains("Onepice"):
				tint = tops_color
			elif mat_name.contains("Bottoms"):
				tint = bottoms_color
			elif mat_name.contains("Shoes"):
				tint = shoes_color
			elif mat_name.contains("Accessory"):
				tint = accessory_color
			if tint != Color.WHITE:
				mat.set_shader_parameter(&"color", tint)
			if mat_name.contains("_SKIN") or mat_name.contains("_CLOTH"):
				mat.next_pass = CelLook.make_outline(mat)
			else:
				mat.next_pass = null
			mi.set_surface_override_material(s, mat)
	for child: Node in node.get_children():
		_dress(child)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null


func _turn(bone: int, axis: Vector3, degrees: float) -> void:
	if bone >= 0:
		_skeleton.set_bone_pose_rotation(bone, _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion() * Quaternion(axis, deg_to_rad(degrees)))


func _pose_legs() -> void:
	if pose != Pose.SEATED:
		return
	for side: String in ["L", "R"]:
		var out: float = 8.0 if side == "L" else -8.0
		var thigh: int = _skeleton.find_bone("J_Bip_%s_UpperLeg" % side)
		_skeleton.set_bone_pose_rotation(thigh, Quaternion(Vector3.FORWARD, deg_to_rad(-out)) * Quaternion(Vector3.RIGHT, deg_to_rad(-78.0)))
		_turn(_skeleton.find_bone("J_Bip_%s_LowerLeg" % side), Vector3.RIGHT, 70.0)


func _pose_upper_body() -> void:
	# Bones are world-aligned at rest in VRoid models: the arms lie along X.
	_turn(_spine, Vector3.FORWARD, rad_to_deg(_lean))
	_turn(_head, Vector3.RIGHT, -8.0 if pose == Pose.HATCH else 6.0)
	# In the hatch the elbows stay up and the hands come in to the rim.
	var left_down: float = -58.0 if pose == Pose.HATCH else -72.0
	var right_down: float = 58.0 if pose == Pose.HATCH else 72.0
	var bend: float = 75.0 if pose == Pose.HATCH else 20.0
	_turn(_arm_l, Vector3.FORWARD, left_down)
	_turn(_arm_r, Vector3.FORWARD, lerpf(right_down, -70.0, _cheer))
	# Around Y a left arm (along +X) swings forward (+Z) with a negative angle.
	_turn(_fore_l, Vector3.UP, -bend)
	_turn(_fore_r, Vector3.UP, lerpf(bend, 5.0, _cheer))


## One spring chain per strand of hair (VRoid names them HairJoint-*). Bust
## and skirt bones are left alone.
func _set_up_springs() -> void:
	var roots: Array[int] = []
	for bone: int in _skeleton.get_bone_count():
		if not _skeleton.get_bone_name(bone).begins_with("HairJoint-"):
			continue
		var bone_parent: int = _skeleton.get_bone_parent(bone)
		if bone_parent < 0 or not _skeleton.get_bone_name(bone_parent).begins_with("HairJoint-"):
			if not _skeleton.get_bone_children(bone).is_empty():
				roots.append(bone)
	if roots.is_empty():
		return
	_springs = SpringBoneSimulator3D.new()
	_skeleton.add_child(_springs)
	_springs.setting_count = roots.size()
	for i: int in roots.size():
		var end: int = roots[i]
		while not _skeleton.get_bone_children(end).is_empty():
			end = _skeleton.get_bone_children(end)[0]
		_springs.set_root_bone(i, roots[i])
		_springs.set_end_bone(i, end)
		_springs.set_stiffness(i, hair_stiffness)
		_springs.set_drag(i, hair_drag)
		_springs.set_gravity(i, hair_gravity)
		_springs.set_radius(i, hair_radius)
		# Measured from the vehicle, so 60 m/s isn't a 60 m/s wind by itself.
		_springs.set_center_from(i, SpringBoneSimulator3D.CENTER_FROM_NODE)
		if _player != null:
			_springs.set_center_node(i, _springs.get_path_to(_player))


func _set_layer(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 2
	for child: Node in node.get_children():
		_set_layer(child)
