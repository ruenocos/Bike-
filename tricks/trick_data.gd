class_name TrickData
extends Resource
## One trick. Make a new one with right-click > New Resource > TrickData in the
## FileSystem dock, then add it to the TrickRunner's `tricks` list on the Player.
##
## Godot note: a Resource is a data file (.tres) with typed fields. Exported
## fields show up in the inspector, so tricks can be tuned without touching code.

enum Direction { UP, DOWN, LEFT, RIGHT }

@export var display_name: String = "Trick"
## Right-stick flick direction that starts this trick.
@export var direction: Direction = Direction.UP
## How long the trick takes (s). Land before it finishes and you bail.
@export var duration: float = 0.6
## Points added to the combo when the trick finishes.
@export var score: int = 100

@export_group("Visual")
## The rider's body during this trick (empty = the rig's general trick pose).
@export var pose: RiderPose
## Axis in the bike's own space: (1,0,0) pitches (flips), (0,1,0) yaws (spins).
@export var rotation_axis: Vector3 = Vector3.RIGHT
## Total rotation over the trick (deg). Negative pitch is nose down (front flip).
@export var rotation_degrees: float = 360.0
## Body squash at the middle of the trick (0 = none, 0.35 = 35% shorter).
@export var squash: float = 0.0
