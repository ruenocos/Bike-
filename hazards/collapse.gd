class_name Collapse
extends Node3D
## The wall of destruction that chases you down the stage (hazards/collapse.tscn).
## It follows the stage centerline (StageBuilder.transform_at_distance) behind
## the rider, starting slow and speeding up over the stage. When it reaches
## the rider's progress, `caught` fires (the game ends the run). Track it has
## passed crumbles away (StageBuilder.crumble_before).
##
## Speed = start_speed + accel * time, capped at max_speed, plus a bit more of
## each per stage, all times the run's collapse_speed_scale (an upgrade
## lowers it). It also never falls more than max_gap behind you (the leash),
## so clean fast riding keeps it at bay but every bail or slow line brings it
## closer. Every number is an export: tune it on the Collapse node.
## The look (Wall, Debris pieces, Glow light) is plain nodes in the scene;
## this script only moves them.

signal caught

@export_group("Timing")
## Waits this long after the stage starts before moving.
@export_range(0.0, 20.0, 0.1, "suffix:s") var start_delay: float = 3.0
## Starts this far behind the rider's spawn point.
@export_range(0.0, 300.0, 1.0, "suffix:m") var start_gap: float = 40.0

@export_group("Speed")
## Speed when it starts moving...
@export_range(0.0, 80.0, 0.5, "suffix:m/s") var start_speed: float = 28.0
## ...gaining this much per second...
@export_range(0.0, 10.0, 0.05, "suffix:m/s²") var accel: float = 1.2
## ...up to this.
@export_range(0.0, 100.0, 0.5, "suffix:m/s") var max_speed: float = 50.0

@export_group("Leash")
## Never more than this far behind the rider...
@export_range(20.0, 1000.0, 5.0, "suffix:m") var max_gap: float = 180.0
## ...this much shorter each stage after the first...
@export_range(-100.0, 0.0, 1.0, "suffix:m") var per_stage_gap: float = -20.0
## ...but never shorter than this.
@export_range(10.0, 500.0, 5.0, "suffix:m") var min_max_gap: float = 90.0

@export_group("Per stage")
## Each stage after the first adds these to start_speed, accel and max_speed.
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var per_stage_speed: float = 2.0
@export_range(0.0, 2.0, 0.01, "suffix:m/s²") var per_stage_accel: float = 0.1
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var per_stage_max_speed: float = 2.0

@export_group("Look")
## How fast the debris pieces tumble and drift.
@export_range(0.0, 5.0, 0.05) var debris_speed: float = 1.0
## Glow light flicker around its energy in the scene.
@export_range(0.0, 5.0, 0.05) var glow_flicker: float = 1.5

## Stage distance of the wall's front (m).
var distance: float = 0.0
var speed: float = 0.0
var running: bool = false

@onready var debris: Node3D = $Debris
@onready var glow: OmniLight3D = $Glow

var _builder: StageBuilder
var _time: float = 0.0
var _stage_index: int = 0
var _speed_scale: float = 1.0
var _glow_energy: float = 1.0
## Each debris piece's spot in the scene; it bobs and drifts around it.
var _debris_home: Array[Vector3] = []


func _ready() -> void:
	_glow_energy = glow.light_energy
	for piece: Node3D in debris.get_children():
		_debris_home.append(piece.position)


## Puts the wall behind `spawn_distance` on a freshly built stage.
func reset(builder: StageBuilder, spawn_distance: float, stage_index: int, speed_scale: float) -> void:
	_builder = builder
	_stage_index = stage_index
	_speed_scale = speed_scale
	distance = spawn_distance - start_gap
	speed = 0.0
	_time = 0.0
	running = true
	_place()
	reset_physics_interpolation()


func stop() -> void:
	running = false


## Called by the game each physics tick with the rider's stage progress.
func advance(delta: float, player_progress: float) -> void:
	if not running or _builder == null:
		return
	_time += delta
	if _time > start_delay:
		var extra: float = maxf(_stage_index, 0)
		var top: float = max_speed + per_stage_max_speed * extra
		speed = minf(start_speed + per_stage_speed * extra + (accel + per_stage_accel * extra) * (_time - start_delay), top)
		speed *= _speed_scale
		distance += speed * delta
		var leash: float = maxf(max_gap + per_stage_gap * extra, min_max_gap)
		distance = maxf(distance, player_progress - leash)
	_place()
	_builder.crumble_before(distance - 20.0)
	if distance >= player_progress:
		running = false
		caught.emit()


func _place() -> void:
	if _builder == null:
		return
	var at: Transform3D = _builder.transform_at_distance(distance)
	# Stand the wall upright across the track, facing down it.
	var forward: Vector3 = -at.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	global_transform = Transform3D(Basis.looking_at(forward.normalized(), Vector3.UP), at.origin)


func _process(delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0 * debris_speed
	var pieces: Array[Node] = debris.get_children()
	for i: int in mini(pieces.size(), _debris_home.size()):
		var piece: Node3D = pieces[i] as Node3D
		var phase: float = t * (0.6 + 0.07 * i) + i * 1.7
		piece.position = _debris_home[i] + Vector3(sin(phase * 0.9) * 6.0, fmod(phase * 6.0, 30.0) - 10.0, -fmod(phase * 3.0, 6.0))
		piece.rotate_x(delta * debris_speed * (1.0 + 0.3 * i))
		piece.rotate_z(delta * debris_speed * 0.7)
	glow.light_energy = _glow_energy + (sin(t * 23.0) + 0.6 * sin(t * 7.0)) * glow_flicker
