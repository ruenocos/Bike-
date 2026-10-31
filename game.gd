extends Node3D
## The run: stage -> summary -> pick 1 of 3 upgrades -> next stage, until the
## collapse catches you. Each stage is a new seed, leans toward harder chunks
## and has a faster collapse (same length every stage). Upgrades change the run's own copy of the tuning, so
## player_tuning.tres is never touched. (debug/test_track.tscn stays the
## sandbox for feel work.)
##
## v0.8 open landscape: each stage starts with a sprint start on the start
## pad (StartSprint), crashes and respawns only cost time (the collapse
## gains ground), riding over the valley's crests is out of bounds and
## respawns you on the nearest ride line after `oob_time`. The run ends only
## when the collapse catches you.
##
## User args (after a bare `--`): --seed=<n> fixes the run seed,
## --autopilot rides by itself (debug/autopilot.gd, for recordings).

@export var base_tuning: PlayerTuning = preload("res://player/player_tuning.tres")
## What boost gates and score earn between stages (upgrade rerolls).
@export var rules: RunRules = preload("res://scoring/run_rules.tres")
@export var upgrade_pool: Array[UpgradeData] = []
## Middle chunks per stage. The same every stage: later stages get harder
## through harder chunks (StageBuilder.tier_bias) and a faster collapse,
## never through more length.
@export_range(1, 20) var middle_chunks: int = 8
## Falling this far below the track respawns you on it.
@export_range(5.0, 200.0, 1.0, "suffix:m") var fall_margin: float = 40.0
## Respawning puts you this far back up the nearest ride line...
@export_range(0.0, 100.0, 1.0, "suffix:m") var fall_respawn_back: float = 10.0
## ...at this fraction of your speed (never below respawn_min_speed).
@export_range(0.0, 1.0, 0.05) var fall_respawn_speed: float = 0.6
@export_range(0.0, 60.0, 1.0, "suffix:m/s") var respawn_min_speed: float = 25.0

@export_group("Out of bounds and penalties")
## Seconds past the valley crests before you're put back on a line.
@export_range(0.5, 10.0, 0.1, "suffix:s") var oob_time: float = 3.0
## Time cost of an out-of-bounds or fall respawn (s): added to the stage
## clock, and the collapse gains this many seconds of its speed.
@export_range(0.0, 20.0, 0.1, "suffix:s") var respawn_time_cost: float = 3.0
## Time cost of a crash / bail (s). Crashes never end the run by themselves.
@export_range(0.0, 20.0, 0.1, "suffix:s") var bail_time_cost: float = 1.5

@onready var builder: StageBuilder = $StageBuilder
@onready var collapse: Collapse = $Collapse
@onready var player: Player = $Player
@onready var hud: RunHud = $RunHud
@onready var stats: StageStats = $StageStats
@onready var summary: StageSummary = $Menus/StageSummary
@onready var picker: UpgradePicker = $Menus/UpgradePicker
@onready var run_over: RunOver = $Menus/RunOver
@onready var far_ground: Node3D = $FarGround
@onready var start_sprint: StartSprint = $StartSprint

var run_seed: int = 0
## 0 = first stage.
var stage_index: int = 0
var run_tuning: PlayerTuning
var upgrades_taken: Array[UpgradeData] = []
## How far down the stage the rider is (m).
var player_progress: float = 0.0
var in_stage: bool = false
## Time spent past the crests (s); 0 when in bounds.
var oob_timer: float = 0.0
## Upgrade rerolls in hand (earned with boost gates and score, RunRules).
var rerolls: int = 0
var _choices: Array[UpgradeData] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Stage distance of the start pad's drop-in edge.
var _drop_in_distance: float = 0.0


func _ready() -> void:
	player.auto_respawn = false
	player.fell.connect(_on_player_fell)
	builder.finished.connect(_on_finished)
	collapse.caught.connect(_on_caught)
	summary.continued.connect(_on_summary_continued)
	picker.picked.connect(_on_upgrade_picked)
	run_over.restart.connect(start_run)
	start_sprint.launched.connect(_on_launched)
	Events.bailed.connect(_on_bailed)
	Events.gate_collected.connect(func(score: int) -> void: hud.flash_gate(score))
	picker.reroll_requested.connect(_on_reroll)
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
	rerolls = rules.start_rerolls
	player.combo.drop()
	player.combo.run_total = 0
	start_stage()


func start_stage() -> void:
	_freeze_player()
	# Out of the way while the new stage is built: a new finish gate in the
	# same place as the old one would otherwise "see" the parked rider.
	player.global_position = Vector3(0.0, 100000.0, 0.0)
	builder.build(_rng.randi(), middle_chunks, stage_index)
	# CSG builds its collision a frame or two after entering the tree.
	for i: int in 3:
		await get_tree().physics_frame
	var spawn: Transform3D = builder.get_spawn_transform()
	var forward: Vector3 = -spawn.basis.z
	player.set_physics_process(true)
	# Standing on the start pad: the sprint start gets you going.
	player.place(spawn.origin + Vector3.UP * 0.05, atan2(-forward.x, -forward.z), 0.0)
	player.state_machine.transition_to(&"Air", {})
	player_progress = builder.progress_at(player.global_position, true)
	var drop_in: Node3D = builder.chunks[0].get_node_or_null(^"DropIn") as Node3D
	_drop_in_distance = builder.nearest_distance(drop_in.global_position) if drop_in != null else player_progress + 30.0
	collapse.reset(builder, player_progress, stage_index, run_tuning.collapse_speed_scale)
	start_sprint.begin(player)
	stats.start(get_tree().get_nodes_in_group(&"boost_gates").size())
	oob_timer = 0.0
	in_stage = true


