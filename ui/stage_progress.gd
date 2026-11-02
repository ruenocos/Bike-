@tool
class_name StageProgress
extends Control
## Bar along the bottom of the HUD: the stage from start to finish, how far
## you are (filled), the collapse eating it from the left (red), you (marker)
## and "1.4 / 3.7 KM" on an ink plate at the end (v0.31: the bare label was
## unreadable on bright snow). Drawn as a skewed tape to match the theme.

@export_range(0.0, 1.0, 0.01) var skew: float = 0.6
@export var track_color: Color = Color(0.078, 0.078, 0.086, 0.75)
@export var done_color: Color = Color(0.243, 0.357, 0.227, 1.0)
@export var collapse_color: Color = Color(0.898, 0.196, 0.176, 1.0)
@export var marker_color: Color = Color(0.949, 0.718, 0.02, 1.0)
@export var text_color: Color = Color(0.957, 0.945, 0.91, 1.0)
@export var font: Font
@export_range(8, 64) var font_size: int = 26

var stage_length: float = 3600.0
var finish: float = 3600.0
var player: float = 700.0
var collapse: float = 200.0


func set_values(new_length: float, new_finish: float, new_player: float, new_collapse: float) -> void:
	stage_length = maxf(new_length, 1.0)
	finish = new_finish
	player = new_player
	collapse = new_collapse
	queue_redraw()


## A parallelogram from x0 to x1 over the full height (leaning right).
func _tape(x0: float, x1: float, y0: float, y1: float, color: Color) -> void:
	if x1 <= x0:
		return
	var lean: float = (y1 - y0) * skew
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0 + lean, y0), Vector2(x1 + lean, y0), Vector2(x1, y1), Vector2(x0, y1)]), color)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var y0: float = h * 0.3
	var y1: float = h * 0.7
	_tape(0.0, w, y0, y1, track_color)
	var player_x: float = clampf(player / stage_length, 0.0, 1.0) * w
	_tape(0.0, player_x, y0, y1, done_color)
	var collapse_x: float = clampf(collapse / stage_length, 0.0, 1.0) * w
	_tape(0.0, collapse_x, y0, y1, collapse_color)
	# Quarter ticks.
	for i: int in [1, 2, 3]:
		var tx: float = w * i / 4.0
		_tape(tx - 1.0, tx + 1.0, y0, y1, text_color * Color(1, 1, 1, 0.35))
	var finish_x: float = clampf(finish / stage_length, 0.0, 1.0) * w
	_tape(finish_x - 3.0, finish_x + 3.0, 0.0, h, text_color)
	# You: a mustard slash sticking out of the bar.
	_tape(player_x - 6.0, player_x + 6.0, -h * 0.15, h * 1.15, marker_color)
	# Distance plate.
	var f: Font = font if font != null else get_theme_default_font()
	var text: String = "%.1f / %.1f KM" % [player / 1000.0, finish / 1000.0]
	var text_w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var px: float = w + 26.0
	var plate_h: float = font_size * 1.25
	var py: float = h * 0.5 - plate_h * 0.5
	var lean: float = plate_h * 0.28
	draw_colored_polygon(PackedVector2Array([
		Vector2(px + lean, py), Vector2(px + text_w + 32.0 + lean, py),
		Vector2(px + text_w + 32.0, py + plate_h), Vector2(px, py + plate_h)]), track_color * Color(1, 1, 1, 1.25))
	draw_string(f, Vector2(px + 16.0 + lean * 0.5, py + plate_h * 0.5 + font_size * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)
