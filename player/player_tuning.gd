class_name PlayerTuning
extends Resource
## All feel values live here. Tune them in the inspector while the game runs.
## Edit player/player_tuning.tres (not this script) to change the numbers.

@export_group("Speed")
## Speed you start a run with (m/s).
@export var base_speed: float = 14.0
## Hard cap (m/s). FOV and speed lines scale against this.
@export var max_speed: float = 40.0
## Pedalling only helps up to this speed (m/s). Above it, speed comes from slopes and landings.
@export var pedal_max_speed: float = 18.0
@export var pedal_accel: float = 9.0
@export var brake_decel: float = 18.0
## Linear rolling resistance (1/s).
@export var rolling_drag: float = 0.04
## Quadratic air drag. Sets the natural top speed on a slope.
@export var air_drag: float = 0.0012
@export var gravity: float = 24.0
## Small push into the ground while riding so the body keeps contact on ramps (m/s).
@export var ground_stick_velocity: float = 2.0

@export_group("Steering")
## Yaw rate at low speed (deg/s).
@export var steer_rate_low: float = 140.0
## Yaw rate at max speed (deg/s). Lower = more stable at speed.
@export var steer_rate_high: float = 55.0
@export var air_steer_rate: float = 60.0
## How fast the bike visually banks into turns (deg at full steer).
@export var lean_into_turn_deg: float = 22.0

@export_group("Pump")
## Speed multiplier added per clean pump (0.04 = +4%).
@export var pump_gain: float = 0.04
## A pump counts when the ground is getting steeper downhill (back side of a bump)
## by at least this much compared to the last ~0.2 s (deg).
@export var pump_min_slope_deg: float = 2.0
@export var pump_cooldown: float = 0.35

@export_group("Hop")
@export var hop_min_velocity: float = 5.0
@export var hop_max_velocity: float = 9.5
@export var hop_full_charge: float = 0.25

@export_group("Air")
## Pitch rate when leaning in the air (deg/s). Visual only for now.
@export var air_pitch_rate: float = 180.0

@export_group("Landing")
@export var perfect_angle_deg: float = 10.0
@export var good_angle_deg: float = 25.0
@export var perfect_bonus: float = 0.12
@export var bad_penalty: float = 0.30
## Touchdowns softer than this (m/s into the ground) are just roll-ins: no grade.
@export var land_min_impact: float = 2.0
## Time spent in Land before control returns to Ride (s).
@export var land_duration: float = 0.08
@export var hit_stop_perfect: float = 0.04
@export var bail_duration: float = 0.9

@export_group("Input")
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.12

@export_group("Tricks")
## Window for a right-stick flick to read as a trick gesture (s).
## The stick must go from neutral to past trick_gesture_threshold within this time.
@export var trick_gesture_window: float = 0.15
## Stick magnitude that counts as a full flick (0-1).
@export var trick_gesture_threshold: float = 0.7
## Stick magnitude below which the stick counts as back at neutral (0-1).
@export var trick_neutral_threshold: float = 0.3
## A new flick in the last part of a trick chains the next one (0.3 = last 30%).
@export var trick_chain_window: float = 0.3
## Height above the wheels the bike spins around (m). Roughly the rider's hips.
@export var trick_pivot_height: float = 0.7

@export_group("Grind")
## Press grind within this distance of a rail to snap on (m).
@export var rail_snap_radius: float = 1.5
## A grind press is remembered this long, so pressing a hair early still snaps (s).
@export var grind_buffer: float = 0.15
## Speed lost per second while grinding (m/s^2).
@export var grind_drag: float = 1.0
## Never grind slower than this; snapping on at an angle keeps some flow (m/s).
@export var grind_min_speed: float = 6.0
## Below this speed you fall off the rail (m/s).
@export var grind_fall_off_speed: float = 2.0
## Time to slide from where you were onto the rail (s).
@export var grind_snap_time: float = 0.06
## No re-snapping for this long after leaving a rail (s).
@export var grind_resnap_cooldown: float = 0.35
## Small upward pop when riding off the end of a rail (m/s).
@export var grind_exit_pop: float = 2.0

@export_group("Combo")
## Combo banks after this long of plain riding (s).
@export var combo_drop_time: float = 1.5
## The multiplier is the number of actions in the combo, capped here.
@export var combo_multiplier_cap: int = 10
@export var perfect_landing_score: int = 50
@export var grind_score_per_second: float = 120.0

@export_group("Camera")
@export var fov_base: float = 75.0
@export var fov_max: float = 95.0
## Time for FOV to catch up with speed (s, ease-out).
@export var fov_smoothing: float = 0.25
@export var cam_distance: float = 6.5
@export var cam_height: float = 1.6
## Downward pitch of the camera (deg).
@export var cam_pitch_deg: float = 12.0
@export var cam_position_damping: float = 0.08
@export var cam_rotation_damping: float = 0.2
## How far ahead along velocity the camera looks (m at max speed).
@export var cam_look_ahead: float = 3.0
@export var cam_punch_distance: float = 0.35
@export var cam_punch_time: float = 0.12

@export_group("Speed lines")
## Speed lines start fading in above this fraction of max_speed (0.7 = 70%).
@export var speed_lines_threshold: float = 0.7
## ...and reach full strength at this fraction of max_speed.
@export var speed_lines_full: float = 0.9
@export var speed_lines_max_alpha: float = 0.6
## Time for the lines to catch up with speed (s, ease-out).
@export var speed_lines_fade_time: float = 0.3
