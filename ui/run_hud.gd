class_name RunHud
extends CanvasLayer
## In-run HUD (v0.31 Panzer Pop restyle). Layout and look live in
## run_hud.tscn + ui/theme/panzer_theme.tres; this script only feeds values
## and plays the motion. The game calls update_run() / update_rider() every
## frame (call down); landings, tricks and banks come in through Events.
##
## Declutter rules: the collapse tape only shows when the collapse is
## within `collapse_show_distance`; the combo and callouts only while
## something is happening; GOOD landings show nothing (the impact lines in
## vfx/anime_fx already say it), PERFECT plays the cut-in.

## The edge warning starts at this distance to the collapse (m)...
@export_range(10.0, 500.0, 5.0, "suffix:m") var warn_distance: float = 120.0
## ...and the "COLLAPSE!" tape shows below this one.
@export_range(0.0, 300.0, 5.0, "suffix:m") var alarm_distance: float = 50.0
## The collapse distance tape (top right) only shows closer than this.
@export_range(0.0, 1000.0, 5.0, "suffix:m") var collapse_show_distance: float = 160.0
## Distance the game treats as "far" for the collapse gap (kept for game.gd).
@export_range(10.0, 1000.0, 5.0, "suffix:m") var meter_range: float = 250.0
## How long the stage title card stays up (s), fading over the last 0.8 s.
@export_range(0.5, 10.0, 0.1, "suffix:s") var title_time: float = 3.5
## How long the start / penalty flashes stay up (s).
@export_range(0.1, 5.0, 0.1, "suffix:s") var flash_time: float = 1.4

@export_group("Perfect cut-in")
## Play the red slash + PERFECT on perfect landings.
@export var cut_in_enabled: bool = true
## Fully shown this long before it wipes out (s, real time: ignores hit stop).
@export_range(0.05, 2.0, 0.01, "suffix:s") var cut_in_hold: float = 0.35
## Crew portrait slashed in with the word. Empty = word only.
@export var cut_in_portrait: Texture2D
## Lines picked at random under PERFECT.
@export var cut_in_lines: PackedStringArray = ["ナイス着地！", "完璧！", "いいね！"]

@export_group("Callouts")
## Tricks, banked combos and rough landings show in one small tape under
## the combo for this long (s).
@export_range(0.2, 3.0, 0.05, "suffix:s") var callout_time: float = 1.1
@export var callout_trick_color: Color = Color(0.949, 0.718, 0.02, 1.0)
@export var callout_bank_color: Color = Color(0.957, 0.945, 0.91, 1.0)
@export var callout_bad_color: Color = Color(0.898, 0.196, 0.176, 1.0)

const INK: Color = Color(0.078, 0.078, 0.086, 1.0)
const PAPER: Color = Color(0.957, 0.945, 0.91, 1.0)

