class_name RunOver
extends Control
## The collapse caught you: the run is over. Shows the run and your bests
## (v0.14: NEW BEST, bikes this run unlocked). A rides again, the second
## button goes to the title screen.

signal restart
signal to_menu

@export_range(0.0, 3.0, 0.05, "suffix:s") var input_delay: float = 0.8

@onready var names_label: Label = %Names
@onready var values_label: Label = %Values
@onready var restart_button: Button = %Restart
@onready var menu_button: Button = %Menu
@onready var news_label: Label = %News


func _ready() -> void:
	hide()
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)


func open(stage: int, run_score: int, upgrades: int, report: Dictionary = {}) -> void:
	var names: PackedStringArray = ["REACHED STAGE", "RUN SCORE", "UPGRADES"]
	var values: PackedStringArray = [str(stage), RunHud.group_digits(run_score), str(upgrades)]
	var news: PackedStringArray = []
	if report.get("best_stage", false):
		news.append("NEW BEST STAGE!")
	if report.get("best_score", false):
		news.append("NEW BEST SCORE!")
	for b: BikeData in report.get("unlocked", []):
		news.append("UNLOCKED: %s" % b.display_name.to_upper())
	var st: Dictionary = report.get("stats", {})
	if not st.is_empty():
		names.append_array(["BEST COMBO", "TRICKS", "DISTANCE", "TOP SPEED"])
		values.append_array([RunHud.group_digits(st["best_combo"]), str(st["tricks"]),
			"%.1f KM" % st["km"], "%d KM/H" % roundi(st["top_speed"])])
	names.append_array(["BEST STAGE", "BEST SCORE"])
	values.append_array([str(Save.best_stage), RunHud.group_digits(Save.best_score)])
	names_label.text = "\n".join(names)
	values_label.text = "\n".join(values)
	news_label.text = "\n".join(news)
	news_label.visible = not news.is_empty()
	show()
	UiMotion.open_menu(self)
	await MenuInput.delay_focus(self, restart_button, input_delay)


func _on_restart() -> void:
	hide()
	restart.emit()


func _on_menu() -> void:
	hide()
	to_menu.emit()
