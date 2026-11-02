class_name VehicleAudio
extends Node
## All the sound of riding (audio/vehicle_audio.tscn, a child of the game
## scene). Plays what a VehicleSoundSet holds, plus the layers every vehicle
## shares: wind, the tonal note on each landing grade, the music muffle on a
## bail, the collapse by distance. Reacts only to generic data: speed, on the
## ground or in the air, Events and Player.air_hopped / boost_flashed. Gameplay code never
## plays a sound. Every player is a node below; tweak them in the inspector
## while the game runs.
##
## Godot note: a loop here always plays and only its volume moves, so it can
## come back without a click. Buses are in default_bus_layout.tres (the Audio
## panel at the bottom of the editor).

## The vehicle's sounds. Swap this .tres for another vehicle.
@export var sound_set: VehicleSoundSet
## The vehicle. Falls back to the first node in group "player".
@export var player_path: NodePath = ^"../Player"
## The Collapse. Nothing there (test track) = no collapse sound.
@export var collapse_path: NodePath = ^"../Collapse"
## The node holding `player_progress`, the rider's distance along the stage.
@export var progress_path: NodePath = ^".."

@export_group("Wind")
## Speed that counts as full speed for the wind and the pitch curves (m/s).
@export_range(10.0, 100.0, 1.0, "suffix:m/s") var full_speed: float = 60.0
## Each layer fades in between its two speeds (m/s).
@export_range(0.0, 60.0, 1.0, "suffix:m/s") var wind_low_from: float = 4.0
@export_range(0.0, 60.0, 1.0, "suffix:m/s") var wind_low_to: float = 20.0
@export_range(0.0, 60.0, 1.0, "suffix:m/s") var wind_mid_from: float = 18.0
@export_range(0.0, 60.0, 1.0, "suffix:m/s") var wind_mid_to: float = 38.0
@export_range(0.0, 60.0, 1.0, "suffix:m/s") var wind_high_from: float = 38.0
@export_range(0.0, 60.0, 1.0, "suffix:m/s") var wind_high_to: float = 58.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var wind_low_db: float = -10.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var wind_mid_db: float = -8.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var wind_high_db: float = -8.0
## Extra wind in the air (dB).
@export_range(0.0, 12.0, 0.5, "suffix:dB") var wind_air_boost: float = 3.0
## Low-pass on the Wind bus opens with speed (Hz), a bit further in the air.
@export_range(100.0, 20000.0, 10.0, "suffix:Hz") var wind_cutoff_slow: float = 800.0
@export_range(100.0, 20000.0, 10.0, "suffix:Hz") var wind_cutoff_fast: float = 16000.0
@export_range(1.0, 3.0, 0.05) var wind_cutoff_air_scale: float = 1.4
## Slight pitch rise with speed; the layers do the real work.
@export_range(0.25, 2.0, 0.01) var wind_pitch_slow: float = 0.92
@export_range(0.25, 2.0, 0.01) var wind_pitch_fast: float = 1.12

@export_group("Landing notes")
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var note_perfect_db: float = -5.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var note_good_db: float = -14.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var note_sketchy_db: float = -9.0
## The sketchy note starts slightly flat and slides down to this pitch.
@export_range(0.25, 2.0, 0.01) var sketchy_pitch_from: float = 0.97
@export_range(0.25, 2.0, 0.01) var sketchy_pitch_to: float = 0.84
@export_range(0.01, 2.0, 0.01, "suffix:s") var sketchy_slide_time: float = 0.3

@export_group("Bail")
## The Music bus closes down to this while you're down (Hz).
@export_range(100.0, 20000.0, 10.0, "suffix:Hz") var bail_music_cutoff: float = 600.0
@export_range(0.1, 3.0, 0.05, "suffix:s") var bail_muffle_time: float = 0.6
@export_range(0.01, 1.0, 0.01, "suffix:s") var bail_muffle_fade: float = 0.08

@export_group("Hop detection")
## A leap of the upward speed this big on leaving the ground counts as a hop (m/s).
@export_range(0.5, 10.0, 0.1, "suffix:m/s") var hop_min_kick: float = 2.0

