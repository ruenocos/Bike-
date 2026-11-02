class_name UpgradePicker
extends Control
## Pick 1 of 3 upgrades between stages (v0.31: the "Requisition" screen).
## Up/down moves between the cards, A picks one. Down past the last card
## reaches Reroll (new cards for one reroll, earned with boost gates and
## score: RunRules); hidden when you have none.

signal picked(upgrade: UpgradeData)
signal reroll_requested

@export_range(0.0, 3.0, 0.05, "suffix:s") var input_delay: float = 0.5
## Crew art on the left (empty = the big 補給 kana instead).
@export var portrait: Texture2D:
	set(value):
		portrait = value
		if is_node_ready():
			_apply_portrait()

@onready var buttons: Array[Button] = [%Choice1, %Choice2, %Choice3]
@onready var reroll_button: Button = %Reroll
@onready var names: Array[Label] = [%Name1, %Name2, %Name3]
@onready var descs: Array[Label] = [%Desc1, %Desc2, %Desc3]
@onready var cards: Control = %Cards

var _choices: Array[UpgradeData] = []


func _ready() -> void:
	hide()
	_apply_portrait()
	for i: int in buttons.size():
		buttons[i].pressed.connect(_on_pressed.bind(i))
		buttons[i].focus_entered.connect(func() -> void: UiMotion.kick(buttons[i], 0.04, 0.16))
	reroll_button.pressed.connect(func() -> void: reroll_requested.emit())


func _apply_portrait() -> void:
	(%Portrait as TextureRect).texture = portrait
	(%Portrait as TextureRect).visible = portrait != null
	($BigKana as Control).visible = portrait == null


func open(choices: Array[UpgradeData], rerolls: int = 0) -> void:
	_choices = choices
	reroll_button.visible = rerolls > 0
	reroll_button.text = "REROLL  (%d LEFT)" % rerolls
	for i: int in buttons.size():
		buttons[i].visible = i < choices.size()
		if i < choices.size():
			names[i].text = choices[i].display_name.to_upper()
			descs[i].text = choices[i].description
	show()
	var i: int = 0
	for button: Button in buttons:
		if button.visible:
			UiMotion.tape_in(button, 0.22, 0.06 * i)
			i += 1
	UiMotion.slide_in($Header as Control, Vector2(-200.0, 0.0), 0.3)
	for button: Button in buttons:
		button.disabled = true
	reroll_button.disabled = true
	await MenuInput.delay_focus(self, buttons[0], input_delay)
	for button: Button in buttons:
		button.disabled = false
	reroll_button.disabled = false


func _on_pressed(index: int) -> void:
	if index >= _choices.size():
		return
	hide()
	picked.emit(_choices[index])
