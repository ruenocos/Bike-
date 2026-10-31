class_name StartSprint
extends Node
## The sprint start on each stage's start pad. Holding pedal (RT) rides you
## forward and fills the meter over `fill_time`; letting go (or rolling over
## the drop-in) judges it: inside the sweet zone = PERFECT START (big boost),
## close to it = GOOD START (small boost), anything else = no boost. Then the
## steep drop-in does the rest. The game starts the collapse when it's judged.
## The HUD draws the meter from `meter` and the zone values below.

signal launched(grade: StringName, boost: float)

## Time for the meter to fill while pedal is held (s).
@export_range(0.5, 6.0, 0.1, "suffix:s") var fill_time: float = 2.4
## Sweet zone on the meter (0-1).
@export_range(0.0, 1.0, 0.01) var sweet_from: float = 0.72
@export_range(0.0, 1.0, 0.01) var sweet_to: float = 0.88
## This far either side of the sweet zone still counts as a good start.
@export_range(0.0, 0.5, 0.01) var good_margin: float = 0.1
## Speed added on a perfect / good start (m/s).
@export_range(0.0, 40.0, 0.5, "suffix:m/s") var perfect_boost: float = 14.0
@export_range(0.0, 40.0, 0.5, "suffix:m/s") var good_boost: float = 7.0
## Taps shorter than this (meter value) don't count as a release.
@export_range(0.0, 0.5, 0.01) var min_release: float = 0.2

## 0..1 while pedalling on the pad.
var meter: float = 0.0
## True from the stage start until the start is judged.
var active: bool = false

var _player: Player


## Called by the game when the rider is placed on the start pad.
func begin(player: Player) -> void:
	_player = player
	meter = 0.0
	active = true


## The pedal prompt: the pad trigger, plus the keyboard key when one is bound.
static func prompt_text() -> String:
	var text: String = "Hold RT to pedal"
	for event: InputEvent in InputMap.action_get_events(&"pedal"):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			text += "  /  " + OS.get_keycode_string(code)
			break
	return text


## Called by the game every physics tick while the stage runs. `past_drop_in`
## = the rider has rolled over the edge of the pad.
func tick(delta: float, past_drop_in: bool) -> void:
	if not active:
		return
	if Input.is_action_pressed(&"pedal"):
		meter = minf(meter + delta / fill_time, 1.0)
	if (Input.is_action_just_released(&"pedal") and meter >= min_release) or past_drop_in:
		_judge()


func _judge() -> void:
	active = false
	var grade: StringName = &"none"
	var boost: float = 0.0
	if meter >= sweet_from and meter <= sweet_to:
		grade = &"perfect"
		boost = perfect_boost
	elif meter >= sweet_from - good_margin and meter <= sweet_to + good_margin:
		grade = &"good"
		boost = good_boost
	if _player != null and boost > 0.0:
		_player.speed = minf(_player.speed + boost, _player.tuning.max_speed)
		if _player.is_on_floor():
			_player.velocity = _player.ground_dir * _player.speed
	launched.emit(grade, boost)
