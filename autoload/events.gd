extends Node
## Game-wide signal bus. Children signal up; anything game-wide goes through here.

@warning_ignore("unused_signal")
signal landed(grade: StringName)
@warning_ignore("unused_signal")
signal combo_banked(score: int)
@warning_ignore("unused_signal")
signal bailed
