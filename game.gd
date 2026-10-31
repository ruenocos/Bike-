extends Node3D
## The run: stage -> summary -> pick 1 of 3 upgrades -> next stage, until the
## collapse catches you. Each stage is a new seed, leans toward harder chunks
## and has a faster collapse (same length every stage). Upgrades change the run's own copy of the tuning, so
## player_tuning.tres is never touched. (debug/test_track.tscn stays the
## sandbox for feel work.)
##
## User args (after a bare `--`): --seed=<n> fixes the run seed,
## --autopilot rides by itself (debug/autopilot.gd, for recordings).

@export var base_tuning: PlayerTuning = preload("res://player/player_tuning.tres")
@export var upgrade_pool: Array[UpgradeData] = []
## Middle chunks per stage. The same every stage: later stages get harder
## through harder chunks (StageBuilder.tier_bias) and a faster collapse,
## never through more length.
@export_range(1, 20) var middle_chunks: int = 4
## Falling this far below the track respawns you on it.
@export_range(5.0, 200.0, 1.0, "suffix:m") var fall_margin: float = 40.0
## Respawning after a fall puts you this far back up the track...
@export_range(0.0, 100.0, 1.0, "suffix:m") var fall_respawn_back: float = 10.0
## ...at this fraction of your speed (never below base_speed).
@export_range(0.0, 1.0, 0.05) var fall_respawn_speed: float = 0.5

@onready var builder: StageBuilder = $StageBuilder
@onready var collapse: Collapse = $Collapse
@onready var player: Player = $Player
@onready var hud: RunHud = $RunHud
@onready var stats: StageStats = $StageStats
@onready var summary: StageSummary = $Menus/StageSummary
@onready var picker: UpgradePicker = $Menus/UpgradePicker
@onready var run_over: RunOver = $Menus/RunOver
@onready var far_ground: Node3D = $FarGround

var run_seed: int = 0
## 0 = first stage.
var stage_index: int = 0
var run_tuning: PlayerTuning
var upgrades_taken: Array[UpgradeData] = []
## How far down the stage the rider is (m).
var player_progress: float = 0.0
var in_stage: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	player.auto_respawn = false
	player.fell.connect(_on_player_fell)
	builder.finished.connect(_on_finished)
	collapse.caught.connect(_on_caught)
	summary.continued.connect(_on_summary_continued)
	picker.picked.connect(_on_upgrade_picked)
	run_over.restart.connect(start_run)
	var seed_arg: int = -1
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--seed="):
			seed_arg = arg.trim_prefix("--seed=").to_int()
	if args.has("--autopilot"):
		add_child(preload("res://debug/autopilot.gd").new())
	start_run(seed_arg)


## New run: fresh tuning copy, no upgrades, stage 1. `new_seed` < 0 = random.
func start_run(new_seed: int = -1) -> void:
	run_seed = new_seed if new_seed >= 0 else randi()
	_rng.seed = run_seed
	stage_index = 0
	# Godot note: duplicate() copies the Resource, so changing the copy
	# leaves the .tres (and the test track) alone.
	run_tuning = base_tuning.duplicate() as PlayerTuning
	player.tuning = run_tuning
	upgrades_taken.clear()
	player.combo.drop()
	player.combo.run_total = 0
	start_stage()


func start_stage() -> void:
	_freeze_player()
	builder.build(_rng.randi(), middle_chunks, stage_index)
	# CSG builds its collision a frame or two after entering the tree.
	for i: int in 3:
		await get_tree().physics_frame
	var spawn: Transform3D = builder.get_spawn_transform()
	var forward: Vector3 = -spawn.basis.z
	player.set_physics_process(true)
	player.place(spawn.origin + Vector3.UP * 0.05, atan2(-forward.x, -forward.z), run_tuning.base_speed)
	player.state_machine.transition_to(&"Air", {})
	player_progress = builder.progress_at(player.global_position, true)
	collapse.reset(builder, player_progress, stage_index, run_tuning.collapse_speed_scale)
	stats.start()
	in_stage = true


func _physics_process(delta: float) -> void:
	if not in_stage:
		return
	player_progress = builder.progress_at(player.global_position)
	var track_y: float = builder.transform_at_distance(player_progress).origin.y
	player.kill_y = track_y - fall_margin
	collapse.advance(delta, player_progress)
	builder.free_behind(player_progress)
	far_ground.global_position = Vector3(player.global_position.x, track_y - 60.0, player.global_position.z)


func _process(_delta: float) -> void:
	hud.update_run(stage_index + 1, stats.time, player.combo.run_total, player_progress - collapse.distance,
			player_progress, collapse.distance, builder.length, builder.finish_distance,
			player.catchable_rail != null)


func _on_finished() -> void:
	if not in_stage:
		return
	in_stage = false
	player.combo.bank()
	stats.stop()
	collapse.stop()
	_freeze_player()
	summary.open(stage_index + 1, stats.time, stats.best_combo, stats.score, player.combo.run_total)


func _on_summary_continued() -> void:
	picker.open(_pick_choices(3))


## `count` different upgrades from the pool, picked with the run's RNG.
func _pick_choices(count: int) -> Array[UpgradeData]:
	var pool: Array[UpgradeData] = upgrade_pool.duplicate()
	var choices: Array[UpgradeData] = []
	while choices.size() < count and not pool.is_empty():
		choices.append(pool.pop_at(_rng.randi_range(0, pool.size() - 1)))
	return choices


func _on_upgrade_picked(upgrade: UpgradeData) -> void:
	upgrade.apply(run_tuning)
	upgrades_taken.append(upgrade)
	stage_index += 1
	# A beat before the stage starts, so the A press that picked doesn't hop.
	await get_tree().create_timer(0.2).timeout
	start_stage()


func _on_caught() -> void:
	if not in_stage:
		return
	in_stage = false
	stats.stop()
	player.combo.drop()
	_freeze_player()
	run_over.open(stage_index + 1, player.combo.run_total, upgrades_taken.size())


## Fell off the track (or pressed reset): back on the centerline a little up
## the hill, combo lost.
func _on_player_fell() -> void:
	if not in_stage:
		return
	var at: Transform3D = builder.transform_at_distance(maxf(player_progress - fall_respawn_back, 0.0))
	var forward: Vector3 = -at.basis.z
	var new_speed: float = maxf(player.speed * fall_respawn_speed, run_tuning.base_speed)
	player.combo.drop()
	player.place(at.origin + at.basis.y * 0.3, atan2(-forward.x, -forward.z), new_speed)
	player.state_machine.transition_to(&"Air", {})
	player_progress = builder.progress_at(player.global_position, true)


## Stops the rider where it is while a menu is up. (Only its physics tick:
## disabling the whole node takes the body out of the physics world, and it
## came back a frame late at the next stage's start and dropped through.)
func _freeze_player() -> void:
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.speed = 0.0
	for action: StringName in [&"hop", &"pedal", &"brake", &"grind", &"steer_left", &"steer_right"]:
		Input.action_release(action)
