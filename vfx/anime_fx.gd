class_name AnimeFx
extends CanvasLayer
## Full-screen anime punches (vfx/anime_fx.tscn, child of Player, v0.30):
##   Impact frame: a perfect landing gives a short, soft pale wash with thin
##   radial lines that fade fast (v0.30.1, Wons: "calm down the perfect flash").
##   A good landing only gets the lines. `ink_flip` brings back the full flip
##   to ink and paper.
##   Boost burst: radial lines bursting out from the middle on any boost.
## Held cruising speed lines are vfx/speed_lines (they don't change here).

## Rendered frames of the wash (counted in frames, so the hit stop doesn't
## stretch or skip it). 0 = no flash, lines only.
@export_range(0, 8) var impact_frames: int = 2
## How strong the wash is.
@export_range(0.0, 1.0, 0.01) var impact_strength: float = 0.3
## 0 = a soft pale wash, 1 = the full flip to ink and paper.
@export_range(0.0, 1.0, 0.01) var ink_flip: float = 0.0
## Width of the radial lines (1 = thick wedges).
@export_range(0.0, 1.0, 0.01) var line_width: float = 0.25
## How long the radial lines fade after a landing / a boost.
@export_range(0.05, 1.0, 0.01, "suffix:s") var impact_lines_time: float = 0.12
@export_range(0.05, 1.0, 0.01, "suffix:s") var boost_lines_time: float = 0.32
## Peak strength of the lines per event.
@export_range(0.0, 1.0, 0.01) var perfect_lines: float = 0.45
@export_range(0.0, 1.0, 0.01) var good_lines: float = 0.35
@export_range(0.0, 1.0, 0.01) var boost_lines: float = 0.45

@onready var player: Player = get_parent() as Player
@onready var rect: ColorRect = $Burst

var _material: ShaderMaterial
var _flash_left: int = 0
var _lines: float = 0.0
var _lines_peak: float = 0.0
var _lines_time: float = 0.2
var _lines_left: float = 0.0


func _ready() -> void:
	_material = rect.material as ShaderMaterial
	rect.visible = false
	Events.landed.connect(_on_landed)
	player.boost_flashed.connect(_on_boost)


func _on_landed(grade: StringName) -> void:
	if grade == &"perfect":
		_flash_left = impact_frames
		_fire_lines(perfect_lines, impact_lines_time)
	elif grade == &"good":
		_fire_lines(good_lines, impact_lines_time)


func _on_boost() -> void:
	# A perfect landing also boosts: its own calmer lines win.
	if _flash_left > 0 or _lines_left > 0.0:
		return
	_fire_lines(boost_lines, boost_lines_time)


func _fire_lines(strength: float, time: float) -> void:
	if strength < _lines:
		return
	_lines_peak = strength
	_lines_time = time
	_lines_left = time


func _process(delta: float) -> void:
	_lines_left = maxf(_lines_left - delta, 0.0)
	var x: float = _lines_left / maxf(_lines_time, 0.001)
	_lines = _lines_peak * x
	var flash: bool = _flash_left > 0
	rect.visible = flash or _lines > 0.003
	if not rect.visible:
		return
	_material.set_shader_parameter(&"flash", impact_strength if flash else 0.0)
	_material.set_shader_parameter(&"lines", _lines)
	_material.set_shader_parameter(&"ink_flip", ink_flip)
	_material.set_shader_parameter(&"line_width", line_width)
	# The ring of clear space opens outward as the burst fades.
	_material.set_shader_parameter(&"radius", lerpf(0.75, 0.3, x))
	if flash:
		_flash_left -= 1
