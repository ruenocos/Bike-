extends CanvasLayer
## Top-left readout for tuning feel: speed, state, last landing, combo.
## Finds the player through the "player" group, so it works in any scene.

@onready var label: Label = $Panel/Label
@onready var grade_label: Label = $GradeLabel

var _player: Player


func _ready() -> void:
	Events.landed.connect(_on_landed)
	Events.bailed.connect(_on_bailed)
	grade_label.modulate.a = 0.0


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
	lines.append("combo      x%d   %.2f s" % [p.combo_count, maxf(p.combo_timer, 0.0)])
	lines.append("hop charge %3d%%" % roundi(p.hop_charge / p.tuning.hop_full_charge * 100.0))
	lines.append("pumps      %d" % p.pump_count)
	label.text = "\n".join(lines)


func _on_landed(grade: StringName) -> void:
	var colors: Dictionary[StringName, Color] = {
		&"perfect": Color(1.0, 0.85, 0.2),
		&"good": Color(0.6, 0.9, 1.0),
		&"bad": Color(1.0, 0.35, 0.3),
	}
	_flash(String(grade).to_upper(), colors.get(grade, Color.WHITE))


func _on_bailed() -> void:
	_flash("BAIL", Color(1.0, 0.35, 0.3))


func _flash(text: String, color: Color) -> void:
	grade_label.text = text
	grade_label.modulate = color
	grade_label.scale = Vector2(1.25, 1.25)
	var tween: Tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	tween.tween_property(grade_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(grade_label, "modulate:a", 0.0, 0.5).set_delay(0.45)
