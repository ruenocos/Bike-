class_name BossFight
extends Node3D
## Runs one boss fight (v0.33): builds the arena (boss_arena.tscn) under
## this node, spawns the boss, puts the player on the deck and keeps the
## clock. Game starts it after every `Game.boss_every` stages and listens
## for `won` / `lost`. Nothing of the arena exists outside a fight.
##
## Rules: the arena falls when the clock runs out (run over), like the
## collapse catching you. Crashes and falls off the edge cost time. Beating
## the boss adds its score and rerolls and moves on to the stage summary.

signal won(data: BossData)
signal lost

@export var arena_scene: PackedScene = preload("res://boss/boss_arena.tscn")
@export var boss_scene: PackedScene = preload("res://boss/boss.tscn")
## One per boss fight in order; the last one repeats (with its repeat_scale
## more health each time).
@export var bosses: Array[BossData] = []
## Speed you start with on the deck (m/s): enough to roll into the bowl.
@export_range(0.0, 40.0, 0.5, "suffix:m/s") var spawn_speed: float = 10.0
## Seconds after the boss goes down before `won` (the death animation).
@export_range(0.0, 10.0, 0.1, "suffix:s") var outro_time: float = 2.5
## Points per point of damage dealt (into the combo).
@export_range(0, 1000, 1) var score_per_damage: int = 20

@onready var hud: BossHud = $BossHud

var arena: BossArena
var boss: Boss
var player: Player
var data: BossData
var active: bool = false
## Seconds left before the arena falls.
var time_left: float = 0.0
## Fights so far this run (0 = the first boss).
var fight_index: int = 0
var _outro: float = -1.0
## Centre flash line (text, colour); Game points it at RunHud.flash_message.
var flash: Callable


## Builds the arena and starts fight number `index` (0 = first boss).
## Await it: collision needs a couple of physics frames.
func begin(the_player: Player, index: int, fight_seed: int) -> void:
	end()
	player = the_player
	fight_index = index
	data = data_for(index)
	arena = arena_scene.instantiate() as BossArena
	add_child(arena)
	for i: int in 3:
		await get_tree().physics_frame
	boss = boss_scene.instantiate() as Boss
	arena.add_child(boss)
	var extra: int = maxi(index - (bosses.size() - 1), 0)
	boss.setup(data, arena, player, fight_seed, 1.0 + data.repeat_scale * extra)
	boss.hit_player.connect(_on_boss_hit_player)
	boss.hurt.connect(_on_boss_hurt)
	boss.health_changed.connect(hud.set_health)
	boss.phase_two_started.connect(_on_phase_two)
	boss.died.connect(_on_boss_died)
	time_left = data.time_limit
	_outro = -1.0
	place_player_on_deck(arena.spawn.global_position)
	hud.open(data)
	hud.set_health(boss.health, boss.max_health)
	hud.set_time(time_left)
	active = true


## The tier for fight `index`: in order, the last one repeating.
func data_for(index: int) -> BossData:
	if bosses.is_empty():
		return BossData.new()
	return bosses[clampi(index, 0, bosses.size() - 1)]


## Frees the arena, the boss and everything they made.
func end() -> void:
	active = false
	_outro = -1.0
	if arena != null and is_instance_valid(arena):
		arena.free()
	arena = null
	boss = null
	hud.close()


func add_penalty(seconds: float) -> void:
	if active:
		time_left -= seconds


## On the deck at the angle of `near` (the middle of the arena faces you),
## rolling inward at spawn_speed.
func place_player_on_deck(near: Vector3) -> void:
	var local: Vector3 = arena.to_local(near)
	var flat: Vector2 = Vector2(local.x, local.z)
	if flat.length() < 1.0:
		flat = Vector2(0.0, 1.0)
	flat = flat.normalized() * (arena.bowl_radius + minf(arena.deck_width * 0.5, 8.0))
	var at: Vector3 = arena.to_global(Vector3(flat.x, arena.rim_height + 0.1, flat.y))
	var inward: Vector3 = arena.global_position - at
	inward.y = 0.0
	inward = inward.normalized()
	player.place(at + Vector3.UP * 0.05, atan2(-inward.x, -inward.z), spawn_speed)
	player.state_machine.transition_to(&"Air", {})


func _physics_process(delta: float) -> void:
	if not active or arena == null:
		return
	player.kill_y = arena.kill_y()
	if _outro >= 0.0:
		_outro -= delta
		if _outro < 0.0:
			active = false
			won.emit(data)
		return
	time_left -= delta
	hud.set_time(time_left)
	if time_left <= 0.0:
		active = false
		lost.emit()


func _on_boss_hit_player(what: String) -> void:
	if active and _outro < 0.0:
		player.hit_by_hazard(what, null)


func _on_boss_hurt(damage: float, stomp: bool) -> void:
	hud.kick_health()
	player.combo.add_points(int(damage) * score_per_damage)
	player.hit_stop(0.06)
	player.flash_boost()
	var text: String = "STOMP! -%d" % int(damage) if stomp else "RAM! -%d" % int(damage)
	_flash(text, Color(1.0, 0.75, 0.3))


func _on_phase_two() -> void:
	_flash("IT'S ANGRY!", Color(0.898, 0.196, 0.176))


func _on_boss_died() -> void:
	_outro = outro_time
	_flash("%s DOWN!" % data.display_name, Color(0.949, 0.718, 0.02))


func _flash(text: String, color: Color) -> void:
	if flash.is_valid():
		flash.call(text, color)
