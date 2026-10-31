class_name FinishGate
extends Area3D
## The finish line. Crossing it ends the stage (the chunk passes `crossed`
## up to the StageBuilder). Move the node in the chunk scene to move the line.

signal crossed

var _done: bool = false
## Physics frames to ignore after entering the tree: a freshly built gate
## can report the rider as "entered" before it was ever placed (seen when the
## next stage is built while the rider is parked), which used it up.
var _settle_frames: int = 10


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	_settle_frames -= 1
	if _settle_frames <= 0:
		set_physics_process(false)


func _on_body_entered(body: Node3D) -> void:
	if _done or _settle_frames > 0 or not body is Player:
		return
	_done = true
	crossed.emit()
