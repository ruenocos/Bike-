class_name Boss
extends Node3D
## The boss (v0.33): a giant walker in the middle of the arena. Its numbers
## per fight come from a BossData (.tres); the look and the hit size are on
## this node and in boss.tscn.
##
## How you hurt it: hit it fast. Ramming it at ram_min_speed or more does
## damage (more the faster you go, more again coming down onto it from the
## air) and throws you back out. Touching it slower is a crash for you.
## What it does: walks after you, then picks an attack:
##   SLAM: jumps, lands, sends shockwave rings along the floor (hop them).
##   BARRAGE: shoots shells that land in red circles around and ahead of you.
##   CHARGE: winds up (eye goes red) and runs at you.
## Under phase_two_at health it attacks faster with more of everything.
##
## Model: art/boss/boss_mech.glb (Quaternius Animated Mech Pack, CC0), its
## own animations; CelLook gives it the game's cel look and ink line.

signal health_changed(health: float, max_health: float)
## Hurt by a ram; `stomp` when you came down onto it.
signal hurt(damage: float, stomp: bool)
signal phase_two_started
signal died
## It hit you (shockwave, shell, its body, or touching it too slowly).
signal hit_player(what: String)

enum Mode { INTRO, WALK, SLAM, BARRAGE, WINDUP, CHARGE, STAGGER, DEAD }

## Hit cylinder around the model (m, before model_scale).
@export_range(0.2, 5.0, 0.05, "suffix:m") var hit_radius: float = 1.35
@export_range(0.5, 10.0, 0.1, "suffix:m") var hit_height: float = 5.2
## Turn rate toward you (deg/s).
@export_range(10.0, 720.0, 5.0) var turn_rate: float = 90.0
## Stays inside this share of the arena's floor radius while walking.
@export_range(0.0, 3.0, 0.05) var roam: float = 0.8
## Seconds into the slam animation when it lands (the rings start).
@export_range(0.0, 3.0, 0.05, "suffix:s") var slam_land_time: float = 0.6
## Seconds of the shooting pose before the shells go up.
@export_range(0.0, 3.0, 0.05, "suffix:s") var barrage_fire_time: float = 0.35
## The intro roar before the first attack (s).
@export_range(0.0, 10.0, 0.1, "suffix:s") var intro_time: float = 2.0
## Throw-back after a hit: speed away (m/s, at least) and up.
@export_range(0.0, 60.0, 0.5, "suffix:m/s") var knockback_speed: float = 12.0
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var knockback_up: float = 9.0
## How much of your speed you keep going back out after a ram.
@export_range(0.0, 1.0, 0.05) var knockback_keep: float = 0.6
@export var shockwave_scene: PackedScene = preload("res://boss/attacks/shockwave.tscn")
@export var shell_scene: PackedScene = preload("res://boss/attacks/mortar_shell.tscn")
## Colour of the eye when calm / winding up.
## The glowing eye follows this bone, offset (m, before model_scale, in the
## boss's own axes: -Z is its front).
@export var eye_bone: StringName = &"Head"
@export var eye_offset: Vector3 = Vector3(0.0, 0.1, -0.75)
@export var eye_calm: Color = Color(0.4, 0.9, 1.0)
@export var eye_angry: Color = Color(1.0, 0.2, 0.1)

@onready var model: Node3D = $Model
@onready var eye: MeshInstance3D = $Eye
@onready var eye_light: OmniLight3D = $Eye/Light

var data: BossData
var arena: BossArena
var player: Player
var max_health: float = 100.0
var health: float = 100.0
var mode: Mode = Mode.INTRO
var phase_two: bool = false
## Health multiplier (repeat fights).
var health_scale: float = 1.0

var _anim: AnimationPlayer
var _t: float = 0.0
var _attack_timer: float = 0.0
var _invulnerable: float = 0.0
## Short cooldown so one touch isn't a hit every tick.
var _contact_cooldown: float = 0.0
var _rings_left: int = 0
var _ring_timer: float = 0.0
var _charge_dir: Vector3 = Vector3.FORWARD
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _eye_mat: StandardMaterial3D
var _eye_mount: BoneAttachment3D
## Index of the last attack (0 slam, 1 barrage, 2 charge), -1 = none yet.
var _last_attack: int = -1