@export_group("Collapse")
## Rumble starts here (m)...
@export_range(10.0, 500.0, 5.0, "suffix:m") var collapse_far: float = 180.0
## ...and is at `rumble_mid_level` here, where the debris starts...
@export_range(10.0, 500.0, 5.0, "suffix:m") var collapse_near: float = 120.0
## ...the roar starts here...
@export_range(5.0, 200.0, 5.0, "suffix:m") var collapse_roar: float = 50.0
## ...and everything peaks here.
@export_range(0.0, 100.0, 1.0, "suffix:m") var collapse_peak: float = 10.0
@export_range(0.0, 1.0, 0.01) var rumble_mid_level: float = 0.55
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var rumble_db: float = -6.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var debris_db: float = -12.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var roar_db: float = -7.0
## Time for the collapse to fade out when the stage ends (s).
@export_range(0.01, 3.0, 0.01, "suffix:s") var collapse_fade: float = 0.4
## Cracks come this often at the far edge and right behind you (s).
@export_range(0.1, 20.0, 0.1, "suffix:s") var crack_interval_far: float = 5.0
@export_range(0.1, 20.0, 0.1, "suffix:s") var crack_interval_near: float = 0.8
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var crack_db_far: float = -22.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var crack_db_near: float = -8.0

@export_group("Score feedback")
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var trick_db: float = -15.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var gate_db: float = -12.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var banked_db: float = -11.0

@export_group("Response")
## Time for wind, grind and engine to follow (s).
@export_range(0.01, 1.0, 0.01, "suffix:s") var smoothing: float = 0.1
## Time for ground contact to cut in and out: short, the silence in the air is the cue (s).
@export_range(0.005, 0.5, 0.005, "suffix:s") var motion_smoothing: float = 0.03

## False in headless runs (tests): no real audio there, and the dummy driver
## never frees sounds that were played, which shows up as leaks at exit.
var _audible: bool = DisplayServer.get_name() != "headless"
var _player: Player
var _collapse: Collapse
var _progress_source: Node
var _loops: Array[AudioStreamPlayer] = []
var _wind_speed: float = 0.0
var _in_air: float = 0.0
var _motion_level: float = 0.0
var _grind_level: float = 0.0
var _collapse_levels: Vector3 = Vector3.ZERO
var _crack_timer: float = 0.0
var _last_up_speed: float = 0.0
## Events.cannon_fired exists: it says when a hop fires, no need to detect them.
var _cannon_signal: bool = false
var _tread_grinding: bool = false
var _last_catch_ms: int = -1000
var _muffle_tween: Tween
var _wind_filter: AudioEffectLowPassFilter
var _music_filter: AudioEffectLowPassFilter

@onready var wind_low: AudioStreamPlayer = $WindLow
@onready var wind_mid: AudioStreamPlayer = $WindMid
@onready var wind_high: AudioStreamPlayer = $WindHigh
@onready var motion: AudioStreamPlayer = $Motion
@onready var motion_fast: AudioStreamPlayer = $MotionFast
@onready var engine: AudioStreamPlayer = $Engine
@onready var engine_high: AudioStreamPlayer = $EngineHigh
@onready var grind: AudioStreamPlayer = $Grind
@onready var grind_catch: AudioStreamPlayer = $GrindCatch
@onready var hop: AudioStreamPlayer = $Hop
@onready var boost: AudioStreamPlayer = $Boost
@onready var cannon_boost: AudioStreamPlayer = $CannonBoost
@onready var crush: AudioStreamPlayer = $Crush
@onready var trick_spin: AudioStreamPlayer = $TrickSpin
@onready var landing_impact: AudioStreamPlayer = $LandingImpact
@onready var crash: AudioStreamPlayer = $Crash
@onready var note_perfect: AudioStreamPlayer = $NotePerfect
@onready var note_good: AudioStreamPlayer = $NoteGood
@onready var note_sketchy: AudioStreamPlayer = $NoteSketchy
@onready var trick: AudioStreamPlayer = $Trick
@onready var gate: AudioStreamPlayer = $Gate
@onready var banked: AudioStreamPlayer = $Banked
@onready var rumble: AudioStreamPlayer = $Rumble
@onready var debris: AudioStreamPlayer = $Debris
@onready var roar: AudioStreamPlayer = $Roar
@onready var crack: AudioStreamPlayer = $Crack


