class_name PauseMenu
extends Control
## Start pauses the run (v0.19): Resume (or Start / B again), Restart run,
## Title screen. Works while the tree is paused (process_mode Always).

signal resumed
signal restart
signal to_menu

@export_range(0.0, 2.0, 0.05, "suffix:s") var input_delay: float = 0.2

@onready var resume_button: Button = %Resume
@onready var restart_button: Button = %RestartRun
@onready var menu_button: Button = %TitleScreen


func _ready() -> void:
	hide()
	resume_button.pressed.connect(_close.bind(resumed))
	restart_button.pressed.connect(_close.bind(restart))
	menu_button.pressed.connect(_close.bind(to_menu))


func open() -> void:
	show()
	await MenuInput.delay_focus(self, resume_button, input_delay)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or resume_button.disabled:
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close(resumed)


func _close(which: Signal) -> void:
	hide()
	which.emit()