@onready var stage_label: Label = $Root/TopLeft/StageTape/StageLabel
@onready var time_label: Label = $Root/TopLeft/TimeTape/TimeLabel
@onready var penalty_tape: Control = $Root/TopLeft/PenaltyTape
@onready var penalty_label: Label = $Root/TopLeft/PenaltyTape/PenaltyLabel
@onready var score_label: Label = $Root/TopRight/ScoreTape/ScoreLabel
@onready var collapse_tape: Control = $Root/TopRight/CollapseTape
@onready var collapse_label: Label = $Root/TopRight/CollapseTape/Row/CollapseLabel
@onready var shield_tape: Control = $Root/TopRight/ShieldTape
@onready var shield_label: Label = $Root/TopRight/ShieldTape/ShieldLabel
@onready var alarm_tape: Control = $Root/AlarmTape
@onready var progress: StageProgress = $Root/Progress
@onready var vignette: ColorRect = $Vignette
@onready var flash_tape: PanelContainer = $Root/Flash
@onready var flash_label: Label = $Root/Flash/FlashLabel
@onready var oob_tape: Control = $Root/OobTape
@onready var oob_label: Label = $Root/OobTape/OobLabel
@onready var start_panel: Control = $Root/StartPanel
@onready var start_prompt: Label = $Root/StartPanel/PromptTape/Prompt
@onready var meter_back: ColorRect = $Root/StartPanel/MeterBack
@onready var good_zone: ColorRect = $Root/StartPanel/MeterBack/GoodZone
@onready var sweet_zone: ColorRect = $Root/StartPanel/MeterBack/SweetZone
@onready var needle: ColorRect = $Root/StartPanel/MeterBack/Needle
@onready var title_card: Control = $Root/TitleCard
@onready var title_stage: Label = $Root/TitleCard/StageTape/StageNo
@onready var title_name: Label = $Root/TitleCard/Name
@onready var title_sub: Label = $Root/TitleCard/Sub
@onready var title_kana: Label = $Root/TitleCard/Kana
@onready var fade: ColorRect = $Fade
@onready var light_flash: ColorRect = $LightFlash
@onready var speed_dial: SpeedDial = $Root/SpeedPanel/Dial
@onready var speed_value: Label = $Root/SpeedPanel/SpeedTape/Row/Value
@onready var combo_panel: Control = $Root/ComboPanel
@onready var combo_mult: Label = $Root/ComboPanel/Row/MultTape/Mult
@onready var combo_tape: Control = $Root/ComboPanel/Row/MultTape
@onready var combo_pips: ShellPips = $Root/ComboPanel/Row/Pips
@onready var combo_points: Label = $Root/ComboPanel/Points
@onready var callout: PanelContainer = $Root/Callout
@onready var callout_label: Label = $Root/Callout/CalloutLabel
@onready var cut_in: Control = $Root/CutIn
@onready var cut_slash: Control = $Root/CutIn/Slash
@onready var cut_words: Control = $Root/CutIn/Slash/Words
@onready var cut_line: Label = $Root/CutIn/Slash/Words/Line
@onready var cut_portrait: TextureRect = $Root/CutIn/Portrait

var _start_flash_timer: float = 0.0
var _title_timer: float = 0.0
var _flash_tween: Tween
var _fade_tween: Tween
var _cut_tween: Tween
var _penalty_timer: float = 0.0
var _penalty_total: float = 0.0
var _callout_timer: float = 0.0
var _last_mult: int = 0
var _was_collapse_shown: bool = false
var _was_alarm: bool = false
var _slash_home: Vector2
var _words_home: Vector2


func _ready() -> void:
	_slash_home = cut_slash.position
	_words_home = cut_words.position
	cut_in.visible = false
	callout.visible = false
	Events.landed.connect(_on_landed)
	Events.trick_completed.connect(_on_trick)
	Events.combo_banked.connect(_on_banked)
	Events.bailed.connect(func() -> void: _callout("BAIL", callout_bad_color, PAPER))


func _process(delta: float) -> void:
	_title_timer = maxf(_title_timer - delta, 0.0)
	title_card.visible = _title_timer > 0.0
	title_card.modulate.a = clampf(_title_timer / 0.8, 0.0, 1.0)
	_start_flash_timer = maxf(_start_flash_timer - delta, 0.0)
	flash_tape.visible = _start_flash_timer > 0.0
	flash_tape.modulate.a = clampf(_start_flash_timer / 0.3, 0.0, 1.0)
	_penalty_timer = maxf(_penalty_timer - delta, 0.0)
	penalty_tape.visible = _penalty_timer > 0.0
	penalty_tape.modulate.a = clampf(_penalty_timer / 0.3, 0.0, 1.0)
	if _penalty_timer <= 0.0:
		_penalty_total = 0.0
	_callout_timer = maxf(_callout_timer - delta, 0.0)
	callout.visible = _callout_timer > 0.0
	callout.modulate.a = clampf(_callout_timer / 0.25, 0.0, 1.0)


## 12450 -> "12,450".
static func group_digits(value: int) -> String:
	var s: String = str(absi(value))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if value < 0 else "") + s + out


## Speed (km/h + the dial) and the running combo (v0.17).
func update_rider(delta: float, speed: float, max_speed: float, combo_active: bool, multiplier: int, points: int) -> void:
	speed_value.text = "%d" % roundi(speed * 3.6)
	speed_dial.ratio = clampf(speed / maxf(max_speed, 1.0), 0.0, 1.0)
	if combo_active and points > 0:
		if not combo_panel.visible:
			combo_panel.visible = true
			UiMotion.tape_in(combo_tape)
		combo_panel.modulate.a = 1.0
		combo_mult.text = "x%d" % multiplier
		combo_pips.count = multiplier
		combo_points.text = "%s PTS" % group_digits(points)
		if multiplier > _last_mult:
			UiMotion.kick(combo_tape, 0.15)
		_last_mult = multiplier
	elif combo_panel.visible:
		combo_panel.modulate.a = maxf(combo_panel.modulate.a - delta * 3.0, 0.0)
		combo_panel.visible = combo_panel.modulate.a > 0.0
		_last_mult = 0


