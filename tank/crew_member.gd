class_name CrewMember
extends Node3D
## One of the tank's crew (tank/crew_member.tscn, v0.32), visual only. Built
## from primitives as a stand-in: set `model` to a character scene (a VRM, say)
## and the stand-in body is hidden. Reacts to the tank: leans against carves,
## ducks on landings, throws an arm up mid-trick, scarf and hair stream with
## speed.

## A character scene to show instead of the stand-in body.
@export var model: PackedScene
@export var scarf_color: Color = Color(1.0, 0.45, 0.12, 1.0)
## How far they lean against a carve (deg).
@export_range(0.0, 60.0, 1.0) var lean_deg: float = 18.0
## How far they duck on landing (m), and how fast they recover (s).
@export_range(0.0, 1.0, 0.01, "suffix:m") var duck: float = 0.22
@export_range(0.01, 1.0, 0.01, "suffix:s") var recover_time: float = 0.14
## Hair flick at top speed (deg back) and how lively it is.
@export_range(0.0, 90.0, 1.0) var hair_stream_deg: float = 42.0
## Arm raised during tricks.
@export var cheers: bool = true

@onready var _figure: Node3D = $Figure
@onready var _hair: Node3D = $Figure/Head/Hair
@onready var _arm: Node3D = $Figure/ArmR
@onready var _scarf_point: Node3D = $Figure/ScarfPoint

var _player: Player
var _lean: float = 0.0
var _duck: float = 0.0
var _hair_angle: float = 0.0
var _hair_speed: float = 0.0
var _last_state: StringName = &""
var _home_y: float = 0.0


func _ready() -> void:
	_home_y = _figure.position.y
	CelLook.apply($Figure, true)
	CelLook.keep_outline($Figure, 2.5)
	_set_layer(self)
	var parent: Node = get_parent()
	while parent != null and not parent is Player:
		parent = parent.get_parent()
	_player = parent as Player
	if model != null:
		_figure.visible = false
		add_child(model.instantiate())
	elif _player != null:
		var scarf: TrailRibbon = TrailRibbon.new()
		scarf.target = _scarf_point
		scarf.anchor = _player
		scarf.emitting = true
		scarf.width = 0.16
		scarf.lifetime = 0.35
		scarf.drift = 6.0
		scarf.head_color = scarf_color
		scarf.tail_color = Color(scarf_color, 0.0)
		add_child(scarf)
		_scarf = scarf


var _scarf: TrailRibbon


func _process(delta: float) -> void:
	if _player == null:
		return
	var state: StringName = _player.state_machine.get_state_name()
	if state != _last_state:
		if state == &"Land":
			_duck = duck * (1.4 if _player.last_landing_grade == &"perfect" else 1.0)
			_hair_speed -= 7.0
		_last_state = state
	_duck = lerpf(_duck, 0.0, 1.0 - exp(-delta / recover_time))
	_figure.position.y = _home_y - _duck
	_lean = lerpf(_lean, -_player.get_steer() * deg_to_rad(lean_deg), 1.0 - exp(-delta / 0.1))
	_figure.rotation.z = _lean
	_figure.rotation.x = -deg_to_rad(16.0) * _player.speed_ratio
	# A small damped spring, so the hair overshoots and settles.
	var target: float = deg_to_rad(hair_stream_deg) * _player.speed_ratio
	_hair_speed += ((target - _hair_angle) * 90.0 - _hair_speed * 9.0) * delta
	_hair_angle += _hair_speed * delta
	_hair.rotation.x = _hair_angle
	var up: bool = cheers and (_player.tricks.is_mid_trick() or _player.no_hander)
	_arm.rotation.x = lerp_angle(_arm.rotation.x, deg_to_rad(165.0) if up else deg_to_rad(20.0), 1.0 - exp(-delta / 0.07))
	if _scarf != null:
		_scarf.drift_direction = -_player.get_heading_dir()


func _set_layer(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 2
	for child: Node in node.get_children():
		_set_layer(child)
