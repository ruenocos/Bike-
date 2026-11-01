class_name RunOver
extends Control
## The collapse caught you: the run is over. Shows the run and your bests
## (v0.14: NEW BEST, bikes this run unlocked). A rides again, the second
## button goes to the title screen.

signal restart
signal to_menu

@export_range(0.0, 3.0, 0.05, "suffix:s") var input_delay: float = 0.8

@onready var stats_label: Label = %Stats
@onready var restart_button: Button = %Restart
@onready var menu_button: Button = %Menu
@onready var news_label: Label = %News


func _ready() -> void:
	hide()
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)


func open(stage: int, run_score: int, upgrades: int, report: Dictionary = {}) -> void:
	stats_label.text = "Reached stage   %d\nRun score       %d\nUpgrades        %d\n\nBest stage      %d\nBest score      %d" % [
		stage, run_score, upgrades, Save.best_stage, Save.best_score]
	var news: PackedStringArray = []
	if report.get("best_stage", false):
		news.append("NEW BEST STAGE!")
	if report.get("best_score", false):
		news.append("NEW BEST SCORE!")
	for b: BikeData in report.get("unlocked", []):
		news.append("Unlocked: %s" % b.display_name)
	var st: Dictionary = report.get("stats", {})
	if not st.is_empty():
		stats_label.text += "\n\nBest combo      %d\nTricks          %d\nBoost gates     %d\nDistance        %.1f km\nTop speed       %d km/h\nTime riding     %d:%02d" % [
			st["best_combo"], st["tricks"], st["gates"], st["km"], roundi(st["top_speed"]),
			floori(st["time"] / 60.0), int(st["time"]) % 60]
	news_label.text = "\n".join(news)
	news_label.visible = not news.is_empty()
	show()
	await MenuInput.delay_focus(self, restart_button, input_delay)


func _on_restart() -> void:
	hide()
	restart.emit()


func _on_menu() -> void:
	hide()
	to_menu.emit()
