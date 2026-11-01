extends Node
## Rides game.tscn by itself, for recordings. Added by game.gd with
##   godot --path . -- --autopilot [--seed=<n>]
## Extra user args:
##   --autopilot-shots=<dir>  save stills (chunk join from above, collapse
##                            chasing, trick, stage summary, upgrade picker, run over)
##   --autopilot-lose         from stage 2 on, brake after a while so the
##                            collapse catches up (shows the warning and RUN OVER)
##   --autopilot-trace        print progress / speed / gap every second
##   --autopilot-oob          in stage 1, steer gently left from 8 s to 14 s (rides
##                            over the crest: out-of-bounds countdown + respawn)
## Like the demo driver it only presses InputMap actions (Input.action_press),
## so the player code can't tell it from a pad. Menus get ui_accept events.
## v0.8: does the sprint start (releases in the sweet zone) and follows one
## of the chunk's invisible paths (the one nearest to where it enters the
## chunk), with LineFollower; chunks without paths fall back to the centerline.

## Steer toward the line this far ahead (m).
const LOOK_AHEAD: float = 14.0
## Pump tap rhythm on the ground (s).
const PUMP_PERIOD: float = 0.12
## Only flick a trick when the predicted airtime is this much longer than it (s).
const TRICK_MARGIN: float = 0.2
## Menus are confirmed after this long (s).
const MENU_WAIT: float = 1.6
## --autopilot-lose: start braking this long into stage 2+ (s).
const LOSE_AFTER: float = 12.0
## Rails starting within this distance ahead pull the aim over to them (m).
const RAIL_AIM_DISTANCE: float = 70.0
## Lip hops only above this speed (m/s)...
const HOP_MIN_SPEED: float = 35.0
## ...and only when leaving the ground for at least this long (s).
const LAUNCH_AIRTIME: float = 0.3

var _game: Node
var _player: Player
var _builder: StageBuilder
var _collapse: Collapse
var _menus: Node
var _time: float = 0.0
var _stage_time: float = 0.0
var _pump_timer: float = 0.0
var _was_air: bool = false
var _flick_action: StringName = &""
var _flick_ticks: int = -1
var _queued_trick: StringName = &""
var _queued_at: float = 0.0
var _menu_timer: float = 0.0
var _trick_index: int = 0
var _lose: bool = false
var _trace: bool = false
var _trace_timer: float = 0.0
var _shot_dir: String = ""
var _shots_taken: Dictionary[String, bool] = {}
var _shooting: bool = false
var _rail_cache: Dictionary[int, Vector3] = {}
var _sprint: StartSprint
## Path picked per chunk (by chunk instance id).
var _chosen: Dictionary[int, RideLine] = {}
var _oob: bool = false
var _was_oob: bool = false


func _ready() -> void:
	process_physics_priority = -100
	_game = get_parent()
	_player = _game.get_node(^"Player") as Player
	_builder = _game.get_node(^"StageBuilder") as StageBuilder
	_collapse = _game.get_node(^"Collapse") as Collapse
	_menus = _game.get_node(^"Menus")
	_sprint = _game.get_node(^"StartSprint") as StartSprint
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_lose = args.has("--autopilot-lose")
	_trace = args.has("--autopilot-trace")
	_oob = args.has("--autopilot-oob")
	for arg: String in args:
		if arg.begins_with("--autopilot-shots="):
			_shot_dir = arg.trim_prefix("--autopilot-shots=")
	if _trace:
		Events.landed.connect(func(grade: StringName) -> void: print("t=%6.2f LANDED %s %.1f deg" % [_time, grade, _player.last_landing_angle]))
		Events.trick_completed.connect(func(trick_name: String, score: int) -> void: print("t=%6.2f TRICK %s +%d" % [_time, trick_name, score]))
		Events.grind_started.connect(func() -> void: print("t=%6.2f GRIND" % _time))
		Events.combo_banked.connect(func(score: int) -> void: print("t=%6.2f BANKED %d" % [_time, score]))
		Events.bailed.connect(func() -> void: print("t=%6.2f BAILED (%s)" % [_time, _player.last_bail_reason]))
		_builder.finished.connect(func() -> void:
			var st: StageStats = _game.get_node(^"StageStats") as StageStats
			print("t=%6.2f FINISH stage %d  gates %d/%d  score %d  rerolls %d" % [_time, int(_game.get("stage_index")) + 1, st.gates, st.gates_total, st.score, int(_game.get("rerolls"))]))
		_collapse.caught.connect(func() -> void: print("t=%6.2f CAUGHT by the collapse" % _time))


