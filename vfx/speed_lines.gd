extends CanvasLayer
## Speed lines overlay. Child of Player. Fades the shader in between
## speed_lines_threshold and speed_lines_full (x max_speed), eased out,
## smoothed over speed_lines_fade_time.
##
## Godot note: a CanvasLayer draws its 2D children on top of the 3D view,
## independent of the camera. The ColorRect fills the screen and the shader
## decides which pixels show.

@onready var player: Player = get_parent() as Player
@onready var rect: ColorRect = $Lines

var _alpha: float = 0.0
var _material: ShaderMaterial


func _ready() -> void:
	_material = rect.material as ShaderMaterial
	rect.visible = false


func _process(delta: float) -> void:
	var t: PlayerTuning = player.tuning
	var ratio: float = clampf(player.speed / t.max_speed, 0.0, 1.0)
	var x: float = clampf((ratio - t.speed_lines_threshold) / maxf(t.speed_lines_full - t.speed_lines_threshold, 0.0001), 0.0, 1.0)
	# Ease out: lines show up quickly past the threshold, then settle.
	var target: float = 1.0 - (1.0 - x) * (1.0 - x)
	_alpha = lerpf(_alpha, target, 1.0 - exp(-delta / maxf(t.speed_lines_fade_time / 3.0, 0.0001)))
	rect.visible = _alpha > 0.005
	_material.set_shader_parameter(&"intensity", _alpha * t.speed_lines_max_alpha)
