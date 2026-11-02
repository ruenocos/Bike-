extends Node3D
## Headless regression checks from the v0.32 bug sweep: the real game scene for
## the title screen and frozen-rider cases, the tank on a plain slope for the rest.
##   - title screen: no collapse wall
##   - the cannon stays quiet while the rider is frozen (menus)
##   - a boost in the air reaches the flight: cannon blast, sprint start
##   - No Hander: a touchdown's grace ends on leaving the ground and on place()
##   - a bail lets go of the No Hander pose
##   - crushing something in the air keeps your flight path
##   - a landed trick counts on a soft touchdown too
##   - a hazard hit still pending doesn't follow you through place()
## Run:  <exe> --headless --path . --fixed-fps 60 res://debug/regress_test.tscn
## Exits with code 1 on failure.

const GAME: PackedScene = preload("res://game.tscn")
const LOG: PackedScene = preload("res://chunks/parts/props/log.tscn")

var _failures: PackedStringArray = PackedStringArray()
var _player: Player
var _patch: TerrainPatch
var _bails: int = 0
var _crushes: int = 0
var _fired: int = 0


func _ready() -> void:
	Events.bailed.connect(func() -> void: _bails += 1)
	Events.cannon_fired.connect(func(_kind: StringName) -> void: _fired += 1)
	await _run_game_cases()
	await _run_slope_cases()
	if _failures.is_empty():
		print("REGRESS TEST PASSED")
	else:
		for failure: String in _failures:
			print("FAILED: ", failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(ok: bool, label: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		_failures.append(label)


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


# --- The real game scene -----------------------------------------------------

func _run_game_cases() -> void:
	var game: Node3D = GAME.instantiate() as Node3D
	add_child(game)
	await _ticks(5)
	var collapse: Collapse = game.get_node("Collapse") as Collapse
	var player: Player = game.get_node("Player") as Player
	var menu: MainMenu = game.get_node("Menus/MainMenu") as MainMenu

	_check(not collapse.visible, "title: the collapse wall is hidden")
	_fired = 0
	Input.action_press(&"cannon_blast")
	await _ticks(2)
	Input.action_release(&"cannon_blast")
	await _ticks(1)
	_check(_fired == 0 and player.speed == 0.0, "title: the cannon button does nothing")

	menu.ride.emit(menu.bikes[0])
	for i: int in 60:
		await get_tree().physics_frame
		if game.get("in_stage"):
			break
	_check(game.get("in_stage"), "ride: the stage starts")
	_check(collapse.visible, "ride: the collapse wall is back")
	game.queue_free()
	await _ticks(2)


# --- The tank on a plain slope -----------------------------------------------

func _run_slope_cases() -> void:
	_patch = TerrainPatch.new()
	_patch.length = 900.0
	_patch.slope_deg = 14.0
	_patch.noise_amplitude = 0.0
	add_child(_patch)
	_player = (load("res://tank/tank.tscn") as PackedScene).instantiate() as Player
	add_child(_player)
	_player.tuning = _player.tuning.duplicate() as PlayerTuning
	_player.crushed.connect(func(_at: Vector3) -> void: _crushes += 1)
	await _ticks(5)
	await _blast_in_air()
	await _sprint_in_air()
	await _no_hander_place()
	await _no_hander_bounce()
	await _no_hander_bail()
	await _crush_in_air()
	await _soft_trick_landing()
	await _pending_hazard_place()
	Input.action_release(&"no_hander")


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, _patch.surface_height(x, z), z)


func _on_ground(z: float, speed: float) -> void:
	_player.place(_ground(0.0, z) + Vector3.UP * 0.05, 0.0, speed)
	_player.combo.drop()
	_player.state_machine.transition_to(&"Air", {})
	await _ticks(15)


## Flying high over the slope (no ground in reach for a while).
func _in_air(speed: float) -> void:
	_player.place(_ground(0.0, -40.0) + Vector3.UP * 60.0, 0.0, speed)
	_player.state_machine.transition_to(&"Air", {})
	await _ticks(2)


func _blast_in_air() -> void:
	await _in_air(30.0)
	var cannon: TankCannon = _player.get_node("TankCannon") as TankCannon
	cannon.cooldown = 0.0
	var before: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	cannon.blast()
	var after: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	_check(after > before + _player.tuning.blast_speed * 0.8, "air blast reaches the flight (%.1f -> %.1f m/s)" % [before, after])


func _sprint_in_air() -> void:
	await _in_air(30.0)
	var sprint: StartSprint = StartSprint.new()
	add_child(sprint)
	sprint.begin(_player)
	sprint.meter = (sprint.sweet_from + sprint.sweet_to) * 0.5
	var before: float = _player.velocity.length()
	sprint.tick(0.0, true)
	_check(_player.velocity.length() > before + sprint.perfect_boost * 0.8, "sprint start judged in the air keeps its boost (%.1f -> %.1f m/s)" % [before, _player.velocity.length()])
	sprint.queue_free()


func _no_hander_place() -> void:
	await _on_ground(-40.0, 30.0)
	Input.action_press(&"no_hander")
	_player.no_hander = true
	_player.no_hander_time = 1.0
	_player.start_no_hander_grace()
	_player.place(_ground(0.0, -40.0) + Vector3.UP * 0.05, 0.0, 30.0)
	_bails = 0
	await _ticks(30)
	Input.action_release(&"no_hander")
	_check(_bails == 0, "respawning during the No Hander grace doesn't bail after the respawn (%d)" % _bails)


func _no_hander_bounce() -> void:
	await _on_ground(-40.0, 30.0)
	Input.action_press(&"no_hander")
	_player.no_hander = true
	_player.start_no_hander_grace()
	_player.global_position += Vector3.UP * 60.0
	_player.state_machine.transition_to(&"Air", {})
	_player.bail_immunity_timer = 0.0
	_bails = 0
	await _ticks(40)
	Input.action_release(&"no_hander")
	_check(_bails == 0, "bouncing back into the air ends the No Hander grace (%d mid-air bails)" % _bails)


func _no_hander_bail() -> void:
	await _on_ground(-40.0, 30.0)
	_player.no_hander = true
	_player.no_hander_time = 0.5
	_player.state_machine.transition_to(&"Bail", {})
	_check(not _player.no_hander, "a bail ends the No Hander pose")
	await _ticks(60)


## The hull sensor is off so the sphere meets the log, flying with a stale
## ground_dir pointing somewhere else.
func _crush_in_air() -> void:
	var sensor: TankHullSensor = _player.get_node_or_null("Visual/TankRig/HullSensor") as TankHullSensor
	if sensor == null:
		for node: Node in _player.find_children("*", "Area3D", true, false):
			if node is TankHullSensor:
				sensor = node as TankHullSensor
	sensor.enabled = false
	_player.tuning.crushes_props = true
	var prop: Node3D = LOG.instantiate() as Node3D
	add_child(prop)
	var at: Vector3 = _ground(0.0, -60.0) + Vector3.UP * 30.0
	# Low enough for the short fall on the way there.
	prop.global_position = at + Vector3.FORWARD * 6.0 + Vector3.DOWN * 0.5
	await _ticks(2)
	_player.place(at, 0.0, 40.0)
	_player.state_machine.transition_to(&"Air", {})
	_player.ground_dir = Vector3.RIGHT
	_crushes = 0
	var flight: Vector3 = Vector3.FORWARD
	for i: int in 60:
		flight = _player.velocity
		await get_tree().physics_frame
		if _crushes > 0:
			break
	var angle: float = rad_to_deg(flight.angle_to(_player.velocity))
	_check(_crushes == 1 and angle < 15.0, "crushing in the air keeps the flight path (%d crushed, %.0f deg off)" % [_crushes, angle])
	sensor.enabled = true
	prop.queue_free()
	await _ticks(2)


func _soft_trick_landing() -> void:
	await _on_ground(-40.0, 30.0)
	await _ticks(10)
	var along: Vector3 = _player.ground_dir * 30.0
	_player.air_tricks = 1
	_player.tricks.tricks_this_air = 1
	_player.last_landing_grade = &"-"
	var landed: Array[StringName] = []
	var on_landed: Callable = func(grade: StringName) -> void: landed.append(grade)
	Events.landed.connect(on_landed)
	_player.state_machine.transition_to(&"Land", {"velocity": along})
	Events.landed.disconnect(on_landed)
	_check(landed.size() == 1 and _player.speed > 30.0 + _player.tuning.trick_land_boost * 0.9, "a landed trick counts on a soft touchdown (%s, %.1f m/s)" % [landed, _player.speed])
	_check(_player.tricks.tricks_this_air == 0, "a soft touchdown clears the air's trick count")
	await _ticks(10)


func _pending_hazard_place() -> void:
	await _on_ground(-40.0, 30.0)
	_player.hit_by_hazard("A tree", null)
	_player.place(_ground(0.0, -40.0) + Vector3.UP * 0.05, 0.0, 30.0)
	_player.state_machine.transition_to(&"Air", {})
	_bails = 0
	await _ticks(5)
	_check(_bails == 0, "a hazard hit still pending doesn't follow you through place()")
