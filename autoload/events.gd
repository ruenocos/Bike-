extends Node
## Game-wide signal bus. Children signal up; anything game-wide goes through here.

@warning_ignore("unused_signal")
signal landed(grade: StringName)
@warning_ignore("unused_signal")
signal combo_banked(score: int)
@warning_ignore("unused_signal")
signal bailed
@warning_ignore("unused_signal")
signal combo_dropped
@warning_ignore("unused_signal")
signal trick_completed(trick_name: String, score: int)
@warning_ignore("unused_signal")
signal grind_started
@warning_ignore("unused_signal")
signal carve_started
@warning_ignore("unused_signal")
signal lip_air
## Rode through a BoostGate (its score).
@warning_ignore("unused_signal")
signal gate_collected(score: int)

## Something gave the vehicle a burst of speed (boost, perfect landing, a
## drop), strength 0..1. SpeedFeel kicks the FOV and blur on it and re-emits
## its own detected surges here, so sound can hang a whoosh off it.
@warning_ignore("unused_signal")
signal speed_gained(strength: float)
