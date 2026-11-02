class_name VehicleSoundSet
extends Resource
## Every sound that belongs to one vehicle (one .tres per vehicle, see
## audio/sound_sets/). VehicleAudio plays them from generic data only (speed,
## on the ground or in the air, Events), so a new vehicle is a new .tres, no code.
## Leave a stream empty and that layer stays silent.
## One-shots are best as an AudioStreamRandomizer with 3-5 takes.

@export_group("Motion")
## Ground contact at low speed (tyres, treads). Stops the moment you leave the ground.
@export var motion_loop: AudioStream
## Ground contact at high speed; crossfades in between the two speeds below.
@export var motion_loop_fast: AudioStream
## Above this the motion loop fades in (m/s).
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var motion_start_speed: float = 1.0
## Crossfade to the fast loop starts and ends here (m/s).
@export_range(0.0, 60.0, 1.0, "suffix:m/s") var motion_fast_from: float = 18.0
@export_range(0.0, 60.0, 1.0, "suffix:m/s") var motion_fast_to: float = 38.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var motion_db_slow: float = -24.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var motion_db_fast: float = -10.0
@export_range(0.25, 2.0, 0.01) var motion_pitch_slow: float = 0.8
@export_range(0.25, 2.0, 0.01) var motion_pitch_fast: float = 1.3

@export_group("Engine")
## Runs all the time. Leave empty for a vehicle without an engine.
@export var engine_loop: AudioStream
## Crossfades in at high speed between the two speeds below.
@export var engine_loop_high: AudioStream
@export_range(0.0, 60.0, 1.0, "suffix:m/s") var engine_high_from: float = 12.0
@export_range(0.0, 60.0, 1.0, "suffix:m/s") var engine_high_to: float = 42.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var engine_db_idle: float = -18.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var engine_db_full: float = -8.0
@export_range(0.25, 2.0, 0.01) var engine_pitch_idle: float = 0.8
@export_range(0.25, 2.0, 0.01) var engine_pitch_full: float = 1.3

@export_group("Hop")
## The pop when leaving the ground on purpose, and air hops.
@export var hop: AudioStream
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var hop_db: float = -10.0

@export_group("Boost")
## The whoosh on any boost (Player.boost_flashed).
@export var boost: AudioStream
## The blast on a boost fired by the vehicle (Events.cannon_fired, kind boost).
@export var cannon_boost: AudioStream
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var boost_db: float = -13.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var cannon_boost_db: float = -5.0

@export_group("Landing impacts")
## The physical hit per grade; the tonal note on top is VehicleAudio's.
@export var landing_perfect: AudioStream
@export var landing_good: AudioStream
@export var landing_sketchy: AudioStream
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var landing_perfect_db: float = -3.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var landing_good_db: float = -7.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var landing_sketchy_db: float = -2.0

@export_group("Crash")
@export var crash: AudioStream
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var crash_db: float = -1.0

@export_group("Grind")
@export var grind_loop: AudioStream
## The clank on catching a rail.
@export var grind_catch: AudioStream
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var grind_db: float = -10.0
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var grind_catch_db: float = -4.0
@export_range(0.25, 2.0, 0.01) var grind_pitch_slow: float = 0.85
@export_range(0.25, 2.0, 0.01) var grind_pitch_fast: float = 1.25

@export_group("Props and tricks")
## Running over a small prop (Events.prop_crushed).
@export var crush: AudioStream
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var crush_db: float = -6.0
## A trick's spin (a turret whir): on Events.trick_started, or trick_completed without it.
@export var trick_spin: AudioStream
@export_range(-80.0, 12.0, 0.5, "suffix:dB") var trick_spin_db: float = -12.0
