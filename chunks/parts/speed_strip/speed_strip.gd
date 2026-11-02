@tool
class_name SpeedStrip
extends Node3D
## A speed ramp (v0.34): a long strip of glowing chevrons painted onto the
## ground. Riding over it pushes you along its -Z: a kick on the way in, then
## steady acceleration for as long as you stay on it. Placed on the run-up of
## kickers so they throw you into a big air. Big, bright and readable from far
## away (Haste-style): the thing you aim for, instead of small clutter.
##
## The node's -Z is the direction of the push; place it at the back end of the
## strip. Each chevron finds the ground under it when the stage loads (so the
## strip follows any bump), and you count as "on it" while you're over the
## strip and close to that ground.
##
## Godot note: a Decal projects a texture down its own -Y onto whatever is
## below, inside its box (`paint_depth` above and below the chevron).

## Strip length along -Z (m).
@export_range(10.0, 300.0, 1.0, "suffix:m") var length: float = 70.0:
	set(v):
		length = v
		_rebuild()
## Strip width (m).
@export_range(2.0, 40.0, 0.5, "suffix:m") var width: float = 9.0:
	set(v):
		width = v
		_rebuild()
## One chevron every this many metres.
@export_range(2.0, 30.0, 0.5, "suffix:m") var chevron_spacing: float = 7.0:
	set(v):
		chevron_spacing = v
		_rebuild()
## How far above and below each chevron the paint reaches (m).
@export_range(0.5, 20.0, 0.5, "suffix:m") var paint_depth: float = 4.0:
	set(v):
		paint_depth = v
		_rebuild()
@export var color: Color = Color(0.25, 0.95, 1.0):
	set(v):
		color = v
		_rebuild()

@export_group("Push")
## Speed added the moment you ride onto it (m/s).
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var entry_kick: float = 5.0
## Acceleration while on it (m/s²), never past the vehicle's max_speed.
@export_range(0.0, 80.0, 0.5, "suffix:m/s²") var accel: float = 22.0
## Only pushes while you head roughly along it (dot of directions).
@export_range(-1.0, 1.0, 0.05) var min_alignment: float = 0.3
## You count as on it up to this high above its ground (m): skipping over a
## bump on the strip still counts, a high flight over it doesn't.
@export_range(0.5, 20.0, 0.5, "suffix:m") var reach_height: float = 4.0
## Line assist: while you head along it, it steers you gently onto its
## centre line (m/s² of sideways pull), so the kicker in front is lined up.
## Your own steering still wins.
@export_range(0.0, 200.0, 1.0, "suffix:m/s²") var line_assist: float = 40.0
## ...starting this far before it, and up to this far past its front end
## (the kicker's run-up).
@export_range(0.0, 60.0, 1.0, "suffix:m") var assist_before: float = 10.0
@export_range(0.0, 60.0, 1.0, "suffix:m") var assist_beyond: float = 20.0
## The assist only helps while you head this much along it (dot of directions).
@export_range(-1.0, 1.0, 0.05) var assist_alignment: float = 0.8

@export_group("Look")
## Chase light: a bright band runs forward along the chevrons this fast (m/s).
@export_range(0.0, 200.0, 1.0, "suffix:m/s") var chase_speed: float = 45.0
## Chevron glow when idle and at the bright band.
@export_range(0.0, 8.0, 0.1) var glow_idle: float = 0.6
@export_range(0.0, 16.0, 0.1) var glow_peak: float = 3.0

const CHEVRON: Texture2D = preload("res://chunks/parts/speed_strip/chevron.png")

var _chevrons: Array[Decal] = []
## Ground height (global y) under each chevron, filled by _settle().
var _ground: PackedFloat32Array = PackedFloat32Array()
var _player: Player
var _on: bool = false
var _kicked: bool = false
var _time: float = 0.0


