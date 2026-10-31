class_name RunOver
extends Control
## The collapse caught you: the run is over. A starts a new run.

signal restart

@export_range(0.0, 3.0, 0.05, "suffix:s") var input_delay: float = 0.8

@onready var stats_label: Label = %Stats
@onready var restart_button: Button = %Restart


func _ready() -> void:
	hide()
	restart_button.pressed.connect(_on_restart)


func open(stage: int, run_score: int, upgrades: int) -> void:
	stats_label.text = "Reached stage   %d\nRun score       %d\nUpgrades        %d" % [stage, run_score, upgrades]
	show()
	await MenuInput.delay_focus(self, restart_button, input_delay)


func _on_restart() -> void:
	hide()
	restart.emit()
