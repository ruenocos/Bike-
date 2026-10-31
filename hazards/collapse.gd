class_name Collapse
extends Node3D
## The wall of destruction that chases you down the stage (hazards/collapse.tscn).
## It follows the stage centerline (StageBuilder.transform_at_distance) behind
## the rider, starting slow and speeding up over the stage. When it reaches
## the rider's progress, `caught` fires (the game ends the run). Track it has
## passed crumbles away (StageBuilder.crumble_before).
##
## Speed = start speed + accel * time, capped at max speed, times the run's
## collapse_speed_scale (an upgrade lowers it). It also never falls more than
## the leash behind you, so clean fast riding keeps it at bay but every bail
## or slow line brings it closer. All four come from the "Difficulty curve"
## arrays on the Collapse node: one entry per stage.
## The look (Wall, Debris pieces, Glow light) is plain nodes in the scene;
## this script only moves them.
## v0.8: it waits on the start pad until the sprint start is judged
## (release()), crashes and respawns push it forward (add_time_penalty), and
## it's mostly felt rather than seen: proximity() drives camera shake and pad
## rumble (the "Feel" group), plus the HUD meter.

signal caught

@export_group("Timing")
## Waits this long after the stage starts before moving.
@export_range(0.0, 20.0, 0.1, "suffix:s") var start_delay: float = 3.0
## Starts this far behind the rider's spawn point.
@export_range(0.0, 300.0, 1.0, "suffix:m") var start_gap: float = 40.0

@export_group("Difficulty curve")
## One entry per stage: stage 1 first, stages past the end use the last entry.
## Speed when it starts moving (m/s)...
@export var start_speed_by_stage: Array[float] = [24.0, 28.0, 30.0, 32.0, 34.0, 36.0, 37.0, 38.0]
## ...gaining this much per second (m/s²)...
@export var accel_by_stage: Array[float] = [0.8, 1.1, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8]
## ...up to this (m/s). Clean riding on the 23 deg slope cruises at ~50-55.
@export var max_speed_by_stage: Array[float] = [44.0, 48.0, 51.0, 53.0, 55.0, 56.0, 57.0, 58.0]
## The leash: never more than this far behind the rider (m). Stage 1 is
## loose, so only real mistakes (several bails, falling off, stalling) let
## it catch up; later stages keep it close.
@export var leash_by_stage: Array[float] = [260.0, 220.0, 180.0, 150.0, 130.0, 110.0, 100.0, 90.0]

@export_group("Penalties")
## A time penalty (crash, out-of-bounds respawn) moves the collapse forward
## by seconds x its speed (at least this speed, m/s)...
@export_range(0.0, 80.0, 1.0, "suffix:m/s") var penalty_min_speed: float = 30.0
## ...but a penalty alone never brings it closer than this (m).
@export_range(0.0, 100.0, 1.0, "suffix:m") var penalty_min_gap: float = 20.0

@export_group("Feel")
## It's felt from this far away (m): shake and rumble grow as it closes in.
@export_range(10.0, 1000.0, 5.0, "suffix:m") var feel_distance: float = 200.0
## Camera shake at point blank (m).
@export_range(0.0, 2.0, 0.01) var shake_max: float = 0.3
## Pad rumble at point blank (0-1, weak and strong motors).
@export_range(0.0, 1.0, 0.05) var rumble_weak_max: float = 0.5
@export_range(0.0, 1.0, 0.05) var rumble_strong_max: float = 0.8
## Proximity curve: 1 = linear, >1 = mostly felt when it's really close.
@export_range(0.5, 4.0, 0.1) var feel_curve: float = 1.6

@export_group("Look")
## How fast the debris pieces tumble and drift.
@export_range(0.0, 5.0, 0.05) var debris_speed: float = 1.0
## Glow light flicker around its energy in the scene.
@export_range(0.0, 5.0, 0.05) var glow_flicker: float = 1.5

## Stage distance of the wall's front (m).
var distance: float = 0.0
var speed: float = 0.0
var running: bool = false
## True after reset() until release(): it sits behind the start pad.
var waiting: bool = false

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
	waiting = true
	_place()
	reset_physics_interpolation()


func stop() -> void:
	running = false


## Starts the chase (the sprint start was judged).
func release() -> void:
	waiting = false


## A crash or respawn: the collapse gains `seconds` of its speed (never
## closer than penalty_min_gap because of a penalty alone).
func add_time_penalty(seconds: float, player_progress: float) -> void:
	if not running:
		return
	var gain: float = seconds * maxf(speed, penalty_min_speed)
	distance = maxf(distance, minf(distance + gain, player_progress - penalty_min_gap))


## 0 (far or not running) .. 1 (right behind you), for shake / rumble / HUD.
func proximity(player_progress: float) -> float:
	if not running or waiting:
		return 0.0
	var gap: float = player_progress - distance
	return pow(clampf(1.0 - gap / feel_distance, 0.0, 1.0), feel_curve)


## Called by the game each physics tick with the rider's stage progress.
func advance(delta: float, player_progress: float) -> void:
	if not running or _builder == null:
		return
	if waiting:
		_place()
		return
	_time += delta
	if _time > start_delay:
		var start: float = _for_stage(start_speed_by_stage)
		speed = minf(start + _for_stage(accel_by_stage) * (_time - start_delay), _for_stage(max_speed_by_stage))
		speed *= _speed_scale
		distance += speed * delta
		distance = maxf(distance, player_progress - _for_stage(leash_by_stage))
	_place()
	_builder.crumble_before(distance - 20.0)
	if distance >= player_progress:
		running = false
		caught.emit()


## This stage's entry of a difficulty-curve array (the last one past its end).
func _for_stage(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(_stage_index, 0, values.size() - 1)]


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
