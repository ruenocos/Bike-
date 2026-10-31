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

