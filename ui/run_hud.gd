class_name RunHud
extends CanvasLayer
## In-run HUD: stage number, stage time, run score, distance to the collapse,
## a stage progress bar, and a red screen-edge warning when the collapse is
## close. The game calls update_run() every frame (call down).

## The edge warning starts at this distance to the collapse (m)...
@export_range(10.0, 500.0, 5.0, "suffix:m") var warn_distance: float = 120.0
## ...and the "COLLAPSE!" text shows below this one.
@export_range(0.0, 300.0, 5.0, "suffix:m") var alarm_distance: float = 50.0

@onready var stage_label: Label = $StageLabel
@onready var time_label: Label = $TimeLabel
@onready var score_label: Label = $ScoreLabel
@onready var collapse_label: Label = $CollapseLabel
@onready var alarm_label: Label = $AlarmLabel
@onready var progress: StageProgress = $Progress
@onready var vignette: ColorRect = $Vignette


func update_run(stage: int, time: float, score: int, gap: float, player_progress: float,
		collapse_distance: float, stage_length: float, finish_distance: float) -> void:
	stage_label.text = "STAGE %d" % stage
	time_label.text = "%d:%05.2f" % [floori(time / 60.0), fmod(time, 60.0)]
	score_label.text = "%d" % score
	collapse_label.text = "COLLAPSE  %d m" % maxi(roundi(gap), 0)
	var danger: float = clampf(1.0 - gap / warn_distance, 0.0, 1.0)
	collapse_label.modulate = Color.WHITE.lerp(Color(1.0, 0.3, 0.15), danger)
	(vignette.material as ShaderMaterial).set_shader_parameter(&"intensity", danger)
	alarm_label.visible = gap < alarm_distance and fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.3
	progress.set_values(stage_length, finish_distance, player_progress, collapse_distance)
