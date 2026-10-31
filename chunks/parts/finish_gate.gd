class_name FinishGate
extends Area3D
## The finish line. Crossing it ends the stage (the chunk passes `crossed`
## up to the StageBuilder). Move the node in the chunk scene to move the line.

signal crossed

var _done: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _done or not body is Player:
		return
	_done = true
	crossed.emit()
