class_name ComboTracker
extends Node
## Combo scoring. Child of Player; states call these functions (call down).
##
## A combo is a chain of actions (tricks, grinds, wall rides, perfect landings).
## Score = sum of action points x multiplier, multiplier = number of actions
## (capped). Plain riding for combo_drop_time banks it into the run total.
## A bail drops it and the points are lost.

var player: Player

## Points collected in this combo, before the multiplier.
var points: float = 0.0
var actions: int = 0
## Time left before the combo banks (s). Only runs down during plain riding.
var timer: float = 0.0
## Everything banked this run.
var run_total: int = 0
var last_banked: int = 0


func setup(owner_player: Player) -> void:
	player = owner_player


func is_active() -> bool:
	return actions > 0


func get_multiplier() -> int:
	return mini(actions, player.tuning.combo_multiplier_cap)


func get_total() -> int:
	return floori(points) * get_multiplier()


## One action: a trick, a grind, a wall ride, a perfect landing.
func add_action(score: int) -> void:
	actions += 1
	points += score
	timer = player.tuning.combo_drop_time


## Grinding: points every tick and the combo stays alive.
func add_grind_time(delta: float) -> void:
	_add_timed_points(player.tuning.grind_score_per_second, delta)


## Wall riding: same as grinding, its own rate.
func add_wall_ride_time(delta: float) -> void:
	_add_timed_points(player.tuning.wall_ride_score_per_second, delta)


func _add_timed_points(per_second: float, delta: float) -> void:
	points += per_second * delta
	timer = player.tuning.combo_drop_time


## A good (not perfect) landing keeps the chain going but scores nothing.
func keep_alive() -> void:
	if is_active():
		timer = player.tuning.combo_drop_time


## Called from Ride: plain riding runs the timer down and banks the combo.
func tick(delta: float) -> void:
	if not is_active():
		return
	timer -= delta
	if timer <= 0.0:
		bank()


func bank() -> void:
	if not is_active():
		return
	last_banked = get_total()
	run_total += last_banked
	Events.combo_banked.emit(last_banked)
	_reset()


func drop() -> void:
	if not is_active():
		return
	_reset()
	Events.combo_dropped.emit()


func _reset() -> void:
	points = 0.0
	actions = 0
	timer = 0.0
