@tool
class_name SpeedDial
extends Control
## Half-round speed gauge behind the speed number (v0.31): an ink track,
## a mustard arc up to the current speed (red past `redline`) and a needle.
## Drawn in code so it scales with the control; colours are exports.

@export_range(0.0, 1.0, 0.01) var ratio: float = 0.6:
	set(value):
		ratio = clampf(value, 0.0, 1.0)
		queue_redraw()
## Past this share of top speed the arc turns red.
@export_range(0.0, 1.0, 0.01) var redline: float = 0.85
@export_range(2.0, 60.0, 1.0, "suffix:px") var thickness: float = 22.0
@export var track_color: Color = Color(0.078, 0.078, 0.086, 0.85)
@export var fill_color: Color = Color(0.949, 0.718, 0.02, 1.0)
@export var hot_color: Color = Color(0.898, 0.196, 0.176, 1.0)
@export var needle_color: Color = Color(0.957, 0.945, 0.91, 1.0)


func _draw() -> void:
	var center: Vector2 = Vector2(size.x * 0.5, size.y - thickness * 0.2)
	var radius: float = minf(size.x * 0.5, size.y) - thickness * 0.5
	draw_arc(center, radius, PI, TAU, 48, track_color, thickness + 10.0, true)
	var cold_end: float = minf(ratio, redline)
	if cold_end > 0.0:
		draw_arc(center, radius, PI, PI + PI * cold_end, 48, fill_color, thickness * 0.6, true)
	if ratio > redline:
		draw_arc(center, radius, PI + PI * redline, PI + PI * ratio, 24, hot_color, thickness * 0.6, true)
	# Tick marks every 10 %.
	for i: int in 11:
		var a: float = PI + PI * float(i) / 10.0
		var dir: Vector2 = Vector2(cos(a), sin(a))
		draw_line(center + dir * (radius + thickness * 0.5), center + dir * (radius + thickness * 0.5 - 8.0),
			needle_color * Color(1, 1, 1, 0.6), 2.0, true)
	var na: float = PI + PI * ratio
	var tip: Vector2 = center + Vector2(cos(na), sin(na)) * (radius + thickness * 0.3)
	draw_line(center, tip, needle_color, 5.0, true)
	draw_circle(center, 9.0, needle_color)