## A quick warm-white flash over the screen (perfect landings, v0.22).
func flash_light(strength: float = 0.2, seconds: float = 0.12) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	light_flash.visible = true
	light_flash.modulate.a = strength
	var tween: Tween = create_tween()
	_flash_tween = tween
	tween.tween_property(light_flash, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_OUT)
	tween.tween_callback(light_flash.hide)


## Full black (the game draws it for a frame or two before a stage build).
func black_out() -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	fade.visible = true
	fade.modulate.a = 1.0


## Black screen fading out over `seconds` (v0.15: after the stage build).
func fade_in(seconds: float) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	fade.visible = true
	fade.modulate.a = 1.0
	var tween: Tween = create_tween()
	_fade_tween = tween
	tween.tween_property(fade, "modulate:a", 0.0, seconds)
	tween.tween_callback(fade.hide)


## Stage title card (v0.12): stage number, biome name, a short line.
func show_title(stage: int, place: String, line: String) -> void:
	title_stage.text = "STAGE %d" % stage
	title_name.text = place.to_upper()
	title_sub.text = line
	title_kana.text = "第%d戦区" % stage
	_title_timer = title_time
	title_card.visible = true
	UiMotion.tape_in(title_stage.get_parent() as Control, 0.2, 0.1)
	UiMotion.slam(title_name, 1.25, 0.28)


## The sprint-start meter (hidden when `sprint` is null or done).
func show_start(sprint: StartSprint) -> void:
	start_panel.visible = sprint != null and sprint.active
	if not start_panel.visible:
		return
	start_prompt.text = StartSprint.prompt_text().to_upper()
	var w: float = meter_back.size.x
	good_zone.position.x = w * maxf(sprint.sweet_from - sprint.good_margin, 0.0)
	good_zone.size.x = w * (minf(sprint.sweet_to + sprint.good_margin, 1.0) - maxf(sprint.sweet_from - sprint.good_margin, 0.0))
	sweet_zone.position.x = w * sprint.sweet_from
	sweet_zone.size.x = w * (sprint.sweet_to - sprint.sweet_from)
	needle.position.x = w * sprint.meter - needle.size.x * 0.5


## The centre flash tape: `text` in `color` on ink.
func _center_flash(text: String, color: Color, seconds: float) -> void:
	var was_up: bool = _start_flash_timer > 0.0
	flash_label.text = text
	flash_label.add_theme_color_override(&"font_color", color)
	_start_flash_timer = seconds
	flash_tape.visible = true
	flash_tape.reset_size()
	if was_up:
		UiMotion.kick(flash_tape, 0.12)
	else:
		UiMotion.slam(flash_tape, 1.3, 0.2)


func flash_start(grade: StringName) -> void:
	match grade:
		&"perfect":
			_center_flash("PERFECT START!", Color(0.949, 0.718, 0.02), flash_time)
		&"good":
			_center_flash("GOOD START", PAPER, flash_time)
		_:
			_center_flash("GO!", PAPER, flash_time)


## A short centre flash in a colour (upgrade powers: SHIELD!, DOUBLE HOP).
func flash_message(text: String, color: Color) -> void:
	_center_flash(text, color, flash_time * 0.7)


## "BOOST +300" when riding through a boost gate.
func flash_gate(score: int) -> void:
	_center_flash("BOOST  +%d" % score, Color(0.949, 0.718, 0.02), flash_time * 0.7)


## Seconds left before an out-of-bounds respawn; < 0 hides the warning.
func show_out_of_bounds(seconds_left: float) -> void:
	var shown: bool = seconds_left >= 0.0
	if shown and not oob_tape.visible:
		oob_tape.visible = true
		UiMotion.slam(oob_tape, 1.2, 0.18)
	oob_tape.visible = shown
	if shown:
		oob_label.text = "OUT OF BOUNDS  %.1f" % seconds_left


