class_name RiderVfx
extends Node3D
## The rider's particles (vfx/rider_vfx.tscn, child of Player):
##   DustTrail      kicked-up dirt while riding, more and longer at speed
##   CarveSpray     a sideways spray on hard carves at speed
##   GrindSparks    while grinding
##   LandingBurst   one burst per graded landing (bigger on perfect) and on crashes
##   CollapseDebris rocks flying past you when the collapse is close
##                  (the game calls set_collapse_proximity)
## The particles live in world space (local_coords off), so trails stay behind.
## Look (colours, sizes, lifetimes) is in each node's process material.

## Dust starts above this speed (m/s)...
@export_range(0.0, 60.0, 0.5, "suffix:m/s") var dust_min_speed: float = 8.0
## ...and carve spray when steering harder than this (0-1) above this speed.
@export_range(0.0, 1.0, 0.05) var spray_min_steer: float = 0.45
@export_range(0.0, 60.0, 0.5, "suffix:m/s") var spray_min_speed: float = 25.0
## Burst size per landing grade (amount ratio 0-1).
@export var burst_perfect: float = 1.0
@export var burst_good: float = 0.45
@export var burst_sketchy: float = 0.7
@export var burst_crash: float = 1.0
## Debris spawns this far behind you and flies this much faster than you.
## Rocks only fly past once the collapse is this close (0..1 of its feel range).
@export_range(0.0, 1.0, 0.01) var debris_from: float = 0.45
@export_range(0.0, 60.0, 0.5, "suffix:m") var debris_behind: float = 12.0
@export_range(0.0, 60.0, 0.5, "suffix:m/s") var debris_overtake: float = 18.0

@onready var player: Player = get_parent() as Player
var _tinted: StandardMaterial3D

@onready var dust: GPUParticles3D = $DustTrail
@onready var spray: GPUParticles3D = $CarveSpray
@onready var sparks: GPUParticles3D = $GrindSparks
@onready var burst: GPUParticles3D = $LandingBurst
@onready var debris: GPUParticles3D = $CollapseDebris

var _collapse: float = 0.0


func _ready() -> void:
	Events.landed.connect(_on_landed)
	Events.bailed.connect(func() -> void: _burst(burst_crash))


func set_collapse_proximity(proximity: float) -> void:
	_collapse = proximity


func _process(_delta: float) -> void:
	var state: StringName = player.state_machine.get_state_name()
	var grounded: bool = player.is_grounded() and (state == &"Ride" or state == &"Land" or state == &"Bail")
	var ratio: float = clampf(player.speed / player.tuning.max_speed, 0.0, 1.0)
	dust.emitting = grounded and player.speed > dust_min_speed
	dust.amount_ratio = clampf(0.25 + ratio, 0.0, 1.0)
	var steer: float = absf(player.get_steer())
	spray.emitting = grounded and steer > spray_min_steer and player.speed > spray_min_speed
	if spray.emitting:
		# Out to the side you're carving away from, and up.
		var side: Vector3 = player.ground_dir.cross(player.ground_normal).normalized() * signf(player.get_steer())
		(spray.process_material as ParticleProcessMaterial).direction = (side + Vector3.UP * 0.6).normalized()
	sparks.emitting = state == &"Grind"
	var forward: Vector3 = player.velocity.normalized() if player.velocity.length() > 1.0 else player.get_heading_dir()
	debris.emitting = _collapse > debris_from
	debris.amount_ratio = clampf((_collapse - debris_from) / maxf(1.0 - debris_from, 0.01), 0.1, 1.0)
	if debris.emitting:
		debris.global_position = player.global_position - forward * debris_behind + Vector3.UP * 4.0
		var mat: ParticleProcessMaterial = debris.process_material as ParticleProcessMaterial
		mat.direction = forward
		mat.initial_velocity_min = player.speed + debris_overtake * 0.6
		mat.initial_velocity_max = player.speed + debris_overtake


func _on_landed(grade: StringName) -> void:
	match grade:
		&"perfect":
			_burst(burst_perfect)
		&"good":
			_burst(burst_good)
		&"sketchy":
			_burst(burst_sketchy)


## Tints the dust, carve spray and landing puffs (they share one material;
## the biome sets it: blue-ish on snow so it doesn't vanish into white).
func set_tint(color: Color) -> void:
	var quad: QuadMesh = dust.draw_pass_1 as QuadMesh
	if quad == null or not quad.material is StandardMaterial3D:
		return
	if _tinted == null:
		# Our own copy, so the scene's shared material stays as it is.
		_tinted = (quad.material as StandardMaterial3D).duplicate() as StandardMaterial3D
		for particles: GPUParticles3D in [dust, spray, burst]:
			particles.material_override = _tinted
	_tinted.albedo_color = color


## A dust puff at the rider (air hop, v0.13).
func puff(size: float) -> void:
	_burst(size)


func _burst(size: float) -> void:
	burst.global_position = player.global_position
	burst.amount_ratio = size
	burst.restart()
