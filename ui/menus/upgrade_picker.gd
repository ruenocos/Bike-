class_name UpgradePicker
extends Control
## Pick 1 of 3 upgrades between stages. Left/right moves between the cards,
## A picks one.

signal picked(upgrade: UpgradeData)

@export_range(0.0, 3.0, 0.05, "suffix:s") var input_delay: float = 0.5

@onready var buttons: Array[Button] = [%Choice1, %Choice2, %Choice3]

var _choices: Array[UpgradeData] = []


func _ready() -> void:
	hide()
	for i: int in buttons.size():
		buttons[i].pressed.connect(_on_pressed.bind(i))


func open(choices: Array[UpgradeData]) -> void:
	_choices = choices
	for i: int in buttons.size():
		buttons[i].visible = i < choices.size()
		if i < choices.size():
			buttons[i].text = "%s\n\n%s" % [choices[i].display_name.to_upper(), choices[i].description]
	show()
	for button: Button in buttons:
		button.disabled = true
	await MenuInput.delay_focus(self, buttons[0], input_delay)
	for button: Button in buttons:
		button.disabled = false


func _on_pressed(index: int) -> void:
	if index >= _choices.size():
		return
	hide()
	picked.emit(_choices[index])
