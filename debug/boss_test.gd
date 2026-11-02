extends Node3D
## Headless checks for the boss fight (v0.33), on the real arena, boss and
## tank:
##   - rolling in from the deck (pedal held) gets you over ramming speed
##   - a fast ram hurts the boss and throws you back out, no crash
##   - touching it slowly is a crash and does no damage
##   - coming down onto it from the air (stomp) does more than a ram
##   - a shockwave crashes you on the ground; hopping over it doesn't
##   - a shell crashes you in its circle; outside it doesn't
##   - riding off the edge counts as a fall
##   - health to zero = won; clock to zero = lost
##   - the boss's own AI runs every attack for a while without errors
## Run:  <exe> --headless --path . --fixed-fps 60 res://debug/boss_test.tscn
## `-- --boss-trace` prints each case. Exits with code 1 on failure.

const TANK: PackedScene = preload("res://tank/tank.tscn")
const FIGHT: PackedScene = preload("res://boss/boss_fight.tscn")

var _failures: PackedStringArray = PackedStringArray()
var _player: Player
var _fight: BossFight
var _bails: int = 0
var _fell: int = 0
var _won: int = 0
var _lost: int = 0
var _trace: bool = false


func _ready() -> void:
	_trace = OS.get_cmdline_user_args().has("--boss-trace")
	_player = TANK.instantiate() as Player
	add_child(_player)
	_player.auto_respawn = false
	_player.tuning = _player.tuning.duplicate() as PlayerTuning
	_fight = FIGHT.instantiate() as BossFight
	add_child(_fight)
	Events.bailed.connect(func() -> void: _bails += 1)
	_player.fell.connect(func() -> void: _fell += 1)
	_fight.won.connect(func(_d: BossData) -> void: _won += 1)
	_fight.lost.connect(func() -> void: _lost += 1)
	await get_tree().physics_frame
	await _run()


