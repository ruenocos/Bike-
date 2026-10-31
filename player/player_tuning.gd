class_name PlayerTuning
extends Resource
## All feel values live here. Tune them in the inspector while the game runs.
## Edit player/player_tuning.tres (not this script) to change the numbers.

@export_group("Speed")
## Speed you start a run with (m/s).
@export var base_speed: float = 14.0
## Hard cap (m/s). FOV and speed lines scale against this.
@export var max_speed: float = 60.0
## Pedalling only helps up to this speed (m/s). Above it, speed comes from slopes and landings.
@export var pedal_max_speed: float = 18.0
@export var pedal_accel: float = 9.0
@export var brake_decel: float = 18.0
## Linear rolling resistance (1/s). Low, so slow riding (halfpipe, runout)
## keeps its speed; air_drag does the work at high speed.
@export var rolling_drag: float = 0.015
## Quadratic air drag. Sets the natural top speed on a slope: 0.0028 tops out
## around 55 m/s on the 23 deg main descent (gravity along it 9.4 m/s^2).
@export var air_drag: float = 0.0028
@export var gravity: float = 24.0
## Small push into the ground while riding so the body keeps contact on ramps (m/s).
@export var ground_stick_velocity: float = 2.0

@export_group("Steering")
## Yaw rate at low speed (deg/s).
@export var steer_rate_low: float = 140.0
## Yaw rate at max speed (deg/s). Lower = more stable at speed. 40 still
## takes the 52 m radius berm apex at ~50 m/s on most of the stick.
@export var steer_rate_high: float = 40.0
@export var air_steer_rate: float = 60.0
## How fast the bike visually banks into turns (deg at full steer).
@export var lean_into_turn_deg: float = 22.0
## Extra bank at max speed, so fast turns look committed (deg at full steer).
@export var lean_speed_extra_deg: float = 14.0
## Time for the steer to follow the stick (s). Small = snappy, 0 = instant.
@export_range(0.0, 0.3, 0.005) var steer_response_time: float = 0.0
## Stick response curve: 1 = linear, >1 = finer near the middle, full lock unchanged.
@export_range(1.0, 3.0, 0.05) var steer_curve: float = 1.0
## Hard carving at speed costs a little speed: this much per second at full
## steer (m/s^2)...
@export_range(0.0, 20.0, 0.1) var carve_drag: float = 0.0
## ...fading in from this fraction of max_speed.
@export_range(0.0, 1.0, 0.05) var carve_drag_from: float = 0.5

@export_group("Crashes")
## Hitting an obstacle (group "obstacles": trees, rocks, fences, boulders)
## faster than this into it is a crash (Bail). Slower = you glance off (m/s).
@export_range(1.0, 60.0, 0.5) var crash_min_impact: float = 10.0
## Speed lost in a crash (0.5 = keep half).
@export_range(0.0, 1.0, 0.05) var crash_penalty: float = 0.5

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
## Hop direction: 0 = straight up, 1 = along the ground normal. Toward the normal
## means a hop on a downhill slope pops off the slope instead of being cancelled
## by it (0.7 = mostly along the normal).
@export_range(0.0, 1.0) var hop_normal_blend: float = 0.7

@export_group("Air")
## No manual balance: the bike's nose follows the flight path, then settles
## onto the predicted landing surface over this long before touchdown (s).
@export var air_land_blend_time: float = 0.3

