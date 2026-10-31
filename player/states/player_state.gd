class_name PlayerState
extends Node
## Base class for player states. Override the three functions below.
## `player` and `machine` are filled in by PlayerStateMachine.setup().

var player: Player
var machine: PlayerStateMachine


func enter(_msg: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
