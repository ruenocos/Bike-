class_name StageProgress
extends Control
## Thin bar along the bottom of the HUD: the stage from start to finish, the
## collapse eating it from the left (red), and you (white marker).

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
	draw_rect(Rect2(0.0, y - 3.0, w, 6.0), Color(1.0, 1.0, 1.0, 0.25))
	var collapse_x: float = clampf(collapse / stage_length, 0.0, 1.0) * w
	draw_rect(Rect2(0.0, y - 4.0, collapse_x, 8.0), Color(1.0, 0.25, 0.1, 0.9))
	var finish_x: float = clampf(finish / stage_length, 0.0, 1.0) * w
	draw_rect(Rect2(finish_x - 2.0, 0.0, 4.0, h), Color(1.0, 1.0, 1.0, 0.9))
	var player_x: float = clampf(player / stage_length, 0.0, 1.0) * w
	draw_circle(Vector2(player_x, y), h * 0.5, Color(1.0, 1.0, 1.0))
	draw_circle(Vector2(player_x, y), h * 0.5 - 3.0, Color(1.0, 0.8, 0.2))
