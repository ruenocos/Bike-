@tool
class_name DifficultyCurve
extends Resource
## How hard a run gets, stage by stage, in one place (hazards/difficulty.tres).
## Read by the Collapse (chase speed, leash, mercy), the Game (what a crash or
## a respawn costs) and the HazardDirector (falling trees per stage).
## Every "by stage" array is one entry per stage, stage 1 first; stages past
## the end use the last entry. Edit the numbers in the Inspector.
##
## v0.33 balance pass (Wons: "we cant even beat the second stage"): stages 1-2
## are a warm-up that forgives a respawn or a few crashes; the pressure of
## the old stage 2 now starts at stage 3-4 and the late stages are unchanged.

@export_group("Collapse chase")
## Speed when it starts moving (m/s)...
@export var start_speed_by_stage: Array[float] = [22.0, 24.0, 28.0, 31.0, 33.0, 35.0, 37.0, 38.0]
## ...gaining this much per second (m/s²)...
@export var accel_by_stage: Array[float] = [0.5, 0.6, 0.8, 0.9, 1.0, 1.1, 1.3, 1.4]
## ...up to this (m/s). Clean riding cruises at ~50-57; the slow technical
## bits (set pieces, climbs) are ~35-45.
@export var max_speed_by_stage: Array[float] = [38.0, 40.0, 43.0, 45.5, 47.5, 49.5, 51.0, 52.5]
## The leash: it's never further than this behind you (m). Clean riding sits
## at the leash, so this is your mistake budget.
@export var leash_by_stage: Array[float] = [230.0, 210.0, 180.0, 150.0, 125.0, 110.0, 100.0, 95.0]
## Mercy: while it's closer than `mercy_gap`, it moves at this fraction of
## its speed, so a rider who is back up to speed can pull away again
## (1 = no mercy).
@export var mercy_by_stage: Array[float] = [0.7, 0.75, 0.85, 0.9, 0.95, 1.0]
## How close counts as "close" for the mercy (m).
@export_range(0.0, 300.0, 5.0, "suffix:m") var mercy_gap: float = 90.0

@export_group("Penalties")
## Time cost of a crash / bailed landing (s): the stage clock and the
## collapse gain this many seconds. Crashes never end the run by themselves.
@export_range(0.0, 20.0, 0.1, "suffix:s") var bail_time_cost: float = 0.7
## Time cost of an out-of-bounds or fall respawn (s).
@export_range(0.0, 20.0, 0.1, "suffix:s") var respawn_time_cost: float = 2.0
## A penalty moves the collapse by seconds x its speed (at least this, m/s)...
@export_range(0.0, 80.0, 1.0, "suffix:m/s") var penalty_min_speed: float = 30.0
## ...but a penalty alone never brings it closer than this (m).
@export_range(0.0, 200.0, 1.0, "suffix:m") var penalty_min_gap: float = 70.0
## A respawn always puts the collapse at least this far behind you first
## (m), so landing behind it (abyss respawn points sit before the drop) can't
## end the run on the spot. The respawn penalty then applies as usual.
@export_range(0.0, 400.0, 5.0, "suffix:m") var respawn_safe_gap: float = 110.0
## After a respawn you keep this fraction of your speed...
@export_range(0.0, 1.0, 0.05) var respawn_speed: float = 0.7
## ...but never less than this (m/s), so you're not slower than the collapse.
@export_range(0.0, 60.0, 1.0, "suffix:m/s") var respawn_min_speed: float = 34.0

@export_group("Hazards")
## Falling trees placed per stage.
@export var trees_per_stage: Array[int] = [0, 1, 1, 2, 2, 3, 3, 3]


## This stage's entry of a "by stage" float array (stage_index 0 = stage 1).
static func pick(values: Array[float], stage_index: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(stage_index, 0, values.size() - 1)]
