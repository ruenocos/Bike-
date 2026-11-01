extends Node3D
## Lines up the rider in every pose for a look (`-- --shot=<abs png>` saves
## a still and quits). Run windowed: `<exe> --path . res://debug/rider_poses.tscn`.

const RIG: PackedScene = preload("res://player/rider/rider_rig.tscn")
const POSES: PackedStringArray = ["ride", "tuck", "pedal", "air", "trick", "grind", "bail", "nohander"]
## Trick poses (v0.22) shown after the general ones.
const TRICK_POSES: PackedStringArray = ["trick_tuck", "trick_kick_left", "trick_kick_right"]

@export var spacing: float = 1.25
@export var camera_angle_deg: float = 35.0

var _shot: String = ""
var _frames: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
		if arg.begins_with("--angle="):
			camera_angle_deg = float(arg.trim_prefix("--angle="))
	var names: PackedStringArray = POSES + TRICK_POSES
	for i: int in names.size():
		var rig: RiderRig = RIG.instantiate() as RiderRig
		if TRICK_POSES.has(names[i]):
			rig.pose_trick = load("res://player/rider/poses/%s.tres" % names[i]) as RiderPose
			rig.preview = "trick"
		else:
			rig.preview = names[i]
		rig.position = Vector3((i - (names.size() - 1) * 0.5) * spacing, 0.0, 0.0)
		add_child(rig)
		CelLook.apply(rig, true)
		var label: Label3D = Label3D.new()
		label.text = names[i]
		label.position = rig.position + Vector3(0.0, 1.9, 0.0)
		label.pixel_size = 0.004
		add_child(label)
	var cam: Camera3D = $Camera3D
	var a: float = deg_to_rad(camera_angle_deg)
	cam.position = Vector3(-sin(a) * 1.5, 1.6, cos(a) * 7.5) + Vector3(0, 0, 0)
	cam.look_at(Vector3(0.0, 0.8, 0.0))


func _process(_delta: float) -> void:
	_frames += 1
	if _shot != "" and _frames == 20:
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()
