class_name BossMortarShell
extends Node3D
## One shell of the boss's barrage: a red circle on the floor that fills up,
## the shell dropping in from above, then a blast. On the ground (or low) in
## the circle when it lands = a crash. Made by Boss; the look is in
## boss/attacks/mortar_shell.tscn.

signal hit_player

## Above the floor this high you're safe from the blast (m).
@export_range(0.5, 10.0, 0.1, "suffix:m") var safe_height: float = 3.0
## Where the shell starts above the target (m).
@export_range(5.0, 200.0, 1.0, "suffix:m") var drop_height: float = 70.0
## The blast flash (s).
@export_range(0.05, 2.0, 0.05, "suffix:s") var blast_time: float = 0.45

@onready var marker: MeshInstance3D = $Marker
@onready var fill: MeshInstance3D = $Fill
@onready var shell: MeshInstance3D = $Shell
@onready var blast: MeshInstance3D = $Blast

var player: Player
var arena: BossArena
var radius: float = 6.0
var delay: float = 1.5
var _t: float = 0.0
var _landed: bool = false


func setup(target: Vector3, blast_radius: float, land_delay: float, the_arena: BossArena, the_player: Player) -> void:
	arena = the_arena
	player = the_player
	radius = blast_radius
	delay = land_delay
	var n: Vector3 = arena.normal_at(target)
	var side: Vector3 = n.cross(Vector3.FORWARD if absf(n.z) < 0.9 else Vector3.RIGHT).normalized()
	transform = Transform3D(Basis(side, n, side.cross(n)), arena.surface_point(target) + n * 0.08)


func _ready() -> void:
	top_level = true
	marker.scale = Vector3(radius, 1.0, radius)
	fill.scale = Vector3(0.01, 1.0, 0.01)
	blast.visible = false
	shell.position = Vector3.UP * drop_height


func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed:
		var k: float = clampf(_t / maxf(delay, 0.01), 0.0, 1.0)
		fill.scale = Vector3(radius * k, 1.0, radius * k)
		shell.position = Vector3.UP * drop_height * (1.0 - k * k)
		if k >= 1.0:
			_land()
		return
	var b: float = clampf((_t - delay) / blast_time, 0.0, 1.0)
	blast.scale = Vector3.ONE * radius * (0.6 + 0.6 * b)
	blast.transparency = b
	if b >= 1.0:
		queue_free()


func _land() -> void:
	_landed = true
	marker.visible = false
	fill.visible = false
	shell.visible = false
	blast.visible = true
	if player == null or arena == null:
		return
	var flat: Vector2 = Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
	if flat.length() > radius:
		return
	var ground: Vector3 = arena.surface_point(player.global_position)
	if player.global_position.y - ground.y > safe_height:
		return
	hit_player.emit()