func _physics_process(delta: float) -> void:
	_time += delta
	if not bool(_game.get("in_stage")):
		_was_air = false
		_stage_time = 0.0
		_handle_menus(delta)
		return
	_stage_time += delta
	_menu_timer = 0.0
	var progress: float = _game.get("player_progress")
	if _sprint.active:
		# Sprint start: pedal, let go in the middle of the sweet zone.
		if _sprint.meter < (_sprint.sweet_from + _sprint.sweet_to) * 0.5:
			Input.action_press(&"pedal")
		else:
			Input.action_release(&"pedal")
		return
	Input.action_press(&"pedal")
	_steer(progress)
	if _oob and int(_game.get("stage_index")) == 0 and _stage_time > 8.0 and _stage_time < 14.0:
		Input.action_release(&"steer_right")
		Input.action_press(&"steer_left", 0.35)
	var oob_timer: float = _game.get("oob_timer")
	if _trace and (oob_timer > 0.0) != _was_oob:
		print("t=%6.2f %s" % [_time, "OUT OF BOUNDS" if oob_timer > 0.0 else "back in bounds / respawned at x %.1f, %.1f m/s" % [_player.global_position.x, _player.speed]])
	_was_oob = oob_timer > 0.0
	_ride(delta)
	if _lose and int(_game.get("stage_index")) >= 1 and _stage_time > LOSE_AFTER:
		Input.action_press(&"brake")
	else:
		Input.action_release(&"brake")
	if _trace:
		_trace_timer -= delta
		if _trace_timer <= 0.0:
			_trace_timer = 1.0
			print("t=%6.2f stage %d  %5.0f / %5.0f m  v=%5.1f  %-5s  gap %5.0f m  collapse %4.1f m/s  run=%d  fps %d" % [
				_time, int(_game.get("stage_index")) + 1, progress, _builder.length, _player.speed,
				_player.state_machine.get_state_name(), progress - _collapse.distance, _collapse.speed, _player.combo.run_total,
				Engine.get_frames_per_second()])


## Follows one ride line of the chunk you're in (a different one per chunk),
## else the stage centerline / a rail's line when one is coming up.
func _steer(progress: float) -> void:
	# v0.13: a falling tree coming down ahead.
	for node: Node in get_tree().get_nodes_in_group(&"hop_hazards"):
		var tree: FallingTree = node as FallingTree
		if tree != null and tree.falling and not tree.down and tree.global_position.distance_to(_player.global_position) < 90.0:
			_shot("v0.16_falling_tree.png", null)
	var index: int = _builder.chunk_index_at(progress)
	var chunk: Chunk = _builder.chunks[index]
	if is_instance_valid(chunk):
		var lines: Array[RideLine] = chunk.get_ride_lines()
		if lines.size() > 0:
			var id: int = chunk.get_instance_id()
			if not _chosen.has(id):
				var best: float = INF
				for candidate: RideLine in lines:
					var dist: float = LineFollower.distance_to(candidate, _player.global_position)
					if dist < best:
						best = dist
						_chosen[id] = candidate
			LineFollower.steer(_player, _chosen[id], LineFollower.look_ahead(_player.speed))
			return
	var ahead: Transform3D = _builder.transform_at_distance(progress + LOOK_AHEAD)
	var target: Vector3 = ahead.origin + ahead.basis.x * _rail_aim(progress)
	var to_target: Vector3 = target - _player.global_position
	to_target.y = 0.0
	var going: Vector3 = Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	var steer: float = 0.0
	if going.length() > 0.5 and to_target.length() > 0.5 and _player.state_machine.get_state_name() != &"Grind":
		# Signed angle from where we go to where we want to go (+ = target on the right).
		steer = clampf(going.normalized().signed_angle_to(to_target.normalized(), Vector3.DOWN) * 3.0, -1.0, 1.0)
	if steer >= 0.0:
		Input.action_release(&"steer_left")
		Input.action_press(&"steer_right", maxf(steer, 0.001))
	else:
		Input.action_release(&"steer_right")
		Input.action_press(&"steer_left", -steer)


## Sideways offset of a rail starting within RAIL_AIM_DISTANCE ahead (or the
## one being ridden), else 0 (the middle of the track).
func _rail_aim(progress: float) -> float:
	for node: Node in get_tree().get_nodes_in_group(&"rails"):
		var rail: Path3D = node as Path3D
		if rail == null or not rail.is_inside_tree() or rail.curve.point_count < 2:
			continue
		var id: int = rail.get_instance_id()
		if not _rail_cache.has(id):
			# (start distance, end distance, sideways offset), once per rail.
			var start: Vector3 = rail.to_global(rail.curve.get_point_position(0))
			var finish: Vector3 = rail.to_global(rail.curve.get_point_position(rail.curve.point_count - 1))
			var start_d: float = _builder.nearest_distance(start)
			var at: Transform3D = _builder.transform_at_distance(start_d)
			_rail_cache[id] = Vector3(start_d, _builder.nearest_distance(finish), (start - at.origin).dot(at.basis.x))
		var info: Vector3 = _rail_cache[id]
		if progress > info.x - RAIL_AIM_DISTANCE and progress < info.y:
			return info.z
	return 0.0