func _ready() -> void:
	set_process(_audible)
	set_physics_process(_audible)
	_player = get_node_or_null(player_path) as Player
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
	_collapse = get_node_or_null(collapse_path) as Collapse
	_progress_source = get_node_or_null(progress_path)
	_wind_filter = _bus_filter(&"Wind")
	_music_filter = _bus_filter(&"Music")
	_apply_sound_set()
	_loops = [wind_low, wind_mid, wind_high, motion, motion_fast, engine, engine_high, grind, rumble, debris, roar]
	for loop: AudioStreamPlayer in _loops:
		loop.volume_db = -80.0
		if _audible and loop.stream != null:
			loop.play()
	if not _audible:
		return
	Events.landed.connect(_on_landed)
	Events.bailed.connect(_on_bailed)
	Events.grind_started.connect(_on_grind_caught)
	Events.trick_completed.connect(func(_n: String, _s: int) -> void: _one_shot(trick, trick_db))
	Events.gate_collected.connect(func(_s: int) -> void: _one_shot(gate, gate_db))
	Events.combo_banked.connect(func(_s: int) -> void: _one_shot(banked, banked_db))
	_connect_optional_signals()
	if _player != null:
		_player.boost_flashed.connect(func() -> void: _one_shot(boost, sound_set.boost_db))
		if not _cannon_signal:
			_player.air_hopped.connect(_on_hop)
			_player.state_machine.state_changed.connect(_on_state_changed)


## Signals that only exist once the tank branch is in: each lights up by itself.
func _connect_optional_signals() -> void:
	if Events.has_signal(&"prop_crushed"):
		Events.connect(&"prop_crushed", func(_kind: StringName, _at: Vector3) -> void: _one_shot(crush, sound_set.crush_db))
	if Events.has_signal(&"trick_started"):
		Events.connect(&"trick_started", func(_name: StringName) -> void: _one_shot(trick_spin, sound_set.trick_spin_db))
	else:
		Events.trick_completed.connect(func(_n: String, _s: int) -> void: _one_shot(trick_spin, sound_set.trick_spin_db))
	if Events.has_signal(&"cannon_fired"):
		_cannon_signal = true
		Events.connect(&"cannon_fired", _on_cannon_fired)
	if Events.has_signal(&"tread_grind_started"):
		Events.connect(&"tread_grind_started", func() -> void:
			_tread_grinding = true
			_on_grind_caught())
	if Events.has_signal(&"tread_grind_ended"):
		Events.connect(&"tread_grind_ended", func() -> void: _tread_grinding = false)


## Stop the loops on the way out, or the audio server keeps their streams
## alive past the scene (leaked at exit), and leave the Music bus open.
func _exit_tree() -> void:
	for loop: AudioStreamPlayer in _loops:
		loop.stop()
	if _music_filter != null:
		_music_filter.cutoff_hz = 20000.0


func _physics_process(_delta: float) -> void:
	# Runs after the Player's tick: this is last tick's velocity on the next one.
	if _player != null:
		_last_up_speed = _player.velocity.y


func _process(delta: float) -> void:
	if _player != null:
		_update_vehicle(delta)
	_update_collapse(delta)


