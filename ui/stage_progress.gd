class_name StageProgress
extends Control
## Bar along the bottom of the HUD: the stage from start to finish, how far
## you are (filled), the collapse eating it from the left (red), you (marker)
## and "1.4 / 3.7 km" at the end (v0.9.1: the thin bar went unnoticed).

var stage_length: float = 1.0
var finish: float = 1.0
var player: float = 0.0
var collapse: float = 0.0


func set_values(new_length: float, new_finish: float, new_player: float, new_collapse: float) -> void:
	stage_length = maxf(new_length, 1.0)
	finish = new_finish
	player = new_player
	collapse = new_collapse
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var y: float = h * 0.5
	draw_rect(Rect2(0.0, y - 5.0, w, 10.0), Color(0.0, 0.0, 0.0, 0.35))
	var player_x0: float = clampf(player / stage_length, 0.0, 1.0) * w
	draw_rect(Rect2(0.0, y - 5.0, player_x0, 10.0), Color(1.0, 0.85, 0.45, 0.55))
	var collapse_x: float = clampf(collapse / stage_length, 0.0, 1.0) * w
	draw_rect(Rect2(0.0, y - 5.0, collapse_x, 10.0), Color(1.0, 0.25, 0.1, 0.95))
	var font: Font = get_theme_default_font()
	var text: String = "%.1f / %.1f km" % [player / 1000.0, finish / 1000.0]
	draw_string(font, Vector2(w + 14.0, y + 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(1.0, 1.0, 1.0, 0.9))
	var finish_x: float = clampf(finish / stage_length, 0.0, 1.0) * w
	draw_rect(Rect2(finish_x - 2.0, 0.0, 4.0, h), Color(1.0, 1.0, 1.0, 0.9))
	var player_x: float = clampf(player / stage_length, 0.0, 1.0) * w
	draw_circle(Vector2(player_x, y), h * 0.5, Color(1.0, 1.0, 1.0))
	draw_circle(Vector2(player_x, y), h * 0.5 - 3.0, Color(1.0, 0.8, 0.2))