func _ride(delta: float) -> void:
	var state: StringName = _player.state_machine.get_state_name()
	var air: bool = state == &"Air"
	# Pump rhythm on the ground (it only counts on the back of a roller).
	_pump_timer -= delta
	if state == &"Ride" and _pump_timer <= 0.0:
		_pump_timer = PUMP_PERIOD
		if Input.is_action_pressed(&"lean_forward"):
			Input.action_release(&"lean_forward")
		else:
			Input.action_press(&"lean_forward")
	elif state != &"Ride":
		Input.action_release(&"lean_forward")
	# Hold hop while riding and let go the moment the ground drops away: a
	# coyote hop off every kicker lip (more air for tricks).
	# Only above HOP_MIN_SPEED (not on the start deck), and only for a real
	# launch: at speed the bike also leaves the ground for a tick here and there.
	if state == &"Ride" and _player.speed > HOP_MIN_SPEED:
		Input.action_press(&"hop")
	elif air and not _was_air and Input.is_action_pressed(&"hop"):
		if float(_player.predict_landing(1.0).get("time", 1.0)) > LAUNCH_AIRTIME:
			Input.action_release(&"hop")
	elif state == &"Grind" or state == &"Bail":
		Input.action_release(&"hop")
	# Rails are ledges: let go of the (held) hop just before one, and the
	# rail catches you by itself.
	if state == &"Ride" and LineFollower.rail_ahead(_player) <= maxf(_player.speed, 1.0) * 0.3:
		Input.action_release(&"hop")
	elif state == &"Ride" and LineFollower.rail_ahead(_player) < maxf(_player.speed, 1.0) * 0.6:
		Input.action_press(&"hop")
	# Tricks: on takeoff, flick one if the predicted airtime allows; queue a
	# second when there's time for both.
	if air and not _was_air:
		var landing: Dictionary = _player.predict_landing(4.0)
		var airtime: float = float(landing.get("time", 0.0))
		var tricks: Array[TrickData] = _player.tricks.tricks
		var first: TrickData = tricks[_trick_index % tricks.size()]
		var second: TrickData = tricks[(_trick_index + 1) % tricks.size()]
		if airtime > first.duration + TRICK_MARGIN:
			_flick(_trick_action(first))
			_trick_index += 1
			if airtime > first.duration + second.duration + TRICK_MARGIN:
				_queued_trick = _trick_action(second)
				_queued_at = _time + first.duration * 0.8
				_trick_index += 1
	_was_air = air
	if _queued_trick != &"" and _time >= _queued_at and _flick_ticks < 0:
		_flick(_queued_trick)
		_queued_trick = &""
	if _flick_ticks >= 0:
		_flick_ticks += 1
		if _flick_ticks == 3:
			Input.action_release(_flick_action)
			_flick_ticks = -1


func _trick_action(trick: TrickData) -> StringName:
	match trick.direction:
		TrickData.Direction.UP:
			return &"trick_up"
		TrickData.Direction.DOWN:
			return &"trick_down"
		TrickData.Direction.LEFT:
			return &"trick_left"
	return &"trick_right"


func _flick(action: StringName) -> void:
	_flick_action = action
	Input.action_press(action)
	_flick_ticks = 0


func _handle_menus(delta: float) -> void:
	for action: StringName in [&"pedal", &"hop", &"lean_forward", &"grind", &"brake", &"steer_left", &"steer_right"]:
		Input.action_release(action)
	_menu_timer += delta
	if _menu_timer < MENU_WAIT:
		return
	if get_viewport().gui_get_focus_owner() == null:
		return
	_menu_timer = 0.0
	# Godot note: GUI buttons react to input events, not to Input.action_press.
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = pressed
		Input.parse_input_event(event)


