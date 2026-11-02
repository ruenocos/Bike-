extends CanvasLayer
## Top-left readout for tuning feel: speed, state, last landing, trick, combo.
## Big centre text flashes three stacked lines, each with its own timing so
## one never overwrites another: trick / grind / carve / lip air on top, the landing
## grade under it, banked combos at the bottom.
## Finds the player through the "player" group, so it works in any scene.
## The readout panel is hidden by default (v0.8.2); F3 (debug_overlay action)
## toggles it. The centre flashes always show.

@onready var label: Label = $Panel/Label
@onready var trick_label: Label = $TrickLabel
@onready var grade_label: Label = $GradeLabel
@onready var bank_label: Label = $BankLabel

## Each flash holds fully visible this long, then fades out (s).
const FLASH_HOLD: float = 0.6
const FLASH_FADE: float = 0.3

var _player: Player
var _tweens: Dictionary[Label, Tween] = {}


func _ready() -> void:
	Events.landed.connect(_on_landed)
	Events.bailed.connect(_on_bailed)
	Events.trick_completed.connect(_on_trick_completed)
	Events.combo_banked.connect(_on_combo_banked)
	Events.grind_started.connect(_on_grind_started)
	Events.carve_started.connect(_on_carve_started)
	Events.lip_air.connect(_on_lip_air)
	for flash_label: Label in [trick_label, grade_label, bank_label]:
		flash_label.modulate.a = 0.0
	($Panel as Control).visible = show_panel


## Show the top-left readout at start (F3 toggles it while playing).
@export var show_panel: bool = false
## The big centre flashes (trick / grade / banked). Off in game.tscn since
## v0.31: the RunHud shows those (PERFECT cut-in, callouts).
@export var show_flashes: bool = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		($Panel as Control).visible = not ($Panel as Control).visible


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	var p: Player = _player
	var lines: PackedStringArray = PackedStringArray()
	lines.append("FPS        %d" % Engine.get_frames_per_second())
	lines.append("speed      %5.1f m/s   %3d km/h" % [p.speed, roundi(p.speed * 3.6)])
	lines.append("state      %s" % p.state_machine.get_state_name())
	lines.append("landing    %4.1f°  %s" % [p.last_landing_angle, p.last_landing_grade])
	lines.append("last bail  %s" % p.last_bail_reason)
	if p.bail_immunity_timer > 0.0:
		lines.append("bail immune %.2f s" % p.bail_immunity_timer)
	if p.tricks.is_mid_trick():
		lines.append("trick      %s  %3d%%" % [p.tricks.current.display_name, roundi(p.tricks.get_progress() * 100.0)])
	else:
		lines.append("trick      - (last: %s)" % p.tricks.last_trick_name)
	var c: ComboTracker = p.combo
	lines.append("combo      %d x%d = %d   %.2f s" % [floori(c.points), c.get_multiplier(), c.get_total(), maxf(c.timer, 0.0)])
	lines.append("run total  %d" % c.run_total)
	lines.append("hop charge %3d%%" % roundi(p.hop_charge / p.tuning.hop_full_charge * 100.0))
	lines.append("pumps      %d" % p.pump_count)
	label.text = "\n".join(lines)


func _on_landed(grade: StringName) -> void:
	var colors: Dictionary[StringName, Color] = {
		&"perfect": Color(1.0, 0.85, 0.2),
		&"good": Color(0.6, 0.9, 1.0),
		&"sketchy": Color(1.0, 0.6, 0.15),
		&"bail": Color(1.0, 0.35, 0.3),
	}
	_flash(grade_label, String(grade).to_upper(), colors.get(grade, Color.WHITE))


func _on_bailed() -> void:
	_flash(grade_label, "BAIL", Color(1.0, 0.35, 0.3))


func _on_trick_completed(trick_name: String, score: int) -> void:
	_flash(trick_label, "%s  +%d" % [trick_name.to_upper(), score], Color(0.75, 1.0, 0.55))


func _on_grind_started() -> void:
	_flash(trick_label, "GRIND", Color(0.4, 0.95, 1.0))


## Carve and lip air flashes don't cover a trick name that is still showing.
func _on_carve_started() -> void:
	if trick_label.modulate.a < 0.05:
		_flash(trick_label, "CARVE", Color(0.4, 0.95, 1.0))


func _on_lip_air() -> void:
	if trick_label.modulate.a < 0.05:
		_flash(trick_label, "LIP AIR", Color(0.4, 0.95, 1.0))


func _on_combo_banked(score: int) -> void:
	_flash(bank_label, "BANKED %d" % score, Color(1.0, 0.85, 0.2))


## Pops the label in, holds it, fades it. A new flash on the same label
## restarts it; the other labels keep their own tweens.
func _flash(target: Label, text: String, color: Color) -> void:
	if not show_flashes:
		return
	if _tweens.has(target):
		_tweens[target].kill()
	target.text = text
	target.modulate = color
	target.scale = Vector2(1.25, 1.25)
	var tween: Tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	tween.tween_property(target, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate:a", 0.0, FLASH_FADE).set_delay(FLASH_HOLD)
	_tweens[target] = tween
