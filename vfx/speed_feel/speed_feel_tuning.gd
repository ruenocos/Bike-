class_name SpeedFeelTuning
extends Resource
## Every number that sells speed on screen (v0.31 "low and loud"): the low
## chase framing, the FOV kick on speed gains and the radial blur.
## Vehicle-agnostic: framing is in multiples of SpeedFeel.vehicle_height, so a
## bigger vehicle (the tank) gets a proportionally higher, further camera.
## Edit speed_feel.tres in the Inspector; values apply live.

@export_group("Low chase framing")
## Speed ratio (speed / max speed) where the camera starts dropping low.
@export_range(0.0, 1.0, 0.01) var low_from: float = 0.45
## Speed ratio where it is fully low.
@export_range(0.0, 1.0, 0.01) var low_full: float = 0.8
## Camera height above the vehicle's centre at full speed, in vehicle heights.
## 0.45 x 1.7 m bike = about 0.75 m above the wheel hub, ~1.1 m off the ground.
@export_range(0.1, 2.0, 0.05) var low_height: float = 0.45
## Camera distance behind the vehicle at full speed, in vehicle heights.
@export_range(0.5, 6.0, 0.05) var low_distance: float = 2.0
## Pitch down (degrees) at full speed, on top of the slope follow. Low and
## nearly level puts the horizon in the upper third and the ground fills the rest.
@export_range(-10.0, 30.0, 0.5, "suffix:°") var low_pitch_deg: float = 4.0
## In the air the framing rises back by this much (0 = stays low, 1 = normal
## framing), so you can read the landing.
@export_range(0.0, 1.0, 0.05) var air_raise: float = 0.5
## Time (s) to blend between the framings.
@export_range(0.05, 2.0, 0.05, "suffix:s") var low_blend_time: float = 0.5

@export_group("FOV kick")
## Extra FOV (degrees) at a full-strength kick, on top of the speed FOV.
@export_range(0.0, 30.0, 0.5, "suffix:°") var fov_kick_deg: float = 9.0
## Time to reach the peak of a kick (ease-out).
@export_range(0.01, 0.5, 0.01, "suffix:s") var kick_attack: float = 0.1
## Time to settle back (ease-out).
@export_range(0.05, 3.0, 0.05, "suffix:s") var kick_release: float = 0.7
## A speed gain of this many m/s within ~0.15 s counts as a surge (gravity on
## the steepest slope adds well under 1 m/s in that time).
@export_range(0.5, 20.0, 0.1, "suffix:m/s") var surge_threshold: float = 2.5
## A surge this big (m/s) gives a full-strength kick.
@export_range(1.0, 30.0, 0.5, "suffix:m/s") var surge_full: float = 8.0
## Kick strength for a perfect landing and for a boost (gate, pad), 0..1.
@export_range(0.0, 1.0, 0.05) var perfect_kick: float = 0.6
@export_range(0.0, 1.0, 0.05) var boost_kick: float = 1.0

@export_group("Radial blur")
## Blur strength at max speed (0..1). Starts at blur_from.
@export_range(0.0, 1.0, 0.01) var blur_max: float = 0.75
@export_range(0.0, 1.0, 0.01) var blur_from: float = 0.35
## Extra blur at a full kick.
@export_range(0.0, 1.0, 0.01) var blur_kick: float = 0.35
## How far each pixel smears toward the centre at strength 1 (fraction of its
## distance to the centre). 0.12 = a long Haste-style smear.
@export_range(0.0, 0.4, 0.005) var blur_length: float = 0.12
## Clear ellipse around the point you ride toward (screen fractions, x/y).
@export var blur_clear: Vector2 = Vector2(0.2, 0.16)
## How quickly the blur ramps from the clear ellipse to full (ellipse radii).
@export_range(0.1, 4.0, 0.05) var blur_feather: float = 1.4
## Extra blur toward the bottom of the screen, where the ground rushes past.
@export_range(0.0, 2.0, 0.05) var blur_bottom_boost: float = 0.8
## The blur converges on where you're heading; this smooths that point.
@export_range(0.01, 1.0, 0.01, "suffix:s") var blur_center_smoothing: float = 0.15