func _process(_delta: float) -> void:
	if _shot_dir.is_empty() or _shooting:
		return
	if (_menus.get_node(^"StageSummary") as Control).visible and _menu_timer > 1.0:
		_shot("v0.16_stage_summary.png", null)
	elif (_menus.get_node(^"UpgradePicker") as Control).visible and _menu_timer > 1.0:
		_shot("v0.16_upgrade_picker.png", null)
	elif (_menus.get_node(^"RunOver") as Control).visible and _menu_timer > 1.0:
		_shot("v0.16_run_over.png", null)
	if not bool(_game.get("in_stage")) or _builder.chunks.size() < 3:
		return
	var progress: float = _game.get("player_progress")
	if _sprint.active and _sprint.meter > 0.55:
		_shot("v0.16_sprint_start.png", null)
	_landscape_shots(progress)
	# The join between the 2nd and 3rd chunk, from above, as you ride up to it.
	var join: float = _builder.chunk_start_distance[2]
	if progress > join - 60.0 and progress < join - 40.0 and not _shots_taken.has("v0.16_chunk_join.png"):
		var at: Transform3D = _builder.transform_at_distance(join)
		var eye: Vector3 = at.origin + Vector3.UP * 45.0 + at.basis.x * 40.0 + at.basis.z * 35.0
		_shot("v0.16_chunk_join.png", _make_camera(eye, at.origin - at.basis.z * 25.0))
	# Looking back up the track at you and the collapse behind you.
	var gap: float = progress - _collapse.distance
	if _stage_time > 5.0 and gap < 45.0 and gap > 15.0 and not _shots_taken.has("v0.16_collapse_chasing.png"):
		var me: Transform3D = _builder.transform_at_distance(progress)
		var eye2: Vector3 = _player.global_position - me.basis.z * 18.0 + Vector3.UP * 7.0 + me.basis.x * 6.0
		var look: Vector3 = _builder.transform_at_distance(progress - 20.0).origin + Vector3.UP * 4.0
		_shot("v0.16_collapse_chasing.png", _make_camera(eye2, look))
	if _player.catchable_rail != null and _player.state_machine.get_state_name() != &"Grind":
		_shot("v0.16_grind_prompt.png", null)
	if _player.tricks.is_mid_trick() and _player.tricks.get_progress() > 0.45:
		_shot("v0.16_trick_air.png", null)


## v0.8 stills: an aerial of the 2nd chunk's split lines, and the rider's
## view (plus an aerial) in the canyon S-turn and the slalom forest.
func _landscape_shots(progress: float) -> void:
	var start2: float = _builder.chunk_start_distance[1]
	if progress > start2 - 40.0 and progress < start2 - 20.0:
		var at: Transform3D = _builder.transform_at_distance(start2 + 150.0)
		var eye: Vector3 = _builder.transform_at_distance(start2 - 10.0).origin + Vector3.UP * 70.0 + Vector3(40.0, 0.0, 0.0)
		_shot("v0.16_overview_lines.png", _make_camera(eye, at.origin))
	var index: int = _builder.chunk_index_at(progress)
	var file: String = _builder.chunk_paths[index].get_file().get_basename()
	var into: float = progress - _builder.chunk_start_distance[index]
	# Ride view at each chunk's key moment (set pieces: in the air off the
	# cliff, over the ravine, across the bend), plus an aerial on the way in.
	var moments: Dictionary[String, float] = {"set_cliff": 165.0, "set_ravine": 200.0, "set_bend_kicker": 150.0,
		"set_rail_gap": 218.0, "set_canyon_slot": 190.0, "set_fork": 185.0,
		"set_river_logs": 190.0, "set_mesa_launch": 200.0, "set_cornice": 115.0, "set_ramp_yard": 150.0,
		"switchback_left": 180.0, "switchback_right": 180.0, "fast_s": 180.0, "slalom": 180.0, "gorge": 180.0}
	for kind: String in moments:
		if not file.ends_with(kind):
			continue
		if into > moments[kind] and into < moments[kind] + 12.0:
			_shot("v0.16_%s_ride.png" % kind, null)
		if into > 20.0 and into < 40.0:
			# High above the chunk's middle, looking down the bend.
			var mid: Transform3D = _builder.transform_at_distance(_builder.chunk_start_distance[index] + 200.0)
			var eye2: Vector3 = mid.origin + Vector3.UP * 190.0 + Vector3(mid.basis.z.x, 0.0, mid.basis.z.z).normalized() * 150.0
			_shot("v0.16_%s_aerial.png" % kind, _make_camera(eye2, mid.origin))


func _make_camera(eye: Vector3, target: Vector3) -> Camera3D:
	var camera: Camera3D = Camera3D.new()
	camera.fov = 70.0
	camera.far = 1200.0
	_game.add_child(camera)
	camera.look_at_from_position(eye, target, Vector3.UP)
	return camera


## Saves one still per name. With a camera, switches to it for the capture.
func _shot(file_name: String, camera: Camera3D) -> void:
	if _shot_dir.is_empty() or _shots_taken.has(file_name):
		if camera != null:
			camera.queue_free()
		return
	_shots_taken[file_name] = true
	_shooting = true
	var previous: Camera3D = get_viewport().get_camera_3d()
	var speed_lines: CanvasLayer = _player.get_node(^"SpeedLines") as CanvasLayer
	if camera != null:
		camera.current = true
		speed_lines.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_shot_dir.path_join(file_name))
	print("shot %s" % file_name)
	if camera != null:
		camera.queue_free()
		speed_lines.visible = true
		if previous != null:
			previous.current = true
	_shooting = false