func _ready() -> void:
	add_to_group(&"speed_strips")
	_rebuild()
	if not Engine.is_editor_hint():
		_settle.call_deferred()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c: Node in get_children(true):
		if c.has_meta(&"speed_strip_part"):
			c.free()
	_chevrons.clear()
	_ground.clear()
	var count: int = maxi(1, int(length / chevron_spacing))
	for i: int in count:
		var d: Decal = Decal.new()
		d.set_meta(&"speed_strip_part", true)
		d.size = Vector3(width, paint_depth * 2.0, minf(chevron_spacing * 0.8, width * 0.7))
		d.position = Vector3(0.0, 0.0, -(i + 0.5) * length / count)
		d.texture_albedo = CHEVRON
		d.texture_emission = CHEVRON
		d.modulate = color
		d.emission_energy = glow_idle
		d.upper_fade = 0.1
		d.lower_fade = 0.1
		d.cull_mask = 1
		d.distance_fade_enabled = true
		d.distance_fade_begin = 260.0
		d.distance_fade_length = 60.0
		add_child(d, false, Node.INTERNAL_MODE_BACK)
		_chevrons.append(d)


## Drops each chevron onto the ground under it (terrain collision is ready a
## couple of physics frames after the chunk spawns).
func _settle() -> void:
	for i: int in 2:
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	_ground.resize(_chevrons.size())
	for i: int in _chevrons.size():
		var d: Decal = _chevrons[i]
		var p: Vector3 = d.global_position
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 60.0, p + Vector3.DOWN * 80.0, 1)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			p.y = (hit["position"] as Vector3).y
			d.global_position = p
		_ground[i] = p.y


func _physics_process(delta: float) -> void:
	_time += delta
	_animate()
	if Engine.is_editor_hint():
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	var forward: Vector3 = -global_basis.z.normalized()
	var flat: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()
	var right: Vector3 = Vector3(-flat.z, 0.0, flat.x)
	var rel: Vector3 = _player.global_position - global_position
	var along: float = rel.dot(forward)
	var side: float = rel.dot(right)
	var going: Vector3 = _player.velocity.normalized() if _player.velocity.length() > 1.0 else forward
	var aligned: bool = going.dot(forward) >= min_alignment
	var near: bool = absf(side) < width * 0.5 + 3.0 and _height_above(along) < reach_height
	# Line assist from a little before the strip to the kicker's run-up.
	# Only for a rider who is really taking it: on the strip's width and
	# heading along it (riders just crossing it keep their line).
	var taking: bool = absf(side) < width * 0.5 + 1.0 and going.dot(forward) >= assist_alignment
	if taking and near and along > -assist_before and along < length + assist_beyond and line_assist > 0.0 and _player.is_grounded():
		var target: Vector3 = global_position + forward * minf(along + 25.0, length + assist_beyond + 10.0)
		var to: Vector3 = target - _player.global_position
		var pull: Vector3 = to - going * to.dot(going)
		pull.y = 0.0
		if pull.length() > 0.15:
			_player.add_side_pull(pull, line_assist * clampf(pull.length() / 3.0, 0.0, 1.0))
	var on: bool = aligned and near and along >= 0.0 and along <= length and absf(side) <= width * 0.5 + 0.5
	if not on:
		if along < 0.0 or along > length or absf(side) > width:
			_kicked = false
		_on = false
		return
	_on = true
	var t: PlayerTuning = _player.tuning
	var add: float = accel * delta
	if not _kicked:
		_kicked = true
		add += entry_kick
		_player.flash_boost()
		Events.speed_gained.emit(entry_kick)
	if _player.is_grounded():
		_player.speed = minf(_player.speed + add, t.max_speed)
	else:
		# In the air the vehicle moves by its velocity: push that along the strip.
		var along_v: float = _player.velocity.dot(flat)
		if along_v < t.max_speed:
			_player.velocity += flat * minf(add, t.max_speed - along_v)


## Rider height above the strip's ground at `along` (m); INF off the strip.
func _height_above(along: float) -> float:
	if _ground.is_empty() or along < -assist_before - 5.0 or along > length + assist_beyond + 5.0:
		return INF
	var f: float = clampf(along / length * _ground.size() - 0.5, 0.0, _ground.size() - 1.0)
	var i: int = int(f)
	var g: float = lerpf(_ground[i], _ground[mini(i + 1, _ground.size() - 1)], f - i)
	return _player.global_position.y - g


func _animate() -> void:
	if _chevrons.is_empty():
		return
	# A bright band runs forward (faster while you ride it).
	var run: float = chase_speed * (1.8 if _on else 1.0)
	var head: float = fposmod(_time * run, length + 20.0)
	for d: Decal in _chevrons:
		var k: float = clampf(1.0 - absf(-d.position.z - head) / 12.0, 0.0, 1.0)
		d.emission_energy = lerpf(glow_idle, glow_peak, k * k)
