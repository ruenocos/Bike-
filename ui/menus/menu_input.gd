class_name MenuInput
extends RefCounted
## Gamepad helpers shared by the menus.


## Disables `button` for `delay` seconds, then focuses it. Godot note: a
## focused Button is what ui_accept (A on the pad) presses, and the D-pad /
## left stick (ui_left/right/up/down) moves focus between buttons.
static func delay_focus(menu: Control, button: Button, delay: float) -> void:
	button.disabled = true
	await menu.get_tree().create_timer(delay).timeout
	button.disabled = false
	button.grab_focus()
