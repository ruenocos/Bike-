extends Node
## Gamepad check for the menus: real joypad button / d-pad events (not
## actions), the way a pad sends them. Opens each menu and checks:
##   - stage summary: A continues
##   - upgrade picker: A picks the focused card; d-pad down reaches REROLL and A rerolls
##   - run over: A restarts
## Found in v0.9.1: ui_accept had no pad button, so A did nothing in menus.
## Run:  <exe> --path . res://debug/menu_test.tscn   (not headless: GUI focus needs a window)
## Exits with code 1 on failure.

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_run.call_deferred()


func _button(index: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = index
		e.pressed = pressed
		Input.parse_input_event(e)
		await get_tree().process_frame
		await get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	print("%-4s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _run() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var summary: StageSummary = (load("res://ui/menus/stage_summary.tscn") as PackedScene).instantiate() as StageSummary
	var picker: UpgradePicker = (load("res://ui/menus/upgrade_picker.tscn") as PackedScene).instantiate() as UpgradePicker
	var run_over: RunOver = (load("res://ui/menus/run_over.tscn") as PackedScene).instantiate() as RunOver
	for menu: Control in [summary, picker, run_over]:
		layer.add_child(menu)
	var got: Dictionary[String, int] = {"continued": 0, "picked": 0, "reroll": 0, "restart": 0}
	summary.continued.connect(func() -> void: got["continued"] += 1)
	picker.picked.connect(func(_u: UpgradeData) -> void: got["picked"] += 1)
	picker.reroll_requested.connect(func() -> void: got["reroll"] += 1)
	run_over.restart.connect(func() -> void: got["restart"] += 1)
	var ups: Array[UpgradeData] = [load("res://scoring/upgrades/clean_landings.tres"),
		load("res://scoring/upgrades/long_fuse.tres"), load("res://scoring/upgrades/pump_legs.tres")]

	summary.open(1, 60.0, 100, 100, 100, 3, 20, 1, 1)
	await get_tree().create_timer(1.0).timeout
	await _button(JOY_BUTTON_A)
	_check(got["continued"] == 1, "stage summary: A continues")

	picker.open(ups, 1)
	await get_tree().create_timer(1.0).timeout
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_A)
	_check(got["reroll"] == 1, "upgrade picker: d-pad down + A rerolls")
	picker.open(ups, 0)
	await get_tree().create_timer(1.0).timeout
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _button(JOY_BUTTON_A)
	_check(got["picked"] == 1, "upgrade picker: d-pad right + A picks a card")

	run_over.open(2, 1000, 1)
	await get_tree().create_timer(1.2).timeout
	await _button(JOY_BUTTON_A)
	_check(got["restart"] == 1, "run over: A restarts")

	print("MENU TEST %s" % ("PASSED" if _failures.is_empty() else "FAILED (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
