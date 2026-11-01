extends CanvasLayer
## Speed lines overlay. Child of Player. Fades the shader in between
## speed_lines_threshold and speed_lines_full (x max_speed), eased out,
## smoothed over speed_lines_fade_time, and gets denser as it does. A boost
## (Player.flash_boost) flashes them for speed_lines_boost_time.
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
	# Ease out: lines show up quickly past the threshold, then settle. Held
	# speed only gets a faint version (cruising sits near top speed, and full
	# lines all the time hid the world, v0.26); boosts flash the full ones.
	var target: float = (1.0 - (1.0 - x) * (1.0 - x)) * t.speed_lines_steady
	# A boost flashes them whatever the speed.
	if t.speed_lines_boost_time > 0.0 and player.boost_timer > 0.0:
		target = maxf(target, 0.6 * player.boost_timer / t.speed_lines_boost_time)
	_alpha = lerpf(_alpha, target, 1.0 - exp(-delta / maxf(t.speed_lines_fade_time / 3.0, 0.0001)))
	rect.visible = _alpha > 0.005
	_material.set_shader_parameter(&"intensity", _alpha * t.speed_lines_max_alpha)
	# Denser near max speed, not just brighter.
	_material.set_shader_parameter(&"density", lerpf(t.speed_lines_density_min, t.speed_lines_density_max, _alpha))
	# Keep the middle (the rider and the way ahead) clear.
	_material.set_shader_parameter(&"inner_radius", t.speed_lines_clear_radius)