func _update_vehicle(delta: float) -> void:
	var state: StringName = _player.state_machine.get_state_name()
	var grinding: bool = state == &"Grind" or _tread_grinding
	var grounded: bool = _player.is_grounded() and not grinding
	var in_air: bool = not grounded and not grinding
	var moving: float = _player.velocity.length() if in_air else _player.speed
	var weight: float = _follow(delta, smoothing)
	_wind_speed = lerpf(_wind_speed, moving, weight)
	_in_air = lerpf(_in_air, 1.0 if in_air else 0.0, weight)
	var ratio: float = clampf(_wind_speed / full_speed, 0.0, 1.0)

	var boost: float = wind_air_boost * _in_air
	_set_level(wind_low, _ramp(_wind_speed, wind_low_from, wind_low_to), wind_low_db + boost)
	_set_level(wind_mid, _ramp(_wind_speed, wind_mid_from, wind_mid_to), wind_mid_db + boost)
	_set_level(wind_high, _ramp(_wind_speed, wind_high_from, wind_high_to), wind_high_db + boost)
	var wind_pitch: float = lerpf(wind_pitch_slow, wind_pitch_fast, ratio)
	wind_low.pitch_scale = wind_pitch
	wind_mid.pitch_scale = wind_pitch
	wind_high.pitch_scale = wind_pitch
	if _wind_filter != null:
		var cutoff: float = lerpf(wind_cutoff_slow, wind_cutoff_fast, ratio * ratio)
		_wind_filter.cutoff_hz = minf(cutoff * lerpf(1.0, wind_cutoff_air_scale, _in_air), 20000.0)

	var ground_ratio: float = clampf(_player.speed / full_speed, 0.0, 1.0)
	var rolling: bool = grounded and _player.speed > sound_set.motion_start_speed
	_motion_level = lerpf(_motion_level, 1.0 if rolling else 0.0, _follow(delta, motion_smoothing))
	var fast: float = _ramp(_player.speed, sound_set.motion_fast_from, sound_set.motion_fast_to)
	var motion_db: float = lerpf(sound_set.motion_db_slow, sound_set.motion_db_fast, sqrt(ground_ratio))
	_set_level(motion, _motion_level * sqrt(1.0 - fast), motion_db)
	_set_level(motion_fast, _motion_level * sqrt(fast), motion_db)
	var motion_pitch: float = lerpf(sound_set.motion_pitch_slow, sound_set.motion_pitch_fast, ground_ratio)
	motion.pitch_scale = motion_pitch
	motion_fast.pitch_scale = motion_pitch

	var rev: float = _ramp(_wind_speed, sound_set.engine_high_from, sound_set.engine_high_to)
	var engine_db: float = lerpf(sound_set.engine_db_idle, sound_set.engine_db_full, ratio)
	_set_level(engine, sqrt(1.0 - rev), engine_db)
	_set_level(engine_high, sqrt(rev), engine_db)
	var engine_pitch: float = lerpf(sound_set.engine_pitch_idle, sound_set.engine_pitch_full, ratio)
	engine.pitch_scale = engine_pitch
	engine_high.pitch_scale = engine_pitch

	_grind_level = lerpf(_grind_level, 1.0 if grinding else 0.0, weight)
	_set_level(grind, _grind_level, sound_set.grind_db)
	grind.pitch_scale = lerpf(sound_set.grind_pitch_slow, sound_set.grind_pitch_fast, ground_ratio)


## The collapse by distance: rumble from far, debris from near, a roar at close range.
func _update_collapse(delta: float) -> void:
	var gap: float = _collapse_gap()
	var target: Vector3 = Vector3.ZERO
	if gap >= 0.0:
		var far: float = 1.0 - _ramp(gap, collapse_near, collapse_far)
		var close: float = 1.0 - _ramp(gap, collapse_peak, collapse_near)
		target.x = far * rumble_mid_level + close * (1.0 - rumble_mid_level)
		target.y = close
		target.z = 1.0 - _ramp(gap, collapse_peak, collapse_roar)
	_collapse_levels = _collapse_levels.lerp(target, _follow(delta, collapse_fade if gap < 0.0 else smoothing))
	_set_level(rumble, _collapse_levels.x, rumble_db)
	_set_level(debris, _collapse_levels.y, debris_db)
	_set_level(roar, _collapse_levels.z, roar_db)
	if gap < 0.0 or gap > collapse_far:
		return
	_crack_timer -= delta
	if _crack_timer <= 0.0:
		var nearness: float = 1.0 - _ramp(gap, collapse_peak, collapse_far)
		_crack_timer = lerpf(crack_interval_far, crack_interval_near, nearness) * randf_range(0.6, 1.4)
		_one_shot(crack, lerpf(crack_db_far, crack_db_near, nearness))