@export_group("Landing")
## Grades by the angle between the velocity and the ground at touchdown (deg).
## <= perfect: speed bonus + juice. <= good: no change. <= sketchy: speed loss
## and a wobble, combo kept. Above sketchy: Bail.
@export var perfect_angle_deg: float = 12.0
@export var good_angle_deg: float = 30.0
@export var sketchy_angle_deg: float = 55.0
@export var perfect_bonus: float = 0.12
## Speed bonus for a perfect landing coming back from a lip air. 0 so the
## halfpipe can't be farmed for speed (each wall would add perfect_bonus).
@export var lip_air_perfect_bonus: float = 0.0
## Speed lost on a sketchy landing (0.15 = -15%).
@export var sketchy_penalty: float = 0.15
## Speed lost on a bail (0.5 = keep half).
@export var bad_penalty: float = 0.5
## Landing mid-trick: a trick at least this far done (0-1) is completed for you
## and the landing is graded sketchy at best. Less than this is a Bail.
@export var trick_land_tolerance: float = 0.7
## Steep touchdowns slower than this (m/s into the ground, 14 = a ~4 m drop) are sketchy, not a
## Bail, so hopping in place or dropping off a ledge at low speed never crashes.
@export var bail_min_impact: float = 14.0
## Camera shake on a sketchy landing.
@export var sketchy_shake_strength: float = 0.12
@export var sketchy_shake_time: float = 0.25
## Touchdowns softer than this (m/s into the ground) are just roll-ins: no grade.
@export var land_min_impact: float = 2.0
## Time spent in Land before control returns to Ride (s).
@export var land_duration: float = 0.08
@export var hit_stop_perfect: float = 0.04
@export var bail_duration: float = 0.6
## After a bail ends, the next landing within this window can't bail; it is sketchy instead (s).
@export var bail_immunity: float = 1.0

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
## Press grind within this distance of a rail to snap on (m), at low speed...
@export var rail_snap_radius: float = 1.5
## ...growing to this at rail_snap_fast_speed and above (m). Lining up with
## a 12 cm bar at 50 m/s is hard; the reach makes it a line choice instead.
@export var rail_snap_radius_fast: float = 3.5
@export var rail_snap_fast_speed: float = 50.0
## Holding grind near a rail pulls you sideways toward it (the magnet):
## from this far away (m)...
@export var rail_magnet_radius: float = 8.0
## ...at most this fast sideways (m/s)...
@export var rail_magnet_speed: float = 7.0
## ...closing the gap in about this long (s).
@export var rail_magnet_time: float = 0.3
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
## Push along the rail while grinding (m/s^2). 0 by default; upgrades raise it.
@export var grind_accel: float = 0.0

@export_group("Transitions")
## Ground normal smoothing while riding (s). Hides the facets of curved CSG
## surfaces; too high and the bike lags behind a quarter pipe's curve.
@export var ground_normal_smoothing: float = 0.03
## Length of the ground probe along the surface normal (m).
@export var ground_probe_length: float = 1.2
## Ground tilted more than this counts as a transition: camera mode, transition pump (deg).
@export var transition_min_tilt_deg: float = 20.0
## Leaving the ground going up a face steeper than this is a lip air (deg, 90 = vertical).
@export var lip_min_angle_deg: float = 80.0
## The face must have been that steep within this long before you leave it (s).
@export var lip_memory_time: float = 0.15
## Rolling over a convex edge lets go of the ground once the surface has
## turned this far away under you (deg). Above the ~40 deg of a test-track
## roller, so bumps stay rideable and pumpable.
@export var convex_release_deg: float = 45.0
## Same, rolling over the coping at the top of a steep face (deg).
@export var lip_release_deg: float = 20.0
## Vert assist in a lip air: aim this far out over the pipe from the lip line (m).
@export var vert_assist_margin: float = 0.05
## ...closing the gap in about this long (s)...
@export var vert_assist_time: float = 0.35
## ...reacting this fast (s, smaller = stronger)...
@export var vert_assist_response: float = 0.12
## ...and never moving you across the lip faster than this (m/s).
@export var vert_assist_max_speed: float = 2.5
## A transition pump counts on the way down when the ground points down at least this much (deg).
@export var pump_transition_min_deg: float = 10.0
## Riding a transition steeper than this scores carve points (deg).
@export var carve_min_angle_deg: float = 45.0

@export_group("Combo")
## Combo banks after this long of plain riding (s).
@export var combo_drop_time: float = 1.5
## The multiplier is the number of actions in the combo, capped here.
@export var combo_multiplier_cap: int = 10
@export var perfect_landing_score: int = 50
@export var grind_score_per_second: float = 120.0
## Points only, no multiplier step (like lip airs), so halfpipe combos stay
## in line with downhill ones.
@export var carve_score_per_second: float = 25.0
## Points for an air off a quarter-pipe lip (points only, not a combo action).
@export var lip_air_score: int = 100
## Multiplies every trick's score (upgrades raise it).
@export var trick_score_scale: float = 1.0
## Landing (not bailing) after tricks adds this much speed per trick (m/s)...
@export_range(0.0, 20.0, 0.1) var trick_land_boost: float = 0.0
## ...up to this much per landing (m/s).
@export_range(0.0, 30.0, 0.1) var trick_land_boost_max: float = 0.0

