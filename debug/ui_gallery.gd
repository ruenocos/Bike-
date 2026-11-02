extends Node
## UI gallery (v0.31): every HUD state and menu with sample data, one after
## another, so the look can be checked without riding. Open
## debug/ui_gallery.tscn and press F6, or record stills:
##   <exe> --path . res://debug/ui_gallery.tscn -- --ui-shots=<abs dir>
## Each page holds `page_time` seconds; the screenshot is taken near the end.

@export_range(0.5, 10.0, 0.1, "suffix:s") var page_time: float = 2.0

@onready var hud: RunHud = $RunHud
@onready var menus: CanvasLayer = $Menus

var _shots_dir: String = ""


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-shots="):
			_shots_dir = arg.trim_prefix("--ui-shots=")
			DirAccess.make_dir_recursive_absolute(_shots_dir)
	Save.enabled = false
	_run.call_deferred()


func _shot(page: String) -> void:
	await get_tree().create_timer(page_time * 0.85).timeout
	if _shots_dir != "":
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_shots_dir.path_join("ui_%s.png" % page))
	await get_tree().create_timer(page_time * 0.15).timeout


func _hide_menus() -> void:
	for c: Node in menus.get_children():
		(c as Control).hide()


func _feed_hud(gap: float, mult: int, points: int, speed: float) -> void:
	hud.update_run(2, 75.4, 12450, gap, 1400.0, 300.0, 3600.0, 3500.0, 1)
	hud.update_rider(0.016, speed, 60.0, mult > 0, mult, points)


func _run() -> void:
	_hide_menus()
	hud.show_title(2, "Snowline", "Thin air, fast snow")
	_feed_hud(400.0, 0, 0, 30.0)
	await _shot("1_title_card")

	_feed_hud(400.0, 5, 850, 52.0)
	Events.trick_completed.emit("Frontloop", 400)
	await _shot("2_hud_combo")

	_feed_hud(140.0, 7, 1600, 58.0)
	hud.play_cut_in()
	await get_tree().create_timer(0.2).timeout
	if _shots_dir != "":
		get_viewport().get_texture().get_image().save_png(_shots_dir.path_join("ui_3_perfect.png"))
	await get_tree().create_timer(page_time * 0.6).timeout

	_feed_hud(40.0, 0, 0, 44.0)
	hud.flash_penalty(1.5)
	hud.flash_message("SHIELD!", Color(0.949, 0.718, 0.02))
	await _shot("4_hud_danger")

	hud.visible = false
	var summary: StageSummary = menus.get_node(^"StageSummary") as StageSummary
	summary.open(2, 102.3, 3210, 8400, 12450, 3, 20, 1, 1)
	await _shot("5_stage_clear")
	_hide_menus()

	var picker: UpgradePicker = menus.get_node(^"UpgradePicker") as UpgradePicker
	var ups: Array[UpgradeData] = [load("res://scoring/upgrades/air_control.tres"),
		load("res://scoring/upgrades/perfect_streak.tres"), load("res://scoring/upgrades/crash_shield.tres")]
	picker.open(ups, 1)
	await get_tree().create_timer(0.8).timeout
	await _shot("6_requisition")
	_hide_menus()

	var run_over: RunOver = menus.get_node(^"RunOver") as RunOver
	run_over.open(3, 12450, 2, {"best_score": true, "stats": {"best_combo": 3210, "tricks": 14, "gates": 6,
		"km": 9.4, "top_speed": 214.0, "time": 312.0}})
	await _shot("7_run_over")
	_hide_menus()

	var pause: PauseMenu = menus.get_node(^"PauseMenu") as PauseMenu
	pause.open()
	await _shot("8_pause")
	_hide_menus()

	var title: MainMenu = menus.get_node(^"MainMenu") as MainMenu
	var bikes: Array[BikeData] = [load("res://player/bikes/trail.tres"), load("res://player/bikes/dart.tres"),
		load("res://player/bikes/hopper.tres"), load("res://player/bikes/tank.tres")]
	title.open(bikes, 0)
	await get_tree().create_timer(0.6).timeout
	await _shot("9_title")
	if _shots_dir != "":
		get_tree().quit()
