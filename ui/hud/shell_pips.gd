@tool
class_name ShellPips
extends Control
## Combo multiplier as a row of shells (v0.31): `count` filled out of `max_count`.
## A shell is a rounded-top bar; filling a new one kicks it.

@export_range(0, 20) var count: int = 3:
	set(value):
		if value > count and is_inside_tree() and not Engine.is_editor_hint():
			_kick = 1.0
		count = clampi(value, 0, max_count)
		queue_redraw()
@export_range(1, 20) var max_count: int = 8:
	set(value):
		max_count = maxi(value, 1)
		queue_redraw()
@export_range(4.0, 40.0, 1.0, "suffix:px") var shell_width: float = 12.0
@export_range(2.0, 20.0, 1.0, "suffix:px") var gap: float = 6.0
@export var filled_color: Color = Color(0.949, 0.718, 0.02, 1.0)
@export var empty_color: Color = Color(0.078, 0.078, 0.086, 0.55)

var _kick: float = 0.0


func _process(delta: float) -> void:
	if _kick > 0.0:
		_kick = maxf(_kick - delta * 6.0, 0.0)
		queue_redraw()


func _draw() -> void:
	var h: float = size.y
	for i: int in max_count:
		var x: float = i * (shell_width + gap)
		var filled: bool = i < count
		var grow: float = _kick * 6.0 if filled and i == count - 1 else 0.0
		var rect: Rect2 = Rect2(x - grow * 0.5, -grow, shell_width + grow, h + grow)
		var color: Color = filled_color if filled else empty_color
		var r: float = rect.size.x * 0.5
		draw_rect(Rect2(rect.position.x, rect.position.y + r, rect.size.x, rect.size.y - r), color)
		draw_circle(Vector2(rect.position.x + r, rect.position.y + r), r, color)
		if filled:
			# Casing band near the base.
			draw_rect(Rect2(rect.position.x, rect.end.y - 6.0, rect.size.x, 3.0), Color(0.078, 0.078, 0.086, 0.5))