func _run() -> void:
	await _fight.begin(_player, 0, 7)
	_check(_fight.arena != null and _fight.boss != null, "arena and boss built")
	_check(is_equal_approx(_fight.boss.health, _fight.data.max_health), "boss starts at full health")
	await _roll_in_case()
	await _ram_case()
	await _slow_case()
	await _stomp_case()
	await _shockwave_case(false)
	await _shockwave_case(true)
	await _shell_case(0.0, true)
	await _shell_case(20.0, false)
	await _edge_case()
	await _ai_case()
	await _win_case()
	await _lose_case()
	_fight.end()
	if _failures.is_empty():
		print("BOSS TEST PASSED")
	else:
		for failure: String in _failures:
			print("FAILED: ", failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(ok: bool, label: String) -> void:
	if _trace or not ok:
		print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		_failures.append(label)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


## Boss AI off (it stands still in WALK with no attack due).
func _freeze_boss() -> void:
	var boss: Boss = _fight.boss
	boss.set_physics_process(false)
	boss.global_position = _fight.arena.surface_point(_fight.arena.global_position)
	boss.mode = Boss.Mode.WALK


## On the flat floor `dist` m in front of the boss (+Z side), facing it.
func _place_facing_boss(dist: float, speed: float) -> void:
	var at: Vector3 = _fight.boss.global_position + Vector3(0.0, 0.0, dist)
	at = _fight.arena.surface_point(at) + Vector3.UP * 0.4
	_player.place(at, 0.0, speed)
	_player.combo.drop()
	_player.state_machine.transition_to(&"Air", {})
	await _frames(10)


## Holds the boss's contact check on, nothing else (AI off).
func _contact_frames(n: int) -> void:
	for i: int in n:
		_fight.boss.call(&"_check_contact")
		_fight.boss.set(&"_contact_cooldown", maxf(float(_fight.boss.get(&"_contact_cooldown")) - 1.0 / 60.0, 0.0))
		_fight.boss.set(&"_invulnerable", maxf(float(_fight.boss.get(&"_invulnerable")) - 1.0 / 60.0, 0.0))
		await get_tree().physics_frame


func _roll_in_case() -> void:
	_freeze_boss()
	_fight.place_player_on_deck(_fight.arena.spawn.global_position)
	Input.action_press(&"pedal")
	var top: float = 0.0
	for i: int in 60 * 8:
		top = maxf(top, _player.speed)
		await get_tree().physics_frame
	Input.action_release(&"pedal")
	if _trace:
		print("    roll in: top speed %.1f m/s" % top)
	_check(top >= _fight.data.ram_min_speed + 4.0, "rolling in from the deck reaches ram speed (%.1f m/s)" % top)
	_check(_fell == 0, "rolling in stays on the arena")


func _ram_case() -> void:
	_freeze_boss()
	var boss: Boss = _fight.boss
	boss.health = boss.max_health
	await _place_facing_boss(30.0, 26.0)
	_bails = 0
	var before: float = boss.health
	var start_dist: float = 0.0
	await _contact_frames(60 * 2)
	var flat: Vector3 = _player.global_position - boss.global_position
	start_dist = Vector2(flat.x, flat.z).length()
	_check(boss.health < before, "fast ram hurts the boss (%.0f -> %.0f)" % [before, boss.health])
	_check(_bails == 0, "fast ram is no crash for you")
	_check(start_dist > boss.get_hit_radius() + 2.0, "ram throws you back out (%.1f m from it)" % start_dist)


func _slow_case() -> void:
	_freeze_boss()
	var boss: Boss = _fight.boss
	boss.health = boss.max_health
	boss.set(&"_invulnerable", 0.0)
	await _place_facing_boss(boss.get_hit_radius() + 3.0, 4.0)
	_bails = 0
	Input.action_press(&"pedal")
	await _contact_frames(60 * 2)
	Input.action_release(&"pedal")
	_check(_bails >= 1, "slow touch is a crash")
	_check(is_equal_approx(boss.health, boss.max_health), "slow touch does no damage")


func _stomp_case() -> void:
	_freeze_boss()
	var boss: Boss = _fight.boss
	boss.health = boss.max_health
	boss.set(&"_invulnerable", 0.0)
	# A plain ram at 20 m/s for comparison, then a fall onto it at 20 m/s.
	await _place_facing_boss(25.0, 20.0)
	await _contact_frames(60 * 2)
	var ram: float = boss.max_health - boss.health
	boss.health = boss.max_health
	boss.set(&"_invulnerable", 0.0)
	var above: Vector3 = boss.global_position + Vector3(0.0, boss.get_hit_height() * 0.8, 0.5)
	_player.place(above, 0.0, 0.0)
	_player.state_machine.transition_to(&"Air", {})
	_player.velocity = Vector3(0.0, -20.0, 0.0)
	await _contact_frames(3)
	var stomp: float = boss.max_health - boss.health
	if _trace:
		print("    ram %.1f, stomp %.1f" % [ram, stomp])
	_check(ram > 0.0 and stomp > ram, "stomp does more than a ram (%.1f vs %.1f)" % [stomp, ram])


func _shockwave_case(hop: bool) -> void:
	_freeze_boss()
	var boss: Boss = _fight.boss
	await _place_facing_boss(30.0, 0.0)
	await _frames(40)
	_bails = 0
	var ring: BossShockwave = boss.shockwave_scene.instantiate() as BossShockwave
	ring.setup(boss.global_position, 24.0, _fight.arena, _player)
	ring.radius = boss.get_hit_radius()
	var hits: Array[int] = [0]
	ring.hit_player.connect(func() -> void:
		hits[0] += 1
		_player.hit_by_hazard("Shockwave", null))
	_fight.arena.add_child(ring)
	var hopped: bool = false
	for i: int in 60 * 2:
		var flat: Vector3 = _player.global_position - boss.global_position
		var d: float = Vector2(flat.x, flat.z).length()
		if hop and not hopped and ring.radius > d - 6.0:
			hopped = true
			# A full-charge hop, the way Ride does it.
			_player.hop_release_charge = 1.0
			_player.do_hop()
			_player.state_machine.transition_to(&"Air", {})
		await get_tree().physics_frame
	if hop:
		_check(hits[0] == 0 and _bails == 0, "hopping over a shockwave is safe")
	else:
		_check(hits[0] == 1 and _bails >= 1, "a shockwave crashes you on the ground")
	if is_instance_valid(ring):
		ring.queue_free()


func _shell_case(offset: float, want_hit: bool) -> void:
	_freeze_boss()
	await _place_facing_boss(30.0, 0.0)
	await _frames(40)
	_bails = 0
	var shell: BossMortarShell = _fight.boss.shell_scene.instantiate() as BossMortarShell
	shell.setup(_player.global_position + Vector3(offset, 0.0, 0.0), 6.0, 1.0, _fight.arena, _player)
	var hits: Array[int] = [0]
	shell.hit_player.connect(func() -> void:
		hits[0] += 1
		_player.hit_by_hazard("Shell", null))
	_fight.arena.add_child(shell)
	await _frames(60 * 2)
	if want_hit:
		_check(hits[0] == 1 and _bails >= 1, "a shell landing on you crashes you")
	else:
		_check(hits[0] == 0 and _bails == 0, "a shell %.0f m away misses" % offset)


func _edge_case() -> void:
	_freeze_boss()
	_fell = 0
	# On the deck facing outward.
	var arena: BossArena = _fight.arena
	var at: Vector3 = arena.to_global(Vector3(0.0, arena.rim_height + 0.4, arena.bowl_radius + 3.0))
	_player.place(at, PI, 18.0)
	_player.state_machine.transition_to(&"Air", {})
	for i: int in 60 * 6:
		await get_tree().physics_frame
		if _fell > 0:
			break
	_check(_fell >= 1, "riding off the edge is a fall")
	_fight.place_player_on_deck(_player.global_position)
	await _frames(10)
	_check(not arena.is_off_edge(_player.global_position) and _player.global_position.y > arena.kill_y(), "respawn puts you back on the deck")


func _ai_case() -> void:
	var boss: Boss = _fight.boss
	boss.health = boss.max_health
	boss.set_physics_process(true)
	await _place_facing_boss(55.0, 0.0)
	var seen: Dictionary[int, bool] = {}
	_fight.time_left = 999.0
	for i: int in 60 * 40:
		seen[boss.mode] = true
		# Keep the player safe from bails piling up: it just sits there.
		await get_tree().physics_frame
	for m: Boss.Mode in [Boss.Mode.WALK, Boss.Mode.SLAM, Boss.Mode.BARRAGE, Boss.Mode.WINDUP, Boss.Mode.CHARGE]:
		_check(seen.has(m), "AI ran %s in 40 s" % Boss.Mode.keys()[m])
	_check(_fight.active, "fight still running")


func _win_case() -> void:
	_freeze_boss()
	var boss: Boss = _fight.boss
	boss.health = 1.0
	boss.set(&"_invulnerable", 0.0)
	_won = 0
	await _place_facing_boss(30.0, 26.0)
	await _contact_frames(60)
	_check(boss.is_dead(), "boss goes down at zero health")
	await _frames(int(60 * (_fight.outro_time + 0.5)))
	_check(_won == 1, "won after the outro")


func _lose_case() -> void:
	await _fight.begin(_player, 1, 3)
	_check(_fight.data.display_name == "COLOSSUS", "second fight is the second boss")
	_lost = 0
	_fight.time_left = 0.3
	await _frames(40)
	_check(_lost == 1 and not _fight.active, "clock at zero = lost")
	await _fight.begin(_player, 4, 3)
	_check(_fight.data.display_name == "TITAN" and _fight.boss.max_health > _fight.data.max_health,
			"after the last tier it repeats with more health (%.0f)" % _fight.boss.max_health)
