class_name StageSummary
extends Control
## Shown when you cross the finish: time, best combo, stage score, run score,
## boost gates collected and the upgrade rerolls they (and the score) earned.
## Continue (A) goes on to the upgrade picker.

signal continued

## Buttons ignore input this long after opening, so a button still held from
## riding (hop is also ui_accept) doesn't skip the screen (s).
@export_range(0.0, 3.0, 0.05, "suffix:s") var input_delay: float = 0.5

@onready var title_label: Label = %Title
@onready var kana_label: Label = %Kana
@onready var names_label: Label = %Names
@onready var values_label: Label = %Values
@onready var continue_button: Button = %Continue


func _ready() -> void:
	hide()
	continue_button.pressed.connect(_on_continue)


func open(stage: int, time: float, best_combo: int, stage_score: int, run_score: int,
		gates: int = 0, gates_total: int = 0, rerolls_earned: int = 0, rerolls: int = 0) -> void:
	title_label.text = "STAGE %d CLEAR" % stage
	kana_label.text = "第%d戦区 突破" % stage
	names_label.text = "TIME\nBEST COMBO\nSTAGE SCORE\nRUN SCORE\nBOOST GATES\nREROLLS"
	values_label.text = "%d:%05.2f\n%s\n%s\n%s\n%d / %d\n+%d  (%d)" % [
		floori(time / 60.0), fmod(time, 60.0), RunHud.group_digits(best_combo), RunHud.group_digits(stage_score),
		RunHud.group_digits(run_score), gates, gates_total, rerolls_earned, rerolls]
	show()
	UiMotion.open_menu(self)
	await MenuInput.delay_focus(self, continue_button, input_delay)


func _on_continue() -> void:
	hide()
	continued.emit()
