extends Node
## Gamepad check for the menus: real joypad button / d-pad events (not
## actions), the way a pad sends them. Opens each menu and checks:
##   - stage summary: A continues
##   - upgrade picker: A picks the focused card; d-pad down reaches REROLL and A rerolls
##   - run over: A restarts, d-pad down + A goes to the title screen
##   - pause menu (v0.19): A resumes, d-pad down twice + A goes to the title
##   - title screen (v0.14): d-pad right shows the next bike, A on a locked
##	 bike does nothing, back to the first bike and A rides on it
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
	# Never touch the player's real save file from a test.
	Save.enabled = false
	Save.best_stage = 0
	Save.best_score = 0
	Save.total_gates = 0
	Save.runs = 0
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var summary: StageSummary = (load("res://ui/menus/stage_summary.tscn") as PackedScene).instantiate() as StageSummary
	var picker: UpgradePicker = (load("res://ui/menus/upgrade_picker.tscn") as PackedScene).instantiate() as UpgradePicker
	var run_over: RunOver = (load("res://ui/menus/run_over.tscn") as PackedScene).instantiate() as RunOver
	var title: MainMenu = (load("res://ui/menus/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	var pause: PauseMenu = (load("res://ui/menus/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	for menu: Control in [summary, picker, run_over, title, pause]:
		layer.add_child(menu)
	var got: Dictionary[String, int] = {"continued": 0, "picked": 0, "reroll": 0, "restart": 0, "menu": 0, "ride": 0}
	var rode: Array[BikeData] = []
	run_over.to_menu.connect(func() -> void: got["menu"] += 1)
	title.ride.connect(func(b: BikeData) -> void:
		got["ride"] += 1
		rode.append(b))
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
	run_over.open(2, 1000, 1)
	await get_tree().create_timer(1.2).timeout
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_A)
	_check(got["menu"] == 1, "run over: d-pad down + A goes to the title screen")

	var paused: Dictionary[String, int] = {"resumed": 0, "menu": 0}
	pause.resumed.connect(func() -> void: paused["resumed"] += 1)
	pause.to_menu.connect(func() -> void: paused["menu"] += 1)
	pause.open()
	await get_tree().create_timer(0.5).timeout
	await _button(JOY_BUTTON_A)
	_check(paused["resumed"] == 1, "pause menu: A resumes")
	pause.open()
	await get_tree().create_timer(0.5).timeout
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_A)
	_check(paused["menu"] == 1, "pause menu: d-pad down twice + A goes to the title screen")

	var bikes: Array[BikeData] = [load("res://player/bikes/trail.tres"), load("res://player/bikes/dart.tres")]
	title.open(bikes, 0)
	await get_tree().create_timer(0.8).timeout
	await _button(JOY_BUTTON_DPAD_RIGHT)
	_check(title.index == 1, "title screen: d-pad right shows the next bike")
	await _button(JOY_BUTTON_A)
	_check(got["ride"] == 0, "title screen: A on a locked bike does nothing")
	await _button(JOY_BUTTON_DPAD_LEFT)
	await _button(JOY_BUTTON_A)
	_check(got["ride"] == 1 and rode[0] == bikes[0], "title screen: back to the first bike, A rides it")

	print("MENU TEST %s" % ("PASSED" if _failures.is_empty() else "FAILED (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
