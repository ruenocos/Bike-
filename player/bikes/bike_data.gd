class_name BikeData
extends Resource
## One bike you can ride (player/bikes/*.tres, v0.14): a colour, a few stat
## changes on top of PlayerTuning (the same UpgradeData as the run upgrades,
## applied at the start of every run) and what unlocks it. Unlocks are worked
## out from the save's lifetime stats, so they're permanent.

enum Unlock { FREE, REACH_STAGE, TOTAL_GATES, BEST_SCORE, RUNS }

@export var display_name: String = "Bike"
@export_multiline var description: String = ""
@export var frame_color: Color = Color(0.1, 0.62, 0.66)
## Stat changes for this bike (applied before any run upgrade).
@export var modifiers: Array[UpgradeData] = []
@export var unlock: Unlock = Unlock.FREE
## Stage to reach / gates to collect in total / score to beat / runs to ride.
@export var unlock_value: int = 0


func is_unlocked(best_stage: int, total_gates: int, best_score: int, runs: int) -> bool:
	match unlock:
		Unlock.REACH_STAGE:
			return best_stage >= unlock_value
		Unlock.TOTAL_GATES:
			return total_gates >= unlock_value
		Unlock.BEST_SCORE:
			return best_score >= unlock_value
		Unlock.RUNS:
			return runs >= unlock_value
	return true


func unlock_text() -> String:
	match unlock:
		Unlock.REACH_STAGE:
			return "Reach stage %d" % unlock_value
		Unlock.TOTAL_GATES:
			return "Ride through %d boost gates (all runs)" % unlock_value
		Unlock.BEST_SCORE:
			return "Score %d in one run" % unlock_value
		Unlock.RUNS:
			return "Ride %d runs" % unlock_value
	return ""


func apply(tuning: PlayerTuning) -> void:
	for m: UpgradeData in modifiers:
		if m != null:
			m.apply(tuning)
