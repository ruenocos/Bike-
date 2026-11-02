class_name PlayerStateMachine
extends Node
## Runs one PlayerState at a time. States are the child nodes of this node,
## and they are looked up by node name (Ride, Air, Land, Grind, Bail).

signal state_changed(state_name: StringName)

@export var initial_state: PlayerState

var state: PlayerState
var _states: Dictionary[StringName, PlayerState] = {}


func setup(player: Player) -> void:
	for child: Node in get_children():
		if child is PlayerState:
			var player_state: PlayerState = child as PlayerState
			player_state.player = player
			player_state.machine = self
			_states[StringName(child.name)] = player_state
	state = initial_state
	state.enter({})


func physics_update(delta: float) -> void:
	state.physics_update(delta)


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	if not _states.has(state_name):
		push_error("No player state named %s" % state_name)
		return
	state.exit()
	state = _states[state_name]
	# Before enter(): Land can hand straight over to Ride or Bail in its
	# enter(), and listeners should hear Land first.
	state_changed.emit(state_name)
	state.enter(msg)


func get_state_name() -> StringName:
	return StringName(state.name) if state else &"-"
