extends Node
## Meta progression (v0.14): lifetime stats in user://save.cfg (best stage,
## best score, boost gates in total, runs) and the chosen bike. Bikes unlock
## from these stats (BikeData.is_unlocked), so nothing else needs saving.
## Bots and tests don't touch the file: `--autopilot` or `--no-save` (or a
## headless run) keeps everything in memory.

const SAVE_PATH: String = "user://save.cfg"

var best_stage: int = 0
var best_score: int = 0
var total_gates: int = 0
var runs: int = 0
## resource_path of the chosen BikeData ("" = the first bike).
var bike: String = ""
## False for bots and tests: stats still count for the session, no file.
var enabled: bool = true


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	enabled = not (args.has("--autopilot") or args.has("--no-save") or DisplayServer.get_name() == "headless")
	if enabled:
		load_file()


func load_file() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_stage = int(cfg.get_value("stats", "best_stage", 0))
	best_score = int(cfg.get_value("stats", "best_score", 0))
	total_gates = int(cfg.get_value("stats", "total_gates", 0))
	runs = int(cfg.get_value("stats", "runs", 0))
	bike = String(cfg.get_value("bike", "selected", ""))


func save_file() -> void:
	if not enabled:
		return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("stats", "best_stage", best_stage)
	cfg.set_value("stats", "best_score", best_score)
	cfg.set_value("stats", "total_gates", total_gates)
	cfg.set_value("stats", "runs", runs)
	cfg.set_value("bike", "selected", bike)
	cfg.save(SAVE_PATH)


func is_unlocked(b: BikeData) -> bool:
	return b.is_unlocked(best_stage, total_gates, best_score, runs)


## Adds a finished run. Returns what changed for the run-over screen:
## {"best_stage": bool, "best_score": bool, "unlocked": Array[BikeData]}.
func record_run(stage: int, score: int, gates: int, bikes: Array[BikeData]) -> Dictionary:
	var locked_before: Array[BikeData] = []
	for b: BikeData in bikes:
		if not is_unlocked(b):
			locked_before.append(b)
	var report: Dictionary = {"best_stage": stage > best_stage, "best_score": score > best_score}
	best_stage = maxi(best_stage, stage)
	best_score = maxi(best_score, score)
	total_gates += gates
	runs += 1
	var unlocked: Array[BikeData] = []
	for b: BikeData in locked_before:
		if is_unlocked(b):
			unlocked.append(b)
	report["unlocked"] = unlocked
	save_file()
	return report


func choose_bike(b: BikeData) -> void:
	bike = b.resource_path
	save_file()
