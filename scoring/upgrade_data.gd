class_name UpgradeData
extends Resource
## One upgrade you can pick between stages: a change to one PlayerTuning value
## for the rest of the run. The game applies it to the run's own copy of the
## tuning, so player_tuning.tres itself never changes.
## Make a new one with right-click > New Resource > UpgradeData, then add it
## to the Game node's `upgrade_pool`.

enum Mode { ADD, MULTIPLY }

@export var display_name: String = "Upgrade"
@export_multiline var description: String = ""
## PlayerTuning property to change (its name in player_tuning.gd).
@export var stat: StringName = &""
@export var mode: Mode = Mode.ADD
## Added to the value (ADD) or multiplied with it (MULTIPLY).
@export var amount: float = 0.0


func apply(tuning: PlayerTuning) -> void:
	if not stat in tuning:
		push_error("UpgradeData %s: PlayerTuning has no '%s'" % [display_name, stat])
		return
	var value: float = float(tuning.get(stat))
	tuning.set(stat, value + amount if mode == Mode.ADD else value * amount)
