class_name BossHud
extends CanvasLayer
## Boss fight HUD (v0.33): name tape, health bar and the arena clock at the
## top, the intro card in the middle. Layout in boss_hud.tscn (Panzer Pop
## theme); BossFight feeds it (call down).

## How long the intro card stays up (s).
@export_range(0.5, 10.0, 0.1, "suffix:s") var intro_time: float = 2.8
## Under this many seconds the clock turns red and blinks.
@export_range(0.0, 120.0, 1.0, "suffix:s") var warn_time: float = 30.0

@onready var top: Control = $Root/Top
@onready var name_label: Label = $Root/Top/NameTape/Name
@onready var health_bar: ProgressBar = $Root/Top/Health
@onready var time_tape: PanelContainer = $Root/Top/TimeTape
@onready var time_label: Label = $Root/Top/TimeTape/Time
@onready var intro: Control = $Root/Intro
@onready var intro_name: Label = $Root/Intro/Name
@onready var intro_sub: Label = $Root/Intro/Sub

var _intro_timer: float = 0.0


func _ready() -> void:
	visible = false
	intro.visible = false


func open(data: BossData) -> void:
	visible = true
	name_label.text = data.display_name
	intro_name.text = data.display_name
	intro_sub.text = data.subtitle
	intro.visible = true
	_intro_timer = intro_time
	intro.modulate.a = 1.0
	UiMotion.slam(intro_name, 1.3, 0.28)
	UiMotion.tape_in(top, 0.2, 0.3)


func close() -> void:
	visible = false


func set_health(health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = health


func kick_health() -> void:
	UiMotion.kick(health_bar, 0.1)


func set_time(seconds: float) -> void:
	var s: float = maxf(seconds, 0.0)
	time_label.text = "ARENA FALLS IN %d:%02d" % [floori(s / 60.0), floori(fmod(s, 60.0))]
	var warn: bool = s < warn_time
	time_label.add_theme_color_override(&"font_color", Color(0.898, 0.196, 0.176) if warn else Color(0.957, 0.945, 0.91))
	time_tape.modulate.a = 1.0 if not warn or fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.3 else 0.45


func _process(delta: float) -> void:
	if _intro_timer > 0.0:
		_intro_timer -= delta
		intro.modulate.a = clampf(_intro_timer / 0.6, 0.0, 1.0)
		if _intro_timer <= 0.0:
			intro.visible = false
