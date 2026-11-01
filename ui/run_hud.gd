class_name RunHud
extends CanvasLayer
## In-run HUD: stage number, stage time, run score, distance to the collapse,
## a stage progress bar and a red screen-edge warning when the collapse is
## close. The game calls update_run() every frame (call down). Layout and text live in run_hud.tscn.
## v0.8: the sprint-start meter + pedal prompt (StartPanel), PERFECT START
## flash, OUT OF BOUNDS countdown, "+x s" time penalties and the collapse
## proximity meter under the distance.

## The edge warning starts at this distance to the collapse (m)...
@export_range(10.0, 500.0, 5.0, "suffix:m") var warn_distance: float = 120.0
## ...and the "COLLAPSE!" text shows below this one.
@export_range(0.0, 300.0, 5.0, "suffix:m") var alarm_distance: float = 50.0
## The collapse meter starts filling at this distance (m).
@export_range(10.0, 1000.0, 5.0, "suffix:m") var meter_range: float = 250.0
## How long the stage title card stays up (s), fading over the last 0.8 s.
@export_range(0.5, 10.0, 0.1, "suffix:s") var title_time: float = 3.5
## How long the start / penalty flashes stay up (s).
@export_range(0.1, 5.0, 0.1, "suffix:s") var flash_time: float = 1.4

@onready var stage_label: Label = $StageLabel
@onready var time_label: Label = $TimeLabel
@onready var score_label: Label = $ScoreLabel
@onready var collapse_label: Label = $CollapseLabel
@onready var alarm_label: Label = $AlarmLabel
@onready var progress: StageProgress = $Progress
@onready var vignette: ColorRect = $Vignette
@onready var collapse_fill: ColorRect = $CollapseMeter/Fill
@onready var penalty_label: Label = $PenaltyLabel
@onready var oob_label: Label = $OobLabel
@onready var start_flash: Label = $StartFlash
@onready var start_panel: Control = $StartPanel
@onready var start_prompt: Label = $StartPanel/Prompt
@onready var meter_back: ColorRect = $StartPanel/MeterBack
@onready var good_zone: ColorRect = $StartPanel/MeterBack/GoodZone
@onready var sweet_zone: ColorRect = $StartPanel/MeterBack/SweetZone
@onready var needle: ColorRect = $StartPanel/MeterBack/Needle
@onready var title_card: Control = $TitleCard
@onready var shield_label: Label = $ShieldLabel
@onready var fade: ColorRect = $Fade
@onready var title_stage: Label = $TitleCard/StageNo
@onready var title_name: Label = $TitleCard/Name
@onready var title_sub: Label = $TitleCard/Sub

var _start_flash_timer: float = 0.0
var _title_timer: float = 0.0
var _penalty_timer: float = 0.0
var _penalty_total: float = 0.0


func _process(delta: float) -> void:
	_title_timer = maxf(_title_timer - delta, 0.0)
	title_card.visible = _title_timer > 0.0
	title_card.modulate.a = clampf(_title_timer / 0.8, 0.0, 1.0)
	_start_flash_timer = maxf(_start_flash_timer - delta, 0.0)
	start_flash.visible = _start_flash_timer > 0.0
	start_flash.modulate.a = clampf(_start_flash_timer / 0.3, 0.0, 1.0)
	_penalty_timer = maxf(_penalty_timer - delta, 0.0)
	penalty_label.visible = _penalty_timer > 0.0
	penalty_label.modulate.a = clampf(_penalty_timer / 0.3, 0.0, 1.0)
	if _penalty_timer <= 0.0:
		_penalty_total = 0.0


## Full black (the game draws it for a frame or two before a stage build).
func black_out() -> void:
	fade.visible = true
	fade.modulate.a = 1.0


## Black screen fading out over `seconds` (v0.15: after the stage build).
func fade_in(seconds: float) -> void:
	fade.visible = true
	fade.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, seconds)
	tween.tween_callback(fade.hide)


## Stage title card (v0.12): stage number, biome name, a short line.
func show_title(stage: int, place: String, line: String) -> void:
	title_stage.text = "STAGE %d" % stage
	title_name.text = place.to_upper()
	title_sub.text = line
	_title_timer = title_time


## The sprint-start meter (hidden when `sprint` is null or done).
func show_start(sprint: StartSprint) -> void:
	start_panel.visible = sprint != null and sprint.active
	if not start_panel.visible:
		return
	start_prompt.text = StartSprint.prompt_text()
	var w: float = meter_back.size.x
	good_zone.position.x = w * maxf(sprint.sweet_from - sprint.good_margin, 0.0)
	good_zone.size.x = w * (minf(sprint.sweet_to + sprint.good_margin, 1.0) - maxf(sprint.sweet_from - sprint.good_margin, 0.0))
	sweet_zone.position.x = w * sprint.sweet_from
	sweet_zone.size.x = w * (sprint.sweet_to - sprint.sweet_from)
	needle.position.x = w * sprint.meter - needle.size.x * 0.5


func flash_start(grade: StringName) -> void:
	match grade:
		&"perfect":
			start_flash.text = "PERFECT START!"
			start_flash.modulate = Color(0.5, 1.0, 0.55)
		&"good":
			start_flash.text = "GOOD START"
			start_flash.modulate = Color(1.0, 0.9, 0.4)
		_:
			start_flash.text = "GO!"
			start_flash.modulate = Color.WHITE
	_start_flash_timer = flash_time


## A short centre flash in a colour (upgrade powers: SHIELD!, DOUBLE HOP).
func flash_message(text: String, color: Color) -> void:
	start_flash.text = text
	start_flash.modulate = color
	_start_flash_timer = flash_time * 0.7


## "BOOST +300" when riding through a boost gate.
func flash_gate(score: int) -> void:
	start_flash.text = "BOOST  +%d" % score
	start_flash.modulate = Color(1.0, 0.8, 0.3)
	_start_flash_timer = flash_time * 0.7


## Seconds left before an out-of-bounds respawn; < 0 hides the warning.
func show_out_of_bounds(seconds_left: float) -> void:
	oob_label.visible = seconds_left >= 0.0
	if oob_label.visible:
		oob_label.text = "OUT OF BOUNDS  %.1f" % seconds_left


## "+x s": a crash or respawn cost time (penalties close together add up).
func flash_penalty(seconds: float) -> void:
	_penalty_total += seconds
	penalty_label.text = "+%.1f s" % _penalty_total
	_penalty_timer = flash_time


func update_run(stage: int, time: float, score: int, gap: float, player_progress: float,
		collapse_distance: float, stage_length: float, finish_distance: float, shields: int = 0) -> void:
	shield_label.visible = shields > 0
	shield_label.text = "SHIELD x%d" % shields
	stage_label.text = "STAGE %d" % stage
	time_label.text = "%d:%05.2f" % [floori(time / 60.0), fmod(time, 60.0)]
	score_label.text = "%d" % score
	collapse_label.text = "COLLAPSE  %d m" % maxi(roundi(gap), 0)
	var danger: float = clampf(1.0 - gap / warn_distance, 0.0, 1.0)
	collapse_label.modulate = Color.WHITE.lerp(Color(1.0, 0.3, 0.15), danger)
	(vignette.material as ShaderMaterial).set_shader_parameter(&"intensity", danger)
	alarm_label.visible = gap < alarm_distance and fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.3
	progress.set_values(stage_length, finish_distance, player_progress, collapse_distance)
	collapse_fill.size.x = (collapse_fill.get_parent() as Control).size.x * clampf(1.0 - gap / meter_range, 0.0, 1.0)