func _physics_process(delta: float) -> void:
	if not in_stage:
		return
	player_progress = builder.progress_at(player.global_position)
	var track_y: float = builder.transform_at_distance(player_progress).origin.y
	player.kill_y = track_y - fall_margin
	start_sprint.tick(delta, player_progress > _drop_in_distance)
	collapse.advance(delta, player_progress)
	builder.free_behind(player_progress)
	far_ground.global_position = Vector3(player.global_position.x, track_y - 60.0, player.global_position.z)
	_update_out_of_bounds(delta)
	_update_collapse_feel()


## Past the valley crests (sideways from the centerline): count down, then
## put the rider back on the nearest ride line.
func _update_out_of_bounds(delta: float) -> void:
	if builder.out_of_bounds(player.global_position, player_progress):
		oob_timer += delta
		if oob_timer >= oob_time:
			_respawn_on_line()
	else:
		oob_timer = 0.0
	hud.show_out_of_bounds(oob_time - oob_timer if oob_timer > 0.0 else -1.0)


## The collapse is felt: camera shake and pad rumble grow as it closes in.
func _update_collapse_feel() -> void:
	var near: float = collapse.proximity(player_progress)
	player.camera_rig.set_collapse_shake(near * collapse.shake_max)
	player.vfx.set_collapse_proximity(near)
	if near > 0.01:
		Input.start_joy_vibration(0, near * collapse.rumble_weak_max, near * collapse.rumble_strong_max, 0.1)


func _process(_delta: float) -> void:
	# While it waits behind the start pad it isn't a threat yet.
	var gap: float = player_progress - collapse.distance
	if collapse.waiting:
		gap = maxf(gap, hud.meter_range)
	hud.update_run(stage_index + 1, stats.time, player.combo.run_total, gap,
			player_progress, collapse.distance, builder.length, builder.finish_distance,
			player.catchable_rail != null)
	hud.show_start(start_sprint if in_stage else null)


func _on_launched(grade: StringName, _boost: float) -> void:
	collapse.release()
	hud.flash_start(grade)


## A crash or a bailed landing costs time; it never ends the run by itself.
func _on_bailed() -> void:
	if in_stage:
		_add_penalty(bail_time_cost)


func _add_penalty(seconds: float) -> void:
	if seconds <= 0.0:
		return
	stats.time += seconds
	collapse.add_time_penalty(seconds, player_progress)
	hud.flash_penalty(seconds)


func _on_finished() -> void:
	if not in_stage:
		return
	in_stage = false
	player.combo.bank()
	stats.stop()
	collapse.stop()
	_freeze_player()
	var earned: int = rules.earned(stats.gates, stats.score)
	rerolls = mini(rerolls + earned, rules.max_rerolls)
	summary.open(stage_index + 1, stats.time, stats.best_combo, stats.score, player.combo.run_total,
			stats.gates, stats.gates_total, earned, rerolls)


func _on_summary_continued() -> void:
	_choices = _pick_choices(3)
	picker.open(_choices, rerolls)


## Spend a reroll: three new cards (different from the ones shown, when the
## pool allows).
func _on_reroll() -> void:
	if rerolls <= 0:
		return
	rerolls -= 1
	var old: Array[UpgradeData] = _choices
	var fresh: Array[UpgradeData] = []
	for i: int in 8:
		fresh = _pick_choices(3)
		var overlap: bool = false
		for u: UpgradeData in fresh:
			if old.has(u):
				overlap = true
		if not overlap:
			break
	_choices = fresh
	picker.open(_choices, rerolls)


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


## Fell off the world (or pressed reset): same as running out of bounds.
func _on_player_fell() -> void:
	if in_stage:
		_respawn_on_line()


## Back on the nearest ride line, a little up the hill, with a time cost.
## Combo lost. (Falls back to the centerline where a chunk has no lines.)
func _respawn_on_line() -> void:
	oob_timer = 0.0
	var line: RideLine = builder.nearest_ride_line(player.global_position, player_progress)
	var pos: Vector3
	var forward: Vector3
	if line != null:
		var pts: PackedVector3Array = line.get_global_points()
		var i: int = line.nearest_index(player.global_position)
		var back: int = clampi(i - int(fall_respawn_back / 2.0), 0, pts.size() - 2)
		pos = pts[back] + Vector3.UP * 0.5
		forward = pts[back + 1] - pts[back]
	else:
		var at: Transform3D = builder.transform_at_distance(maxf(player_progress - fall_respawn_back, 0.0))
		pos = at.origin + at.basis.y * 0.5
		forward = -at.basis.z
	var new_speed: float = maxf(player.speed * fall_respawn_speed, respawn_min_speed)
	player.combo.drop()
	player.place(pos, atan2(-forward.x, -forward.z), new_speed)
	player.state_machine.transition_to(&"Air", {})
	player_progress = builder.progress_at(player.global_position, true)
	_add_penalty(respawn_time_cost)


## Stops the rider where it is while a menu is up. (Only its physics tick:
## disabling the whole node takes the body out of the physics world, and it
## came back a frame late at the next stage's start and dropped through.)
func _freeze_player() -> void:
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.speed = 0.0
	player.camera_rig.set_collapse_shake(0.0)
	player.vfx.set_collapse_proximity(0.0)
	Input.stop_joy_vibration(0)
	hud.show_out_of_bounds(-1.0)
	for action: StringName in [&"hop", &"pedal", &"brake", &"grind", &"steer_left", &"steer_right"]:
		Input.action_release(action)