func _ready() -> void:
	_anim = _find_anim(model)
	_eye_mat = (eye.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	eye.material_override = _eye_mat
	CelLook.apply(model, true)
	CelLook.keep_outline(model, 4.0)
	_attach_eye()


## Starts the fight. `scale_health` grows its health for repeat fights.
func setup(boss_data: BossData, the_arena: BossArena, the_player: Player, fight_seed: int, scale_health: float = 1.0) -> void:
	data = boss_data
	arena = the_arena
	player = the_player
	health_scale = scale_health
	_rng.seed = fight_seed
	max_health = data.max_health * health_scale
	health = max_health
	phase_two = false
	_last_attack = -1
	_attack_timer = 0.0
	scale = Vector3.ONE * data.model_scale
	CelLook.apply(model, true, data.tint)
	global_position = arena.surface_point(arena.global_position)
	_face(player.global_position, 1000.0)
	_set_mode(Mode.INTRO)
	health_changed.emit(health, max_health)


## Size of the hit cylinder at the current scale (m).
func get_hit_radius() -> float:
	return hit_radius * (data.model_scale if data != null else 1.0)


func get_hit_height() -> float:
	return hit_height * (data.model_scale if data != null else 1.0)


func is_dead() -> bool:
	return mode == Mode.DEAD


func _physics_process(delta: float) -> void:
	if data == null or player == null:
		return
	_t += delta
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)
	match mode:
		Mode.INTRO:
			if _t >= intro_time:
				_set_mode(Mode.WALK)
		Mode.WALK:
			_walk(delta)
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_pick_attack()
		Mode.SLAM:
			_face(player.global_position, delta)
			if _t >= slam_land_time and _rings_left > 0:
				_ring_timer -= delta
				if _ring_timer <= 0.0:
					_spawn_ring()
			if _rings_left <= 0 and _t >= slam_land_time + 0.6:
				_set_mode(Mode.WALK)
		Mode.BARRAGE:
			_face(player.global_position, delta)
			if _t >= barrage_fire_time and _rings_left > 0:
				_fire_barrage()
			if _t >= barrage_fire_time + 0.8:
				_set_mode(Mode.WALK)
		Mode.WINDUP:
			_face(player.global_position, delta * 2.0)
			if _t >= data.charge_windup:
				var to: Vector3 = player.global_position - global_position
				to.y = 0.0
				_charge_dir = to.normalized() if to.length() > 0.1 else -global_basis.z
				_set_mode(Mode.CHARGE)
		Mode.CHARGE:
			_charge(delta)
		Mode.STAGGER:
			if _t >= data.hit_cooldown:
				_set_mode(Mode.WALK)
		Mode.DEAD:
			pass
	if mode != Mode.DEAD:
		_check_contact()
	_update_eye(delta)


func _walk(delta: float) -> void:
	_face(player.global_position, delta)
	var target: Vector3 = player.global_position
	var to: Vector3 = target - global_position
	to.y = 0.0
	if to.length() > get_hit_radius() * 2.0:
		_move_to(global_position + to.normalized() * data.walk_speed * delta, arena.floor_radius * roam)


func _charge(delta: float) -> void:
	var limit: float = maxf(arena.floor_radius * roam, arena.bowl_radius * 0.55)
	var before: Vector3 = global_position
	_move_to(global_position + _charge_dir * data.charge_speed * delta, limit)
	_face(global_position + _charge_dir, 1000.0)
	# Stops at the time limit or when it runs into the limit.
	if _t >= data.charge_time or before.distance_to(global_position) < data.charge_speed * delta * 0.25:
		_set_mode(Mode.WALK)


## Moves on the arena floor, kept within `limit` m of the middle.
func _move_to(at: Vector3, limit: float) -> void:
	var local: Vector3 = arena.to_local(at)
	var flat: Vector2 = Vector2(local.x, local.z)
	if flat.length() > limit:
		flat = flat.normalized() * limit
	global_position = arena.surface_point(arena.to_global(Vector3(flat.x, 0.0, flat.y)))


