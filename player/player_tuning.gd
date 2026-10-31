class_name PlayerTuning
extends Resource
## All feel values live here. Tune them in the inspector while the game runs.

@export_group("Speed")
@export var base_speed: float = 14.0
@export var max_speed: float = 40.0
@export var pump_gain: float = 0.04

@export_group("Landing")
@export var perfect_angle_deg: float = 10.0
@export var good_angle_deg: float = 25.0
@export var perfect_bonus: float = 0.12
@export var bad_penalty: float = 0.30

@export_group("Input")
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.12
@export var hop_full_charge: float = 0.25

@export_group("Camera")
@export var fov_base: float = 75.0
@export var fov_max: float = 95.0
