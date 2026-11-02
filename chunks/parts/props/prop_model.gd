@tool
class_name PropModel
extends Node3D
## The look of a prop (tree, rock, log, fence): one of `variants` (picked
## from the prop's position, so the same spot always gets the same model),
## scaled, with the cel look. Collision stays on the prop's own simple
## shape; this node is visual only. The model is a generated child that
## isn't saved: change the variants / scale here and it updates.

## Set by the game for the current stage's biome (v0.12): trees and rocks
## swap to the biome's models and every prop takes its tint.
static var biome: Biome

## What this is, so a biome can swap the model ("none" keeps `variants`).
@export_enum("none", "tree", "rock") var kind: String = "none"
## Model scenes to pick from (.gltf / .glb).
@export var variants: Array[PackedScene] = []:
	set(v):
		variants = v
		_rebuild()
## Scale applied to the model.
@export var model_scale: Vector3 = Vector3.ONE:
	set(v):
		model_scale = v
		_rebuild()
## Random extra rotation around up (deg, +/-), also picked from the position.
@export_range(0.0, 180.0, 1.0) var yaw_jitter: float = 180.0
## Draw the inverted-hull outline (costs a second pass; trees and rocks).
@export var outline: bool = true:
	set(v):
		outline = v
		_rebuild()
## Ink line thickness on logs, fences and boulders (px; not scenery trees and
## rocks), so what you can hit stands out (v0.30).
@export_range(0.0, 8.0, 0.25) var hazard_outline: float = 3.0
## Trees shorter than this are "crushable": the tank flattens them (v0.31).
@export_range(0.0, 40.0, 0.5, "suffix:m") var small_tree_height: float = 7.0
## A soft dark blob on the ground under it (v0.27; strength from the biome).
@export var contact_shadow: bool = true
## Footprint of that blob compared with the model's own (1.3 = a bit wider).
@export_range(0.5, 3.0, 0.05) var contact_shadow_scale: float = 1.3
## Small per-prop colour shifts (v0.27, picked from the position) so a
## forest isn't one flat colour: value +/- this, hue nudged warm or cool.
@export_range(0.0, 0.2, 0.01) var color_jitter: float = 0.04
## Wind sway for trees (v0.28, visual only: vfx/cel/includes/sway.gdshaderinc).
## Offset = this x height^2 (m), so 0.003 moves a 10 m top ~0.3 m.
@export_range(0.0, 0.02, 0.0005) var tree_sway: float = 0.003

static var _blob: GradientTexture2D
## Off with `-- --debug-nocontact` (frame-time checks).
static var contact_shadows_on: bool = true
## Contact-shadow decals alive right now (budget check, --print-stage).
static var contact_shadow_count: int = 0

var _model: Node3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _model != null:
		_model.free()
		_model = null
	if variants.is_empty():
		return
	var pool: Array[PackedScene] = variants
	var size: float = 1.0
	var tint: Color = Color.WHITE
	if biome != null and not Engine.is_editor_hint():
		tint = biome.prop_tint
		if kind == "tree" and not biome.trees.is_empty():
			pool = biome.trees
			size = biome.tree_scale
		elif kind == "rock" and not biome.rocks.is_empty():
			pool = biome.rocks
	var spot: Vector3 = global_position
	var h: int = hash(Vector3i(roundi(spot.x * 10.0), roundi(spot.y * 10.0), roundi(spot.z * 10.0)))
	var scene: PackedScene = pool[absi(h) % pool.size()]
	if scene == null:
		return
	_model = scene.instantiate() as Node3D
	_model.scale = model_scale * size
	_model.rotation.y = deg_to_rad(float(posmod(h >> 3, 360) - 180) / 180.0 * yaw_jitter)
	add_child(_model, false, Node.INTERNAL_MODE_BACK)
	if not Engine.is_editor_hint() and color_jitter > 0.0:
		# Three steps each way, so the converted materials are still shared.
		var v: float = float(posmod(h >> 11, 3) - 1)
		var w: float = float(posmod(h >> 13, 3) - 1)
		tint = tint * Color(1.0 + w * color_jitter * 0.75, 1.0, 1.0 - w * color_jitter * 0.75) * (1.0 + v * color_jitter)
		tint.a = 1.0
	CelLook.apply(_model, outline, tint)
	if kind == "none":
		CelLook.keep_outline(_model, hazard_outline)
	if kind == "tree" and _model_aabb(_model, Transform3D.IDENTITY).size.y < small_tree_height:
		get_parent().add_to_group(&"crushable")
	if kind == "tree" and tree_sway > 0.0:
		_set_sway(_model, tree_sway)
	if contact_shadow and contact_shadows_on and biome != null and biome.contact_shadow > 0.0 and not Engine.is_editor_hint():
		_add_contact_shadow()


func _add_contact_shadow() -> void:
	var box: AABB = _model_aabb(_model, Transform3D.IDENTITY)
	if box.size == Vector3.ZERO:
		return
	if _blob == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_blob = GradientTexture2D.new()
		_blob.gradient = g
		_blob.fill = GradientTexture2D.FILL_RADIAL
		_blob.fill_from = Vector2(0.5, 0.5)
		_blob.fill_to = Vector2(1.0, 0.5)
		_blob.width = 64
		_blob.height = 64
	var d: Decal = Decal.new()
	var size: float = maxf(box.size.x, box.size.z)
	# Small stones / bushes don't need one (keeps the decal count down:
	# Forward+ clusters up to 512 lights + decals in view).
	if size < 1.0:
		return
	var foot: float = minf(size, 9.0) * contact_shadow_scale
	d.size = Vector3(foot, 2.5, foot)
	d.position = Vector3(box.get_center().x, box.position.y, box.get_center().z)
	d.texture_albedo = _blob
	d.modulate = Color(biome.shadow_tint.darkened(0.6), biome.contact_shadow)
	# Not on the rider (layer 2) riding past or hopping a log.
	d.cull_mask = 1
	d.distance_fade_enabled = true
	d.distance_fade_begin = 70.0
	d.distance_fade_length = 20.0
	add_child(d, false, Node.INTERNAL_MODE_BACK)
	contact_shadow_count += 1
	d.tree_exiting.connect(func() -> void: contact_shadow_count -= 1)


## Flattened by the tank: squash into the ground and go.
func crush() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.25, 0.08, 1.25), 0.08)
	tween.tween_property(self, "scale", Vector3(1.25, 0.0, 1.25), 0.5)
	tween.tween_callback(queue_free)


func _set_sway(node: Node, amount: float) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).set_instance_shader_parameter(&"sway", amount)
	for child: Node in node.get_children():
		_set_sway(child, amount)


## The model's bounds in this node's space (all its meshes together).
func _model_aabb(node: Node, xf: Transform3D) -> AABB:
	var box: AABB = AABB()
	var here: Transform3D = xf * (node as Node3D).transform if node is Node3D else xf
	if node is MeshInstance3D:
		box = here * (node as MeshInstance3D).get_aabb()
	for child: Node in node.get_children():
		var b: AABB = _model_aabb(child, here)
		if b.size != Vector3.ZERO:
			box = b if box.size == Vector3.ZERO else box.merge(b)
	return box
