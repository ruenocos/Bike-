extends Node3D
## Headless checks for the v0.13 hazards and upgrade powers, on a plain
## generated slope:
##   - a falling tree ahead comes down before you reach it and crashes you if
##     you ride into it; hopping it (the bots' hop timing) clears it
##   - Crash Shield turns that crash into a glance at full speed
##   - Double Hop: releasing hop in the air pops you up again
##   - Gate Magnet pulls you through a gate 5 m off your line (without it
##     you miss it)
## Run:  <exe> --headless --path . --fixed-fps 60 res://debug/powers_test.tscn
## Exits with code 1 on failure.

const PLAYER: PackedScene = preload("res://player/player.tscn")
const TREE: PackedScene = preload("res://hazards/falling_tree.tscn")
const GATE: PackedScene = preload("res://chunks/parts/boost_gate.tscn")
const TUNING: PlayerTuning = preload("res://player/player_tuning.tres")

var _failures: PackedStringArray = PackedStringArray()
var _player: Player
var _patch: TerrainPatch
var _bails: int = 0
var _shields: int = 0
var _air_hops: int = 0
var _gates: int = 0


func _ready() -> void:
	_patch = TerrainPatch.new()
	_patch.length = 900.0
	_patch.slope_deg = 14.0
	_patch.noise_amplitude = 0.0
	_patch.ground_cover = null
	add_child(_patch)
	_player = PLAYER.instantiate() as Player
	add_child(_player)
	_player.kill_y = -100000.0
	Events.bailed.connect(func() -> void: _bails += 1)
	Events.gate_collected.connect(func(_s: int) -> void: _gates += 1)
	_player.shield_used.connect(func() -> void: _shields += 1)
	_player.air_hopped.connect(func() -> void: _air_hops += 1)
	_run.call_deferred()


func _run() -> void:
	for i: int in 3:
		await get_tree().physics_frame
	await _tree_case("falling tree, no hop: comes down in time and crashes you", false, 0, true)
	await _tree_case("falling tree, bot hop timing: clears it", true, 0, false)
	await _tree_case("falling tree, Crash Shield: glance at full speed", false, 1, false)
	await _double_hop_case()
	await _gate_case("gate 5 m off the line, Gate Magnet: pulled through", 10.0, true)
	await _gate_case("gate 5 m off the line, no magnet: missed", 0.0, false)
	if _failures.is_empty():
		print("POWERS TEST PASSED")
		get_tree().quit(0)
	else:
		for f: String in _failures:
			print("FAIL ", f)
		print("POWERS TEST FAILED (%d)" % _failures.size())
		get_tree().quit(1)


func _fail(msg: String) -> void:
	_failures.append(msg)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, _patch.surface_height(x, z), z)


func _start(tuning: PlayerTuning, speed: float) -> void:
	_player.tuning = tuning
	_player.set_physics_process(true)
	_player.place(_ground(0.0, -20.0) + Vector3.UP * 0.05, 0.0, speed)
	_player.combo.drop()
	_player.state_machine.transition_to(&"Air", {})
	_player.bail_immunity_timer = 0.0
	_bails = 0
	_shields = 0
	_air_hops = 0
	_gates = 0
	for i: int in 20:
		await get_tree().physics_frame


func _tree_case(label: String, hop: bool, shields: int, want_crash: bool) -> void:
	await _start(TUNING.duplicate() as PlayerTuning, 45.0)
	_player.shields_left = shields
	var cross: Vector3 = _ground(0.0, -260.0)
	var tree: FallingTree = TREE.instantiate() as FallingTree
	add_child(tree)
	tree.global_position = _ground(5.0, -260.0)
	tree.look_at(Vector3(cross.x, tree.global_position.y, cross.z), Vector3.UP)
	tree.crossing = cross
	var down_when_passing: bool = false
	var speed_before: float = 0.0
	for i: int in 60 * 8:
		await get_tree().physics_frame
		if hop:
			LineFollower.hop_for_rails(_player)
		if _player.global_position.z > -250.0:
			speed_before = _player.speed
		elif not down_when_passing and _player.global_position.z < -255.0 and tree.down:
			down_when_passing = true
		if _player.global_position.z < -330.0:
			break
	Input.action_release(&"hop")
	if not down_when_passing:
		_fail("%s: the tree wasn't down when the rider got there" % label)
	if want_crash and _bails == 0:
		_fail("%s: rode through the trunk without a crash" % label)
	if not want_crash and _bails > 0:
		_fail("%s: crashed (%s)" % [label, _player.last_bail_reason])
	if shields > 0:
		if _shields != 1:
			_fail("%s: shield not used" % label)
		if _player.speed < speed_before * 0.85 or _player.global_position.z > -300.0:
			_fail("%s: lost speed %.0f -> %.0f" % [label, speed_before, _player.speed])
	print("case | %s | bails %d, shields used %d" % [label, _bails, _shields])
	tree.queue_free()


func _double_hop_case() -> void:
	var t: PlayerTuning = TUNING.duplicate() as PlayerTuning
	t.air_hops = 1.0
	await _start(t, 40.0)
	# Pop off the ground with a hop, then release hop again in the air.
	Input.action_press(&"hop")
	for i: int in 12:
		await get_tree().physics_frame
	Input.action_release(&"hop")
	for i: int in 20:
		await get_tree().physics_frame
	var in_air: bool = _player.state_machine.get_state_name() == &"Air"
	var vy_before: float = _player.velocity.y
	Input.action_press(&"hop")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"hop")
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not in_air:
		_fail("double hop: the first hop didn't leave the ground")
	elif _air_hops != 1 or _player.velocity.y < vy_before + t.air_hop_velocity * 0.5:
		_fail("double hop: no second pop (air hops %d, vy %.1f -> %.1f)" % [_air_hops, vy_before, _player.velocity.y])
	print("case | double hop | air hops %d" % _air_hops)
	for i: int in 120:
		await get_tree().physics_frame


func _gate_case(label: String, magnet: float, want: bool) -> void:
	var t: PlayerTuning = TUNING.duplicate() as PlayerTuning
	t.gate_magnet_radius = magnet
	await _start(t, 45.0)
	var gate: BoostGate = GATE.instantiate() as BoostGate
	add_child(gate)
	gate.global_position = _ground(5.0, -200.0) + Vector3.UP * 1.0
	for i: int in 60 * 5:
		await get_tree().physics_frame
		if _player.global_position.z < -230.0:
			break
	if want and _gates == 0:
		_fail("%s: gate missed (rider at x %.1f)" % [label, _player.global_position.x])
	if not want and _gates > 0:
		_fail("%s: gate collected without the magnet" % label)
	print("case | %s | gates %d" % [label, _gates])
	gate.queue_free()