## Turns toward `target` at turn_rate (pass a big delta to snap).
func _face(target: Vector3, delta: float) -> void:
	var to: Vector3 = target - global_position
	to.y = 0.0
	if to.length() < 0.1:
		return
	var want: float = atan2(-to.x, -to.z)
	var step: float = deg_to_rad(turn_rate) * delta
	rotation.y = rotation.y + clampf(wrapf(want - rotation.y, -PI, PI), -step, step)


func _pick_attack() -> void:
	var weights: Array[float] = [data.shockwave_weight, data.mortar_weight, data.charge_weight]
	# Never the same attack twice in a row (when another one is possible).
	if _last_attack >= 0 and weights.size() > 1:
		var others: float = 0.0
		for i: int in weights.size():
			if i != _last_attack:
				others += weights[i]
		if others > 0.0:
			weights[_last_attack] = 0.0
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		_attack_timer = _interval()
		return
	var roll: float = _rng.randf() * total
	var pick: int = 0
	for i: int in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			pick = i
			break
	_last_attack = pick
	match pick:
		0:
			_rings_left = data.shockwave_rings + (1 if phase_two else 0)
			_ring_timer = 0.0
			_set_mode(Mode.SLAM)
		1:
			_rings_left = 1
			_set_mode(Mode.BARRAGE)
		_:
			_set_mode(Mode.WINDUP)


func _interval() -> float:
	return data.attack_interval * (data.phase_two_tempo if phase_two else 1.0)


func _spawn_ring() -> void:
	_rings_left -= 1
	_ring_timer = data.shockwave_gap
	var ring: BossShockwave = shockwave_scene.instantiate() as BossShockwave
	ring.setup(global_position, data.shockwave_speed, arena, player)
	ring.radius = get_hit_radius()
	ring.hit_player.connect(func() -> void: hit_player.emit("Shockwave"))
	arena.add_child(ring)


func _fire_barrage() -> void:
	_rings_left = 0
	var count: int = data.mortar_count + (2 if phase_two else 0)
	var lead: Vector3 = player.velocity * data.mortar_lead
	lead.y = 0.0
	for i: int in count:
		var target: Vector3 = player.global_position + lead
		if i > 0:
			# The first shell goes where you're headed; the rest spread
			# around it, so there's always a way out.
			var a: float = _rng.randf() * TAU
			var d: float = data.mortar_radius * (1.6 + _rng.randf() * 2.8)
			target += Vector3(sin(a), 0.0, cos(a)) * d
		var local: Vector3 = arena.to_local(target)
		var flat: Vector2 = Vector2(local.x, local.z)
		if flat.length() > arena.edge_radius() - data.mortar_radius:
			flat = flat.normalized() * (arena.edge_radius() - data.mortar_radius)
		target = arena.to_global(Vector3(flat.x, 0.0, flat.y))
		var shell: BossMortarShell = shell_scene.instantiate() as BossMortarShell
		shell.setup(target, data.mortar_radius, data.mortar_delay + i * 0.12, arena, player)
		shell.hit_player.connect(func() -> void: hit_player.emit("Shell"))
		arena.add_child(shell)


## You touched it: a ram (fast) hurts it and throws you out; slow is a crash.
func _check_contact() -> void:
	if _contact_cooldown > 0.0:
		return
	var to_player: Vector3 = player.global_position - global_position
	var flat: Vector3 = Vector3(to_player.x, 0.0, to_player.z)
	if flat.length() > get_hit_radius() + 0.4:
		return
	if to_player.y < -1.0 or to_player.y > get_hit_height():
		return
	_contact_cooldown = 0.6
	var away: Vector3 = flat.normalized() if flat.length() > 0.05 else global_basis.z
	var v: Vector3 = player.velocity
	var approach: float = -Vector3(v.x, 0.0, v.z).dot(away)
	var stomp: bool = player.state_machine.get_state_name() == &"Air" and v.y < 0.0 and to_player.y > get_hit_height() * 0.45
	var impact: float = maxf(approach, -v.y if stomp else 0.0)
	impact = maxf(impact, v.length() * 0.75)
	if mode == Mode.CHARGE:
		impact += data.charge_speed * 0.25
	if impact >= data.ram_min_speed and _invulnerable <= 0.0:
		var damage: float = data.ram_damage + data.ram_damage_per_speed * (impact - data.ram_min_speed)
		if stomp:
			damage *= data.stomp_multiplier
		_take_damage(damage, stomp)
		_throw_back(away, v.length() * knockback_keep)
	elif impact >= data.ram_min_speed:
		# Still staggering: bounce off without a crash.
		_throw_back(away, v.length() * knockback_keep)
	else:
		hit_player.emit("Boss")
		_throw_back(away, 0.0)


