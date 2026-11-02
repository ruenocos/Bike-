@tool
class_name CelLook
extends RefCounted
## Turns imported models' StandardMaterial3D into eldskald's cel shader
## (vfx/cel, MIT): albedo colour + texture carry over, leaves / grass (alpha)
## get the cut-out version, and an optional inverted-hull outline pass.
## Converted materials are cached per source material, so a forest of the
## same tree shares a handful of materials. The toon light bands come from
## the global `diffuse_curve` (vfx/cel/diffuse_curve.tres, Project Settings >
## Shader Globals, with outline_color / outline_width).

const OPAQUE: Shader = preload("res://vfx/cel/cel-shader-base.gdshader")
const CUTOUT: Shader = preload("res://vfx/cel/cel-shader-cutout.gdshader")
const OUTLINE: Shader = preload("res://vfx/cel/outline.gdshader")

static var _cache: Dictionary[String, Material] = {}
## Coloured ink (v0.30): how much of a line is its surface's darkened colour
## (Biome.outline_local_mix, set per stage by BiomeLook).
static var outline_local_mix: float = 0.7
static var _outlines: Array[ShaderMaterial] = []
static var _white: ImageTexture


## Every MeshInstance3D under `root` gets cel materials (surface overrides).
## `tint` multiplies the colour (biomes: frosted, sun-bleached props).
static func apply(root: Node, outline: bool, tint: Color = Color.WHITE) -> void:
	if root is MeshInstance3D:
		var mi: MeshInstance3D = root as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, material_for(mi.mesh.surface_get_material(s), outline, tint))
	for child: Node in root.get_children():
		apply(child, outline, tint)


static func material_for(source: Material, outline: bool, tint: Color = Color.WHITE) -> Material:
	var key: String = "%d:%s:%s" % [source.get_instance_id() if source != null else 0, outline, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var bm: BaseMaterial3D = source as BaseMaterial3D
	var cut: bool = bm != null and bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = CUTOUT if cut else OPAQUE
	mat.set_shader_parameter(&"color", (bm.albedo_color if bm != null else Color(0.7, 0.7, 0.7)) * tint)
	mat.set_shader_parameter(&"base_texture", bm.albedo_texture if bm != null and bm.albedo_texture != null else _white_texture())
	mat.set_shader_parameter(&"specular", Color(0.15, 0.15, 0.15, 0.2))
	mat.set_shader_parameter(&"fresnel", Color(0.35, 0.28, 0.2, 0.25))
	if cut:
		mat.set_shader_parameter(&"alpha_cutoff", 0.5)
	if outline and not cut:
		mat.next_pass = _outline_material(mat)
	_cache[key] = mat
	return mat


static func _outline_material(surface: ShaderMaterial) -> ShaderMaterial:
	var line: ShaderMaterial = ShaderMaterial.new()
	line.shader = OUTLINE
	line.set_shader_parameter(&"color", surface.get_shader_parameter(&"color"))
	line.set_shader_parameter(&"base_texture", surface.get_shader_parameter(&"base_texture"))
	line.set_shader_parameter(&"local_mix", outline_local_mix)
	_outlines.append(line)
	return line


static func set_outline_local_mix(amount: float) -> void:
	outline_local_mix = amount
	for line: ShaderMaterial in _outlines:
		line.set_shader_parameter(&"local_mix", amount)


## A thicker ink line under `root` (pixels; the global outline_width is 2):
## the rider and things you can hit.
static func keep_outline(root: Node, width: float) -> void:
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).set_instance_shader_parameter(&"outline_min", width)
	for child: Node in root.get_children(true):
		keep_outline(child, width)


static func _white_texture() -> ImageTexture:
	if _white == null:
		var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white