## "+x s": a crash or respawn cost time (penalties close together add up).
func flash_penalty(seconds: float) -> void:
	_penalty_total += seconds
	penalty_label.text = "+%.1f S" % _penalty_total
	_penalty_timer = flash_time
	penalty_tape.visible = true
	UiMotion.tape_in(penalty_tape, 0.14)


func update_run(stage: int, time: float, score: int, gap: float, player_progress: float,
		collapse_distance: float, stage_length: float, finish_distance: float, shields: int = 0) -> void:
	shield_tape.visible = shields > 0
	shield_label.text = "SHIELD x%d" % shields
	stage_label.text = "STAGE %d" % stage
	time_label.text = "%d:%05.2f" % [floori(time / 60.0), fmod(time, 60.0)]
	score_label.text = group_digits(score)
	var gap_m: int = maxi(roundi(gap), 0)
	var show_collapse: bool = gap < collapse_show_distance
	collapse_tape.visible = show_collapse
	if show_collapse and not _was_collapse_shown:
		UiMotion.tape_in(collapse_tape, 0.16)
	_was_collapse_shown = show_collapse
	collapse_label.text = "%d M" % gap_m
	var danger: float = clampf(1.0 - gap / warn_distance, 0.0, 1.0)
	(vignette.material as ShaderMaterial).set_shader_parameter(&"intensity", danger)
	var alarm: bool = gap < alarm_distance
	if alarm and not _was_alarm:
		alarm_tape.visible = true
		UiMotion.slam(alarm_tape, 1.3, 0.2)
	_was_alarm = alarm
	alarm_tape.visible = alarm
	# Blink by alpha, so the tape keeps its place while it pulses.
	alarm_tape.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.3 else 0.35
	progress.set_values(stage_length, finish_distance, player_progress, collapse_distance)


func _on_landed(grade: StringName) -> void:
	if not visible:
		return
	match grade:
		&"perfect":
			if cut_in_enabled:
				play_cut_in()
		&"sketchy":
			_callout("SKETCHY", callout_bad_color, PAPER)


func _on_trick(trick_name: String, score: int) -> void:
	if visible:
		_callout("%s  +%d" % [trick_name.to_upper(), score], callout_trick_color, INK)


func _on_banked(score: int) -> void:
	if visible and score > 0:
		_callout("BANKED  %s" % group_digits(score), callout_bank_color, INK)


## The small tape under the combo: one message at a time, newest wins.
func _callout(text: String, bg: Color, fg: Color) -> void:
	callout_label.text = text
	callout_label.add_theme_color_override(&"font_color", fg)
	var style: StyleBoxFlat = callout.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	style.bg_color = bg
	callout.add_theme_stylebox_override(&"panel", style)
	callout.visible = true
	callout.reset_size()
	_callout_timer = callout_time
	UiMotion.tape_in(callout, 0.14)


## PERFECT: a red band slashes in from the left, the word slams down on it,
## holds `cut_in_hold`, then everything wipes out to the right.
func play_cut_in() -> void:
	if _cut_tween != null:
		_cut_tween.kill()
	cut_line.text = cut_in_lines[randi() % cut_in_lines.size()] if not cut_in_lines.is_empty() else ""
	cut_portrait.texture = cut_in_portrait
	cut_portrait.visible = cut_in_portrait != null
	cut_in.visible = true
	cut_in.modulate.a = 1.0
	var vw: float = cut_in.size.x
	cut_slash.position = _slash_home + Vector2(-vw * 1.4, 0.0)
	cut_words.position = _words_home + Vector2(-220.0, 0.0)
	cut_words.modulate.a = 0.0
	cut_words.pivot_offset = cut_words.size * 0.5
	cut_words.scale = Vector2.ONE * 1.35
	var tween: Tween = create_tween().set_ignore_time_scale(true)
	_cut_tween = tween
	tween.tween_property(cut_slash, "position", _slash_home, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(cut_words, "position", _words_home, 0.16).set_delay(0.04) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(cut_words, "scale", Vector2.ONE, 0.18).set_delay(0.04) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(cut_words, "modulate:a", 1.0, 0.06).set_delay(0.04)
	tween.tween_interval(cut_in_hold)
	tween.tween_property(cut_slash, "position", _slash_home + Vector2(vw * 1.4, 0.0), 0.16) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(cut_words, "modulate:a", 0.0, 0.14)
	tween.tween_callback(cut_in.hide)
