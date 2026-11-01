@tool
class_name RiderPose
extends Resource
## One body pose of the rider on the bike (player/rider/poses/*.tres). The
## RiderRig blends between these; arms and legs are solved to reach the grips
## and pedals, so a pose only says where the hips / torso go and how far the
## hands and feet move off the bike. Units are metres in bike space
## (y up, -z forward, ground at 0).

## Hip centre.
@export var hips: Vector3 = Vector3(0.0, 1.08, 0.14)
## Forward lean of the torso (deg, 0 = upright).
@export_range(-60.0, 90.0, 0.5) var torso_pitch_deg: float = 30.0
## Head tilt on top of the torso (deg, + = look down).
@export_range(-60.0, 60.0, 0.5) var head_pitch_deg: float = -20.0
## Feet off the pedals (added to the pedal points).
@export var foot_left: Vector3 = Vector3.ZERO
@export var foot_right: Vector3 = Vector3.ZERO
## Hands off the grips (added to the grip points).
@export var hand_left: Vector3 = Vector3.ZERO
@export var hand_right: Vector3 = Vector3.ZERO
## Tilts the whole bike (deg, + = nose up), e.g. a manual in the air.
@export_range(-45.0, 45.0, 0.5) var bike_pitch_deg: float = 0.0


func blended(to: RiderPose, t: float) -> RiderPose:
	var p: RiderPose = RiderPose.new()
	p.hips = hips.lerp(to.hips, t)
	p.torso_pitch_deg = lerpf(torso_pitch_deg, to.torso_pitch_deg, t)
	p.head_pitch_deg = lerpf(head_pitch_deg, to.head_pitch_deg, t)
	p.foot_left = foot_left.lerp(to.foot_left, t)
	p.foot_right = foot_right.lerp(to.foot_right, t)
	p.hand_left = hand_left.lerp(to.hand_left, t)
	p.hand_right = hand_right.lerp(to.hand_right, t)
	p.bike_pitch_deg = lerpf(bike_pitch_deg, to.bike_pitch_deg, t)
	return p


## Moves this pose toward `to` (in place), `t` 0..1.
func approach(to: RiderPose, t: float) -> void:
	hips = hips.lerp(to.hips, t)
	torso_pitch_deg = lerpf(torso_pitch_deg, to.torso_pitch_deg, t)
	head_pitch_deg = lerpf(head_pitch_deg, to.head_pitch_deg, t)
	foot_left = foot_left.lerp(to.foot_left, t)
	foot_right = foot_right.lerp(to.foot_right, t)
	hand_left = hand_left.lerp(to.hand_left, t)
	hand_right = hand_right.lerp(to.hand_right, t)
	bike_pitch_deg = lerpf(bike_pitch_deg, to.bike_pitch_deg, t)