@export_group("Run")
## Multiplies the collapse's speed (upgrades lower it).
@export var collapse_speed_scale: float = 1.0

@export_group("Camera")
@export var fov_base: float = 75.0
@export var fov_max: float = 105.0
## FOV follows speed_ratio ^ this (>1 keeps the wide end for real speed).
@export var fov_speed_curve: float = 1.2
## Time for FOV to catch up with speed (s, ease-out).
@export var fov_smoothing: float = 0.25
@export var cam_distance: float = 6.5
@export var cam_height: float = 1.6
## At max speed the camera sits closer and lower (m)...
@export var cam_distance_fast: float = 5.0
@export var cam_height_fast: float = 1.1
## ...easing in from this fraction of max_speed.
@export var cam_fast_from: float = 0.4
## Downward pitch of the camera (deg), on top of the slope pitch below.
@export var cam_pitch_deg: float = 12.0
## The camera pitches with the slope you ride, so it looks down the hill
## (0 = never, 1 = the full slope angle). In the air it uses the ground under you.
## Below 1 on purpose: at 1 the camera tilts as much as the hill, so the hill
## stops looking steep and the flatter track far ahead reads as uphill.
@export var cam_slope_follow: float = 0.55
## Time for the slope pitch to catch up (s).
@export var cam_slope_smoothing: float = 0.3
## Slope pitch limits (deg, + = looking down).
@export var cam_slope_max_deg: float = 40.0
@export var cam_slope_min_deg: float = -15.0
## How far down to look for the ground under you in the air (m).
@export var cam_slope_probe_length: float = 40.0
@export var cam_position_damping: float = 0.08
@export var cam_rotation_damping: float = 0.2
## How far ahead along velocity the camera looks (m at max speed).
@export var cam_look_ahead: float = 3.0
@export var cam_punch_distance: float = 0.35
@export var cam_punch_time: float = 0.12
## On transitions: extra spring arm length (m)...
@export var cam_transition_distance: float = 2.0
## ...extra height (m)...
@export var cam_transition_height: float = 1.0
## ...and how far the camera moves out over the pipe, away from the wall (m).
@export var cam_transition_inset: float = 2.0
## Time to blend into / out of transition framing (s).
@export var cam_transition_blend_time: float = 0.3
## Transition framing stays on this long after leaving the ramp (s).
@export var cam_transition_hold: float = 0.8
## Speed rumble: smooth noise shake, fading in above this fraction of max_speed...
@export var cam_speed_shake_from: float = 0.7
## ...up to this offset at max speed (m)...
@export var cam_speed_shake_amount: float = 0.035
## ...plus this much rotation (deg)...
@export var cam_speed_shake_rotation_deg: float = 0.3
## ...at about this many wobbles per second. Only while on the ground.
@export var cam_speed_shake_frequency: float = 14.0
## Open-valley framing: at speed and outside TightZones the camera pulls this
## much further back (m)...
@export var cam_open_distance: float = 0.0
## ...and this much higher (m), to read the lines ahead...
@export var cam_open_height: float = 0.0
## ...looking this much further down (deg)...
@export var cam_open_pitch_deg: float = 0.0
## ...fading in from this fraction of max_speed.
@export_range(0.0, 1.0, 0.05) var cam_open_from: float = 0.4
## Inside a TightZone it tucks in this much closer than the normal framing (m)...
@export var cam_tight_distance: float = 0.0
## ...and this much lower (m).
@export var cam_tight_height: float = 0.0
## Time to blend between open and tight framing (s).
@export var cam_open_blend_time: float = 0.8

@export_group("Speed lines")
## Speed lines start fading in above this fraction of max_speed (0.7 = 70%).
@export var speed_lines_threshold: float = 0.7
## ...and reach full strength at this fraction of max_speed.
@export var speed_lines_full: float = 0.9
@export var speed_lines_max_alpha: float = 0.7
## Fraction of streak slots lit, from the threshold up to full strength.
@export var speed_lines_density_min: float = 0.2
@export var speed_lines_density_max: float = 0.55
## Time for the lines to catch up with speed (s, ease-out).
@export var speed_lines_fade_time: float = 0.3