func _throw_back(away: Vector3, keep: float) -> void:
	var out: float = maxf(keep, knockback_speed)
	player.velocity = away * out + Vector3.UP * knockback_up
	player.speed = out
	player.ground_dir = away
	player.global_position += away * 0.5 + Vector3.UP * 0.3
	player.state_machine.transition_to(&"Air", {})


func _take_damage(damage: float, stomp: bool) -> void:
	health = maxf(health - damage, 0.0)
	_invulnerable = data.hit_cooldown
	health_changed.emit(health, max_health)
	hurt.emit(damage, stomp)
	if health <= 0.0:
		_set_mode(Mode.DEAD)
		died.emit()
		return
	if not phase_two and health <= max_health * data.phase_two_at:
		phase_two = true
		phase_two_started.emit()
	_set_mode(Mode.STAGGER)


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_t = 0.0
	match mode:
		Mode.INTRO:
			_play(&"Idle")
		Mode.WALK:
			# After an attack the clock starts over; after a stagger it
			# carries on, so ramming it can't keep it from ever attacking.
			if _attack_timer <= 0.0:
				_attack_timer = _interval()
			_play(&"Walk")
		Mode.SLAM:
			_play(&"Jump")
		Mode.BARRAGE:
			_play(&"Shoot")
		Mode.WINDUP:
			_play(&"Punch")
		Mode.CHARGE:
			_play(&"Run")
		Mode.STAGGER:
			_play(&"HitRecieve_1" if _rng.randf() < 0.5 else &"HitRecieve_2")
		Mode.DEAD:
			_play(&"Death")


func _play(anim: StringName) -> void:
	if _anim == null or not _anim.has_animation(anim):
		return
	_anim.play(anim, 0.2)
	if mode == Mode.WALK:
		_anim.speed_scale = clampf(data.walk_speed / 5.0, 0.5, 2.0) if data != null else 1.0
	else:
		_anim.speed_scale = 1.0


func _update_eye(_delta: float) -> void:
	var angry: float = 1.0 if mode == Mode.WINDUP or mode == Mode.CHARGE else (0.5 if phase_two else 0.0)
	if mode == Mode.DEAD:
		angry = 0.0
	var c: Color = eye_calm.lerp(eye_angry, angry)
	var pulse: float = 1.0 + 0.5 * sin(_t * (14.0 if mode == Mode.WINDUP else 3.0))
	_eye_mat.emission = c
	_eye_mat.emission_energy_multiplier = (0.2 if mode == Mode.DEAD else 2.5 * pulse)
	eye_light.light_color = c
	eye_light.light_energy = 0.0 if mode == Mode.DEAD else 2.0 * pulse
	if _invulnerable > 0.0 and mode != Mode.DEAD:
		model.visible = fmod(_invulnerable, 0.12) > 0.04
	else:
		model.visible = true
	if _eye_mount != null:
		eye.global_position = _eye_mount.global_position + global_basis * eye_offset


## The eye follows eye_bone (a BoneAttachment3D made at runtime, so the
## imported model stays untouched).
func _attach_eye() -> void:
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	if skeleton.find_bone(eye_bone) < 0:
		return
	_eye_mount = BoneAttachment3D.new()
	_eye_mount.bone_name = eye_bone
	skeleton.add_child(_eye_mount)


func _find_anim(root: Node) -> AnimationPlayer:
	var found: Array[Node] = root.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null
