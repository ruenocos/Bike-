class_name RiderAudio
extends Node
## The rider's sounds (player/rider_audio.tscn, child of Player). Loops:
## Wind (pitch, volume and AudioBus's low-pass follow speed, louder in the
## air), Roll (tyres on dirt, only on the ground), Grind (while grinding),
## Rumble (the collapse, by proximity: the game calls set_collapse_proximity).
## One-shots react to Events: landing grades, crashes, tricks, banked
## combos, the sprint start. The sounds are synthesized (audio/tools/make_sfx.py).
## All volumes are dB, tweak them in the inspector.

@export_group("Wind")
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var wind_db_slow: float = -30.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var wind_db_fast: float = -3.0
## Extra wind in the air (dB).
@export_range(0.0, 12.0, 0.5, "suffix:dB") var wind_air_boost: float = 3.0
@export var wind_pitch_slow: float = 0.7
@export var wind_pitch_fast: float = 1.45
@export_range(100.0, 20000.0, 10.0, "suffix:Hz") var wind_cutoff_slow: float = 500.0
@export_range(100.0, 20000.0, 10.0, "suffix:Hz") var wind_cutoff_fast: float = 6000.0

@export_group("Rolling")
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var roll_db_slow: float = -36.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var roll_db_fast: float = -10.0
@export var roll_pitch_slow: float = 0.7
@export var roll_pitch_fast: float = 1.4

@export_group("Grind and collapse")
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var grind_db: float = -9.0
## Collapse rumble at point blank (dB); it fades out with distance.
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var rumble_db_max: float = 0.0

@export_group("One-shots")
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var landing_db: float = -4.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var crash_db: float = -2.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var trick_db: float = -8.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var banked_db: float = -10.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var start_db: float = -6.0

## Time for the loops to follow (s).
@export_range(0.01, 1.0, 0.01, "suffix:s") var smoothing: float = 0.08

@onready var player: Player = get_parent() as Player
@onready var wind: AudioStreamPlayer = $Wind
@onready var roll: AudioStreamPlayer = $Roll
@onready var grind: AudioStreamPlayer = $Grind
@onready var rumble: AudioStreamPlayer = $Rumble

## False in headless runs (tests): no real audio there, and the dummy
## driver never frees sounds that were played, which shows up as leaks at exit.
var _audible: bool = DisplayServer.get_name() != "headless"
var _collapse: float = 0.0
var _wind_level: float = 0.0
var _roll_level: float = 0.0
var _grind_level: float = 0.0


func _ready() -> void:
	for loop: AudioStreamPlayer in [wind, roll, grind, rumble]:
		loop.volume_db = -80.0
		if _audible:
			loop.play()
	Events.landed.connect(_on_landed)
	Events.bailed.connect(func() -> void: _one_shot($Crash, crash_db))
	Events.trick_completed.connect(func(_n: String, _s: int) -> void: _one_shot($Trick, trick_db))
	Events.combo_banked.connect(func(_s: int) -> void: _one_shot($Banked, banked_db))
	Events.sprint_launched.connect(_on_sprint_launched)


## Stop the loops on the way out, or the audio server keeps their streams
## alive past the scene (leaked at exit).
func _exit_tree() -> void:
	for loop: AudioStreamPlayer in [wind, roll, grind, rumble]:
		loop.stop()


## 0 (far) .. 1 (right behind you).
func set_collapse_proximity(proximity: float) -> void:
	_collapse = proximity


func _process(delta: float) -> void:
	var t: PlayerTuning = player.tuning
	var ratio: float = clampf(player.speed / t.max_speed, 0.0, 1.0)
	var state: StringName = player.state_machine.get_state_name()
	var grounded: bool = player.is_grounded() and state != &"Grind"
	var weight: float = 1.0 - exp(-delta / smoothing)
	# Speed in the air is the flight speed.
	var moving: float = clampf(player.velocity.length() / t.max_speed, 0.0, 1.0) if state == &"Air" else ratio
	_wind_level = lerpf(_wind_level, moving, weight)
	wind.volume_db = lerpf(wind_db_slow, wind_db_fast, _wind_level) + (wind_air_boost if state == &"Air" else 0.0)
	wind.pitch_scale = lerpf(wind_pitch_slow, wind_pitch_fast, _wind_level)
	AudioBus.set_wind_cutoff(lerpf(wind_cutoff_slow, wind_cutoff_fast, _wind_level * _wind_level))
	_roll_level = lerpf(_roll_level, ratio if grounded and player.speed > 1.0 else 0.0, weight)
	roll.volume_db = _db(_roll_level, roll_db_slow, roll_db_fast)
	roll.pitch_scale = lerpf(roll_pitch_slow, roll_pitch_fast, ratio)
	_grind_level = lerpf(_grind_level, 1.0 if state == &"Grind" else 0.0, weight)
	grind.volume_db = _db(_grind_level, grind_db - 30.0, grind_db)
	rumble.volume_db = _db(_collapse, rumble_db_max - 40.0, rumble_db_max)


## dB for a 0..1 level: silent at 0, from..to above.
func _db(level: float, from: float, to: float) -> float:
	if level < 0.01:
		return -80.0
	return lerpf(from, to, level)


func _on_landed(grade: StringName) -> void:
	match grade:
		&"perfect":
			_one_shot($LandPerfect, landing_db)
		&"good":
			_one_shot($LandGood, landing_db)
		&"sketchy":
			_one_shot($LandSketchy, landing_db)


func _on_sprint_launched(grade: StringName) -> void:
	if grade != &"none":
		_one_shot($Start, start_db)


func _one_shot(sound: Node, db: float) -> void:
	var p: AudioStreamPlayer = sound as AudioStreamPlayer
	p.volume_db = db
	if _audible:
		p.play()
