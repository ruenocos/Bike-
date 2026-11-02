class_name UiMotion
extends RefCounted
## Shared UI motion (v0.31 Panzer Pop). Every move is short and lands hard:
## ease-out expo, no bounce-back except the slam's small overshoot.
## All tweens ignore Engine.time_scale, so they keep playing through the
## hit stop on perfect landings.

## Tape wipe: the control unrolls from its left edge (scale.x 0 -> 1).
static func tape_in(node: Control, time: float = 0.16, delay: float = 0.0) -> Tween:
	node.pivot_offset = Vector2(0.0, node.size.y * 0.5)
	node.scale = Vector2(0.0, 1.0)
	node.modulate.a = 1.0
	var tween: Tween = node.create_tween().set_ignore_time_scale(true)
	tween.tween_property(node, "scale", Vector2.ONE, time).set_delay(delay) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return tween


## Slam: the control drops in from `from_scale` with a little overshoot.
static func slam(node: Control, from_scale: float = 1.4, time: float = 0.2) -> Tween:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * from_scale
	node.modulate.a = 1.0
	var tween: Tween = node.create_tween().set_ignore_time_scale(true)
	tween.tween_property(node, "scale", Vector2.ONE, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


## Slides the control in from `offset` (pixels) with a fade, after `delay`.
static func slide_in(node: Control, offset: Vector2, time: float = 0.22, delay: float = 0.0) -> Tween:
	# Remember the resting place once, so re-opening mid-tween never drifts.
	if not node.has_meta(&"ui_home"):
		node.set_meta(&"ui_home", node.position)
	var target: Vector2 = node.get_meta(&"ui_home") as Vector2
	node.position = target + offset
	node.modulate.a = 0.0
	var tween: Tween = node.create_tween().set_ignore_time_scale(true).set_parallel(true)
	tween.tween_property(node, "position", target, time).set_delay(delay) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, time * 0.5).set_delay(delay)
	return tween


## A short scale kick (a number that just changed, a pip that filled).
static func kick(node: Control, amount: float = 0.18, time: float = 0.14) -> Tween:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * (1.0 + amount)
	var tween: Tween = node.create_tween().set_ignore_time_scale(true)
	tween.tween_property(node, "scale", Vector2.ONE, time) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return tween


## Menu entrance: the direct children of `container` slide in one after another.
static func stagger_children(container: Control, offset: Vector2 = Vector2(160.0, 0.0),
		step: float = 0.05, time: float = 0.24) -> void:
	var i: int = 0
	for child: Node in container.get_children():
		var c: Control = child as Control
		if c == null or not c.visible:
			continue
		slide_in(c, offset, time, step * i)
		i += 1


## Debrief / pause entrance: the colour band wipes in, the header slides in
## from the left, the panel rises (nodes named Band, Header, Panel).
static func open_menu(menu: Control) -> void:
	var band: Control = menu.get_node_or_null(^"Band") as Control
	if band != null:
		tape_in(band, 0.2)
	var header: Control = menu.get_node_or_null(^"Header") as Control
	if header != null:
		slide_in(header, Vector2(-260.0, 0.0), 0.26, 0.05)
	var panel: Control = menu.get_node_or_null(^"Panel") as Control
	if panel != null:
		slide_in(panel, Vector2(0.0, 80.0), 0.26, 0.1)