## Metres between the collapse and the rider, -1 when it isn't chasing you.
func _collapse_gap() -> float:
	if _collapse == null or _progress_source == null or not _collapse.running or _collapse.waiting:
		return -1.0
	return maxf(float(_progress_source.get(&"player_progress")) - _collapse.distance, 0.0)


func _on_landed(grade: StringName) -> void:
	match grade:
		&"perfect":
			_play_stream(landing_impact, sound_set.landing_perfect, sound_set.landing_perfect_db)
			_one_shot(note_perfect, note_perfect_db)
		&"good":
			_play_stream(landing_impact, sound_set.landing_good, sound_set.landing_good_db)
			_one_shot(note_good, note_good_db)
		&"sketchy":
			_play_stream(landing_impact, sound_set.landing_sketchy, sound_set.landing_sketchy_db)
			note_sketchy.pitch_scale = sketchy_pitch_from
			_one_shot(note_sketchy, note_sketchy_db)
			create_tween().tween_property(note_sketchy, ^"pitch_scale", sketchy_pitch_to, sketchy_slide_time)


func _on_bailed() -> void:
	_one_shot(crash, sound_set.crash_db)
	if _music_filter == null:
		return
	if _muffle_tween != null:
		_muffle_tween.kill()
	_muffle_tween = create_tween()
	_muffle_tween.tween_property(_music_filter, ^"cutoff_hz", bail_music_cutoff, bail_muffle_fade)
	_muffle_tween.tween_interval(bail_muffle_time)
	_muffle_tween.tween_property(_music_filter, ^"cutoff_hz", 20000.0, bail_muffle_fade * 2.0)


func _on_state_changed(state_name: StringName) -> void:
	# No hop signal exists: a hop shows as a leap in upward speed on leaving
	# the ground. Riding off a kicker has no leap, so it stays quiet.
	if state_name == &"Air" and _player.velocity.y - _last_up_speed >= hop_min_kick:
		_on_hop()


func _on_hop() -> void:
	_one_shot(hop, sound_set.hop_db)


func _on_cannon_fired(kind: StringName) -> void:
	if kind == &"hop":
		_on_hop()
	elif kind == &"boost":
		_one_shot(cannon_boost, sound_set.cannon_boost_db)


## Both grind signals can fire for one catch: one clank.
func _on_grind_caught() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_catch_ms > 100:
		_one_shot(grind_catch, sound_set.grind_catch_db)
	_last_catch_ms = now


## Puts the sound set's streams on the players.
func _apply_sound_set() -> void:
	motion.stream = sound_set.motion_loop
	motion_fast.stream = sound_set.motion_loop_fast
	engine.stream = sound_set.engine_loop
	engine_high.stream = sound_set.engine_loop_high
	boost.stream = sound_set.boost
	cannon_boost.stream = sound_set.cannon_boost
	crush.stream = sound_set.crush
	trick_spin.stream = sound_set.trick_spin
	grind.stream = sound_set.grind_loop
	grind_catch.stream = sound_set.grind_catch
	hop.stream = sound_set.hop
	crash.stream = sound_set.crash


func _play_stream(player: AudioStreamPlayer, stream: AudioStream, db: float) -> void:
	if stream == null:
		return
	if player.stream != stream:
		player.stream = stream
	_one_shot(player, db)


func _one_shot(player: AudioStreamPlayer, db: float) -> void:
	if not _audible or player.stream == null:
		return
	player.volume_db = db
	player.play()


## A loop's volume for a 0..1 level (equal-power fades read as level²).
func _set_level(player: AudioStreamPlayer, level: float, db: float) -> void:
	player.volume_db = -80.0 if level < 0.003 else db + linear_to_db(level)


func _ramp(value: float, from: float, to: float) -> float:
	return clampf((value - from) / maxf(to - from, 0.001), 0.0, 1.0)


func _follow(delta: float, time: float) -> float:
	return 1.0 - exp(-delta / time)


func _bus_filter(bus_name: StringName) -> AudioEffectLowPassFilter:
	var bus: int = AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return null
	for i: int in AudioServer.get_bus_effect_count(bus):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectLowPassFilter:
			return effect as AudioEffectLowPassFilter
	return null
