extends Node3D
## Headless checks for the tank (v0.31), on a plain generated slope:
##   - a log, a fence: crushed at speed (no bail, small speed cost, they stop
##     colliding); a rock still crashes you
##   - a tree crushes only when its model is small (group "crushable")
##   - the same log still crashes a rider without `crushes_props`
##   - cannon blast: adds speed, then waits for its cooldown
##   - a hop fires the cannon (Player.hopped reaches TankCannon)
## Run:  <exe> --headless --path . --fixed-fps 60 res://debug/tank_test.tscn
## Exits with code 1 on failure.

const TANK: PackedScene = preload("res://tank/tank.tscn")
const LOG: PackedScene = preload("res://chunks/parts/props/log.tscn")
const FENCE: PackedScene = preload("res://chunks/parts/props/fence.tscn")
const ROCK: PackedScene = preload("res://chunks/parts/props/rock.tscn")

var _failures: PackedStringArray = PackedStringArray()
var _player: Player
var _patch: TerrainPatch
var _bails: int = 0
var _crushes: int = 0
var _hops: int = 0


func _ready() -> void:
	_patch = TerrainPatch.new()
	_patch.length = 900.0
	_patch.slope_deg = 14.0
	_patch.noise_amplitude = 0.0
	add_child(_patch)
	_player = TANK.instantiate() as Player
	add_child(_player)
	Events.bailed.connect(func() -> void: _bails += 1)
	_player.crushed.connect(func(_at: Vector3) -> void: _crushes += 1)
	_player.hopped.connect(func() -> void: _hops += 1)
	for i: int in 5:
		await get_tree().physics_frame
	await _run()


func _run() -> void:
	_player.tuning = _player.tuning.duplicate() as PlayerTuning
	await _hit_case("log, tank: crushed", LOG, true, true)
	await _hit_case("fence, tank: crushed", FENCE, true, true)
	await _hit_case("rock, tank: crash", ROCK, true, false)
	await _hit_case("log, no crushing: crash", LOG, false, false)
	await _blast_case()
	await _hop_case()
	if _failures.is_empty():
		print("TANK TEST PASSED")
	else:
		for failure: String in _failures:
			print("FAILED: ", failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _fail(msg: String) -> void:
	_failures.append(msg)


## Places the rider going straight down the slope at `speed`, `dist` m before z.
func _start(z_distance: float, speed: float) -> void:
	var at: Vector3 = _patch.to_global(_patch.valley_to_local(0.0, _patch.base_height(0.0, -z_distance) + 0.1, z_distance))
	_player.place(at, 0.0, speed)
	for i: int in 3:
		await get_tree().physics_frame


func _hit_case(label: String, scene: PackedScene, crushes: bool, want_crush: bool) -> void:
	_player.tuning.crushes_props = crushes
	var prop: Node3D = scene.instantiate() as Node3D
	_patch.add_child(prop)
	prop.position = _patch.valley_to_local(0.0, _patch.base_height(0.0, -200.0), 200.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _start(140.0, 40.0)
	var before: float = _player.speed
	_bails = 0
	_crushes = 0
	for i: int in 60 * 3:
		await get_tree().physics_frame
		if _crushes > 0 or _bails > 0:
			break
	if want_crush:
		if _crushes != 1 or _bails != 0:
			_fail("%s: crushes %d, bails %d" % [label, _crushes, _bails])
		elif _player.speed < before * 0.75:
			_fail("%s: lost too much speed (%.1f -> %.1f)" % [label, before, _player.speed])
		elif (prop as CollisionObject3D).collision_layer != 0:
			_fail("%s: still colliding" % label)
	elif _bails == 0 or _crushes != 0:
		_fail("%s: crushes %d, bails %d" % [label, _crushes, _bails])
	# Let any bail run out before the next case.
	for i: int in 90:
		await get_tree().physics_frame
	if is_instance_valid(prop):
		prop.queue_free()
	await get_tree().physics_frame


func _blast_case() -> void:
	var cannon: TankCannon = _player.get_node("TankCannon") as TankCannon
	await _start(100.0, 20.0)
	cannon.cooldown = 0.0
	var before: float = _player.speed
	if not cannon.blast() or _player.speed < before + _player.tuning.blast_speed * 0.9:
		_fail("blast: no speed gain (%.1f -> %.1f)" % [before, _player.speed])
	if cannon.blast():
		_fail("blast: fired again during the cooldown")
	await get_tree().create_timer(_player.tuning.blast_cooldown + 0.1).timeout
	if not cannon.blast():
		_fail("blast: didn't reload")


func _hop_case() -> void:
	await _start(100.0, 25.0)
	_hops = 0
	_player.do_hop()
	if _hops != 1:
		_fail("hop: the cannon signal didn't fire")
