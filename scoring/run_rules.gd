class_name RunRules
extends Resource
## What score and boost gates are worth between stages (scoring/run_rules.tres).
## At each stage end you earn upgrade rerolls: one per `gates_per_reroll`
## boost gates collected that stage, plus one per `score_per_reroll` points
## banked that stage. Unused rerolls carry over for the rest of the run.

## Boost gates per reroll (0 = gates don't earn rerolls).
@export_range(0, 20) var gates_per_reroll: int = 3
## Banked stage score per reroll (0 = score doesn't earn rerolls).
@export_range(0, 100000, 100) var score_per_reroll: int = 6000
## Rerolls a run starts with.
@export_range(0, 10) var start_rerolls: int = 0
## Most rerolls you can hold.
@export_range(1, 20) var max_rerolls: int = 5


## Rerolls earned for one stage.
func earned(gates: int, stage_score: int) -> int:
	var count: int = 0
	if gates_per_reroll > 0:
		count += floori(float(gates) / gates_per_reroll)
	if score_per_reroll > 0:
		count += floori(float(stage_score) / score_per_reroll)
	return count
