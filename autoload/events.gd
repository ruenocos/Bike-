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

# Vehicle events (v0.31), generic so sound and speed feel can listen without
# knowing the vehicle. Listed in CLAUDE.md.
## Something got crushed: its kind (&"log", &"fence", &"tree") and where.
@warning_ignore("unused_signal")
signal prop_crushed(kind: StringName, position: Vector3)
@warning_ignore("unused_signal")
signal trick_started(trick_name: StringName)
## A trick finished and the landing after it was graded.
@warning_ignore("unused_signal")
signal trick_landed(trick_name: StringName, grade: StringName)
## The cannon went off: kind &"hop" or &"boost".
@warning_ignore("unused_signal")
signal cannon_fired(kind: StringName)
@warning_ignore("unused_signal")
signal tread_grind_started
@warning_ignore("unused_signal")
signal tread_grind_ended
## Speed was just added (m/s): boosts, cannon hops, perfect landings.
@warning_ignore("unused_signal")
signal speed_gained(amount: float)
