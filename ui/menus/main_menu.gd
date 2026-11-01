class_name MainMenu
extends Control
## Title screen (v0.14): pick a bike (D-pad / stick left-right), see what it
## changes and what unlocks it, your best run so far, then A to ride.

signal ride(bike: BikeData)

## How stat names read on the bike card.
const STAT_NAMES: Dictionary[StringName, String] = {
	&"max_speed": "Top speed", &"air_steer_rate": "Air steering", &"hop_max_velocity": "Hop height",
	&"air_hops": "Double hop", &"crash_shields": "Crash shield per stage", &"crash_penalty": "Speed lost in a crash",
}

@export_range(0.0, 3.0, 0.05, "suffix:s") var input_delay: float = 0.4
@export_group("Stat bars")
## Top speed shown empty / full on the Speed bar (m/s).
@export var speed_range: Vector2 = Vector2(50.0, 66.0)
## Hop velocity shown empty / full on the Hop bar (m/s); a double hop adds.
@export var hop_range: Vector2 = Vector2(7.0, 13.0)
@export_range(0.0, 1.0, 0.01) var double_hop_bonus: float = 0.3
## Each crash shield adds this much to the Toughness bar.
@export_range(0.0, 1.0, 0.01) var shield_bonus: float = 0.3

var bikes: Array[BikeData] = []
var index: int = 0
var _waiting: bool = false

@onready var bike_name: Label = %BikeName
@onready var bike_info: Label = %BikeInfo
@onready var lock_label: Label = %Lock
@onready var ride_button: Button = %Ride
@onready var best_label: Label = %Best
@onready var swatch: ColorRect = %Swatch
@onready var speed_bar: ProgressBar = %Speed
@onready var hop_bar: ProgressBar = %Hop
@onready var tough_bar: ProgressBar = %Tough

## The bars compare bikes on the base tuning with the bike's changes.
const BASE_TUNING: PlayerTuning = preload("res://player/player_tuning.tres")


func _ready() -> void:
	hide()
	ride_button.pressed.connect(_on_ride)
	(%Prev as Button).pressed.connect(func() -> void: _cycle(-1))
	(%Next as Button).pressed.connect(func() -> void: _cycle(1))


func open(all_bikes: Array[BikeData], selected: int) -> void:
	bikes = all_bikes
	index = clampi(selected, 0, maxi(bikes.size() - 1, 0))
	best_label.text = "Best stage   %d\nBest score   %d\nBoost gates  %d\nRuns         %d" % [Save.best_stage, Save.best_score, Save.total_gates, Save.runs]
	_show_bike()
	show()
	_waiting = true
	await MenuInput.delay_focus(self, ride_button, input_delay)
	_waiting = false
	_show_bike()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_left"):
		_cycle(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right"):
		_cycle(1)
		get_viewport().set_input_as_handled()


func _cycle(step: int) -> void:
	if bikes.is_empty():
		return
	index = posmod(index + step, bikes.size())
	_show_bike()


func _show_bike() -> void:
	if bikes.is_empty():
		return
	var b: BikeData = bikes[index]
	var open_bike: bool = Save.is_unlocked(b)
	bike_name.text = b.display_name.to_upper()
	swatch.color = b.frame_color if open_bike else Color(0.3, 0.3, 0.32)
	var lines: PackedStringArray = [b.description]
	for m: UpgradeData in b.modifiers:
		var label: String = STAT_NAMES.get(m.stat, String(m.stat))
		if m.mode == UpgradeData.Mode.ADD:
			lines.append("%s  %s%s" % [label, "+" if m.amount >= 0.0 else "", String.num(m.amount, 1)])
		else:
			lines.append("%s  %+d%%" % [label, roundi((m.amount - 1.0) * 100.0)])
	bike_info.text = "\n".join(lines)
	var t: PlayerTuning = BASE_TUNING.duplicate() as PlayerTuning
	b.apply(t)
	# 0..1 over the Stat bars ranges.
	speed_bar.value = clampf(inverse_lerp(speed_range.x, speed_range.y, t.max_speed), 0.05, 1.0)
	hop_bar.value = clampf(inverse_lerp(hop_range.x, hop_range.y, t.hop_max_velocity) + t.air_hops * double_hop_bonus, 0.05, 1.0)
	tough_bar.value = clampf((1.0 - t.crash_penalty) * 0.9 + t.crash_shields * shield_bonus, 0.05, 1.0)
	lock_label.visible = not open_bike
	lock_label.text = "LOCKED: %s" % b.unlock_text()
	if not _waiting:
		ride_button.disabled = not open_bike
	ride_button.text = "Ride" if open_bike else "Locked"


func _on_ride() -> void:
	var b: BikeData = bikes[index]
	if not Save.is_unlocked(b):
		return
	Save.choose_bike(b)
	hide()
	ride.emit(b)
